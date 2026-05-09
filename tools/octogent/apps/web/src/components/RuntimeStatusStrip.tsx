import type { UsageChartData } from "../app/hooks/useUsageHeatmapPolling";
import type { ClaudeUsageSnapshot } from "../app/types";
import { ForgeHealthBadge } from "./ForgeHealthBadge";
import { StudioToggle } from "./StudioToggle";

// Header strip — minimalist (2026-05-09).
//
// Reduced to the three elements the user actually needs:
//   1. mascot icon (identity)
//   2. ForgeHealthBadge (status pill — what's happening)
//   3. StudioToggle (the LIGHT THE FORGE button — the only action that
//      matters from the header)
//
// The 30-day commits sparkline, the Claude tokens mini-chart, and the
// Claude session/week usage rails were removed from the header. They live
// in the MONITOR tab + GitHub view where they belong.
//
// Props are kept for backward compatibility with App.tsx callsite, but
// most are unused now. App.tsx can stop passing them in a follow-up
// without changing this signature.
type RuntimeStatusStripProps = {
  sparklinePoints?: string;
  usageData?: UsageChartData | null;
  claudeUsage?: ClaudeUsageSnapshot | null;
  isRefreshingClaudeUsage?: boolean;
  onRefreshClaudeUsage?: () => void;
};

export const RuntimeStatusStrip = (_props: RuntimeStatusStripProps) => {
  return (
    <section className="console-status-strip" aria-label="Forge runtime status">
      <div className="console-status-main">
        <img
          src="/merlin-mascot.png"
          alt="MERLIN"
          className="console-status-octopus-icon"
          style={{
            width: 28,
            height: 28,
            imageRendering: "pixelated",
          }}
        />
        <ForgeHealthBadge />
        <StudioToggle />
      </div>
    </section>
  );
};
