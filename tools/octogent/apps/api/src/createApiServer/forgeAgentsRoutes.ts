// forgeAgentsRoutes.ts — Catalog of MERLIN agents (`.claude/agents/*.md`).
//
// Powers the <AgentLauncher /> picker so the user can spawn a worker
// targeted at a specific specialist (art_direction, bug_hunter, gd_economy,
// audio_*, blender_*, content_*, etc.).
//
// Protocol:
//   GET /api/forge/agents -> { agents: [{ id, name, description? }], total: number, error: string|null }
//
// Reads from <workspaceCwd>/.claude/agents/*.md. Returns id = filename stem
// (e.g. "art_direction"), name = first non-empty H1/H2 markdown title or
// id-as-fallback, description = first non-blank line after the title (cap
// 240 chars).
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

import type { ApiRouteHandler } from "./routeHelpers";
import { writeJson, writeMethodNotAllowed } from "./routeHelpers";

const AGENTS_PATH = "/api/forge/agents";
const DESCRIPTION_MAX_CHARS = 240;
// Skip non-agent files in .claude/agents/. AGENTS.md is the roster, CHANGELOG
// is the meta log, dispatcher is the routing entrypoint.
const SKIP_AGENT_FILES = new Set(["AGENTS.md", "CHANGELOG.md", "task_dispatcher.md"]);

interface AgentSummary {
  id: string;
  name: string;
  description?: string;
}

const extractTitle = (raw: string): string | null => {
  const lines = raw.split("\n");
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.startsWith("# ")) {
      return trimmed.slice(2).trim();
    }
    if (trimmed.startsWith("## ")) {
      return trimmed.slice(3).trim();
    }
  }
  return null;
};

const extractDescription = (raw: string): string | undefined => {
  // Find the first non-empty paragraph after the title that isn't an HTML
  // comment or a YAML/AUTO_ACTIVATE annotation.
  const lines = raw.split("\n");
  let pastTitle = false;
  for (const line of lines) {
    const trimmed = line.trim();
    if (!pastTitle) {
      if (trimmed.startsWith("# ") || trimmed.startsWith("## ")) {
        pastTitle = true;
      }
      continue;
    }
    if (trimmed.length === 0) continue;
    if (trimmed.startsWith("<!--") || trimmed.startsWith("---")) continue;
    if (trimmed.startsWith("##") || trimmed.startsWith("# ")) continue;
    if (trimmed.startsWith(">")) {
      const stripped = trimmed.slice(1).trim();
      if (stripped.length > 0) {
        return stripped.slice(0, DESCRIPTION_MAX_CHARS);
      }
      continue;
    }
    return trimmed.slice(0, DESCRIPTION_MAX_CHARS);
  }
  return undefined;
};

// Walk up parent directories looking for `.claude/agents/`. Octogent is
// vendored under `<merlinRepo>/tools/octogent/`, so `workspaceCwd` is the
// Octogent dir and the agents catalog lives at `<merlinRepo>/.claude/agents/`
// (two levels up). We walk up to 5 parents max so we never escape the user's
// home tree on a misconfigured deploy.
const findAgentsDir = (workspaceCwd: string): string | null => {
  let current = resolve(workspaceCwd);
  for (let i = 0; i < 5; i++) {
    const candidate = join(current, ".claude", "agents");
    if (existsSync(candidate)) return candidate;
    const parent = dirname(current);
    if (parent === current) break; // hit filesystem root
    current = parent;
  }
  return null;
};

const readAgents = (workspaceCwd: string): AgentSummary[] => {
  const dir = findAgentsDir(workspaceCwd);
  if (!dir) return [];
  const out: AgentSummary[] = [];
  for (const entry of readdirSync(dir)) {
    if (!entry.endsWith(".md")) continue;
    if (SKIP_AGENT_FILES.has(entry)) continue;
    const fullPath = join(dir, entry);
    try {
      const stats = statSync(fullPath);
      if (!stats.isFile()) continue;
      const raw = readFileSync(fullPath, "utf-8");
      const id = entry.replace(/\.md$/, "");
      const title = extractTitle(raw) ?? id;
      const description = extractDescription(raw);
      out.push({
        id,
        name: title,
        ...(description ? { description } : {}),
      });
    } catch {
      // Ignore unreadable files
    }
  }
  out.sort((a, b) => a.id.localeCompare(b.id));
  return out;
};

export const handleForgeAgentsRoute: ApiRouteHandler = async (
  { request, response, requestUrl, corsOrigin },
  { workspaceCwd },
) => {
  if (requestUrl.pathname !== AGENTS_PATH) {
    return false;
  }
  if (request.method !== "GET") {
    writeMethodNotAllowed(response, corsOrigin);
    return true;
  }
  try {
    const agents = readAgents(workspaceCwd);
    writeJson(response, 200, { agents, total: agents.length, error: null }, corsOrigin);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    writeJson(
      response,
      200,
      { agents: [], total: 0, error: message.slice(0, 200) },
      corsOrigin,
    );
  }
  return true;
};
