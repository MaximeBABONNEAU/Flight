import { useEffect, useState } from "react";

import {
  buildDeckTentaclesUrl,
  buildTerminalSnapshotsUrl,
} from "../../runtime/runtimeEndpoints";

export type ForgeHealthState = "ok" | "warn" | "down" | "unknown";

export type ForgeHealth = {
  state: ForgeHealthState;
  workersActive: number;
  workersIdle: number;
  tentacleTotal: number;
  apiLatencyMs: number | null;
  lastUpdate: number | null;
};

const POLL_INTERVAL_MS = 8_000;
const SLOW_API_THRESHOLD_MS = 1_500;

type RawTerminalSnapshot = {
  terminalId?: string;
  lifecycleState?: string;
  agentRuntimeState?: string;
};

type RawTentacle = {
  tentacleId?: string;
};

const fetchJsonWithTiming = async <T,>(
  url: string,
): Promise<{ data: T | null; latencyMs: number | null }> => {
  const start = performance.now();
  try {
    const response = await fetch(url, {
      method: "GET",
      headers: { Accept: "application/json" },
      cache: "no-store",
    });
    const latencyMs = Math.round(performance.now() - start);
    if (!response.ok) return { data: null, latencyMs };
    const data = (await response.json()) as T;
    return { data, latencyMs };
  } catch {
    return { data: null, latencyMs: null };
  }
};

const deriveState = (
  terminalsOk: boolean,
  tentaclesOk: boolean,
  apiLatencyMs: number | null,
): ForgeHealthState => {
  if (!terminalsOk && !tentaclesOk) return "down";
  if (!terminalsOk || !tentaclesOk) return "warn";
  if (apiLatencyMs !== null && apiLatencyMs > SLOW_API_THRESHOLD_MS) return "warn";
  return "ok";
};

export const useForgeHealth = (): ForgeHealth => {
  const [health, setHealth] = useState<ForgeHealth>({
    state: "unknown",
    workersActive: 0,
    workersIdle: 0,
    tentacleTotal: 0,
    apiLatencyMs: null,
    lastUpdate: null,
  });

  useEffect(() => {
    let isDisposed = false;
    let isInFlight = false;

    const refresh = async () => {
      if (isDisposed || isInFlight) return;
      isInFlight = true;
      try {
        const [terminals, tentacles] = await Promise.all([
          fetchJsonWithTiming<RawTerminalSnapshot[] | { snapshots?: RawTerminalSnapshot[] }>(
            buildTerminalSnapshotsUrl(),
          ),
          fetchJsonWithTiming<RawTentacle[]>(buildDeckTentaclesUrl()),
        ]);

        const termArr: RawTerminalSnapshot[] = Array.isArray(terminals.data)
          ? terminals.data
          : Array.isArray(terminals.data?.snapshots)
            ? terminals.data!.snapshots!
            : [];
        const workersActive = termArr.filter(
          (t) => t.lifecycleState === "running" && t.agentRuntimeState === "processing",
        ).length;
        const workersIdle = termArr.filter(
          (t) => t.lifecycleState === "running" && t.agentRuntimeState !== "processing",
        ).length;

        const tentacleArr = Array.isArray(tentacles.data) ? tentacles.data : [];
        const tentacleTotal = tentacleArr.length;

        const slowest = Math.max(terminals.latencyMs ?? 0, tentacles.latencyMs ?? 0) || null;

        if (!isDisposed) {
          setHealth({
            state: deriveState(terminals.data !== null, tentacles.data !== null, slowest),
            workersActive,
            workersIdle,
            tentacleTotal,
            apiLatencyMs: slowest,
            lastUpdate: Date.now(),
          });
        }
      } finally {
        isInFlight = false;
      }
    };

    void refresh();
    const timerId = window.setInterval(() => {
      void refresh();
    }, POLL_INTERVAL_MS);

    return () => {
      isDisposed = true;
      window.clearInterval(timerId);
    };
  }, []);

  return health;
};
