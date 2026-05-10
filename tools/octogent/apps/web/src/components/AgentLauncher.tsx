import { useEffect, useMemo, useState } from "react";

import {
  buildForgeAgentsUrl,
  buildTerminalsUrl,
} from "../runtime/runtimeEndpoints";

// AgentLauncher — Pick a MERLIN agent (.claude/agents/*.md), give it a
// task, spawn a worker. Bridges between the 108-agent catalog and the
// existing terminal-create endpoint so the user can target a specialist
// without writing prompts manually.
//
// Flow:
//  1. GET /api/forge/agents -> populate dropdown
//  2. User picks an agent + types task description
//  3. POST /api/terminals with {tentacleId, name, autoRenamePromptContext,
//     workspaceMode: "shared", bypassPermissions: true, nameOrigin: "user"}
//  4. Worker spawns; user sees it appear in <SingleScreenForge />.

const AGENTS_POLL_MS = 60_000; // refresh once a minute (catalog rarely changes)
const TASK_MAX_CHARS = 600;

interface Agent {
  id: string;
  name: string;
  description?: string;
}

interface AgentsResponse {
  agents: Agent[];
  total: number;
  error: string | null;
}

interface TerminalCreateResponse {
  terminalId?: string;
  error?: string;
}

const fetchAgents = async (): Promise<AgentsResponse | null> => {
  try {
    const response = await fetch(buildForgeAgentsUrl(), {
      method: "GET",
      headers: { Accept: "application/json" },
      cache: "no-store",
    });
    if (!response.ok) return null;
    const json: unknown = await response.json();
    if (typeof json !== "object" || json === null) return null;
    return json as AgentsResponse;
  } catch {
    return null;
  }
};

const truncate = (s: string, n: number): string =>
  s.length <= n ? s : `${s.slice(0, n - 1)}…`;

export const AgentLauncher = () => {
  const [agents, setAgents] = useState<Agent[]>([]);
  const [filter, setFilter] = useState<string>("");
  const [selectedId, setSelectedId] = useState<string>("");
  const [task, setTask] = useState<string>("");
  const [submitting, setSubmitting] = useState<boolean>(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [lastSpawnId, setLastSpawnId] = useState<string | null>(null);

  useEffect(() => {
    let disposed = false;

    const refresh = async () => {
      const data = await fetchAgents();
      if (disposed || !data) return;
      setAgents(data.agents);
      setSelectedId((current) => current || data.agents[0]?.id || "");
    };

    void refresh();
    const timer = window.setInterval(() => {
      void refresh();
    }, AGENTS_POLL_MS);

    return () => {
      disposed = true;
      window.clearInterval(timer);
    };
  }, []);

  const filteredAgents = useMemo(() => {
    const q = filter.trim().toLowerCase();
    if (!q) return agents;
    return agents.filter(
      (a) =>
        a.id.toLowerCase().includes(q) ||
        a.name.toLowerCase().includes(q) ||
        (a.description ?? "").toLowerCase().includes(q),
    );
  }, [agents, filter]);

  const selectedAgent = useMemo(
    () => agents.find((a) => a.id === selectedId) ?? null,
    [agents, selectedId],
  );

  const canSpawn = !submitting && selectedAgent !== null && task.trim().length > 0;

  const handleSpawn = async () => {
    if (!canSpawn || !selectedAgent) return;
    setSubmitting(true);
    setSubmitError(null);
    setLastSpawnId(null);
    try {
      const trimmedTask = task.trim();
      const response = await fetch(buildTerminalsUrl(), {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({
          tentacleId: selectedAgent.id,
          workspaceMode: "shared",
          bypassPermissions: true,
          name: `${selectedAgent.id}: ${truncate(trimmedTask, 40)}`,
          nameOrigin: "user",
          autoRenamePromptContext: `[agent: ${selectedAgent.id}] ${trimmedTask}`,
        }),
      });
      if (!response.ok) {
        const txt = await response.text();
        setSubmitError(`HTTP ${response.status}: ${truncate(txt, 100)}`);
        return;
      }
      const json: unknown = await response.json();
      if (typeof json === "object" && json !== null) {
        const snap = json as TerminalCreateResponse;
        if (snap.error) {
          setSubmitError(snap.error);
        } else if (snap.terminalId) {
          setLastSpawnId(snap.terminalId);
          setTask("");
        }
      }
    } catch (e) {
      setSubmitError(e instanceof Error ? e.message : "Network error");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <section
      className="agent-launcher"
      aria-label="MERLIN agent launcher"
      style={{
        margin: "8px 16px 0",
        padding: "12px 14px",
        borderRadius: "8px",
        background: "rgba(20, 14, 6, 0.55)",
        border: "1px solid rgba(126, 200, 80, 0.30)",
        fontFamily: "Georgia, 'Cormorant Garamond', serif",
        color: "rgba(255, 245, 220, 0.92)",
      }}
    >
      <header
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "baseline",
          marginBottom: "8px",
        }}
      >
        <h3
          style={{
            margin: 0,
            fontSize: "12px",
            fontWeight: 600,
            letterSpacing: "0.08em",
            textTransform: "uppercase",
            color: "rgba(126, 200, 80, 0.92)",
          }}
        >
          Spawn agent
        </h3>
        <span
          style={{
            fontSize: "11px",
            opacity: 0.55,
            fontVariantNumeric: "tabular-nums",
          }}
        >
          {agents.length} agents
        </span>
      </header>

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "1fr 2fr",
          gap: "8px",
          marginBottom: "8px",
        }}
      >
        <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
          <input
            type="search"
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            placeholder="Filter agents…"
            style={{
              background: "rgba(0,0,0,0.30)",
              border: "1px solid rgba(126, 200, 80, 0.18)",
              borderRadius: "5px",
              padding: "5px 8px",
              color: "rgba(255, 245, 220, 0.92)",
              fontFamily: "Consolas, Menlo, monospace",
              fontSize: "11px",
              boxSizing: "border-box",
            }}
          />
          <select
            value={selectedId}
            onChange={(e) => setSelectedId(e.target.value)}
            size={6}
            style={{
              background: "rgba(0,0,0,0.30)",
              border: "1px solid rgba(126, 200, 80, 0.18)",
              borderRadius: "5px",
              padding: "5px 6px",
              color: "rgba(255, 245, 220, 0.92)",
              fontFamily: "Consolas, Menlo, monospace",
              fontSize: "11px",
              outline: "none",
            }}
          >
            {filteredAgents.length === 0 ? (
              <option disabled>No agents match</option>
            ) : (
              filteredAgents.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.id}
                </option>
              ))
            )}
          </select>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: "6px" }}>
          <div
            style={{
              fontSize: "11px",
              opacity: 0.7,
              minHeight: "26px",
              padding: "4px 8px",
              background: "rgba(0,0,0,0.20)",
              borderRadius: "5px",
              borderLeft: "2px solid rgba(126, 200, 80, 0.40)",
              fontStyle: "italic",
              lineHeight: 1.35,
            }}
          >
            {selectedAgent
              ? truncate(selectedAgent.description ?? selectedAgent.name, 220)
              : "Select an agent to see its description."}
          </div>
          <textarea
            value={task}
            onChange={(e) => {
              setTask(e.target.value.slice(0, TASK_MAX_CHARS));
              setSubmitError(null);
            }}
            placeholder='Task for this agent. Examples: "Audit risk_hint coverage in fastroute_cards.json", "Refactor scaled_dc to use difficulty_tier", "Add unit tests for merlin_effect_engine.PROMISE pipeline"'
            rows={4}
            style={{
              flex: 1,
              background: "rgba(0,0,0,0.30)",
              border: "1px solid rgba(126, 200, 80, 0.18)",
              borderRadius: "5px",
              padding: "6px 9px",
              color: "rgba(255, 245, 220, 0.92)",
              fontFamily: "Consolas, Menlo, monospace",
              fontSize: "12px",
              lineHeight: 1.4,
              resize: "vertical",
              boxSizing: "border-box",
            }}
          />
        </div>
      </div>

      <footer
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          gap: "8px",
        }}
      >
        <span
          style={{
            fontSize: "10px",
            opacity: 0.55,
            fontVariantNumeric: "tabular-nums",
          }}
        >
          {selectedAgent ? `→ ${selectedAgent.id}` : "no agent picked"}
          {task.trim().length > 0 ? ` · ${task.trim().length}/${TASK_MAX_CHARS} chars` : ""}
          {lastSpawnId ? ` · spawned ${lastSpawnId} ✓` : ""}
        </span>
        <button
          type="button"
          onClick={handleSpawn}
          disabled={!canSpawn}
          style={{
            background: canSpawn ? "rgba(126, 200, 80, 0.85)" : "rgba(0,0,0,0.35)",
            border: "1px solid rgba(126, 200, 80, 0.50)",
            color: canSpawn ? "#0a1605" : "rgba(255,245,220,0.55)",
            padding: "6px 14px",
            borderRadius: "5px",
            fontSize: "11px",
            fontWeight: 600,
            fontFamily: "Georgia, serif",
            cursor: canSpawn ? "pointer" : "default",
            opacity: submitting ? 0.6 : 1,
            letterSpacing: "0.06em",
            textTransform: "uppercase",
          }}
        >
          {submitting ? "Spawning…" : "Spawn worker"}
        </button>
      </footer>

      {submitError ? (
        <div
          style={{
            marginTop: "6px",
            fontSize: "11px",
            color: "#faa32c",
            fontStyle: "italic",
          }}
        >
          {submitError}
        </div>
      ) : null}
    </section>
  );
};
