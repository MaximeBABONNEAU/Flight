# BoardNarration — Post-Run Cinematic Replay

> Plan dédié — session 2026-05-12 | Complexity MODERATE | Branch main

## Goal

Build a Godot 4 post-run scene where the player watches a cinematic replay of their run on a 3D plateau. Each card encountered becomes an Ogham sigil token. Biome-specific lighting + particles + plateau material give ambience. Merlin (LLM) comments each sigil as it lights up. The narrative is persisted to a `run_history` journal for cross-run continuity.

## User Decisions (locked via AskUserQuestion 2026-05-12)

| Dimension | Choice |
|-----------|--------|
| Placement | Post-fin de run, AVANT EndRunScreen (insert, not replace) |
| Role | Replay narratif du run (chronological cards-as-tokens) |
| Visual style | Sigles Ogham (use existing Unicode glyphs U+1680..U+169F) |
| Mechanic | Lecture passive cinématique (click-to-advance, no input) |
| Background | 3D plateau per-biome with shaders/lighting (not flat PNG) |
| Merlin voice | LLM Ollama (merlin-narrator-lora) — already deployed |
| Scope | Functional Godot scene + 4 scripts + flow wiring |
| Integration | Read MerlinStore.run_state + persist journal to save profile |

## Architecture

### New files

| Path | Role |
|------|------|
| `scenes/BoardNarration.tscn` | 3D scene root — camera, lights, plateau, UI overlay |
| `scripts/board_narration/board_narration.gd` | Controller (class_name BoardNarration) |
| `scripts/board_narration/sigle_token.gd` | Single Ogham token (Node3D + Label3D + OmniLight3D) |
| `scripts/board_narration/biome_ambience.gd` | Static helper — per-biome lighting / particles / plateau material |
| `scripts/board_narration/run_journal.gd` | Static helper — build journal entries, persist via save_system |

### Modified files

| Path | Change |
|------|--------|
| `scripts/core/game_flow_controller.gd` | Add SCENE_BOARD_NARRATION + route run_ended → BoardNarration → EndRunScreen |
| `scripts/merlin/merlin_save_system.gd` | Add `save_run_journal(entry)` appending to `meta.run_history` (FIFO cap 30) |

### Data flow

```
Run completes → run_ended signal
  → GameFlowController._on_run_ended()
    → BoardNarration scene loaded
      → reads MerlinStore.state.run (story_log, factions, biome, oghams_decouverts, cards_played)
      → BiomeAmbience.apply_to(scene, biome) — light + particles + plateau material
      → for each card in story_log: spawn SigleToken at spiral position
      → narration loop: highlight token → LLM call → typewriter → click to advance
      → on done: RunJournal.save_to_profile(save_system, journal_entry)
      → emit narration_done → flow controller
    → EndRunScreen loaded (existing 3-screen flow: narrative / journey / rewards)
  → Hub
```

### Journal entry schema (written to `profile.meta.run_history[]`)

```json
{
  "run_id":       "uuid-v4 string",
  "biome":        "foret_broceliande",
  "ended_at":     "2026-05-12T21:35:00Z",
  "outcome":      "death | victory | abandon | hard_max",
  "cards_played": 12,
  "life_final":   0,
  "cards": [
    {
      "card_id":   "string",
      "ogham":     "beith | luis | ... | empty string if no ogham",
      "option":    0,
      "faction_deltas": {"druides": 5.0, "korrigans": -3.0}
    }
  ],
  "narrations": [
    {"card_id": "string", "comment": "string", "source": "llm | fallback"}
  ],
  "final_factions": {
    "druides":  42.0, "anciens":  18.0, "korrigans":  7.0,
    "niamh":    33.0, "ankou":   12.0
  }
}
```

FIFO cap 30 (oldest entries dropped). Date format ISO-8601 UTC. All field names are stable.

## Per-Biome Ambience Spec

| Biome | Light direction | Light color | Particles | Plateau material |
|-------|-----------------|-------------|-----------|------------------|
| foret_broceliande | top-left, soft | #5c8a4a (mossy green) | drifting leaves, slow | mossy stone, green tint |
| landes_bruyere | low-right, harsh | #c89048 (heather gold) | wind streaks, fast | weathered scrub texture |
| cotes_sauvages | high, blue-cool | #6090b8 (sea-foam blue) | sea-spray mist | wet granite slab |
| villages_celtes | bottom-front (hearth) | #d87038 (ember orange) | ember sparks rising | wooden plank, dark grain |
| cercles_pierres | high, cold cyan | #8090a8 (moonlit grey) | low fog | unpolished granite, runes etched |
| marais_korrigans | side, eerie | #a8b840 (will-o-wisp yellow-green) | mist + floating glow | peat moss, dark brown |
| collines_dolmens | overhead, muted | #b89860 (dust gold) | slow dust motes | weathered limestone |
| iles_mystiques | omnidirectional | #80c0d0 (ethereal cyan) | snow + mist mix | obsidian black, polished |

Source colours bias toward `MerlinVisual.BIOME_CRT_PALETTES[biome][5]` (mid-bright index) with adjustments per biome.

## Acceptance Criteria

- BoardNarration.tscn parses (validate.bat passes)
- Smoke test passes: `python tools/cli.py godot smoke --scene "res://scenes/BoardNarration.tscn" --duration 10` → `passed=true, script_errors=[]`
- Scene initializes with mock run_state if no real run available (test mode)
- Each of 8 biomes has distinct lighting + particle preset (no fallback to a single biome)
- Sigle tokens use unicode glyphs from `MerlinConstants.OGHAM_FULL_SPECS[ogham].unicode`
- LLM call is optional — fallback to deterministic text per Ogham category if Ollama unavailable
- Journal entry appended to `profile.meta.run_history[]` after narration completes
- No regression in `EndRunScreen.tscn` smoke

## Out of Scope (this session)

- AI sprite generation via Nano-Banana
- 3D figurines GLB
- TTS voice
- Drag-and-drop or other mechanics
- Per-biome custom plateau GLB meshes (use one CylinderMesh + biome material swap)
- 8 GLB biome environment imports (procedural lighting + particles only this round)
