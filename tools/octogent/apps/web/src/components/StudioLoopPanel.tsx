import { useEffect, useMemo, useState } from "react";

type StudioStatus = {
  state: "idle" | "starting" | "running" | "stopping";
  directorTerminalId?: string;
  startedAt?: string;
  workerCount?: number;
  workerTerminalIds: string[];
};

type TerminalSnapshot = {
  terminalId: string;
  tentacleId?: string;
  tentacleName?: string;
  studioRole?: "director" | "worker";
  lifecycleState?: "running" | "stopped";
  lifecycleReason?: string;
  agentRuntimeState?: string;
  parentTerminalId?: string;
  createdAt?: string;
  endedAt?: string;
};

const POLL_INTERVAL_MS = 3_000;
const STUDIO_TENTACLE_ID = "studio";

const formatRelativeTime = (iso?: string): string => {
  if (!iso) return "";
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "";
  const elapsedSec = Math.max(0, Math.floor((Date.now() - date.getTime()) / 1000));
  if (elapsedSec < 60) return `${elapsedSec}s ago`;
  const elapsedMin = Math.floor(elapsedSec / 60);
  if (elapsedMin < 60) return `${elapsedMin}m ago`;
  const elapsedHours = Math.floor(elapsedMin / 60);
  return `${elapsedHours}h ${elapsedMin % 60}m ago`;
};

const formatElapsed = (iso?: string): string => {
  if (!iso) return "";
  const elapsedSec = Math.max(0, Math.floor((Date.now() - new Date(iso).getTime()) / 1000));
  const min = Math.floor(elapsedSec / 60);
  const sec = elapsedSec % 60;
  if (min === 0) return `${sec}s`;
  if (min < 60) return `${min}m ${sec}s`;
  const h = Math.floor(min / 60);
  return `${h}h ${min % 60}m`;
};

const stateBadgeColor = (state?: string): string => {
  switch (state) {
    case "thinking":
    case "running":
      return "var(--forge-amber)";
    case "tool":
    case "tool_use":
      return "var(--forge-rune-blue, #4a90e2)";
    case "idle":
      return "var(--forge-aged-silver)";
    default:
      return "var(--forge-bronze)";
  }
};

const lifecycleColor = (reason?: string): string => {
  if (!reason) return "var(--forge-aged-silver)";
  if (reason.includes("kill") || reason.includes("operator")) return "var(--forge-blood)";
  if (reason.includes("complete") || reason.includes("exit")) return "var(--forge-moss)";
  return "var(--forge-aged-silver)";
};

export const StudioLoopPanel = () => {
  const [status, setStatus] = useState<StudioStatus | null>(null);
  const [snapshots, setSnapshots] = useState<TerminalSnapshot[]>([]);
  const [, setTick] = useState(0);

  useEffect(() => {
    let cancelled = false;
    const poll = async () => {
      try {
        const [statusRes, snapsRes] = await Promise.all([
          fetch("/api/studio/status", { cache: "no-store" }),
          fetch("/api/terminal-snapshots", { cache: "no-store" }),
        ]);
        if (cancelled) return;
        if (statusRes.ok) {
          const s = (await statusRes.json()) as StudioStatus;
          setStatus(s);
        }
        if (snapsRes.ok) {
          const raw = await snapsRes.json();
          const items: TerminalSnapshot[] = Array.isArray(raw)
            ? raw
            : ((raw?.terminals ?? raw?.snapshots ?? []) as TerminalSnapshot[]);
          setSnapshots(items.filter((t) => t.tentacleId === STUDIO_TENTACLE_ID));
        }
      } catch {
        // Silent — keep last good state.
      }
    };
    void poll();
    const interval = window.setInterval(poll, POLL_INTERVAL_MS);
    const ticker = window.setInterval(() => setTick((t) => t + 1), 1000);
    return () => {
      cancelled = true;
      window.clearInterval(interval);
      window.clearInterval(ticker);
    };
  }, []);

  const { activeWorkers, completedWorkers, director } = useMemo(() => {
    const active: TerminalSnapshot[] = [];
    const completed: TerminalSnapshot[] = [];
    let dir: TerminalSnapshot | null = null;
    for (const s of snapshots) {
      if (s.studioRole === "director" || s.terminalId === status?.directorTerminalId) {
        if (s.lifecycleState === "running") dir = s;
        continue;
      }
      if (s.lifecycleState === "running") {
        active.push(s);
      } else if (s.terminalId.startsWith("studio-worker-")) {
        completed.push(s);
      }
    }
    completed.sort((a, b) =>
      (b.endedAt ?? b.createdAt ?? "").localeCompare(a.endedAt ?? a.createdAt ?? ""),
    );
    return { activeWorkers: active, completedWorkers: completed.slice(0, 6), director: dir };
  }, [snapshots, status?.directorTerminalId]);

  const cycleNumber = useMemo(() => {
    const allWorkerNumbers = snapshots
      .map((s) => {
        const m = s.terminalId.match(/^studio-worker-(\d+)$/);
        return m ? Number.parseInt(m[1] ?? "0", 10) : null;
      })
      .filter((n): n is number => n !== null);
    if (allWorkerNumbers.length === 0) return 1;
    const maxN = Math.max(...allWorkerNumbers);
    return Math.floor(maxN / 3) + 1;
  }, [snapshots]);

  const isRunning = status?.state === "running";
  const isIdle = !status || status.state === "idle";

  if (isIdle && completedWorkers.length === 0) {
    return null;
  }

  return (
    <div
      style={{
        position: "fixed",
        right: 16,
        top: 90,
        bottom: 16,
        width: 360,
        zIndex: 100,
        background: "linear-gradient(180deg, rgba(45,31,15,0.95), rgba(15,12,8,0.97))",
        border: "1px solid var(--forge-bronze, #8c6a3a)",
        borderRadius: 4,
        boxShadow: "0 8px 32px rgba(0,0,0,0.6), inset 0 1px 0 rgba(214,162,26,0.2)",
        color: "var(--forge-parchment, #e8d9b8)",
        fontFamily: "'Cormorant Garamond', Georgia, serif",
        display: "flex",
        flexDirection: "column",
        overflow: "hidden",
      }}
    >
      <header
        style={{
          padding: "10px 14px",
          borderBottom: "1px solid var(--forge-bronze, #8c6a3a)",
          background: "linear-gradient(180deg, rgba(74,58,32,0.6), rgba(45,31,15,0.4))",
        }}
      >
        <div
          style={{
            fontFamily: "'Cinzel', Georgia, serif",
            fontSize: "0.85rem",
            fontWeight: 700,
            letterSpacing: "0.18em",
            color: "var(--forge-gold, #d6a21a)",
            textTransform: "uppercase",
            textShadow: "0 0 8px rgba(214,162,26,0.4)",
          }}
        >
          Studio Loop
        </div>
        <div
          style={{
            fontSize: "0.8rem",
            color: "var(--forge-aged-silver, #a89880)",
            marginTop: 4,
            display: "flex",
            justifyContent: "space-between",
          }}
        >
          <span>
            Cycle #{cycleNumber} · {activeWorkers.length} worker{activeWorkers.length === 1 ? "" : "s"}
          </span>
          <span>
            {isRunning && status?.startedAt ? formatElapsed(status.startedAt) : status?.state ?? "idle"}
          </span>
        </div>
      </header>

      {isRunning && activeWorkers.length === 0 && <div className="forge-startup-shimmer" />}

      <div style={{ flex: 1, overflowY: "auto", padding: "8px 0" }}>
        {director && (
          <Section title="Director" accent="var(--forge-gold)">
            <WorkerRow snapshot={director} />
          </Section>
        )}

        {isRunning && activeWorkers.length === 0 && director && (
          <StartupPhaseTracker startedAt={status?.startedAt} />
        )}

        {activeWorkers.length > 0 && (
          <Section title={`Active wave · ${activeWorkers.length}`} accent="var(--forge-amber)">
            {activeWorkers.map((w) => (
              <WorkerRow key={w.terminalId} snapshot={w} />
            ))}
          </Section>
        )}

        {completedWorkers.length > 0 && (
          <Section title="Completed (recent)" accent="var(--forge-moss, #4a7c59)">
            {completedWorkers.map((w) => (
              <WorkerRow key={w.terminalId} snapshot={w} dimmed />
            ))}
          </Section>
        )}

        {!isRunning && completedWorkers.length === 0 && (
          <div
            style={{
              padding: "20px 16px",
              fontStyle: "italic",
              color: "var(--forge-aged-silver, #a89880)",
              textAlign: "center",
            }}
          >
            Forge dormant — light it to begin a cycle.
          </div>
        )}
      </div>

      <footer
        style={{
          padding: "8px 14px",
          borderTop: "1px solid var(--forge-bronze, #8c6a3a)",
          fontSize: "0.7rem",
          letterSpacing: "0.1em",
          color: "var(--forge-aged-silver, #a89880)",
          fontFamily: "'Cinzel', serif",
          textTransform: "uppercase",
          textAlign: "center",
        }}
      >
        polling 3s · click a worker to open its terminal
      </footer>
    </div>
  );
};

const Section = ({
  title,
  accent,
  children,
}: {
  title: string;
  accent: string;
  children: React.ReactNode;
}) => (
  <section style={{ padding: "6px 14px 12px" }}>
    <h4
      style={{
        margin: "0 0 6px",
        fontFamily: "'Cinzel', serif",
        fontSize: "0.7rem",
        letterSpacing: "0.18em",
        textTransform: "uppercase",
        color: accent,
        fontWeight: 600,
      }}
    >
      {title}
    </h4>
    <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>{children}</div>
  </section>
);

const WorkerRow = ({
  snapshot,
  dimmed = false,
}: {
  snapshot: TerminalSnapshot;
  dimmed?: boolean;
}) => {
  const taskName = snapshot.tentacleName ?? snapshot.terminalId;
  const stateColor =
    snapshot.lifecycleState === "running"
      ? stateBadgeColor(snapshot.agentRuntimeState)
      : lifecycleColor(snapshot.lifecycleReason);
  const isRunning = snapshot.lifecycleState === "running";

  return (
    <div
      style={{
        padding: "6px 8px",
        borderLeft: `3px solid ${stateColor}`,
        background: dimmed ? "rgba(15,12,8,0.4)" : "rgba(45,31,15,0.4)",
        borderRadius: 2,
        opacity: dimmed ? 0.6 : 1,
        transition: "opacity 0.2s",
      }}
    >
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "baseline",
        }}
      >
        <span
          style={{
            fontFamily: "'Cinzel', serif",
            fontSize: "0.72rem",
            letterSpacing: "0.08em",
            color: "var(--forge-gold, #d6a21a)",
            textTransform: "uppercase",
          }}
        >
          {snapshot.terminalId.replace(/^studio-/, "")}
        </span>
        <span
          style={{
            fontSize: "0.65rem",
            color: stateColor,
            fontFamily: "'Cinzel', serif",
            letterSpacing: "0.1em",
            textTransform: "uppercase",
          }}
        >
          {isRunning ? snapshot.agentRuntimeState ?? "live" : snapshot.lifecycleReason ?? "stopped"}
        </span>
      </div>
      <div
        style={{
          fontSize: "0.85rem",
          color: dimmed ? "var(--forge-aged-silver, #a89880)" : "var(--forge-parchment, #e8d9b8)",
          marginTop: 2,
          fontFamily: "'Cormorant Garamond', Georgia, serif",
          fontStyle: "italic",
          lineHeight: 1.3,
        }}
      >
        {taskName.replace(/^Studio (Worker \d+|Director)\s*[—-]?\s*/, "") || taskName}
      </div>
      <div
        style={{
          fontSize: "0.65rem",
          color: "var(--forge-aged-silver, #a89880)",
          marginTop: 2,
        }}
      >
        {isRunning
          ? `started ${formatRelativeTime(snapshot.createdAt)}`
          : `ended ${formatRelativeTime(snapshot.endedAt ?? snapshot.createdAt)}`}
      </div>
    </div>
  );
};

const STARTUP_PHASES = [
  { label: "Booting Claude Code", delayS: 0 },
  { label: "Reading CLAUDE.md", delayS: 5 },
  { label: "Scanning progress.md", delayS: 12 },
  { label: "Building backlog", delayS: 20 },
  { label: "Planning wave", delayS: 30 },
  { label: "Spawning workers", delayS: 45 },
];

const StartupPhaseTracker = ({ startedAt }: { startedAt?: string | undefined }) => {
  const [, setTick] = useState(0);

  useEffect(() => {
    const t = window.setInterval(() => setTick((n) => n + 1), 1000);
    return () => window.clearInterval(t);
  }, []);

  const elapsedS = startedAt
    ? Math.max(0, Math.floor((Date.now() - new Date(startedAt).getTime()) / 1000))
    : 0;

  return (
    <div className="studio-startup-phase">
      {STARTUP_PHASES.map((phase) => {
        const done = elapsedS >= phase.delayS + 8;
        const active = !done && elapsedS >= phase.delayS;
        if (elapsedS < phase.delayS) return null;
        return (
          <div key={phase.label} className="studio-startup-phase-step">
            {done ? (
              <span className="studio-startup-check">&#10003;</span>
            ) : active ? (
              <span className="studio-startup-spinner" />
            ) : null}
            <span style={{ opacity: done ? 0.5 : 1 }}>{phase.label}…</span>
          </div>
        );
      })}
    </div>
  );
};
