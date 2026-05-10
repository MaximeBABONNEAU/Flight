import type { TerminalSnapshot } from "@octogent/core";

import { resolvePrompt } from "./prompts";

export type StudioState = "idle" | "starting" | "running" | "stopping";

export type StudioStatus = {
  state: StudioState;
  startedAt?: string;
  stoppedAt?: string;
  directorTerminalId?: string;
  workerCount?: number;
  bypassPermissions: true;
  workerTerminalIds: string[];
  lastError?: string;
};

export type StartStudioOptions = {
  workerCount?: number;
};

const DIRECTOR_TERMINAL_ID = "studio-director";
const STUDIO_TENTACLE_ID = "studio";
const DEFAULT_WORKER_COUNT = 9;
const MIN_WORKER_COUNT = 1;
const MAX_WORKER_COUNT = 9;
const STUDIO_API_PORT_FALLBACK = "8787";

type StudioRuntimeDeps = {
  promptsDir: string;
  getApiPort: () => string;
  createTerminal: (options: {
    terminalId?: string;
    tentacleId?: string;
    tentacleName?: string;
    workspaceMode?: "shared" | "worktree";
    initialPrompt?: string;
    parentTerminalId?: string;
    bypassPermissions?: boolean;
    studioRole?: "director" | "worker";
    nameOrigin?: "user" | "generated" | "prompt";
  }) => TerminalSnapshot;
  killTerminal: (terminalId: string) => TerminalSnapshot | null;
  listTerminalSnapshots: () => TerminalSnapshot[];
};

export const createStudioRuntime = (deps: StudioRuntimeDeps) => {
  const { promptsDir, getApiPort, createTerminal, killTerminal, listTerminalSnapshots } = deps;

  let state: StudioState = "idle";
  let directorTerminalId: string | undefined;
  let startedAt: string | undefined;
  let stoppedAt: string | undefined;
  let lastError: string | undefined;
  let plannedWorkerCount = 0;

  const clampWorkerCount = (requested: number | undefined): number => {
    if (typeof requested !== "number" || !Number.isFinite(requested)) {
      return DEFAULT_WORKER_COUNT;
    }
    return Math.max(MIN_WORKER_COUNT, Math.min(MAX_WORKER_COUNT, Math.floor(requested)));
  };

  const findStudioWorkerTerminalIds = (): string[] => {
    if (!directorTerminalId) {
      return [];
    }
    const snapshots = listTerminalSnapshots();
    return snapshots
      .filter(
        (snapshot) =>
          snapshot.studioRole === "worker" || snapshot.parentTerminalId === directorTerminalId,
      )
      .map((snapshot) => snapshot.terminalId);
  };

  const buildStatus = (): StudioStatus => ({
    state,
    bypassPermissions: true,
    workerTerminalIds: findStudioWorkerTerminalIds(),
    ...(directorTerminalId ? { directorTerminalId } : {}),
    ...(startedAt ? { startedAt } : {}),
    ...(stoppedAt ? { stoppedAt } : {}),
    ...(plannedWorkerCount > 0 ? { workerCount: plannedWorkerCount } : {}),
    ...(lastError ? { lastError } : {}),
  });

  const startStudio = async (options: StartStudioOptions): Promise<StudioStatus> => {
    if (state === "running" || state === "starting") {
      return buildStatus();
    }

    state = "starting";
    lastError = undefined;
    stoppedAt = undefined;
    plannedWorkerCount = clampWorkerCount(options.workerCount);

    try {
      let resolvedApiPort = STUDIO_API_PORT_FALLBACK;
      try {
        const candidate = getApiPort();
        if (candidate && candidate.length > 0) {
          resolvedApiPort = candidate;
        }
      } catch {
        // Fallback already set.
      }

      const directorPrompt = await resolvePrompt(promptsDir, "studio-director", {
        directorTerminalId: DIRECTOR_TERMINAL_ID,
        workerCount: String(plannedWorkerCount),
        apiPort: resolvedApiPort,
        tentacleId: STUDIO_TENTACLE_ID,
      });

      if (!directorPrompt) {
        throw new Error("Studio director prompt template not found (prompts/studio-director.md).");
      }

      const directorSnapshot = createTerminal({
        terminalId: DIRECTOR_TERMINAL_ID,
        tentacleId: STUDIO_TENTACLE_ID,
        tentacleName: "Studio Director",
        nameOrigin: "user",
        workspaceMode: "shared",
        initialPrompt: directorPrompt,
        bypassPermissions: true,
        studioRole: "director",
      });

      directorTerminalId = directorSnapshot.terminalId;
      startedAt = new Date().toISOString();
      state = "running";
      return buildStatus();
    } catch (error) {
      lastError = error instanceof Error ? error.message : String(error);
      state = "idle";
      directorTerminalId = undefined;
      return buildStatus();
    }
  };

  const stopStudio = (): StudioStatus => {
    if (state === "idle" || state === "stopping") {
      return buildStatus();
    }

    state = "stopping";

    try {
      // Kill workers first (they're children of the director).
      for (const workerTerminalId of findStudioWorkerTerminalIds()) {
        try {
          killTerminal(workerTerminalId);
        } catch {
          // Best-effort: keep killing the others.
        }
      }

      // Then kill the director itself.
      if (directorTerminalId) {
        try {
          killTerminal(directorTerminalId);
        } catch {
          // Best-effort.
        }
      }

      stoppedAt = new Date().toISOString();
      state = "idle";
      directorTerminalId = undefined;
      plannedWorkerCount = 0;
      return buildStatus();
    } catch (error) {
      lastError = error instanceof Error ? error.message : String(error);
      state = "idle";
      return buildStatus();
    }
  };

  const getStatus = (): StudioStatus => buildStatus();

  return {
    startStudio,
    stopStudio,
    getStatus,
  };
};

export type StudioRuntime = ReturnType<typeof createStudioRuntime>;
