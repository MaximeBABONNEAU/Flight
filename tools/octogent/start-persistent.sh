#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────────
# tools/octogent/start-persistent.sh
#
# Idempotent persistent launcher for Octogent inside WSL Ubuntu.
#
# Behaviour:
#   1. If Octogent is already running on the configured port → no-op, exit 0.
#   2. Else: ensure prereqs (node 22+, pnpm, claude CLI, build artifacts).
#   3. If `.octogent/tentacles/` is empty → run integrate-merlin-agents.mjs
#      to pre-populate the 103-agent catalog.
#   4. Launch via `setsid -f` so the process detaches from this shell and
#      survives WSL session teardown.
#   5. Wait up to 15s for the port to bind, then `curl` health-check.
#
# Usage (from anywhere):
#   wsl bash tools/octogent/start-persistent.sh
#
# Stop:
#   wsl bash -c 'pkill -f "node tools/octogent/bin/octogent"'
#
# Logs:
#   wsl tail -f /tmp/octogent.log
# ────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── 0. Drop root → merlin (REQUIRED for Claude Code bypass mode) ──────
# Claude Code 2.x refuses --permission-mode bypassPermissions when running
# as root (security check). Studio mode requires bypass for autonomous
# workers, so we MUST run Octogent as a non-root user. Re-exec via sudo
# if we landed here as root.
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
  TARGET_USER="${OCTOGENT_USER:-merlin}"
  if id -u "$TARGET_USER" >/dev/null 2>&1; then
    rm -f /tmp/octogent.pid /tmp/octogent.log 2>/dev/null || true
    echo "[octogent-persistent] running as root — re-exec as $TARGET_USER (claude bypass requires non-root)"
    exec sudo -u "$TARGET_USER" -- bash "$0" "$@"
  else
    echo "[octogent-persistent] WARNING: running as root and user '$TARGET_USER' missing — bypass mode will fail"
  fi
fi

# Resolve repo root from this script's location (tools/octogent/ → ../..).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MERLIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OCTOGENT_DIR="$SCRIPT_DIR"

PORT="${PORT:-8787}"
HOST_BIND="${HOST:-0.0.0.0}"   # Bind 0.0.0.0 so Windows host can reach via localhost.
LOG_FILE="${LOG_FILE:-/tmp/octogent.log}"
PID_FILE="${PID_FILE:-/tmp/octogent.pid}"

log() { printf '[octogent-persistent] %s\n' "$*"; }

# ── 1. Already running? Curl-first decision tree (fix 2026-05-09) ─────────
# Single source of truth for "is the forge healthy?":
#   1. curl /api/deck/tentacles — if HTTP 200 in <3s, definitely up.
#   2. else inspect port owner via ss -tlnp:
#        - PID belongs to bin/octogent → zombie, kill + relaunch
#        - PID is a foreign process → refuse with clear error
#        - port free → fall through to launch
# Replaces a fragile PID-file + pgrep early-exit pair that returned
# "Already running" on zombie processes and blocked watchdog recovery.
if curl -fsS -o /dev/null -m 8 "http://localhost:${PORT}/api/deck/tentacles" 2>/dev/null; then
  EXISTING_PID="$(ss -tlnp 2>/dev/null | grep -E ":${PORT}\s" | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2)"
  log "Already running AND healthy (PID ${EXISTING_PID:-unknown}, curl OK). No-op."
  log "  UI:   http://localhost:$PORT"
  log "  Logs: tail -f $LOG_FILE"
  [ -n "$EXISTING_PID" ] && echo "$EXISTING_PID" > "$PID_FILE"
  exit 0
fi

# Curl failed. If port is bound, decide whether it's a zombie we own or a
# foreign process we must not touch.
if ss -tln 2>/dev/null | grep -qE ":${PORT}\s"; then
  EXISTING_PID="$(ss -tlnp 2>/dev/null | grep -E ":${PORT}\s" | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2)"
  if [ -z "$EXISTING_PID" ]; then
    log "ERROR: port $PORT bound but no PID via ss -tlnp."
    log "  → Investigate manually: ss -tlnp | grep :$PORT"
    exit 3
  fi
  EXISTING_ARGS="$(tr '\0' ' ' < /proc/${EXISTING_PID}/cmdline 2>/dev/null || true)"
  if echo "$EXISTING_ARGS" | grep -q "bin/octogent"; then
    log "Octogent zombie detected (PID $EXISTING_PID, curl unresponsive >3s, cmd matches bin/octogent). Killing for restart."
    kill -9 "$EXISTING_PID" 2>/dev/null || sudo kill -9 "$EXISTING_PID" 2>/dev/null || true
    sleep 2
    if ss -tln 2>/dev/null | grep -qE ":${PORT}\s"; then
      log "ERROR: zombie kill failed — port $PORT still bound after PID $EXISTING_PID. Refuse."
      exit 3
    fi
    rm -f "$PID_FILE" 2>/dev/null
  else
    log "ERROR: port $PORT bound by foreign process (PID $EXISTING_PID, cmd='${EXISTING_ARGS:0:80}')."
    log "  → Investigate: ps -fp $EXISTING_PID"
    exit 3
  fi
fi

# Stale PID file cleanup (PID dead but file lingers).
if [ -f "$PID_FILE" ]; then
  PFILE_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "$PFILE_PID" ] && ! kill -0 "$PFILE_PID" 2>/dev/null; then
    rm -f "$PID_FILE"
  fi
fi

# ── 2. Prereqs ────────────────────────────────────────────────────────────
# Source fnm / nvm if present (non-interactive bash skips ~/.bashrc).
[ -s "$HOME/.fnm/fnm" ] && export PATH="$HOME/.fnm:$PATH" && eval "$(fnm env --use-on-cd 2>/dev/null)" || true
# shellcheck disable=SC1091
[ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh" >/dev/null 2>&1 || true

command -v node >/dev/null 2>&1 || { log "ERROR: node not in PATH"; exit 1; }
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 22 ] || { log "ERROR: Node $NODE_MAJOR < 22"; exit 1; }

command -v pnpm >/dev/null 2>&1 || { log "ERROR: pnpm not in PATH (npm install -g pnpm@10.4.1)"; exit 1; }
command -v claude >/dev/null 2>&1 || log "WARN: claude CLI missing — Octogent will refuse to start."

# Build artifacts present?
if [ ! -d "$OCTOGENT_DIR/dist" ] || [ ! -d "$OCTOGENT_DIR/apps/web/dist" ]; then
  log "First-time build (dist missing) …"
  ( cd "$OCTOGENT_DIR" && pnpm install --frozen-lockfile && pnpm build ) || {
    log "ERROR: build failed"; exit 1;
  }
fi

# ── 2.5. Auto-repair corrupt tentacles.json (TIER 1.4) ────────────────────
# Octogent crashes mid-write can leave a 0-byte or truncated tentacles.json.
# The next boot then fails parseRegistryDocument with "Unexpected end of JSON
# input". Rather than asking a human to manually delete the file (twice this
# session), detect + backup + delete here so the registry rebuilds clean
# from .octogent/tentacles/*/CONTEXT.md on launch.
HOME_OCTO="${HOME}/.octogent/projects"
if [ -d "$HOME_OCTO" ]; then
  for tjson in "$HOME_OCTO"/*/state/tentacles.json; do
    [ -f "$tjson" ] || continue
    if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$tjson" 2>/dev/null; then
      backup="${tjson}.broken.$(date +%s)"
      log "Corrupt registry detected: $tjson — backup to $backup"
      mv "$tjson" "$backup" 2>/dev/null || rm -f "$tjson" 2>/dev/null
    fi
  done
fi

# ── 3. Integrate 103 MERLIN agents on first run ───────────────────────────
TENTACLE_COUNT=0
if [ -d "$OCTOGENT_DIR/.octogent/tentacles" ]; then
  TENTACLE_COUNT="$(find "$OCTOGENT_DIR/.octogent/tentacles" -maxdepth 1 -mindepth 1 -type d | wc -l)"
fi
if [ "$TENTACLE_COUNT" -lt 50 ]; then
  log "Tentacles count = $TENTACLE_COUNT (< 50) — running integration."
  ( cd "$MERLIN_ROOT" && node "$OCTOGENT_DIR/integrate-merlin-agents.mjs" ) || {
    log "WARN: agent integration failed — continuing with empty deck."
  }
fi

# ── 4. Detached launch ────────────────────────────────────────────────────
# IMPORTANT: cwd MUST be the dir containing the .octogent/ state — that's
# tools/octogent/, not MERLIN_ROOT. Octogent uses `process.cwd()` as its
# workspaceCwd and reads tentacles from `<cwd>/.octogent/tentacles/`. If we
# launch from MERLIN_ROOT, the deck shows zero agents because the catalog
# lives at tools/octogent/.octogent/. project.json there already has
# displayName="MERLIN" so the dashboard still shows "MERLIN" as the
# project name.
log "Launching: HOST=$HOST_BIND PORT=$PORT, cwd=$OCTOGENT_DIR"
cd "$OCTOGENT_DIR"
setsid -f bash -c "OCTOGENT_NO_OPEN=1 HOST='$HOST_BIND' PORT='$PORT' node bin/octogent > '$LOG_FILE' 2>&1"

# ── 5. Wait for port + verify ─────────────────────────────────────────────
DEADLINE=$(( $(date +%s) + 15 ))
PID=""
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  PID="$(pgrep -f "node tools/octogent/bin/octogent" | head -1 || true)"
  if [ -n "$PID" ] && ss -tln 2>/dev/null | grep -q ":$PORT "; then
    break
  fi
  sleep 1
done

if [ -z "$PID" ] || ! ss -tln 2>/dev/null | grep -q ":$PORT "; then
  log "FAILED to bind port $PORT in 15s — last log lines:"
  tail -10 "$LOG_FILE" 2>/dev/null
  exit 2
fi
echo "$PID" > "$PID_FILE"

if curl -fsS -o /dev/null -w 'HTTP %{http_code}\n' "http://localhost:$PORT" >/dev/null 2>&1; then
  log "Octogent up. PID $PID. UI: http://localhost:$PORT"
  log "Tentacles: $(find "$OCTOGENT_DIR/.octogent/tentacles" -maxdepth 1 -mindepth 1 -type d | wc -l)"
else
  log "Bound but health-check failed. Logs: tail -f $LOG_FILE"
fi
