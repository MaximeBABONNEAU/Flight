import { type TerminalSnapshot, buildTerminalList, isAgentRuntimeState } from "@octogent/core";
import { type ReactNode, useCallback, useEffect, useRef, useState } from "react";

import { useBackendLivenessPolling } from "./app/hooks/useBackendLivenessPolling";
import { OCTOBOSS_ID } from "./app/hooks/useCanvasGraphData";
import { useClaudeUsagePolling } from "./app/hooks/useClaudeUsagePolling";
import { useCodexUsagePolling } from "./app/hooks/useCodexUsagePolling";
import { useConsoleKeyboardShortcuts } from "./app/hooks/useConsoleKeyboardShortcuts";
import { useGitHubPrimaryViewModel } from "./app/hooks/useGitHubPrimaryViewModel";
import { useGithubSummaryPolling } from "./app/hooks/useGithubSummaryPolling";
import { useInitialColumnsHydration } from "./app/hooks/useInitialColumnsHydration";
import { useMonitorRuntime } from "./app/hooks/useMonitorRuntime";
import { usePersistedUiState } from "./app/hooks/usePersistedUiState";
import { useTentacleGitLifecycle } from "./app/hooks/useTentacleGitLifecycle";
import { useTerminalCompletionNotification } from "./app/hooks/useTerminalCompletionNotification";
import { useTerminalMutations } from "./app/hooks/useTerminalMutations";
import { useTerminalStateReconciliation } from "./app/hooks/useTerminalStateReconciliation";
import { useUsageHeatmapPolling } from "./app/hooks/useUsageHeatmapPolling";
import { useWorkspaceSetup } from "./app/hooks/useWorkspaceSetup";
import {
  createTerminalRuntimeStateStore,
  getTerminalRuntimeStateInfo,
  stripTerminalRuntimeState,
  stripTerminalRuntimeStates,
} from "./app/terminalRuntimeStateStore";
import type { TerminalView } from "./app/types";
import { clampSidebarWidth } from "./app/uiStateNormalizers";
import { ActiveAgentsSidebar } from "./components/ActiveAgentsSidebar";
import { DirectiveBox } from "./components/DirectiveBox";
import { ForgeStory } from "./components/ForgeStory";
import { RuntimeStatusStrip } from "./components/RuntimeStatusStrip";
import { SidebarActionPanel } from "./components/SidebarActionPanel";
import { SingleScreenForge } from "./components/SingleScreenForge";
import { StudioLoopPanel } from "./components/StudioLoopPanel";
import { TelemetryTape } from "./components/TelemetryTape";
import { HttpTerminalSnapshotReader } from "./runtime/HttpTerminalSnapshotReader";
import {
  buildTerminalEventsSocketUrl,
  buildTerminalSnapshotsUrl,
} from "./runtime/runtimeEndpoints";

export const App = () => {
  const [terminals, setTerminals] = useState<TerminalView>([]);
  const [recentlyCreatedTerminal, setRecentlyCreatedTerminal] = useState<
    TerminalView[number] | null
  >(null);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [hoveredGitHubOverviewPointIndex, setHoveredGitHubOverviewPointIndex] = useState<
    number | null
  >(null);
  const [deckSidebarContent, setDeckSidebarContent] = useState<ReactNode>(null);
  const [conversationsSidebarContent, setConversationsSidebarContent] = useState<ReactNode>(null);
  const [conversationsActionPanel, setConversationsActionPanel] = useState<ReactNode>(null);
  const [promptsSidebarContent, setPromptsSidebarContent] = useState<ReactNode>(null);
  const terminalEventsRefreshTimerRef = useRef<number | null>(null);
  const runtimeStateStoreRef = useRef(createTerminalRuntimeStateStore());
  const runtimeStateStore = runtimeStateStoreRef.current;

  const sortTerminalSnapshots = useCallback(
    (snapshots: TerminalView) =>
      [...snapshots].sort((left, right) => {
        return new Date(left.createdAt).getTime() - new Date(right.createdAt).getTime();
      }),
    [],
  );

  const {
    activePrimaryNav,
    setActivePrimaryNav,
    applyHydratedUiState,
    isActiveAgentsSectionExpanded,
    isAgentsSidebarVisible,
    isBottomTelemetryVisible,
    isClaudeUsageSectionExpanded,
    isCodexUsageSectionExpanded,
    isMonitorVisible,
    isRuntimeStatusStripVisible,
    isUiStateHydrated,
    minimizedTerminalIds,
    readUiState,
    setIsActiveAgentsSectionExpanded,
    setIsAgentsSidebarVisible,
    setIsBottomTelemetryVisible,
    setIsClaudeUsageSectionExpanded,
    setIsCodexUsageSectionExpanded,
    setIsMonitorVisible,
    setIsRuntimeStatusStripVisible,
    setIsUiStateHydrated,
    setMinimizedTerminalIds,
    setSidebarWidth,
    setTerminalCompletionSound,
    sidebarWidth,
    terminalCompletionSound,
    canvasOpenTerminalIds,
    setCanvasOpenTerminalIds,
    canvasOpenTentacleIds,
    setCanvasOpenTentacleIds,
    canvasTerminalsPanelWidth,
    setCanvasTerminalsPanelWidth,
  } = usePersistedUiState({ columns: terminals });
  const {
    workspaceSetup,
    isWorkspaceSetupLoading,
    workspaceSetupError,
    refreshWorkspaceSetup,
    runWorkspaceSetupStep,
  } = useWorkspaceSetup();
  const [runningWorkspaceSetupStepId, setRunningWorkspaceSetupStepId] = useState<
    | "initialize-workspace"
    | "ensure-gitignore"
    | "check-claude"
    | "check-git"
    | "check-curl"
    | "create-tentacles"
    | null
  >(null);

  const readColumns = useCallback(
    async (signal?: AbortSignal) => {
      const readerOptions: { endpoint: string; signal?: AbortSignal } = {
        endpoint: buildTerminalSnapshotsUrl(),
      };
      if (signal) {
        readerOptions.signal = signal;
      }
      const reader = new HttpTerminalSnapshotReader(readerOptions);
      const nextColumns = await buildTerminalList(reader);
      runtimeStateStore.syncFromTerminals(nextColumns);
      return stripTerminalRuntimeStates(nextColumns);
    },
    [runtimeStateStore],
  );

  const refreshColumns = useCallback(async () => {
    const nextColumns = await readColumns();
    setTerminals(nextColumns);
    return nextColumns;
  }, [readColumns]);

  const {
    clearPendingDeleteTerminal,
    confirmDeleteTerminal,
    createTerminal,
    isCreatingTerminal,
    isDeletingTerminalId,
    pendingDeleteTerminal,
    requestDeleteTerminal,
  } = useTerminalMutations({
    readColumns: async () => readColumns(),
    setColumns: setTerminals,
    setLoadError,
    setMinimizedTerminalIds,
  });

  const {
    gitStatusByTentacleId,
    gitStatusLoadingByTentacleId,
    pullRequestByTentacleId,
    pullRequestLoadingByTentacleId,
    openGitTentacleId,
    openGitTentacleStatus,
    openGitTentaclePullRequest,
    gitCommitMessageDraft,
    gitDialogError,
    isGitDialogLoading,
    isGitDialogMutating,
    setGitCommitMessageDraft,
    openTentacleGitActions,
    closeTentacleGitActions,
    commitTentacleChanges,
    commitAndPushTentacleBranch,
    pushTentacleBranch,
    syncTentacleBranch,
    mergeTentaclePullRequest,
  } = useTentacleGitLifecycle({
    columns: terminals,
  });

  useInitialColumnsHydration({
    readColumns,
    readUiState,
    applyHydratedUiState,
    setColumns: setTerminals,
    setLoadError,
    setIsLoading,
    setIsUiStateHydrated,
  });

  useEffect(() => {
    return () => {
      if (terminalEventsRefreshTimerRef.current !== null) {
        window.clearTimeout(terminalEventsRefreshTimerRef.current);
        terminalEventsRefreshTimerRef.current = null;
      }
    };
  }, []);

  useEffect(() => {
    const socket = new WebSocket(buildTerminalEventsSocketUrl());

    socket.addEventListener("message", (event) => {
      if (typeof event.data !== "string") {
        return;
      }

      try {
        const payload = JSON.parse(event.data) as
          | {
              type?: unknown;
              snapshot?: TerminalSnapshot;
              terminalId?: string;
              agentRuntimeState?: string;
              toolName?: string;
            }
          | undefined;
        if (!payload || typeof payload.type !== "string") {
          return;
        }

        if (payload.type === "terminal-created" || payload.type === "terminal-updated") {
          if (!payload.snapshot) {
            return;
          }
          const runtimeState = getTerminalRuntimeStateInfo(payload.snapshot);
          runtimeStateStore.setRuntimeState(payload.snapshot.terminalId, runtimeState);
          const structuralSnapshot = stripTerminalRuntimeState(payload.snapshot);
          if (payload.type === "terminal-created") {
            setRecentlyCreatedTerminal(structuralSnapshot as TerminalView[number]);
          }
          setTerminals((current) =>
            sortTerminalSnapshots([
              ...current.filter(
                (terminal) => terminal.terminalId !== structuralSnapshot.terminalId,
              ),
              structuralSnapshot,
            ]),
          );
          return;
        }

        if (payload.type === "terminal-state-changed") {
          if (!payload.terminalId || !isAgentRuntimeState(payload.agentRuntimeState)) {
            return;
          }
          runtimeStateStore.setRuntimeState(payload.terminalId, {
            state: payload.agentRuntimeState,
            ...(payload.toolName ? { toolName: payload.toolName } : {}),
          });
          return;
        }

        if (payload.type === "terminal-deleted") {
          if (!payload.terminalId) {
            return;
          }
          runtimeStateStore.removeTerminal(payload.terminalId);
          setTerminals((current) =>
            current.filter((terminal) => terminal.terminalId !== payload.terminalId),
          );
          return;
        }

        if (payload.type !== "terminal-list-changed") {
          return;
        }
      } catch {
        return;
      }

      if (terminalEventsRefreshTimerRef.current !== null) {
        window.clearTimeout(terminalEventsRefreshTimerRef.current);
      }
      terminalEventsRefreshTimerRef.current = window.setTimeout(() => {
        terminalEventsRefreshTimerRef.current = null;
        void refreshColumns();
      }, 100);
    });

    return () => {
      if (terminalEventsRefreshTimerRef.current !== null) {
        window.clearTimeout(terminalEventsRefreshTimerRef.current);
        terminalEventsRefreshTimerRef.current = null;
      }
      socket.close();
    };
  }, [refreshColumns, runtimeStateStore, sortTerminalSnapshots]);

  const { codexUsageSnapshot, refreshCodexUsage } = useCodexUsagePolling();
  const { claudeUsageSnapshot, isRefreshingClaudeUsage, refreshClaudeUsage } =
    useClaudeUsagePolling();
  const backendLivenessStatus = useBackendLivenessPolling();
  const { githubRepoSummary, isRefreshingGitHubSummary, refreshGitHubRepoSummary } =
    useGithubSummaryPolling();
  const handleMaximizeTerminal = useCallback(
    (terminalId: string) => {
      setMinimizedTerminalIds((current) =>
        current.filter((currentTerminalId) => currentTerminalId !== terminalId),
      );
    },
    [setMinimizedTerminalIds],
  );
  const handleActiveTerminalIdsChange = useCallback(
    (activeTerminalIds: ReadonlySet<string>) => {
      runtimeStateStore.retainTerminalIds(activeTerminalIds);
    },
    [runtimeStateStore],
  );

  useTerminalStateReconciliation({
    columns: terminals,
    setMinimizedTerminalIds,
    onActiveTerminalIdsChange: handleActiveTerminalIdsChange,
  });

  // Auto-show studio director + workers as columns. Catches:
  //  1) terminals with studioRole === director (the studio backend sets this)
  //  2) terminals with tentacleId === "studio" (workers spawned by director
  //     via `node bin/octogent terminal create --tentacle-id studio` — they
  //     don't get studioRole set explicitly but share the studio tentacleId)
  // Any matching terminal is force-removed from minimizedTerminalIds so it
  // renders as a visible column with live log streaming.
  useEffect(() => {
    const studioTerminalIds = terminals
      .filter((t) => {
        const role = (t as { studioRole?: string }).studioRole;
        return role === "director" || role === "worker" || t.tentacleId === "studio";
      })
      .map((t) => t.terminalId);
    if (studioTerminalIds.length === 0) return;
    setMinimizedTerminalIds((current) =>
      current.filter((id) => !studioTerminalIds.includes(id)),
    );
  }, [terminals, setMinimizedTerminalIds]);
  const { playCompletionSoundPreview } = useTerminalCompletionNotification(
    runtimeStateStore,
    terminalCompletionSound,
  );
  const { heatmapData, isLoadingHeatmap, refreshHeatmap } = useUsageHeatmapPolling({
    enabled: isUiStateHydrated && (activePrimaryNav === 3 || isRuntimeStatusStripVisible),
  });

  useConsoleKeyboardShortcuts({ setActivePrimaryNav });
  const monitorRuntime = useMonitorRuntime({
    enabled: isUiStateHydrated && isMonitorVisible,
  });

  const {
    githubCommitCount30d,
    sparklinePoints,
    githubOverviewGraphSeries,
    githubOverviewGraphPolylinePoints,
    githubOverviewHoverLabel,
    githubStatusPill,
    githubRepoLabel,
    githubStarCountLabel,
    githubOpenIssuesLabel,
    githubOpenPrsLabel,
    githubRecentCommits,
  } = useGitHubPrimaryViewModel({
    githubRepoSummary,
    hoveredGitHubOverviewPointIndex,
    setHoveredGitHubOverviewPointIndex,
  });
  const hasSidebarActionPanel =
    conversationsActionPanel !== null ||
    pendingDeleteTerminal !== null ||
    (openGitTentacleId !== null &&
      terminals.find((terminal) => terminal.tentacleId === openGitTentacleId)?.workspaceMode ===
        "worktree");

  const sidebarActionPanel = hasSidebarActionPanel ? (
    conversationsActionPanel ? (
      <>{conversationsActionPanel}</>
    ) : (
      <SidebarActionPanel
        pendingDeleteTerminal={pendingDeleteTerminal}
        isDeletingTerminalId={isDeletingTerminalId}
        clearPendingDeleteTerminal={clearPendingDeleteTerminal}
        confirmDeleteTerminal={confirmDeleteTerminal}
        openGitTentacleId={openGitTentacleId}
        columns={terminals}
        openGitTentacleStatus={openGitTentacleStatus}
        openGitTentaclePullRequest={openGitTentaclePullRequest}
        gitCommitMessageDraft={gitCommitMessageDraft}
        gitDialogError={gitDialogError}
        isGitDialogLoading={isGitDialogLoading}
        isGitDialogMutating={isGitDialogMutating}
        setGitCommitMessageDraft={setGitCommitMessageDraft}
        closeTentacleGitActions={closeTentacleGitActions}
        commitTentacleChanges={commitTentacleChanges}
        commitAndPushTentacleBranch={commitAndPushTentacleBranch}
        pushTentacleBranch={pushTentacleBranch}
        syncTentacleBranch={syncTentacleBranch}
        mergeTentaclePullRequest={mergeTentaclePullRequest}
        requestDeleteTerminal={requestDeleteTerminal}
      />
    )
  ) : null;

  useEffect(() => {
    if (!hasSidebarActionPanel || isAgentsSidebarVisible) {
      return;
    }
    setIsAgentsSidebarVisible(true);
  }, [isAgentsSidebarVisible, setIsAgentsSidebarVisible, hasSidebarActionPanel]);

  const handleTerminalRenamed = useCallback((terminalId: string, tentacleName: string) => {
    setTerminals((current) =>
      current.map((t) =>
        t.terminalId === terminalId ? { ...t, tentacleName, label: tentacleName } : t,
      ),
    );
  }, []);

  const handleTerminalActivity = useCallback((terminalId: string) => {
    setTerminals((current) =>
      current.map((t) => (t.terminalId === terminalId ? { ...t, hasUserPrompt: true } : t)),
    );
  }, []);

  const handleRunWorkspaceSetupStep = useCallback(
    async (
      stepId:
        | "initialize-workspace"
        | "ensure-gitignore"
        | "check-claude"
        | "check-git"
        | "check-curl"
        | "create-tentacles",
    ) => {
      setRunningWorkspaceSetupStepId(stepId);
      try {
        await runWorkspaceSetupStep(stepId);
      } finally {
        setRunningWorkspaceSetupStepId(null);
      }
    },
    [runWorkspaceSetupStep],
  );

  return (
    <div className="page console-shell">
      {isRuntimeStatusStripVisible && (
        <RuntimeStatusStrip
          sparklinePoints={sparklinePoints}
          usageData={heatmapData}
          claudeUsage={claudeUsageSnapshot}
          isRefreshingClaudeUsage={isRefreshingClaudeUsage}
          onRefreshClaudeUsage={refreshClaudeUsage}
        />
      )}

      {/* ForgeStory: prose narrative panel (recent commits + uptime + cycle) */}
      <ForgeStory />

      {/* DirectiveBox: user directive to the autonomous studio director */}
      <DirectiveBox />

      {/* Phase B+C — SingleScreenForge: strip 8-tab nav + active terminals */}
      <SingleScreenForge terminals={terminals} runtimeStateStore={runtimeStateStore} />

      {/* PHASE_B_DEAD_CODE_START — removed during Phase B+C strip. Phase H
          will reclaim the now-unused state, hooks, and component imports.
          Block intentionally absent here: TS cannot type-check JSX that
          references stripped imports, so deletion is required for a
          green build. */}
      {/* PHASE_B_DEAD_CODE_END */}

      {isUiStateHydrated && isMonitorVisible && isBottomTelemetryVisible && (
        <TelemetryTape monitorFeed={monitorRuntime.monitorFeed} />
      )}
      <StudioLoopPanel />
    </div>
  );
};
