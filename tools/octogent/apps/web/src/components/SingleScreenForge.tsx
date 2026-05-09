import type { TerminalView } from "../app/types";

// SingleScreenForge — Phase B+C of .planning/forge_refonte_spec.md.
// Replaces the 8-tab nav + PrimaryViewRouter with a single above-the-fold
// canvas: active terminals list + idle hint. The "Lance + oublie" user
// only needs to see what's running; what got committed is in ForgeStory
// (mounted above this component).

interface TerminalEntry {
  terminalId: string;
  name?: string | null;
  tentacleId?: string | null;
  lifecycleState?: string;
  agentRuntimeState?: string;
  workspaceMode?: string;
  bypassPermissions?: boolean;
  studioRole?: string;
}

interface SingleScreenForgeProps {
  terminals: TerminalView;
}

const STATE_COLOR: Record<string, string> = {
  processing: "#7ec850", // phosphor-green
  idle: "rgba(255,255,255,0.55)",
  waiting_for_permission: "#faa32c", // amber
  starting: "#7ec850",
  stopped: "rgba(255,255,255,0.30)",
};

const STATE_LABEL: Record<string, string> = {
  processing: "working",
  idle: "idle",
  waiting_for_permission: "BLOCKED · permission",
  starting: "starting…",
  stopped: "stopped",
};

const stateColor = (state: string | undefined): string =>
  STATE_COLOR[state ?? ""] ?? "rgba(255,255,255,0.4)";

const stateLabel = (state: string | undefined): string =>
  STATE_LABEL[state ?? ""] ?? state ?? "?";

const rowDisplayName = (t: TerminalEntry): string => {
  if (t.name && t.name.trim().length > 0) return t.name;
  if (t.tentacleId && t.tentacleId.trim().length > 0) return t.tentacleId;
  return t.terminalId;
};

const isActive = (t: TerminalEntry): boolean =>
  t.lifecycleState === "running" || t.lifecycleState === "starting";

export const SingleScreenForge = ({ terminals }: SingleScreenForgeProps) => {
  const activeTerminals = terminals.filter((t) => isActive(t as TerminalEntry));
  const stuckCount = activeTerminals.filter(
    (t) => (t as TerminalEntry).agentRuntimeState === "waiting_for_permission",
  ).length;

  return (
    <main
      className="single-screen-forge"
      aria-label="MERLIN Forge — single screen"
      style={{
        margin: "12px 16px 0",
        padding: "16px 18px",
        borderRadius: "10px",
        background: "rgba(20, 14, 6, 0.45)",
        border: "1px solid rgba(214, 162, 26, 0.18)",
        fontFamily: "Georgia, 'Cormorant Garamond', serif",
        color: "rgba(255, 245, 220, 0.92)",
        minHeight: "320px",
      }}
    >
      <header
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "baseline",
          marginBottom: "12px",
          paddingBottom: "8px",
          borderBottom: "1px solid rgba(214, 162, 26, 0.15)",
        }}
      >
        <h2
          style={{
            margin: 0,
            fontSize: "15px",
            fontWeight: 600,
            letterSpacing: "0.06em",
            textTransform: "uppercase",
            color: "rgba(214, 162, 26, 0.92)",
          }}
        >
          Active terminals ({activeTerminals.length})
        </h2>
        {stuckCount > 0 ? (
          <span
            style={{
              fontSize: "12px",
              color: "#faa32c",
              fontWeight: 600,
              letterSpacing: "0.04em",
            }}
          >
            ⚠ {stuckCount} blocked on permission
          </span>
        ) : null}
      </header>

      {activeTerminals.length === 0 ? (
        <div
          style={{
            padding: "32px 12px",
            textAlign: "center",
            opacity: 0.6,
            fontStyle: "italic",
            fontSize: "14px",
            lineHeight: 1.6,
          }}
        >
          Forge is idle — no active terminals.
          <br />
          Click <strong>▶ Light the Forge</strong> above to start the studio
          director and spawn workers.
        </div>
      ) : (
        <ul
          style={{
            listStyle: "none",
            margin: 0,
            padding: 0,
            display: "flex",
            flexDirection: "column",
            gap: "6px",
          }}
        >
          {activeTerminals.map((raw) => {
            const t = raw as TerminalEntry;
            const color = stateColor(t.agentRuntimeState);
            return (
              <li
                key={t.terminalId}
                style={{
                  display: "grid",
                  gridTemplateColumns: "11px 160px 1fr",
                  gap: "12px",
                  alignItems: "center",
                  padding: "8px 10px",
                  borderRadius: "6px",
                  background: "rgba(0,0,0,0.20)",
                  fontSize: "13px",
                }}
              >
                <span
                  aria-hidden="true"
                  style={{
                    width: 8,
                    height: 8,
                    borderRadius: "50%",
                    background: color,
                    boxShadow:
                      t.agentRuntimeState === "processing"
                        ? `0 0 6px ${color}`
                        : "none",
                  }}
                />
                <span
                  style={{
                    color,
                    fontWeight: 600,
                    fontSize: "11px",
                    letterSpacing: "0.06em",
                    textTransform: "uppercase",
                    fontVariantNumeric: "tabular-nums",
                  }}
                >
                  {stateLabel(t.agentRuntimeState)}
                </span>
                <span
                  style={{
                    whiteSpace: "nowrap",
                    overflow: "hidden",
                    textOverflow: "ellipsis",
                  }}
                  title={`${rowDisplayName(t)} · ${t.terminalId} · ws=${
                    t.workspaceMode ?? "?"
                  } · bypass=${t.bypassPermissions ? "true" : "false"}`}
                >
                  {rowDisplayName(t)}
                </span>
              </li>
            );
          })}
        </ul>
      )}
    </main>
  );
};
