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

  // Minimalist styling (2026-05-09): no pulse animation, no glow shadows,
  // no text-shadow. Just border + dot + label + counts. Per user request:
  // "pas besoin d'effets superflux".
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
        gap: "8px",
        padding: "4px 12px",
        borderRadius: "16px",
        background: "rgba(0,0,0,0.25)",
        border: `1px solid ${color}`,
        fontFamily: "Georgia, serif",
        fontSize: "12px",
        letterSpacing: "0.06em",
        color: "rgba(255,255,255,0.88)",
        whiteSpace: "nowrap",
      }}
    >
      <span
        aria-hidden="true"
        style={{
          width: 7,
          height: 7,
          borderRadius: "50%",
          background: color,
        }}
      />
      <span
        style={{
          fontWeight: 600,
          color,
          letterSpacing: "0.1em",
          textTransform: "uppercase",
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
