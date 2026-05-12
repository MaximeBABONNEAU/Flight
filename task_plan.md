# Task Plan — MERLIN Game Development

> **Source**: `docs/DEV_PLAN_V2.5.md` (canonical phase plan).
> **Consumed by**: `tools/octogent/prompts/studio-director.md` Tier 1 backlog.
> **Last refresh**: 2026-05-12 (added BoardNarration feature task — see §"Active Feature").

---

## Active Feature — BoardNarration (Post-Run Cinematic Replay) [2026-05-12]

**Detailed plan:** `docs/BOARD_NARRATION_PLAN.md`
**Status:** IN PROGRESS — 3 helper scripts written, controller + scene + wiring pending.
**Complexity:** MODERATE | **Branch:** main | **Dispatcher classification:** UI Layout + Animation + Shader + LLM Integration

### BoardNarration phase checklist (current sprint)

- [x] AskUserQuestion Wave 1 + 2 (8 dimensions clarified, decisions logged in plan doc)
- [x] `ui-ux-pro-max` skill invocation (design_sprint FIRST)
- [x] Dispatcher + store + infra read (game_flow_controller, end_run_screen, save_system, constants, visual palette)
- [x] `docs/BOARD_NARRATION_PLAN.md` written
- [x] `scripts/board_narration/sigle_token.gd` (class_name SigleToken)
- [x] `scripts/board_narration/biome_ambience.gd` (class_name BoardBiomeAmbience, 8 biome presets)
- [x] `scripts/board_narration/run_journal.gd` (class_name BoardRunJournal, FIFO cap 30)
- [ ] `scripts/board_narration/board_narration.gd` (controller, orchestrates everything)
- [ ] `scenes/BoardNarration.tscn` (minimal root + script self-builds)
- [ ] `scripts/merlin/merlin_save_system.gd` — add `save_run_journal()` thin wrapper
- [ ] `scripts/core/game_flow_controller.gd` — insert BoardNarration phase between run_ended and EndRunScreen
- [ ] `validate.bat` parse-check pass
- [ ] Smoke runtime `python tools/cli.py godot smoke --scene "res://scenes/BoardNarration.tscn" --duration 10`
- [ ] `everything-claude-code:code-reviewer` agent on 6 touched files
- [ ] `llm_expert.md` agent review on LLM commentary loop
- [ ] `superpowers:verification-before-completion` (design_sprint LAST)
- [ ] `everything-claude-code:learn-eval` (session-end ACTION 5)
- [ ] Conventional commit `feat(narration): add post-run BoardNarration scene`

---

## Hard Rules for Studio (read this BEFORE picking a task)

- **GAME WORK ONLY.** No `tools/octogent/`, no `tools/autodev/`, no `server/`, no `validate.bat` edits, no dashboard / Forge UI work. The Forge is the orchestration tool — workers ship the GAME.
- **Use Windows Godot MCP** for scene/script work: `mcp__godot-mcp__*` tools (Godot Engine v4.5.1.stable.official at `C:/Users/PGNK2128/Godot/Godot_v4.5.1-stable_win64_console.exe`). NEVER spawn `wsl godot` or any Linux Godot binary — the project's runtime target is Windows.
- **Validate via Windows `validate.bat`**: from WSL workers, call `cmd.exe /c "C:\\Users\\PGNK2128\\Godot-MCP\\validate.bat"`. The bat's parse check is the source of truth — `python tools/cli.py godot validate_step0` is an alias that ALSO routes to Windows Godot via `tools/adapters/godot_adapter.py`.
- **Conventional commits**: `refactor(cleanup):`, `feat(merlin):`, `fix(merlin):`, etc. NO `[AI-assisted]` tag (personal project).
- **One task = one commit on `octogent/studio-worker-<N>`**, then `DONE: <task>` to director.

---

## Phase 0 — Cleanup Dead Code (BLOCKING — must reach 0 refs)

> Audit 2026-05-10: 872 dead-code references in `scripts/`. Each item below targets a specific symbol family. Each task is independently committable.

### Phase 0 Tasks

- [ ] **P0-A** Remove `souffle` references from `scripts/`. Targets: dead enum entries, unused vars, comment-stripping where Souffle is referenced as an active system. Acceptance: `grep -r "souffle" scripts/ --include="*.gd" | wc -l` returns 0 (or only comments). [agents: bug_hunter, code-reviewer]

- [ ] **P0-B** Remove `flux` references from `scripts/`. Same shape as P0-A. Targets: `FLUX_*` constants in `merlin_constants.gd`, flux state keys in `merlin_store.gd`, flux UI hooks. [agents: bug_hunter, code-reviewer]

- [ ] **P0-C** Remove `triade` references from `scripts/`. Includes `TRIADE_*` action dispatch rename: `TRIADE_START_RUN -> START_RUN`, `TRIADE_GET_CARD -> GET_CARD`, `TRIADE_RESOLVE_CHOICE -> RESOLVE_CHOICE`, `TRIADE_END_RUN -> END_RUN`, `TRIADE_DAMAGE_LIFE -> DAMAGE_LIFE`, `TRIADE_HEAL_LIFE -> HEAL_LIFE`, `TRIADE_GENERATE_MAP -> GENERATE_MAP`, `TRIADE_SELECT_NODE -> SELECT_NODE`, `TRIADE_PROGRESS_MISSION -> PROGRESS_MISSION`, `TRIADE_USE_SKILL -> USE_SKILL`, `TRIADE_APPLY_EFFECTS -> APPLY_EFFECTS`. Update all callers: `merlin_game_controller.gd`, `test_merlin_store.gd`, `test_llm_full_run.gd`, `test_llm_benchmark_run.gd`, `test_llm_intelligence.gd`, `auto_play_runner.gd`, `game_debug_server.gd`. [agents: refactor-cleaner, code-reviewer]

- [ ] **P0-D** Remove `bestiole` references from `scripts/`. Includes deletion of `scripts/ui/bestiole_*.gd` files (5 files, ~410 lines), bestiole state in `game_manager.gd`, bestiole UI in `merlin_game_ui.gd`. [agents: refactor-cleaner, code-reviewer]

- [ ] **P0-E** Remove `awen` references from `scripts/`. Targets: `REROLL_AWEN_COST` in `Calendar.gd`, awen UI hooks. Replace with biome-currency where the gameplay function is preserved. [agents: refactor-cleaner, code-reviewer]

- [ ] **P0-F** Remove `gauges` references from `scripts/`. Includes `GAUGES` const in `merlin_card_system.gd`, gauge init/check/effect logic, `LEGACY_GAUGE_EFFECTS` in `merlin_effect_engine.gd` (keep `QUEUE_CARD`/`TRIGGER_ARC` in `VALID_CODES`). [agents: refactor-cleaner, code-reviewer]

- [ ] **P0-G** Remove `essence` references from `scripts/`. Targets: `essence{14}` meta state keys in `merlin_store.gd`, `ESSENCE_*` constants in `merlin_constants.gd`, essence effects in `merlin_effect_engine.gd`. [agents: refactor-cleaner, code-reviewer]

- [ ] **P0-H** Delete `scripts/minigames/mg_de_du_destin.gd` (D20 dice — replaced by minigame system). [agents: refactor-cleaner]

- [ ] **P0-I** Delete `scripts/ui/hub_souffle_bar.gd`, `scripts/ui/hub_triade_hud.gd`. [agents: refactor-cleaner]

- [ ] **P0-J** Update `scripts/autoload/merlin_visual.gd`: remove palette entries `souffle`, `souffle_full`, `bestiole`. Remove `CRT_ASPECT_COLORS Triade` section. Verify GBC has no dead entries. [agents: art_direction, code-reviewer]

- [ ] **P0-K** Final acceptance check: `grep -rE "souffle|flux|triade|bestiole|awen|bond|gauges|essence" scripts/ --include="*.gd"` returns lines only inside commented historical refs. Then run `cmd.exe /c "C:\\Users\\PGNK2128\\Godot-MCP\\validate.bat"` and verify 0 errors / 0 warnings. Commit: `refactor(cleanup): remove all dead systems (Phase 0 closes)`. [agents: code-reviewer, security-reviewer]

---

## Phase 1 — Core Data Layer Alignment (after Phase 0)

> Bible v2.4 has 18 Oghams with specific effects. The current `OGHAM_FULL_SPECS` in `merlin_constants.gd` does NOT match. Phase 1 corrects the divergences.

### Phase 1 Tasks

- [ ] **P1-A** Read `docs/GAME_DESIGN_BIBLE.md` Ogham specs and `scripts/merlin/merlin_constants.gd:OGHAM_FULL_SPECS`. Produce a diff table (one row per Ogham: bible-effect vs code-effect vs verdict). Output: `docs/audits/ogham_alignment_2026-05.md`. [agents: code-explorer]

- [ ] **P1-B** For each diverging Ogham (from P1-A diff), update `OGHAM_FULL_SPECS` to match the bible. One commit per Ogham (18 max). [agents: bug_hunter, code-reviewer]

- [ ] **P1-C** Verify `OGHAM_AFFINITY_SCORE_BONUS` (+10%) and `OGHAM_AFFINITY_COOLDOWN_BONUS` (-1) constants are wired correctly in `merlin_effect_engine.gd`. [agents: code-explorer, code-reviewer]

- [ ] **P1-D** Add unit tests for `MerlinTestEngine.scaled_dc()` (the asymptotic curve from Cycle 11). Test cases: card_index 0/1/3/5/10/20/30/50 + each `difficulty_tier` 1/2/3 + `base_override` path. File: `tests/test_merlin_test_engine.gd`. [agents: tdd-guide, code-reviewer]

---

## Anti-Targets (DO NOT pick these)

Studio must NEVER spawn workers for:

- Anything in `tools/octogent/` (the dashboard itself — that's "improving the meta-tool")
- Anything in `tools/autodev/` (autonomous loop infrastructure)
- Anything in `server/` (MCP server)
- `validate.bat` modifications
- `package.json` / `pnpm-lock.yaml` modifications
- `.claude/agents/` or `.claude/hooks/` edits
- New audit reports without an explicit user request (they don't ship the game)

If the LLM auto-gen at Tier 3 proposes any of the above, REJECT and try again with the constraint reinforced.

---

## Effectiveness KPIs (track these per session)

- **Game-code commit ratio**: target >= 80% of commits should be in `scripts/`, `scenes/`, `assets/`, `addons/merlin_*`. Current baseline (audit 2026-05-10): 25%.
- **Phase 0 dead-code count**: 872 -> 0. Each `P0-*` task should reduce by 50-150 refs.
- **Worker autonomous commit count**: target >= 1 per worker per hour while running. Current baseline: 0.
- **Validate.bat green**: must stay green (0 errors / 0 warnings) at every merge.

---

## Older entries (archived)

Older focus blocks (C42b code-review fixes, C41 forge redesign, etc.) have been moved to git history. This file now tracks ONLY the live game-development backlog. The Forge tooling work is complete enough to support autonomous game dev — further forge improvements happen only on user-explicit request.
