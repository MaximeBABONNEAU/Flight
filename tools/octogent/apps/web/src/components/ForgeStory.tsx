import { useEffect, useState } from "react";

import { buildForgeStoryUrl, buildStudioStatusUrl } from "../runtime/runtimeEndpoints";

// ForgeStory — Plain-language narrative panel for the "Lance + oublie" user.
// When they re-open the dashboard 4-8h later, they want to see in PROSE what
// happened: how long the forge has run, what the director is doing, what got
// committed. Counters in chips don't convey that. This component fetches
// recent git activity + studio status and renders a single narrative block
// + a list of last commits with relative timestamps.

const STORY_POLL_MS = 15_000;
const STATUS_POLL_MS = 8_000;

interface RecentCommit {
  sha: string;
  subject: string;
  ts: number;
  agoSec: number;
}

interface ForgeStorySnapshot {
  now: number;
  recentCommits: ReadonlyArray<RecentCommit>;
  commitsLast24h: number;
  gitError: string | null;
}

interface StudioStatusSnapshot {
  state: string;
  startedAtIso?: string | null;
  uptimeSeconds?: number | null;
  workerCount?: number | null;
  cycleNumber?: number | null;
  lastError?: string | null;
}

const formatRelative = (sec: number): string => {
  if (sec < 5) return "just now";
  if (sec < 60) return `${sec}s ago`;
  const mins = Math.floor(sec / 60);
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  const minPart = mins % 60;
  if (hours < 24) {
    return minPart > 0 ? `${hours}h ${minPart}m ago` : `${hours}h ago`;
  }
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
};

const formatUptime = (sec: number): string => {
  if (sec < 60) return `${sec}s`;
  const mins = Math.floor(sec / 60);
  if (mins < 60) return `${mins}m`;
  const hours = Math.floor(mins / 60);
  const minPart = mins % 60;
  return minPart > 0 ? `${hours}h ${minPart}m` : `${hours}h`;
};

const fetchJsonOrNull = async <T,>(url: string): Promise<T | null> => {
  try {
    const response = await fetch(url, {
      method: "GET",
      headers: { Accept: "application/json" },
      cache: "no-store",
    });
    if (!response.ok) return null;
    // Validate the JSON envelope: reject non-object payloads and the API's
    // generic error shape `{ error: "..." }` so a 5xx-with-body doesn't
    // satisfy the unsafe `as T` cast and crash the renderer downstream.
    const json: unknown = await response.json();
    if (typeof json !== "object" || json === null || "error" in json) return null;
    return json as T;
  } catch {
    return null;
  }
};

// Compute "ago" from the client's current clock + the commit unix-ts. This
// keeps the display correct when the panel is stale (e.g. fetch failed and
// the last good payload is now 30 minutes old — server's agoSec from then
// would still read "0m ago"). Updates every 30s via a tick state.
const computeAgoSec = (commitTsSec: number, nowSec: number): number =>
  Math.max(0, nowSec - commitTsSec);

const buildHeadline = (
  status: StudioStatusSnapshot | null,
  story: ForgeStorySnapshot | null,
  nowSec: number,
): string => {
  const parts: string[] = [];
  if (status && typeof status.uptimeSeconds === "number" && status.uptimeSeconds > 0) {
    parts.push(`Forge running ${formatUptime(status.uptimeSeconds)}`);
  } else if (status) {
    parts.push(`Forge ${status.state}`);
  } else {
    parts.push("Forge state unknown");
  }
  if (status && typeof status.cycleNumber === "number" && status.cycleNumber > 0) {
    parts.push(`Cycle #${status.cycleNumber}`);
  }
  if (status && typeof status.workerCount === "number") {
    const w = status.workerCount;
    parts.push(w === 0 ? "no workers" : w === 1 ? "1 worker" : `${w} workers`);
  }
  if (story && story.commitsLast24h > 0) {
    parts.push(`${story.commitsLast24h} commits in last 24h`);
  } else if (story && story.recentCommits.length > 0) {
    const latest = story.recentCommits[0];
    if (latest) parts.push(`last commit ${formatRelative(computeAgoSec(latest.ts, nowSec))}`);
  }
  return parts.join(" · ");
};

const TICK_MS = 30_000; // Re-render relative timestamps every 30s.

export const ForgeStory = () => {
  const [story, setStory] = useState<ForgeStorySnapshot | null>(null);
  const [status, setStatus] = useState<StudioStatusSnapshot | null>(null);
  // Drive a periodic re-render so "5m ago" advances even when no new fetch
  // has succeeded. Stored as unix seconds so it can feed computeAgoSec.
  const [nowSec, setNowSec] = useState<number>(() => Math.floor(Date.now() / 1000));

  useEffect(() => {
    const tick = window.setInterval(() => {
      setNowSec(Math.floor(Date.now() / 1000));
    }, TICK_MS);
    return () => window.clearInterval(tick);
  }, []);

  useEffect(() => {
    let disposed = false;
    let storyInflight = false;

    const refreshStory = async () => {
      if (disposed || storyInflight) return;
      storyInflight = true;
      try {
        const data = await fetchJsonOrNull<ForgeStorySnapshot>(buildForgeStoryUrl());
        if (!disposed && data) setStory(data);
      } finally {
        storyInflight = false;
      }
    };

    void refreshStory();
    const timer = window.setInterval(() => {
      void refreshStory();
    }, STORY_POLL_MS);

    return () => {
      disposed = true;
      window.clearInterval(timer);
    };
  }, []);

  useEffect(() => {
    let disposed = false;
    let statusInflight = false;

    const refreshStatus = async () => {
      if (disposed || statusInflight) return;
      statusInflight = true;
      try {
        const data = await fetchJsonOrNull<StudioStatusSnapshot>(buildStudioStatusUrl());
        if (!disposed && data) setStatus(data);
      } finally {
        statusInflight = false;
      }
    };

    void refreshStatus();
    const timer = window.setInterval(() => {
      void refreshStatus();
    }, STATUS_POLL_MS);

    return () => {
      disposed = true;
      window.clearInterval(timer);
    };
  }, []);

  // Re-derive headline at render so the "last commit Xm ago" advances with
  // the tick state, not just on poll completion.
  const headline = buildHeadline(status, story, nowSec);
  const commits = story?.recentCommits ?? [];
  const hasCommits = commits.length > 0;
  const showGitError = story?.gitError;

  const isStudioRunning = status?.state === "running";

  return (
    <section
      className="forge-story"
      data-running={String(isStudioRunning)}
      aria-label="Forge activity narrative"
      style={{
        margin: "8px 16px 0",
        padding: "14px 18px",
        borderRadius: "8px",
        background: "rgba(20, 14, 6, 0.55)",
        fontFamily: "Georgia, 'Cormorant Garamond', serif",
        color: "rgba(255, 245, 220, 0.92)",
        lineHeight: 1.45,
      }}
    >
      <div
        style={{
          fontSize: "13px",
          fontWeight: 600,
          letterSpacing: "0.03em",
          color: "rgba(214, 162, 26, 0.95)",
          marginBottom: hasCommits || showGitError ? "10px" : "0",
        }}
      >
        {headline || "Awaiting forge signal…"}
      </div>

      {showGitError ? (
        <div
          style={{
            fontSize: "11px",
            opacity: 0.6,
            fontStyle: "italic",
          }}
        >
          git unavailable: {story?.gitError}
        </div>
      ) : hasCommits ? (
        <ul
          style={{
            listStyle: "none",
            margin: 0,
            padding: 0,
            display: "flex",
            flexDirection: "column",
            gap: "4px",
          }}
        >
          {commits.slice(0, 5).map((c) => (
            <li
              key={c.sha}
              style={{
                display: "grid",
                gridTemplateColumns: "62px 78px 1fr",
                gap: "10px",
                alignItems: "baseline",
                fontSize: "12px",
              }}
            >
              <code
                style={{
                  color: "rgba(126, 200, 80, 0.85)",
                  fontFamily: "Consolas, Menlo, monospace",
                  fontSize: "11px",
                  letterSpacing: "0.02em",
                }}
              >
                {c.sha}
              </code>
              <span style={{ opacity: 0.55, fontVariantNumeric: "tabular-nums" }}>
                {formatRelative(computeAgoSec(c.ts, nowSec))}
              </span>
              <span
                style={{
                  whiteSpace: "nowrap",
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                }}
                title={c.subject}
              >
                {c.subject}
              </span>
            </li>
          ))}
        </ul>
      ) : null}
    </section>
  );
};
