#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────────
// forge-dispatch-fixes.mjs  (Cycle C51)
//
// Closes the M.E.R.L.I.N. forge autonomy loop:
//
//   forge DETECTS  ─ verify_all writes last_verify.json (passed: false)
//   forge DISPATCHES ─ THIS SCRIPT routes failures into tentacle todo.md
//   swarm FIXES    ─ Octogent workers pick up the new todo lines and act
//
// Reads the report at:
//   tools/octogent/.octogent/tentacles/godot_runtime/last_verify.json
//
// Routing rules (script_errors → tentacle):
//   - "Cannot call method" / "null instance" / "Invalid access"
//        → quality_bug_fixer
//   - step0 (parse) errors          → godot_expert
//   - visual_regression: true (C49) → art_direction
//   - tests_passed: false   (C54)   → quality_bug_fixer
//   - anything else                  → debug_qa
//
// Idempotency: existing matching todos (same `Fix `<scene>` runtime errors`
// stable marker) are NOT duplicated.
//
// Exit codes:
//   0  = success (regardless of dispatched count, including passed:true)
//   1  = report missing
//   2  = invalid JSON
//   3  = other I/O error
//
// CLI:
//   node tools/octogent/scripts/forge-dispatch-fixes.mjs [--workspace <path>]
// ─────────────────────────────────────────────────────────────────────

import { readFile, writeFile, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// ── Path resolution ────────────────────────────────────────────────────
const __dirname = dirname(fileURLToPath(import.meta.url));

/**
 * Resolve workspace root. Defaults to cwd; overridable via --workspace.
 * The script lives in tools/octogent/scripts/, so the cwd-default lets the
 * user invoke from anywhere; the --workspace flag is for explicit targeting
 * (e.g. CI runners, watchdog).
 */
function resolveWorkspaceRoot(argv) {
  const idx = argv.indexOf("--workspace");
  if (idx >= 0 && idx + 1 < argv.length) {
    return resolve(argv[idx + 1]);
  }
  return resolve(process.cwd());
}

const WORKSPACE_ROOT = resolveWorkspaceRoot(process.argv.slice(2));
const REPORT_PATH = join(
  WORKSPACE_ROOT,
  "tools",
  "octogent",
  ".octogent",
  "tentacles",
  "godot_runtime",
  "last_verify.json",
);
const TENTACLES_DIR = join(
  WORKSPACE_ROOT,
  "tools",
  "octogent",
  ".octogent",
  "tentacles",
);

// ── Routing ────────────────────────────────────────────────────────────
const TENTACLE_QUALITY = "quality_bug_fixer";
const TENTACLE_GODOT = "godot_expert";
const TENTACLE_ART = "art_direction";
const TENTACLE_DEBUG = "debug_qa";

const RUNTIME_FAIL_PATTERNS = [
  /Cannot call method/i,
  /null instance/i,
  /Invalid access/i,
];

/**
 * Pick a tentacle for a list of script errors.
 * Returns the first match — debug_qa is the safety net so every failure
 * lands somewhere actionable.
 */
function routeScriptErrors(scriptErrors) {
  if (!Array.isArray(scriptErrors) || scriptErrors.length === 0) {
    return TENTACLE_DEBUG;
  }
  const joined = scriptErrors.join(" ␟ ");
  for (const pattern of RUNTIME_FAIL_PATTERNS) {
    if (pattern.test(joined)) return TENTACLE_QUALITY;
  }
  return TENTACLE_DEBUG;
}

/**
 * Heuristic root-cause inference. Cheap pattern match — the worker that
 * picks up the todo will do the real diagnosis. The hint just narrows
 * the search space.
 */
function inferRootCause(scriptErrors) {
  if (!Array.isArray(scriptErrors) || scriptErrors.length === 0) {
    return "unknown (see scene log)";
  }
  const joined = scriptErrors.join(" ").toLowerCase();
  if (joined.includes("add_theme_font_override")) {
    return "missing font/theme override target — likely null @onready node or pre-_ready theme call";
  }
  if (joined.includes("add_theme_stylebox_override")) {
    return "missing stylebox target — likely null @onready node or pre-_ready theme call";
  }
  if (joined.includes("add_item")) {
    return "OptionButton/ItemList not yet ready — @onready node likely null in _ready ordering";
  }
  if (joined.includes("min_value")) {
    return "Range/Slider node null at assignment — check scene tree wiring";
  }
  if (joined.includes("null instance") || joined.includes("null value")) {
    return "null reference — likely missing @onready var or wrong NodePath";
  }
  if (joined.includes("invalid access") && joined.includes("pressed")) {
    return "Button/CheckBox node null when reading 'pressed' — wiring issue";
  }
  return "see script_errors above for stack details";
}

// ── Todo formatting ────────────────────────────────────────────────────
const TODO_TIMESTAMP_ISO = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");

/**
 * Stable marker for idempotency. Format chosen so a simple substring
 * `includes` check on existing todo.md content reliably matches.
 */
function stableMarker(scene) {
  return `Fix \`${scene}\` runtime errors`;
}

function buildSceneTodo(sceneEntry) {
  const { scene, script_errors = [], visual_regression = false } = sceneEntry;
  const errorCount = script_errors.length;
  const firstTwo = script_errors
    .slice(0, 2)
    .map((e) => `"${String(e).replace(/"/g, "\\\"")}"`)
    .join(" / ");
  const cause = inferRootCause(script_errors);
  const visualNote = visual_regression
    ? " Visual regression also flagged — pixel-diff above threshold."
    : "";
  const errorSummary = errorCount > 0
    ? `${errorCount} SCRIPT ERROR — ${firstTwo}.`
    : "smoke FAIL with no script_errors captured (likely exit_code != 0 or timeout).";
  return (
    `- [ ] ${stableMarker(scene)} (auto-dispatched ${TODO_TIMESTAMP_ISO} by ` +
    `forge-dispatch-fixes): ${errorSummary} Root cause likely ${cause}.` +
    `${visualNote} Re-verify with ` +
    "`python tools/cli.py godot verify_all` after fix."
  );
}

function buildStep0Todo(step0Errors) {
  const count = step0Errors.length;
  const firstTwo = step0Errors
    .slice(0, 2)
    .map((e) => `"${String(e).replace(/"/g, "\\\"")}"`)
    .join(" / ");
  const summary = count > 0
    ? `${count} parse error(s) — ${firstTwo}`
    : "validate_step0 reported failure (no specific errors captured)";
  return (
    `- [ ] Fix \`validate_step0\` parse errors (auto-dispatched ` +
    `${TODO_TIMESTAMP_ISO} by forge-dispatch-fixes): ${summary}. ` +
    "Root cause likely GDScript syntax/parser violation. Re-verify with " +
    "`python tools/cli.py godot validate_step0` after fix."
  );
}

function buildTestsTodo() {
  return (
    `- [ ] Fix failing test suite (auto-dispatched ${TODO_TIMESTAMP_ISO} ` +
    "by forge-dispatch-fixes): `verify_all` reported tests_passed: false. " +
    "Re-verify with `python tools/cli.py godot test` after fix."
  );
}

function buildVisualRegressionTodo(scenes) {
  const sceneList = scenes.map((s) => `\`${s}\``).join(", ");
  return (
    `- [ ] Investigate visual regression in ${sceneList} (auto-dispatched ` +
    `${TODO_TIMESTAMP_ISO} by forge-dispatch-fixes): pixel-diff above ` +
    "threshold vs baseline. Compare current capture vs previous baseline " +
    "PNG and decide intentional change vs regression."
  );
}

// ── Append / idempotency ──────────────────────────────────────────────
async function ensureTentacleTodo(tentacle) {
  const tentacleDir = join(TENTACLES_DIR, tentacle);
  const todoPath = join(tentacleDir, "todo.md");
  if (!existsSync(tentacleDir)) {
    await mkdir(tentacleDir, { recursive: true });
  }
  if (!existsSync(todoPath)) {
    const header = `# ${tentacle} — Todo\n\n`;
    await writeFile(todoPath, header, "utf8");
  }
  return todoPath;
}

/**
 * Idempotent append. Skip if the marker is already present.
 * Returns true if the line was newly written, false if skipped.
 */
async function appendIfMissing(todoPath, marker, line) {
  const existing = await readFile(todoPath, "utf8");
  if (existing.includes(marker)) {
    return false;
  }
  // Ensure file ends with newline before appending.
  const sep = existing.endsWith("\n") || existing.length === 0 ? "" : "\n";
  await writeFile(todoPath, existing + sep + line + "\n", "utf8");
  return true;
}

// ── Main ──────────────────────────────────────────────────────────────
async function main() {
  // Load report.
  if (!existsSync(REPORT_PATH)) {
    console.error(`[forge-dispatch] report missing: ${REPORT_PATH}`);
    process.exit(1);
  }

  let raw;
  try {
    raw = await readFile(REPORT_PATH, "utf8");
  } catch (err) {
    console.error(`[forge-dispatch] read failed: ${err.message}`);
    process.exit(3);
  }

  let report;
  try {
    report = JSON.parse(raw);
  } catch (err) {
    console.error(`[forge-dispatch] invalid JSON in ${REPORT_PATH}: ${err.message}`);
    process.exit(2);
  }

  // Nothing to dispatch on a clean report.
  if (report.passed === true) {
    console.log("[forge-dispatch] verify_all passed — nothing to dispatch");
    process.exit(0);
  }

  // Aggregate todos per tentacle.
  /** @type {Map<string, Array<{marker: string, line: string}>>} */
  const dispatchPlan = new Map();
  const enqueue = (tentacle, marker, line) => {
    if (!dispatchPlan.has(tentacle)) dispatchPlan.set(tentacle, []);
    dispatchPlan.get(tentacle).push({ marker, line });
  };

  // 1. Per-scene runtime failures.
  const scenes = Array.isArray(report.scenes) ? report.scenes : [];
  const visualRegressionScenes = [];
  for (const scene of scenes) {
    if (scene.passed === true) continue;
    const tentacle = routeScriptErrors(scene.script_errors);
    enqueue(
      tentacle,
      stableMarker(scene.scene),
      buildSceneTodo(scene),
    );
    if (scene.visual_regression === true) {
      visualRegressionScenes.push(scene.scene);
    }
  }

  // 2. step0 parse errors.
  if (report.step0_passed === false) {
    const step0Errors = Array.isArray(report.step0_errors)
      ? report.step0_errors
      : (report.step0_summary && Array.isArray(report.step0_summary.errors))
        ? report.step0_summary.errors
        : [];
    enqueue(
      TENTACLE_GODOT,
      "Fix `validate_step0` parse errors",
      buildStep0Todo(step0Errors),
    );
  }

  // 3. C49 visual regression aggregate todo.
  if (visualRegressionScenes.length > 0) {
    enqueue(
      TENTACLE_ART,
      "Investigate visual regression in",
      buildVisualRegressionTodo(visualRegressionScenes),
    );
  }

  // 4. C54 test suite failure.
  if (report.tests_passed === false) {
    enqueue(
      TENTACLE_QUALITY,
      "Fix failing test suite",
      buildTestsTodo(),
    );
  }

  // Persist with idempotency.
  let appendedCount = 0;
  let touchedTentacles = 0;
  const summaryByTentacle = [];
  for (const [tentacle, items] of dispatchPlan.entries()) {
    let todoPath;
    try {
      todoPath = await ensureTentacleTodo(tentacle);
    } catch (err) {
      console.error(
        `[forge-dispatch] could not prepare ${tentacle}/todo.md: ${err.message}`,
      );
      process.exit(3);
    }
    let appendedHere = 0;
    for (const { marker, line } of items) {
      try {
        const wrote = await appendIfMissing(todoPath, marker, line);
        if (wrote) appendedHere += 1;
      } catch (err) {
        console.error(
          `[forge-dispatch] append failed (${tentacle}): ${err.message}`,
        );
        process.exit(3);
      }
    }
    if (appendedHere > 0) touchedTentacles += 1;
    appendedCount += appendedHere;
    summaryByTentacle.push(`${tentacle}=${appendedHere}/${items.length}`);
  }

  // Final summary line.
  const summarySuffix = summaryByTentacle.length
    ? ` [${summaryByTentacle.join(", ")}]`
    : "";
  console.log(
    `[forge-dispatch] ${appendedCount} fix-todos appended to ` +
      `${touchedTentacles} tentacles${summarySuffix}`,
  );
  process.exit(0);
}

main().catch((err) => {
  console.error(`[forge-dispatch] unexpected: ${err.stack || err.message}`);
  process.exit(3);
});
