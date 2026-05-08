#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────────
// director-tick.mjs
//
// One pass of the studio-director loop. Designed to be invoked every
// 5 minutes by tools/octogent/scripts/director-watchdog.sh. Idempotent:
// safe to run as often as desired.
//
// Responsibilities (per PROJECT.md):
//   1. Verify Octogent is alive (HTTP 200 on /api/deck/tentacles).
//   2. Inspect studio_director tentacle state.
//   3. If todo.md still has [ ] items AND no swarm is currently running,
//      POST a swarm to wake the workers.
//   4. Append a structured entry to cycle_log.md.
//
// What this script does NOT do (intentionally):
//   - It does not write code itself. The smart work happens INSIDE the
//     Claude agents spawned by the swarm — they read CONTEXT.md, decide
//     the dispatch strategy, and act.
//   - It does not run quality gates. That's a separate script
//     (director-quality-gates.sh) called after each commit batch.
//   - It does not restart Octogent. That's the watchdog's job.
//
// Usage:
//   node tools/octogent/scripts/director-tick.mjs [--dry-run]
// ─────────────────────────────────────────────────────────────────────

import { existsSync, appendFileSync, mkdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const OCTOGENT_DIR = resolve(__dirname, "..");                // tools/octogent/
const TENTACLE_DIR = join(OCTOGENT_DIR, ".octogent", "tentacles", "studio_director");
const CYCLE_LOG = join(TENTACLE_DIR, "cycle_log.md");

const OCTOGENT_BASE = process.env.OCTOGENT_BASE ?? "http://localhost:8787";
const DRY_RUN = process.argv.includes("--dry-run");

const now = () => new Date().toISOString();

const log = (msg) => {
  console.log(`[director-tick ${now()}] ${msg}`);
};

const appendCycleLog = (entry) => {
  if (!existsSync(TENTACLE_DIR)) mkdirSync(TENTACLE_DIR, { recursive: true });
  appendFileSync(CYCLE_LOG, entry);
};

// ── Step 1: Octogent health ────────────────────────────────────────────
let healthOk = false;
let tentacles = [];
try {
  const res = await fetch(`${OCTOGENT_BASE}/api/deck/tentacles`, { signal: AbortSignal.timeout(5000) });
  if (res.ok) {
    tentacles = await res.json();
    healthOk = true;
    log(`Octogent OK (${tentacles.length} tentacles).`);
  } else {
    log(`Octogent HTTP ${res.status}`);
  }
} catch (e) {
  log(`Octogent unreachable: ${e.message}`);
}

if (!healthOk) {
  appendCycleLog(`\n## Cycle ${now()}\n\n- Octogent health: **DOWN**\n- Action: skip (watchdog will restart)\n`);
  process.exit(2);
}

// ── Step 2: studio_director tentacle state ────────────────────────────
const directorEntry = tentacles.find((t) => t.tentacleId === "studio_director");
if (!directorEntry) {
  log(`studio_director tentacle missing from deck — abort.`);
  appendCycleLog(`\n## Cycle ${now()}\n\n- Octogent health: ok\n- Action: **abort** (studio_director tentacle not found in deck)\n`);
  process.exit(3);
}

const todoTotal = directorEntry.todoTotal ?? 0;
const todoDone = directorEntry.todoDone ?? 0;
const todoOpen = todoTotal - todoDone;
log(`studio_director: ${todoDone}/${todoTotal} todos done (${todoOpen} open).`);

// ── Step 3: existing swarm? — heartbeat-based detection ──────────────
// CRITICAL FIX (post-review): GET /api/terminal-snapshots (read-only).
// HEARTBEAT FIX (autopsy 2026-05-05): a swarm parent stayed listed in
// the snapshot for 24h as a zombie after its workers died. Skipping on
// "parent exists" caused 24h of skip-skip cycles. Now: check
// `lastOutputAt` freshness. If silent > STALE_SWARM_S, kill all stale
// matching terminals + fall through to spawn fresh.
const STALE_SWARM_S = Number(process.env.STALE_SWARM_S ?? 1800); // 30 min default
let activeSwarm = null;
let staleSwarmTerminals = [];
try {
  const res = await fetch(`${OCTOGENT_BASE}/api/terminal-snapshots`, {
    signal: AbortSignal.timeout(5000),
  });
  if (res.ok) {
    const data = await res.json();
    const arr = Array.isArray(data) ? data : (data.snapshots ?? data.terminals ?? []);
    const swarmTerminals = arr.filter((t) => String(t.terminalId ?? "").startsWith("studio_director-swarm-"));
    if (swarmTerminals.length > 0) {
      const nowMs = Date.now();
      let freshestMs = 0;
      for (const t of swarmTerminals) {
        const ts = t.lastOutputAt || t.updatedAt || t.createdAt;
        if (!ts) continue;
        try {
          const ms = new Date(ts).getTime();
          if (Number.isFinite(ms) && ms > freshestMs) freshestMs = ms;
        } catch { /* parse error — skip this entry */ }
      }
      const ageS = freshestMs > 0 ? Math.round((nowMs - freshestMs) / 1000) : Infinity;
      if (ageS <= STALE_SWARM_S) {
        activeSwarm = swarmTerminals[0];
        log(`Active swarm: ${activeSwarm.terminalId} freshest=${ageS}s ago (<=${STALE_SWARM_S}s). Skip spawn.`);
      } else {
        staleSwarmTerminals = swarmTerminals;
        log(`Stale swarm: ${swarmTerminals.length} terminals, freshest=${ageS}s ago (>${STALE_SWARM_S}s). Kill+respawn.`);
      }
    }
  }
} catch (e) {
  log(`Terminal list fetch failed: ${e.message} — assuming no active swarm.`);
}

if (activeSwarm) {
  appendCycleLog(`\n## Cycle ${now()}\n\n- Octogent health: ok\n- Active swarm: \`${activeSwarm.terminalId}\` (fresh)\n- Open todos: ${todoOpen}\n- Action: **skip** (swarm already running)\n`);
  process.exit(0);
}

if (staleSwarmTerminals.length > 0 && !DRY_RUN) {
  for (const t of staleSwarmTerminals) {
    try {
      await fetch(`${OCTOGENT_BASE}/api/terminals/${encodeURIComponent(t.terminalId)}/kill`, {
        method: "POST",
        signal: AbortSignal.timeout(5000),
      });
      log(`  Killed stale terminal: ${t.terminalId}`);
    } catch (e) {
      log(`  Kill failed for ${t.terminalId}: ${e.message}`);
    }
  }
  // BUGFIX (2026-05-08): kill marks lifecycleState="stopped" but the spawn
  // check at deckRoutes.ts:589 only filters by terminalId prefix, not state —
  // so a stopped swarm-parent still triggers HTTP 409 "swarm already active".
  // Prune fully removes stale|exited|stopped entries from the registry.
  try {
    const pruneRes = await fetch(`${OCTOGENT_BASE}/api/terminals/prune`, {
      method: "POST",
      signal: AbortSignal.timeout(5000),
    });
    if (pruneRes.ok) {
      const pruneData = await pruneRes.json();
      const pruned = Array.isArray(pruneData.prunedTerminalIds) ? pruneData.prunedTerminalIds : [];
      log(`  Pruned ${pruned.length} stopped terminal(s) from registry.`);
    } else {
      log(`  Prune failed: HTTP ${pruneRes.status}`);
    }
  } catch (e) {
    log(`  Prune fetch failed: ${e.message}`);
  }
  appendCycleLog(`\n## Cycle ${now()}\n\n- Octogent health: ok\n- Stale swarm killed+pruned: ${staleSwarmTerminals.length} terminals\n- Open todos: ${todoOpen}\n- Action: **kill+prune+respawn** (proceeding to spawn)\n`);
} else if (staleSwarmTerminals.length > 0 && DRY_RUN) {
  log(`[DRY RUN] Would kill ${staleSwarmTerminals.length} stale terminals + respawn.`);
  appendCycleLog(`\n## Cycle ${now()}\n\n- Octogent health: ok\n- Stale swarm: ${staleSwarmTerminals.length} (dry-run)\n- Open todos: ${todoOpen}\n- Action: **dry-run** (would kill+respawn)\n`);
  process.exit(0);
}

// ── Step 4: spawn or noop ──────────────────────────────────────────────
if (todoOpen === 0) {
  log(`No open todos — nothing to dispatch. Director idle.`);
  appendCycleLog(`\n## Cycle ${now()}\n\n- Octogent health: ok\n- Active swarm: none\n- Open todos: 0\n- Action: **noop** (no work)\n`);
  process.exit(0);
}

if (DRY_RUN) {
  log(`[DRY RUN] Would POST swarm with ${todoOpen} open todos.`);
  appendCycleLog(`\n## Cycle ${now()}\n\n- Octogent health: ok\n- Active swarm: none\n- Open todos: ${todoOpen}\n- Action: **dry-run** (would spawn)\n`);
  process.exit(0);
}

log(`Spawning swarm — ${todoOpen} workers expected (capped server-side).`);
let spawnResult;
try {
  // Spawn timeout = 60s. Empirical (2026-05-08): the server takes ~40s to
  // create the git worktree + boot the Claude PTY before responding. The
  // previous 10s timeout aborted the client while the server kept working,
  // making the cycle_log report "spawn failed" even though the worker spawned
  // fine. 60s gives comfortable headroom for cold-start git ops on NTFS-via-WSL.
  const res = await fetch(`${OCTOGENT_BASE}/api/deck/tentacles/studio_director/swarm`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ agentProvider: "claude-code", workspaceMode: "worktree" }),
    signal: AbortSignal.timeout(60000),
  });
  spawnResult = await res.json();
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${spawnResult.error ?? "unknown"}`);
} catch (e) {
  log(`Spawn failed: ${e.message}`);
  appendCycleLog(`\n## Cycle ${now()}\n\n- Octogent health: ok\n- Active swarm: none\n- Open todos: ${todoOpen}\n- Action: **spawn-failed**\n- Error: \`${e.message}\`\n`);
  process.exit(4);
}

const workerCount = Array.isArray(spawnResult.workers) ? spawnResult.workers.length : 0;
log(`Swarm spawned: parent=${spawnResult.parentTerminalId} + ${workerCount} workers.`);
appendCycleLog(`\n## Cycle ${now()}\n\n- Octogent health: ok\n- Active swarm: spawned\n- Open todos: ${todoOpen}\n- Action: **spawn**\n- Parent: \`${spawnResult.parentTerminalId}\`\n- Workers: ${workerCount}\n${(spawnResult.workers ?? []).map((w) => `  - \`${w.terminalId}\` -> ${String(w.todoText ?? "").slice(0, 100)}`).join("\n")}\n`);
process.exit(0);
