import { useCallback, useEffect, useRef, useState } from "react";

import {
  buildStudioStartUrl,
  buildStudioStatusUrl,
  buildStudioStopUrl,
} from "../runtime/runtimeEndpoints";

type StudioState = "idle" | "starting" | "running" | "stopping";

type StudioStatus = {
  state: StudioState;
  bypassPermissions: true;
  workerTerminalIds: string[];
  directorTerminalId?: string;
  startedAt?: string;
  stoppedAt?: string;
  workerCount?: number;
  lastError?: string;
};

const POLL_INTERVAL_MS = 5_000;
const DEFAULT_WORKER_COUNT = 9;
const MIN_WORKER_COUNT = 1;
const MAX_WORKER_COUNT = 9;

const formatRelativeMinutes = (timestamp: string | undefined): string | null => {
  if (!timestamp) return null;
  const startedDate = new Date(timestamp);
  if (Number.isNaN(startedDate.getTime())) return null;
  const elapsedMs = Date.now() - startedDate.getTime();
  const elapsedMin = Math.max(0, Math.floor(elapsedMs / 60_000));
  if (elapsedMin === 0) return "just now";
  if (elapsedMin < 60) return `${elapsedMin}m ago`;
  const elapsedHours = Math.floor(elapsedMin / 60);
  return `${elapsedHours}h ${elapsedMin % 60}m ago`;
};

const fetchStatus = async (): Promise<StudioStatus | null> => {
  try {
    const response = await fetch(buildStudioStatusUrl(), { cache: "no-store" });
    if (!response.ok) return null;
    return (await response.json()) as StudioStatus;
  } catch {
    return null;
  }
};

export const StudioToggle = () => {
  const [status, setStatus] = useState<StudioStatus | null>(null);
  const [workerCount, setWorkerCount] = useState<number>(DEFAULT_WORKER_COUNT);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isBusy, setIsBusy] = useState(false);
  const pollTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const refresh = useCallback(async () => {
    const next = await fetchStatus();
    setStatus(next);
  }, []);

  useEffect(() => {
    void refresh();
    pollTimerRef.current = setInterval(() => {
      void refresh();
    }, POLL_INTERVAL_MS);
    return () => {
      if (pollTimerRef.current !== null) {
        clearInterval(pollTimerRef.current);
        pollTimerRef.current = null;
      }
    };
  }, [refresh]);

  const safeParseStatus = async (response: Response): Promise<StudioStatus | null> => {
    try {
      const text = await response.text();
      if (!text) return null;
      const parsed = JSON.parse(text) as Partial<StudioStatus>;
      if (!parsed || typeof parsed !== "object") return null;
      const result: StudioStatus = {
        state: (parsed.state as StudioState) ?? "idle",
        bypassPermissions: true,
        workerTerminalIds: Array.isArray(parsed.workerTerminalIds) ? parsed.workerTerminalIds : [],
      };
      if (typeof parsed.directorTerminalId === "string") {
        result.directorTerminalId = parsed.directorTerminalId;
      }
      if (typeof parsed.startedAt === "string") result.startedAt = parsed.startedAt;
      if (typeof parsed.stoppedAt === "string") result.stoppedAt = parsed.stoppedAt;
      if (typeof parsed.workerCount === "number") result.workerCount = parsed.workerCount;
      if (typeof parsed.lastError === "string") result.lastError = parsed.lastError;
      return result;
    } catch {
      return null;
    }
  };

  const handleStart = useCallback(async () => {
    setErrorMessage(null);
    setIsBusy(true);
    try {
      const response = await fetch(buildStudioStartUrl(), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ workerCount }),
      });
      const payload = await safeParseStatus(response);
      if (!response.ok) {
        setErrorMessage(payload?.lastError ?? `Start failed (${response.status}).`);
        if (payload) setStatus(payload);
        return;
      }
      if (payload) {
        setStatus(payload);
        if (payload.lastError) setErrorMessage(payload.lastError);
      } else {
        setErrorMessage("Studio start succeeded but server returned no status; refreshing…");
        await refresh();
      }
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : String(error));
    } finally {
      setIsBusy(false);
    }
  }, [workerCount, refresh]);

  const handleStop = useCallback(async () => {
    const confirmed = window.confirm(
      "Douse the forge? All studio worker terminals will be killed (workspace branches preserved).",
    );
    if (!confirmed) return;
    setErrorMessage(null);
    setIsBusy(true);
    try {
      const response = await fetch(buildStudioStopUrl(), { method: "POST" });
      const payload = await safeParseStatus(response);
      if (!response.ok) {
        setErrorMessage(payload?.lastError ?? `Stop failed (${response.status}).`);
        if (payload) setStatus(payload);
        return;
      }
      if (payload) {
        setStatus(payload);
      } else {
        await refresh();
      }
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : String(error));
    } finally {
      setIsBusy(false);
    }
  }, [refresh]);

  const state: StudioState = status?.state ?? "idle";
  const isRunning = state === "running";
  const isTransitioning = state === "starting" || state === "stopping" || isBusy;
  const liveWorkerCount = status?.workerTerminalIds?.length ?? 0;
  const startedRelative = formatRelativeMinutes(status?.startedAt);

  return (
    <div className="studio-toggle" data-state={state}>
      <div className="studio-toggle-row">
        {!isRunning && state !== "starting" && (
          <label className="studio-toggle-worker-count">
            Workers
            <input
              aria-label="Worker count"
              disabled={isTransitioning}
              max={MAX_WORKER_COUNT}
              min={MIN_WORKER_COUNT}
              onChange={(event) => {
                const value = Number.parseInt(event.target.value, 10);
                if (Number.isFinite(value)) {
                  setWorkerCount(Math.max(MIN_WORKER_COUNT, Math.min(MAX_WORKER_COUNT, value)));
                }
              }}
              type="number"
              value={workerCount}
            />
          </label>
        )}

        {isRunning ? (
          <button
            className="studio-toggle-button studio-toggle-button--stop"
            disabled={isTransitioning}
            onClick={() => void handleStop()}
            type="button"
          >
            ⏹ Douse the Forge
          </button>
        ) : (
          <button
            className="studio-toggle-button studio-toggle-button--start"
            disabled={isTransitioning}
            onClick={() => void handleStart()}
            type="button"
          >
            {state === "starting" && <span className="forge-ignition-embers" />}
            {state === "starting" ? "Igniting…" : "▶ Light the Forge"}
          </button>
        )}

        {state === "starting" && (
          <span className="studio-toggle-status" style={{ color: "rgba(214,162,26,0.9)" }}>
            Director spawning…
          </span>
        )}

        <span className="studio-toggle-bypass-badge" title="Workers run with --dangerously-skip-permissions">
          BYPASS
        </span>

        {isRunning && (
          <span className="studio-toggle-status">
            {liveWorkerCount} worker{liveWorkerCount === 1 ? "" : "s"}
            {startedRelative ? ` · started ${startedRelative}` : ""}
          </span>
        )}
      </div>

      {errorMessage && (
        <div className="studio-toggle-error" role="alert">
          {errorMessage}
        </div>
      )}
    </div>
  );
};
