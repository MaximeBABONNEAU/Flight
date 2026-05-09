// forgeStoryRoutes.ts — Provides `/api/forge/story` so the dashboard can
// narrate forge activity to a "Lance + oublie" user in plain prose:
// "started Xm ago · last commit Y minutes ago · 12 commits in 24h".
//
// Server-side logic is intentionally minimal. We only run `git log` (cheap)
// and let the frontend aggregate director/worker/backlog from the existing
// /api/studio/status, /api/terminal-snapshots, and /api/deck/tentacles
// endpoints. Adding a new aggregator route would duplicate state we already
// have on the client.
import { execFile } from "node:child_process";
import { promisify } from "node:util";

import type { ApiRouteHandler } from "./routeHelpers";
import { writeJson, writeMethodNotAllowed } from "./routeHelpers";

const execFileAsync = promisify(execFile);

const FORGE_STORY_PATH = "/api/forge/story";
const RECENT_COMMITS_LIMIT = 10;
const COMMITS_24H_WINDOW_S = 24 * 60 * 60;
const GIT_TIMEOUT_MS = 4_000;

interface RecentCommit {
  sha: string;
  subject: string;
  ts: number; // unix seconds
  agoSec: number;
}

interface ForgeStoryResponse {
  now: number; // unix seconds
  recentCommits: ReadonlyArray<RecentCommit>;
  commitsLast24h: number;
  // null when git is unavailable (no repo, missing binary, timeout). The UI
  // falls back to a graceful "git unavailable" message instead of crashing.
  gitError: string | null;
}

const parseGitLog = (raw: string, nowSec: number): RecentCommit[] => {
  const lines = raw.split("\n").filter((l) => l.length > 0);
  const out: RecentCommit[] = [];
  for (const line of lines) {
    // Format: "<sha>\t<unix_ts>\t<subject>"
    const tab1 = line.indexOf("\t");
    const tab2 = tab1 >= 0 ? line.indexOf("\t", tab1 + 1) : -1;
    if (tab1 < 0 || tab2 < 0) continue;
    const sha = line.slice(0, tab1).trim();
    const tsRaw = line.slice(tab1 + 1, tab2).trim();
    const subject = line.slice(tab2 + 1).trim();
    const ts = Number.parseInt(tsRaw, 10);
    if (!sha || !Number.isFinite(ts)) continue;
    out.push({
      sha: sha.slice(0, 8),
      subject,
      ts,
      agoSec: Math.max(0, nowSec - ts),
    });
  }
  return out;
};

const readForgeStory = async (workspaceCwd: string): Promise<ForgeStoryResponse> => {
  const nowSec = Math.floor(Date.now() / 1000);
  try {
    // Recent commits + counter of commits in last 24h. We split into two
    // cheap calls so a failure in one doesn't take down the other. The 24h
    // count uses an ISO timestamp instead of "N seconds ago" because
    // human-relative date strings are locale-dependent on some Windows Git
    // builds; ISO-8601 is interpreted identically across all locales.
    const sinceIso = new Date((nowSec - COMMITS_24H_WINDOW_S) * 1000).toISOString();
    const [recentResult, countResult] = await Promise.all([
      execFileAsync(
        "git",
        ["log", "-n", String(RECENT_COMMITS_LIMIT), "--pretty=format:%H%x09%ct%x09%s"],
        { cwd: workspaceCwd, timeout: GIT_TIMEOUT_MS, maxBuffer: 1024 * 1024 },
      ),
      execFileAsync(
        "git",
        ["log", `--since=${sinceIso}`, "--pretty=format:1"],
        { cwd: workspaceCwd, timeout: GIT_TIMEOUT_MS, maxBuffer: 1024 * 1024 },
      ),
    ]);
    const recentCommits = parseGitLog(recentResult.stdout, nowSec);
    const commitsLast24h = countResult.stdout.split("\n").filter((l) => l.length > 0).length;
    return {
      now: nowSec,
      recentCommits,
      commitsLast24h,
      gitError: null,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      now: nowSec,
      recentCommits: [],
      commitsLast24h: 0,
      gitError: message.slice(0, 200),
    };
  }
};

export const handleForgeStoryRoute: ApiRouteHandler = async (
  { request, response, requestUrl, corsOrigin },
  { workspaceCwd },
) => {
  if (requestUrl.pathname !== FORGE_STORY_PATH) {
    return false;
  }
  if (request.method !== "GET") {
    writeMethodNotAllowed(response, corsOrigin);
    return true;
  }
  const story = await readForgeStory(workspaceCwd);
  writeJson(response, 200, story, corsOrigin);
  return true;
};
