// studioDirectiveRoutes.ts — User directive injection endpoint.
//
// Lets the user give natural-language instructions to the autonomous studio
// director (e.g. "focus on Phase 0 cleanup", "stop spawning audit workers",
// "implement scaled_dc unit tests next"). Persists to disk so directives
// survive director PTY crashes / Octogent restarts.
//
// Protocol:
//   GET  /api/studio/directive  -> {text: string, updatedAt: number(unix-s)}
//   POST /api/studio/directive  body {text: string}
//                                -> {text, updatedAt} on success
//                                   {error: "..."} on validation failure
//
// Storage: <projectStateDir>/state/studio_directive.json
//
// The director reads this at startup (per studio-director.md Tier 0) and
// re-reads it on every wake cycle. Empty text means "no override".
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

import type { ApiRouteHandler } from "./routeHelpers";
import { readJsonBodyOrWriteError, writeJson, writeMethodNotAllowed } from "./routeHelpers";

const DIRECTIVE_PATH = "/api/studio/directive";
const DIRECTIVE_MAX_CHARS = 8_000; // 8 KB cap so a runaway paste doesn't blow the prompt.

interface DirectiveSnapshot {
  text: string;
  updatedAt: number; // unix seconds
}

const directiveFilePath = (projectStateDir: string): string =>
  join(projectStateDir, "state", "studio_directive.json");

const readDirective = (projectStateDir: string): DirectiveSnapshot => {
  const path = directiveFilePath(projectStateDir);
  if (!existsSync(path)) {
    return { text: "", updatedAt: 0 };
  }
  try {
    const raw = readFileSync(path, "utf-8");
    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed !== "object" || parsed === null) {
      return { text: "", updatedAt: 0 };
    }
    const obj = parsed as { text?: unknown; updatedAt?: unknown };
    const text = typeof obj.text === "string" ? obj.text : "";
    const updatedAt = typeof obj.updatedAt === "number" ? obj.updatedAt : 0;
    return { text, updatedAt };
  } catch {
    return { text: "", updatedAt: 0 };
  }
};

const writeDirective = (projectStateDir: string, text: string): DirectiveSnapshot => {
  const path = directiveFilePath(projectStateDir);
  mkdirSync(dirname(path), { recursive: true });
  const snapshot: DirectiveSnapshot = {
    text,
    updatedAt: Math.floor(Date.now() / 1000),
  };
  writeFileSync(path, `${JSON.stringify(snapshot, null, 2)}\n`, "utf-8");
  return snapshot;
};

export const handleStudioDirectiveRoute: ApiRouteHandler = async (
  { request, response, requestUrl, corsOrigin },
  { projectStateDir },
) => {
  if (requestUrl.pathname !== DIRECTIVE_PATH) {
    return false;
  }

  if (request.method === "GET") {
    writeJson(response, 200, readDirective(projectStateDir), corsOrigin);
    return true;
  }

  if (request.method === "POST") {
    const bodyResult = await readJsonBodyOrWriteError(request, response, corsOrigin);
    if (!bodyResult.ok) return true;

    const body = bodyResult.payload as { text?: unknown } | null;
    const rawText = body && typeof body.text === "string" ? body.text : "";
    const trimmed = rawText.trim();

    if (trimmed.length > DIRECTIVE_MAX_CHARS) {
      writeJson(
        response,
        400,
        { error: `Directive too long (max ${DIRECTIVE_MAX_CHARS} chars).` },
        corsOrigin,
      );
      return true;
    }

    const snapshot = writeDirective(projectStateDir, trimmed);
    writeJson(response, 200, snapshot, corsOrigin);
    return true;
  }

  writeMethodNotAllowed(response, corsOrigin);
  return true;
};
