import { useForgeHealth, type ForgeHealthState } from "../app/hooks/useForgeHealth";

const STATE_COLOR: Record<ForgeHealthState, string> = {
  ok: "#3d7a4c", // forge-moss
  warn: "#faa32c", // forge-amber
  down: "#d63a3a", // danger red
  unknown: "rgba(255,255,255,0.35)",
};

const STATE_LABEL: Record<ForgeHealthState, string> = {
  ok: "FORGE OK",
  warn: "DEGRADED",
  down: "FORGE DOWN",
  unknown: "checking…",
};

const STATE_TITLE: Record<ForgeHealthState, string> = {
  ok: "All forge endpoints respond healthy.",
  warn: "Forge is reachable but slow or partial endpoints failed.",
  down: "Forge API unreachable. Watchdog will attempt recovery.",
  unknown: "Probing forge state…",
};

export const ForgeHealthBadge = () => {
  const health = useForgeHealth();
  const color = STATE_COLOR[health.state];

  // Compact metric line — only show counts when we actually have data.
  const hasData = health.lastUpdate !== null;
  const workersChip =
    hasData && (health.workersActive > 0 || health.workersIdle > 0)
      ? `${health.workersActive} active${
          health.workersIdle > 0 ? ` · ${health.workersIdle} idle` : ""
        }`
      : null;
  const tentacleChip =
    hasData && health.tentacleTotal > 0 ? `${health.tentacleTotal} tentacles` : null;
  const latencyChip =
    hasData && health.apiLatencyMs !== null ? `${health.apiLatencyMs}ms` : null;

  const tooltip = [
    STATE_TITLE[health.state],
    workersChip ? `Workers: ${workersChip}` : null,
    tentacleChip ? `Deck: ${tentacleChip}` : null,
    latencyChip ? `API: ${latencyChip}` : null,
  ]
    .filter(Boolean)
    .join(" · ");

  return (
    <span
      className="forge-health-badge"
      data-state={health.state}
      role="status"
      aria-live="polite"
      title={tooltip}
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: "10px",
        padding: "6px 14px",
        borderRadius: "20px",
        background: "rgba(0,0,0,0.35)",
        border: `1px solid ${color}`,
        boxShadow: `0 0 8px ${color}33`,
        fontFamily: "Georgia, serif",
        fontSize: "12px",
        letterSpacing: "0.08em",
        color: "rgba(255,255,255,0.9)",
        whiteSpace: "nowrap",
      }}
    >
      <span
        aria-hidden="true"
        style={{
          width: 8,
          height: 8,
          borderRadius: "50%",
          background: color,
          boxShadow: `0 0 6px ${color}, 0 0 2px ${color} inset`,
          animation: health.state === "ok" ? "forge-pulse 2.4s ease-in-out infinite" : "none",
        }}
      />
      <span
        style={{
          fontWeight: 600,
          color,
          letterSpacing: "0.12em",
          textTransform: "uppercase",
          textShadow: `0 0 4px ${color}66`,
        }}
      >
        {STATE_LABEL[health.state]}
      </span>
      {workersChip ? (
        <span style={{ opacity: 0.7, fontVariantNumeric: "tabular-nums" }}>· {workersChip}</span>
      ) : null}
      {tentacleChip ? (
        <span style={{ opacity: 0.5, fontVariantNumeric: "tabular-nums" }}>· {tentacleChip}</span>
      ) : null}
    </span>
  );
};
