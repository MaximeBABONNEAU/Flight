# Task Plan — MERLIN Game Development

> **Source**: `docs/DEV_PLAN_V2.5.md` (canonical phase plan).
> **Consumed by**: `tools/octogent/prompts/studio-director.md` Tier 1 backlog.
> **Last refresh**: 2026-05-16 (v7.7.10 pipeline complete : KayKit + HUD + animations).

---

## v7.7.7 → v7.7.10 — Pipeline serial cleanup [2026-05-16]

User instruction : *« A, puis tu vérifie et check A et ensuite B ... etc, fais en /loop le traitement »*
Sequential A→B→C→D→E with verification gates.

### A — KayKit canonical asset pipeline (v7.7.8) — `5f0ca582` ✓
- Found KayKit on GitHub : `KayKit-Game-Assets` org (NOT KayLousberg/*).
- Cloned Adventurers pack (142 MB, gitignored).
- Copied `Mage.glb` (3.5 MB committed) to `Assets/blender/kaykit_mage.glb`.
- Fixed bible §20.6 violation : `sigle_token.gd` GLB imports now get
  `CelShadingManager.apply_recursive` (was missing — figurines shipped without outline).
- New `_spawn_glb_guardian(path, pos, scale, rot)` reusable helper in board_narration.
- New `_spawn_kaykit_guardian()` default Mage spawn — fires regardless of plateau source.
- Code-review : 0 CRITICAL/HIGH, 2 MEDIUM fixed.

### B — Disco 4-stat HUD + level-up toast (v7.7.9) — `e7dbd772` ✓
- 4 stacked Labels top-right under "Carte X/Y" : Logic/Empathie/Volonté/Instinct.
- Format : `◆ Logic L3 80%` (glyph + name + level + pass-chance %).
- Color-coded per stat (cyan/rose/gold/violet).
- Live updates via `MerlinStats.stat_changed` signal + scale-pulse FX.
- Level-up toast center-screen 1.5s with fade-in/drift-up/fade-out.
- `_exit_tree` disconnects autoload signals (HIGH-1 leak fix).
- Tweens use `bind_node` to auto-stop on free (HIGH-2 fix).
- Code-review : 0 CRITICAL, 2 HIGH fixed.

### C — Animation P0 trio (v7.7.10) — `efa04948` ✓
- **Parabolic card fly** : `live_card_3d.fly_to_marker` — single linear → 2-phase arc.
- **Boss sting** : red flash + camera Z-punch + SFX, relative recovery.
- **Death anim** : red vignette + camera pull-back + tilt-down + SFX sting.
- Intro transition : already present in `_phase_intro`.
- Code-review : 0 CRITICAL/HIGH, 2 MEDIUM fixed.

### D — Test build verification ✓
- Smoke BoardNarration : exit=0 script_errors=0 passed=True (×4 builds).
- Smoke IntroCeltOS / MenuTest : both passed.
- Captures : `tools/autodev/captures/v7_7_{8_kaykit,9_hud_disco,10_full_test,10_intro,10_menu}/`.
- Confirmed visible : KayKit Mage with outline noir, plateau enrichi, biome cards.

### E — Push + docs (this commit)
- task_plan.md : this section.
- Push origin main : 5 commits (fba4eade → efa04948).

### Status v7.7.10 summary

| Phase | Commit | Status | Verified |
|---|---|---|---|
| v7.7.7 plateau enrichi | `fba4eade` | ✓ shipped | Visual + smoke |
| v7.7.8 KayKit pipeline | `5f0ca582` | ✓ shipped | Visual + smoke |
| v7.7.9 Disco HUD | `e7dbd772` | ✓ shipped | Smoke (HUD post-click) |
| v7.7.10 animations | `efa04948` | ✓ shipped | Smoke (events runtime) |

### Deferred (next session)
- KayKit Skeletons + Medieval Hexagon clones (Ankou + biome tiles)
- 96 P1-P3 items from 106-item animation backlog
- Phase 2 bible §29 : Grimoire UI screen
- Phase 3 : Oghams 18 → 9 Rune-Circuits refacto

---

## Active Feature — v7.7.2.1 Playtest Polish [2026-05-15]

**User feedback (verbatim, post-playthrough with screenshot)** :
*« Le menu principal n'a pas de titre, est flou et comporte des bordures à enlever ... Regarde egalement le texte des cartes, les choix sont sur le côté et illisible et sur la carte elle même aussi, il faut du texte contenu forcemment dedans, limiter le nombre de charactères et /ou prévoir que les cartes puissent se retourner pour afficher plus de scénario »*

### Phase 1 — Quick wins (THIS COMMIT)
- [x] MenuTest : retirer `fog_enabled` (cause flou) + retirer `border_width` du bouton (bordures parasites)
- [x] LiveCard3D : `MAX_BODY_CHARS = 140` + `_truncate_at_word()` smart cut + ellipsis "…"
- [x] LiveCard3D : options Label3D réduites à des ▸ markers (plus de texte qui overlap)
- [x] LiveCard3D : `get_option_texts()` API pour exposer le texte aux Button2D
- [x] BoardNarration : `_build_floating_option_buttons` met le TEXTE dans le Button2D + fixed anchor (bottom 30%, vertical stack centré)
- [x] BoardNarration : `_sync_floating_buttons_to_card_3d` no-op (plus de sync à la position de la carte)
- [ ] Parse + smoke + commit

### Phase 2 — Common asset spawn animation (DEFERRED v7.7.3)
*User : « pour l'intro de celtos, tu utilises les animations de chargement 3D d'asset, ce que tu as utilisé pour le deck de départ ... ces animations d'assets doivent être communes à tous les assets, plateau de jeu compris »*
- Extraire `SigleToken.animate_in` pattern → module commun `asset_spawn_animator.gd`
- Appliquer dans : IntroCeltOS phase 3 (assets 3D au boot), ScenarioLoading parchemins, BoardNarration biome assets, plateau, CardDeck3D
- Pattern : digital upload effect (scale 0→1 + outline trace + opacity 0→1, staggered)

### Phase 3 — ScenarioLoading polish (DEFERRED v7.7.3)
*User : « Le choix des scénarios doit etre mieux animé, essaie de trouver des projets d'animation facile qui correspond à notre jeu pour du godot project que tu pourras manier »*
- Rechercher projets Godot 4 d'animation parchemin/scroll unfurl (GitHub, Godot Asset Lib)
- Améliorer parchemin reveal : unfurl scale Y + ink-write typewriter + plume CPUParticles3D
- TTS Merlin commentary pendant la génération (Phase 2.1.6 backlog)

---

## Active Feature — v7.7.2 Plateau-Only Unified Flow [2026-05-15]

**User directive (verbatim)** : *« Connecte toi en MCP à Godot et lie les scénarios entre eux : intro → menu simple 3D → bouton test → BoardNarration (plateau vide, pièce sombre + lampe vers plateau + bouche Merlin au fond) → biome pick → 3 parchemins LLM → scénario écrit + Merlin commente (clustering, cuisine interne) → assets progressifs → board complet. Tout dans la même scène. »*

### Architecture choices (locked via AskUserQuestion)
| Choice | Decision |
|---|---|
| ScenarioLoading fusion | Sub-scene instanciée en enfant (option 1) — `add_child` au lieu de `change_scene_to_file` |
| Menu simple | Nouvelle scène `MenuTest.tscn` (option 1) — gateway intro→board |
| Ambiance | Vraie ambiance dark + lampe + silhouette Merlin (option 1) — KeyLight + Label3D ogham au fond |

### Implementation Phases
- [x] Phase 1.1 — Créer `scenes/MenuTest.tscn` + `scripts/menu_test.gd`
- [ ] Phase 1.2 — Router IntroCeltOS → MenuTest (3 sites L523, L532, L535)
- [ ] Phase 2.1 — Muscler `BoardNarration._apply_neutral_lighting` : background near-black + ambient dim + fog volumétrique
- [ ] Phase 2.2 — Ajouter `BoardNarration._build_merlin_mouth_silhouette` : Label3D ogham au fond
- [ ] Phase 2.3 — Modifier `BoardNarration._on_biome_picked` : load+instantiate+add_child ScenarioLoading
- [ ] Phase 2.4 — Ajouter `BoardNarration._on_scenario_done` callback
- [ ] Phase 3.1 — `scenario_loading.gd` : signal `skeleton_dispatched` + sub-scene aware `_return_to_board`
- [ ] Phase 4 — Parse check + smoke MenuTest + smoke BoardNarration + commit

### Deferred v7.7.3+
- [ ] Merlin speech-bar widget during scenario writing (Phase 2.1.5 backlog)
- [ ] TTS commentary via use_my_voice (Phase 2.1.6)
- [ ] CPUParticles3D plume mécanique (Phase 2.1.7)
- [ ] Progressive asset cascade visualisation

### UX compliance (4 piliers bible §21.1 + ui-ux-pro-max)
- FACILE : Intro auto → MenuTest click TESTER → Board. 1 click full flow.
- ÉVIDENT : Titre + bouton unique, intention <2s.
- MINIMAL : Pas d'UI parasite.
- TACTILE+DESKTOP : Bouton 360×72 ≥ 44×44, hover stylebox ≤100ms.

### Dispatch Plan
Per `task_dispatcher.md` : UI Layout + Animation + LLM Integration. Direct execution (single-agent) — scope trop petit pour multi-wave. `code-reviewer` invoké en fin de phase.

---

## Active Feature — BoardNarration v6.1 : Hand of Fate 3D Card + Bug Fixes [2026-05-14 part 15]

**User feedback (verbatim):** *"On arrete ce principe de fenetre, tout doit etre ecris dans la carte qui est tirée, façon hands of fate dans la carte qui doit préciser le scnéario et les choix à l'intérieur."* + *"Jouetoi même au jeu, capture chaque frame pour voir la cohérence des animations, tout manquement à ce qui a été décris depuis cette session doit etre corrigé (carte mal animé, texte illisible, boutons manquants, texture et assets n'apparaissant pas au bons moment, assets sur le plateau inutiles...)"*

**v6 livré :**
- [x] NEW `LiveCard3D` component : BoxMesh 1.2×1.7 parchemin face + 5 Label3D (badge, body wrappé, 3 options) + idle float Y bobbing + `await_choice()` async + `fly_to_marker(target)` async
- [x] `_show_live_card_3d(card)` remplace `_show_live_card` parchemin path
- [x] 3 Button2D floating ancrés sur option world positions via `_camera.unproject_position` (synced 10Hz)
- [x] `_get_next_marker_position_preview()` permet à la carte de voler vers le futur marker du pion sans le consommer

**v6.1 bug fixes (en cours après auto-playtest v22) :**
- [x] **Bug 1** : parchemin overlay 2D restait visible pendant LLM fetch (~15s) → hide explicitement au start de chaque iteration du live loop
- [ ] **Bug 2** : LiveCard3D peu visible (rendering/depth/size) → bigger Label3D pixel_size, no_depth_test=true, position closer to camera, double_sided material
- [ ] **Bug 3** : audit dice tray + card deck visuels (peuvent ressembler à "objets parasites" sur plateau)
- [ ] Re-smoke + visual verify chaque frame

---

## Active Feature — BoardNarration v5.7 : Computer-Generated Sequential Reveal [2026-05-14 part 13]

**User feedback (verbatim):** *"Remarque visuelle, des objets intulies sont placés sur le plateau / les carte ne sont pas animées et n'arrivent pas devant nos yeux, il n'y a pas d'animation. Donne un délai d'apparition des éléments de la scène, un élément pa un élément et pas tout en même temps, donne l'impression que c'est généré par un ordinaeur donc trouve un effet qui construit et charge de façon très animé tous les objets en 2 à 10 chunk d'assemblage en tetris ou alors shaders uniquement de contour, trouve une forme sympathique"*

**4 fixes ciblés:**
- [x] `JuiceHelpers.materialize_reveal(host, node, delay)` — hologram-style reveal : scale 0→1 TRANS_BACK + emission flash blanc 3x + material fade back to original (~0.6s par élément)
- [ ] Refactor `_run_biome_drop_choreography` séquentiel : plateau pulse → spotlight → fog → dice tray (delay 0.4s) → card deck (delay 0.7s) → first card flies to camera (delay 1.0s)
- [ ] CardDeck3D `draw_top_card()` : carte vraiment visible devant les yeux (HELD_POSITION_LOCAL plus proche caméra, hover 0.6s avant fade)
- [ ] Audit & nettoyer "objets inutiles" : repositionner BoardBiomeBackdrop trees BEHIND plateau, dice tray rim moins visible, supprimer SigleToken legacy spawns

---

## Active Feature — BoardNarration v5 : Plateau Alive + Physics + Biome Drop [2026-05-14 part 7]

**User feedback (verbatim):** *"Le plateau doit être animé, des effets lumineux, des dés à côté le plateau "vit", des effets volumétriques présent, le filtre PSX doit être très léger, une animation complète lors de la sélection du biome qui fait "tomber" les éléments sur le plateau, il faut intégrer également un gestion des collisions et un moteur physique dans le jeu, les decks de carte doivent être présent et on pioche dedans. Animations très détaillées, cherche des projets sur internet à importer rendant l'exploitation de blender et animation par Claude en MCP bien plus facile et intègre dans le pool d'outils"*

### Sub-features
- [ ] **PSX très léger** : `set_psx_preset("subtle")` instead of "medium" + override scanline/curvature/vignette = 0
- [ ] **Plateau vit** : breathing/pulsing point lights on plateau, volumetric fog drift, subtle ambient particle motion
- [ ] **Dés physiques** : 2-3 RigidBody3D dice next to plateau, idle wobble, roll animation on certain events
- [ ] **Biome drop animation** : on biome pick, all biome assets (trees, props, figurines) DROP from sky onto plateau with physics + gravity + bounce settle (3-5s sequence)
- [ ] **Physics card deck** : visible 3D card stack on plateau, RigidBody3D cards, draw animation = top card lifts + slides into hand zone
- [ ] **Volumetric effects** : light shafts through trees, mist drifts, dust motes
- [ ] **Research tools** : web search Godot 4 + Blender MCP integration, physics card game examples, volumetric addons — integrate into `tools/cli.py` pool

### Wave 1 (PARALLEL design)
- [ ] Research agent : GitHub + Exa search for Godot Blender MCP, physics card games, volumetric setups
- [ ] Plateau-alive design agent : drop choreography spec + lighting plan + dice physics + deck draw flow

### Wave 2 (implementation)
- [ ] Apply PSX subtle preset
- [ ] Build physics card deck (CardDeck3D node : N RigidBody3D cards stacked, draw API)
- [ ] Build 3D dice (2-3 RigidBody3D dice, idle settle, roll on dice_test)
- [ ] Refactor biome reveal as physics drop choreography (assets enter at y=+8, drop with gravity, bounce settle)
- [ ] Add plateau lights (pulsing OmniLight3D × 3, breathing color)
- [ ] Add WorldEnvironment volumetric_fog enabled + drift
- [ ] Document research findings in `docs/MCP_TOOL_RESEARCH.md`

### Wave 3 (verify)
- [ ] Parse check + smoke + visual capture
- [ ] Code review of physics + animation changes
- [ ] learn-eval new patterns (physics card draw, drop choreography)

---

## Active Feature — BoardNarration v4 : Persona/Yakuza UI + Rogue-like Acts [2026-05-14 part 6]

**User feedback (verbatim):** *"Réalise des animations UI / UX proches de Persona / Yakuza, bien vibrant et bien visuellement complexe ! Pour le Game Design, ce n'est pas suffisant, il faut des stats pour chaque situation apparente, avec des choix, des evenements différents type rogue like (boutique / event special / boss etc)"*

### Wave 1 (PARALLEL, design)
- [ ] `ux_animation` agent → produces `docs/BOARD_NARRATION_JUICE.md` (7 animation moments: card deal-in, typewriter accents, button reveal, choice impact, HUD ticker, token spawn burst, card-to-card transition)
- [ ] `game_designer` agent → produces `docs/BOARD_NARRATION_ROGUELIKE.md` (per-card stat readout, 5-act rogue structure: Standard / Shop / Standard / Event / Boss, shop UI / event UI / boss UI specs, 8 new Brocéliande pool cards)

### Wave 2 (SEQUENTIAL, implementation)
- [ ] Apply juice animations to `board_narration.gd` : card deal-in, button reveal slide-from-right, click impact shake+freeze, HUD value ticker, token spawn burst
- [ ] Add `act_type` field to card schema + 5-act sequence in `_run_live_loop`
- [ ] Build stat readout overlay (Difficulty/Risk/FactionPressure/RewardHint badges on card)
- [ ] Implement Shop UI variant (3 wares with price-in-life)
- [ ] Implement Event UI variant (3 event types)
- [ ] Implement Boss UI variant (larger card, 2-phase narration, Anam reward)
- [ ] Add 8 new Brocéliande cards to `fastroute_cards.json` (2 shop + 3 event + 3 boss)

### Wave 3 (Verification)
- [ ] Code-review (everything-claude-code:code-reviewer)
- [ ] Autoplay smoke + visual capture verifying : act indicator visible, stat readout visible, shop variant rendered, event variant rendered, boss variant rendered, all animations smooth
- [ ] Run learn-eval to extract any new patterns

---

## Active Feature — BoardNarration RPG Mechanics + LLM Continuity [2026-05-14 part 5 — corige]

## Active Feature — BoardNarration RPG Mechanics + LLM Continuity [2026-05-14 part 5 — corige]

**User feedback (verbatim):** *"Le scénario doit être écrit et réflechis de long en large par le LLM intégré au jeu, plus de scénarisation, pas seulement de simples éléments, il faut qu'il y ait du lien et que les histoires aient des variances, rebondissements, le texte doit s'écrire petit à petit, pas uniquement des choix mais de la mécanique de RPG autour de ça car là aucun impact, les cartes ne sont pas existantes, j'ai juste des choix qui s'enchainent sans aucun sens ; corige"*

**6 fixes — status:**
- [x] **Typewriter reveal** : `_typewriter_live(text)` at 22 cps with skip-on-click ; replaces instant `text = "…"` assignment in `_show_live_card`
- [x] **LLM timeout bump** : 6s → 15s in `_fetch_card_with_fallback` so the LLM has real generation time
- [x] **HUD with RPG state** : `_build_hud()` adds life ProgressBar (red fill + bronze border) + 5 faction Labels (Druides/Anciens/Korrigans/Niamh/Ankou) in top-right HBox + `_floating_fx_layer` for FX above HUD ; `_refresh_hud()` syncs from `state.run.life_essence` + `state.meta.faction_rep`
- [x] **Floating effect feedback** : `_animate_effect_feedback(effects)` parses ADD_REPUTATION / HEAL_LIFE / DAMAGE_LIFE and spawns `+5 Druides` / `-3 vie` labels via `_spawn_floating_label` (rise + fade Tween 1.6s)
- [x] **Card badges** : `_card_badge_label` RichTextLabel at top of parchment shows title + Ogham glyph (Unicode from `MerlinConstants.OGHAM_FULL_SPECS`) — replaces "just text + 3 buttons" with visible card identity
- [x] **LLM narrative continuity** : Bug found — `context_builder.build_full_context()` was NOT including `story_log` field, so the adapter's two-stage prompt read empty history and every card was generated cold. Fix: add `story_log` + `current_biome` to `build_full_context` return dict. Also bump cap in `store_run.gd::resolve_choice` from 2 to 10 entries so 5-card runs preserve full history.

**Validation:**
- Smoke test passed (exit=0, 0 script_errors, 145 frames captured)
- Frame 10 verified : biome selector with Brocéliande highlighted, 7 others greyed
- Pending : AUTOPLAY=1 smoke to capture HUD + typewriter + floating FX mid-card

---

## Active Feature — BoardNarration Scenario End-to-End [2026-05-14 part 4 — /loop completion]

**Status:** /loop terminates — completion criterion met (jouable + fonctionnel + équilibré, testé end-to-end via autoplay smoke).

### What was added in this iteration
- [x] FastRoute fallback pool wired : `_fetch_card_with_fallback()` races LLM (6s timeout) vs hand-written cards from `data/ai/fastroute_cards.json` (12 Brocéliande entries)
- [x] `_load_fallback_pool()` filters narrative cards to current `_biome_id`, normalizes to `{id, text, prompt, options}` schema
- [x] `_pick_fallback_card()` cycles through the pool round-robin via `_fallback_index`
- [x] **Autoplay mode** : `MERLIN_AUTOPLAY=1` env var → `_build_biome_selector` skips UI and `call_deferred("_on_biome_picked", "foret_broceliande")` ; click deadline drops from 60s to 4s
- [x] Race-with-timeout pattern reused (fire-and-forget Callable + dict holder + poll)

### End-to-end test results (autoplay smoke)
```
INFO smoke exit=0 | script_errors=0 total_errors=17 warnings=5 passed=True
capture_frames: 388
[BoardNarration] AUTOPLAY ON — auto-picking foret_broceliande
[BoardNarration] fallback pool loaded: 12 foret_broceliande cards
[BoardNarration] done — 5 figurines, 0 narrations, outcome=live
```

5 cards resolved live, 5 SigleTokens spawned on plateau, fallback pool successfully cycled through. Verified visually : Card #3 ("Des champignons luminescents forment un cercle parfait au pied d'un vieux hêtre…") displayed with 3 ink-style options ("Entrer dans le cercle" / "Cueillir un champignon" / "Dessiner les runes au sol"). Final state : 5 figurines visible on plateau, parchment closed, biome theme active.

### Balance verification
- LLM 6s race → fallback ensures **no infinite hangs** even cold-start
- Auto-pick option 0 timeout 4s per card prevents stalled run
- `RESOLVE_CHOICE` dispatched via Store applies effects (faction_rep deltas + life essence drain via standard pipeline)
- Run completes in ~190s scene time (intro 4s + 5×~25s cards + outro)
- No script_errors, no engine crashes, no asset load failures

---

## Active Feature — BoardNarration Scene v3 Refonte [2026-05-14 part 3]

**Status:** Major scope expansion landed. The scene now boots into a neutral plateau with a biome selector overlay; only Brocéliande is selectable. Click triggers a reveal animation + parchment-styled scenario UI with the LLM card system. PSX filter is preserved without CRT residuals (scanlines/curvature/vignette = 0).

### Dispatch Plan (per AUTO-ROUTE hook v2026-05-14)

| Wave | Agent | Type | Status |
|------|-------|------|--------|
| 1 | `blender_tower_architect.md` (architect) | PARALLEL | ✅ Spatial+animation architecture delivered (800 words) |
| 1 | `content_worldbuilding.md` (ui_expert) | PARALLEL | ✅ Narrative content + âme design principles delivered |
| 2 | `blender_qa_renderer.md` (reviewer) | SEQUENTIAL | ⏳ Deferred to post-impl review |

Wave 1 outputs preserved verbatim in this session's chat history; key elements integrated below.

### v3 implementation landed
- [x] PSX filter cleaned : `scanline_opacity=0, curvature=0, vignette_intensity=0` (no CRT residuals)
- [x] `_apply_neutral_lighting()` — boot state with warm single overhead spot, no biome tint, no fog
- [x] `_build_biome_selector()` — 8-button overlay (GridContainer 4×2), Brocéliande only unlocked, 7 disabled with "Apprends encore…" tooltips
- [x] Worldbuilding-agent provided lore : `BIOME_TITLES` ("Le Bois qui Murmure" etc.), `BIOME_LOCK_MESSAGES`, `BROCELIANDE_INCANTATION`
- [x] `_on_biome_picked(biome_id)` → `_reveal_biome_sequence()` : apply biome lighting + backdrop + PSX biome tint + spotlight ramp + fog enable + populate UI header + show parchment with arrival incantation, then run live card loop
- [x] Parchment card style : `bg_color = Color(0.92, 0.86, 0.68, 0.97)` cream + `border = Color(0.30, 0.20, 0.12)` dark wood + sepia ink text + dropshadow
- [x] Ink-line option buttons : transparent bg, sepia underline on hover

### Deferred to next session
- [ ] 3D compass-rose beacon mesh (Wave 1 architect spec) — Blender batch
- [ ] 8 3D stone disc tokens (carved emblem per faction) — Blender batch — replaces the 2D Control overlay
- [ ] 3D card deck meshes on plateau (Inscryption-style stacked cards) — Blender batch
- [ ] Full 5.5s animated reveal (mote columns, tree-grow animation) — Tween orchestration
- [ ] Wave 2 QA review by `blender_qa_renderer` — post-impl

### âme design principles applied (worldbuilding agent)
1. Gravité tendre, jamais sombre
2. Le plateau est une nappe, pas une arène
3. Silence comme matière première
4. Pacing de veillée, pas jeu d'action
5. Retenue visuelle = profondeur émotionnelle
6. Le parchemin est une voix, pas une UI
7. Chaque biome a son grain

---

## Active Feature — Lore Assets Batch [2026-05-14 part 2]

**Status:** 14 NEW assets generated autonomously via Blender MCP. Total **19 GLB** assets in `assets/blender/`. Ready for Godot integration next session.

### Newly delivered (14 GLB this batch, ~605 KB)
- 8 PNJ lore — `gwenn`, `aedan`, `bran`, `morwenna`, `seren`, `puck`, `taliesin`, `branwen` (one per biome, distinct silhouette/accessory/hat)
- 5 totem animals/creatures — `raven`, `wolf`, `deer`, `salmon`, `korrigan creature`
- 1 plateau carved wood — `plateau_carved.glb` (113 KB, 16 primitives: rim torus + 8 Ogham radial carvings + rune circle inset + 4 decorative legs)

Full inventory documented in `docs/BLENDER_PIPELINE.md` § "Asset catalogue".

### Pipeline reproducibility
Same `tools/blender/launch.py` + `mcp__blender__execute_blender_code` flow as session 1. Batch run = single MCP call sending ~370-line Python script. All 14 assets exported in ~10 seconds wall-clock.

### Pending integration (not done this session)
- [ ] Replace BoardNarration's procedural `Plateau` `CylinderMesh` with `plateau_carved.glb` instance
- [ ] `sigle_token.gd` — add PNJ-name lookup (currently faction-only). Map biome → PNJ name → GLB filename.
- [ ] Animal cameo system — show totem next to the highlighted figurine during narration
- [ ] Visual smoke check with new plateau + verify the carved rim aesthetic reads well at the camera distance

---

## Active Feature — Blender Autonomous Asset Pipeline [2026-05-14]

**Detailed plan:** `docs/BLENDER_PIPELINE.md`
**Status:** Foundation infra live. 1 placeholder asset (druid figurine) generated end-to-end.

### Delivered this session (2026-05-14)
- [x] `tools/blender/blendermcp_startup.py` — Blender startup script enabling BLENDERMCP addon + starting server on :9876 (non-blocking, hands control to Blender event loop)
- [x] `tools/blender/launch.py` — Python wrapper with start/--stop/--status/--force, Windows SW_MINIMIZE to keep window minimized while preserving the event loop
- [x] `tools/blender/figurines/figurine_druide.py` — placeholder generator (6 primitives, flat-shaded, Inscryption-aesthetic, low-poly stylized)
- [x] **Live verified** — Blender pid spawned, MCP server up, `get_scene_info` round-trips, `execute_blender_code` executes the figurine script
- [x] `assets/blender/figurine_druide.glb` — 27 992 bytes, valid glTF 2.0 binary, 6 meshes embedded, Y-up
- [x] `docs/BLENDER_PIPELINE.md` — pipeline reference, generator convention, PSX/volumetric roadmap

### Critical learning (saved as pattern for `learn-eval`)
- BLENDERMCP `bpy.app.timers.register` dispatcher **requires** Blender's main event loop to tick.
- `--background` mode → main loop DOES NOT tick → MCP commands hang at "Client handler started".
- Any `time.sleep(N)` in the startup script → freezes the main thread → same hang.
- **Fix**: launch WITHOUT `--background`, use OS minimization (SW_MINIMIZE on Windows), and **return immediately** from the startup `main()` so Blender takes over.

### Roadmap — pending next sessions
- [ ] 4 remaining figurines (Anciens, Korrigans, Niamh, Ankou) — copy `figurine_druide.py` template, vary colors + accessory mesh
- [ ] Plateau bois rond — round wooden table with Ogham engravings on the rim
- [ ] Backdrop Forêt Brocéliande — 4-5 tree variants, stumps, ferns
- [ ] Volumetric effects assets — god ray cone meshes, dust mote particles
- [ ] **PSX filter wire-up** (Medium intensity, Inscryption-like) — SubViewport at 480p + `retro_psx_post.gdshader` + vertex snap shader on figurines
- [ ] **VolumetricFog + god rays** in BoardNarration scene
- [ ] Integration `sigle_token.gd` — replace procedural primitives with `PackedScene.instantiate()` of GLB

---

## Active Feature — BoardNarration Refonte v2.2 + FORGE Captures Viewer [2026-05-13]

**Detailed plans:** `docs/BOARD_NARRATION_PLAN.md` + `docs/FORGE_CAPTURES_VIEWER.md`
**Status:** Visual refonte landed. Two BoardNarration bugs fixed + FORGE viewer wired (API + React).

### v2.2 BoardNarration fixes (2026-05-13)
- [x] **Overlay autoloads bypass** — added `MerlinBackdrop` + `ScreenFrame` to `HIDDEN_OVERLAY_AUTOLOADS` (CanvasLayer autoloads were drawing fullscreen ColorRect over the 3D pass)
- [x] **Restore-on-exit** — moved `_restore_global_overlays()` from `_finish()` to `_exit_tree()` (was bringing MerlinBackdrop back over a still-live 3D scene)
- [x] **Spotlight cone softened** — `spot_attenuation 0.7→1.6`, `spot_angle 22→18`, `spot_range 6→5`
- [x] **Volumetric fog added** — `env.fog_enabled=true`, light tan tint, density 0.018 → softens spotlight, adds depth
- [x] **Visual check via PNG capture** — 3019 frames captured, intro+5 figurines+outro all confirmed visible

### FORGE Captures Viewer shipped (2026-05-13)
- [x] `tools/octogent/apps/api/src/createApiServer/capturesRoutes.ts` — 3 routes (list, manifest, serve PNG)
- [x] `requestHandler.ts` — registered `["captures", [...]]` in `API_ROUTE_MAP`
- [x] `tools/octogent/apps/web/src/components/CapturesPrimaryView.tsx` — React scrubber + play controls
- [x] `docs/FORGE_CAPTURES_VIEWER.md` — API contract + wire-up steps + roadmap
- [ ] **Pending wire-up** : allocate `PrimaryNavIndex` slot + add `ConsolePrimaryNav` entry + `PrimaryViewRouter` switch case — see doc

### Known remaining items
- [ ] Patch `tools/adapters/godot_adapter.py` to interpret `--duration` as seconds (currently passes raw to `--quit-after` which counts FRAMES in Godot 4.5 → users need to multiply by 60)
- [ ] Optionally trim `tools/autodev/captures/board_narration_v2/` post-_finish() idle frames (≥frame 1000 are redundant black-ish idle)
- [ ] Run `code-reviewer` agent on 3 new files (capturesRoutes.ts, CapturesPrimaryView.tsx, board_narration.gd v2.2 edits)
- [ ] Run `learn-eval` skill at session end to extract patterns

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

---

## ACTIVE: QA v1 corrective batches (2026-05-14 part 17)

**Origin**: User AskUserQuestion answer after QA v1 multi-agent report (`docs/QA_REPORT_v1.md` — 73% pass / 22 fails / 2 CRITICAL + 6 HIGH).
**Order**: A → B → D (small edits) → C (LLM bulk, background) → QA v2 cascade.
**Smoke gate after each phase.**

### Phase A — Restore Core Loop (CRITICAL)
- [x] A.1 — `merlin_constants.gd:102` LIFE_ESSENCE_DRAIN_PER_CARD = 1 (reverses director q-20260412-001, QA CRITICAL 7.1)
- [ ] A.2 — `merlin_constants.gd:390` EFFECT_CAPS.drain_per_card = 1
- [ ] A.3 — `sfx_helpers.gd` Loop ambient streams (`amb_*` → LOOP_FORWARD) QA CRITICAL 9.2
- [ ] A.4 — `biome_ambience.gd` PRESETS.particle_amount 200 → 60 (QA HIGH 4.8)
- [ ] A.5 — smoke A verify

### Phase B — UX Bible §21 Compliance
- [ ] B.1 — Hide BiomeLabel + NarrationLabel + LifeValueLabel during live card (QA HIGH 8.3)
- [ ] B.2 — SkipButton ≥44×44 px (QA HIGH 8.4)
- [ ] B.3 — Add Back/Retour button → MerlinCabinHub (QA HIGH 3.11)
- [ ] B.4 — smoke B verify

### Phase D — Visual Polish
- [ ] D.1 — `project.godot` MSAA 2x (QA MEDIUM 5.3)
- [ ] D.2 — `project.godot` Viewport 1920×1080 (QA MEDIUM 5.2)
- [ ] D.3 — Delete dead `_build_card_overlay` + 4 refs (QA LOW 1.15)
- [ ] D.4 — Cameo threshold 15 → 10 (QA MEDIUM 6.10)
- [ ] D.5 — Remove 0.5 death halving (QA MEDIUM 6.12)
- [ ] D.6 — Hover SFX on floating buttons (QA MEDIUM 3.15)
- [ ] D.7 — Music cross-fade dedicated AudioStreamPlayer (QA HIGH 9.6)
- [ ] D.8 — smoke D verify

### Phase C — Replayability (background LLM)
- [ ] C.1 — Bulk-generate 380+ fastroute cards via Ollama qwen2.5:7b (QA HIGH 7.9)
- [ ] C.2 — Validate JSON + merge into fastroute_cards.json
- [ ] C.3 — smoke C verify

### Phase QA v2 — Re-run cascade
- [ ] QA2.1 — 3 parallel agents (visual / reactivity-fps-audio / fun-rpg-ux)
- [ ] QA2.2 — Aggregate `docs/QA_REPORT_v2.md`
- [ ] QA2.3 — Compare score v1 (73%) vs v2 (target 90%+)
- [ ] QA2.4 — AskUserQuestion next steps

---

## ACTIVE: v7.5 visual + v7.6 LLM bi-brain (2026-05-15 part 19+20)

### v7.5 SHIPPED — visual pivot + capture pipeline
- [x] Bible v3.4 — §20 low-poly flat + outline + §22 8 biome palettes + §23 mood mystique chaleureux
- [x] 3 perf repos cloned `external/` (multi_mesh_manager, MeshLodGenerator, godot-blender-exporter)
- [x] CelShadingManager pivot (low-poly flat + outline kept)
- [x] biome_palettes.gd (8 hex palettes) + biome_loader.gd + multimesh_outline_helper.gd
- [x] 7 biomes builders migrated to palettes (BoardBiomeBackdrop)
- [x] BiomeLoader wired into board_narration plateau loading
- [x] Capture pipeline 4 bugs fixed (LLM warmup blocker, Timer autostart, PROCESS_MODE_ALWAYS, bootstrap-skip)
- [x] CelShadingManager.apply in _spawn helper (all backdrop spawns get outline)
- [x] JuiceHelpers.materialize_reveal cascade in _spawn (digital-upload progressive)
- [x] _spawn_multimesh_trees via MultiMeshOutlineHelper (2 draw calls for 18 trees)
- [x] plateau_carved.glb DISABLED (was source of persistent rectangle)
- [x] Volumetric fog boosted (density 0.022→0.045, length 24→36, emission 0.25→0.55)
- [x] JuiceHelpers GeometryInstance3D-aware (MMI flash works)
- [x] 8 biomes visual validation (output/captures/biomes_v7_4/) — rectangle gone, palettes distinct

### v7.6 IN PROGRESS — LLM bi-brain runtime
- [x] 1.1 — `addons/merlin_ai/bi_brain_pipeline.gd` orchestrator (~280 LOC) :
  - GBNF JSON output (GM) → Narrator from-scratch prose
  - RAG context injection (retrieve_top_k preferred, last-3 journal fallback)
  - Cascade fallback (GM fail → empty Dict → caller FastRoute ; Narrator fail → GM text stub)
- [ ] 1.2 — Audit `merlin_ai.gd` `generate_with_system` routing : verify `params.brain` actually selects qwen3.5:2b vs qwen3.5:4b per brain_swarm_config NANO/SOLO/DUAL/QUAD
- [ ] 1.3 — Add `MerlinAI.generate_card_bi_brain(biome, act, ogham)` entry point
- [ ] 1.4 — Wire call site in `merlin_omniscient.gd` or `merlin_card_system.gd` card fetch path
- [ ] 1.5 — Test on smoke (capture passed=True 0 errors) with bi-brain enabled

### v7.6 Next phases (user-confirmed 2026-05-15 part 20)
- Phase 2 — Interference Merlin (bible §12) : Swap/Hide/Amplify/Bait/Hint/Gift slots per Confiance T0-T3
- Phase 3 — Pre-fetch + cache N+3 cartes (zero latency card draw)
- Phase 4 — Dynamic act swap (Profiler signal → swap standard→shop/event)
- Phase 5 — Rêve inter-run (1ère carte run N référence run N-1)

---

## ACTIVE: v7.7 Scenario-front-loaded LLM (2026-05-15 part 21)

**Architecture (user-confirmed via 3 rounds AskUserQuestion)** :
- Pre-game loading : LLM produces 3 titles + ogham glyphs (minimal) → player picks 1 → LLM writes 5-beat skeleton (faction_tilt + emotion arc) → cards JIT per-beat via v7.6 BiBrainPipeline
- Loading UX : Merlin live narration streaming (Narrator brain parallel to GM)
- Pre-fetch carte N+1 immediately after render N (zero in-game latency)
- LLM-judge brain : post-card divergence detection (1-2s, Phase 2)
- Adaptive : LLM re-plans beats[from..5] when player diverges (Phase 2)
- Budget : ~25s loading + 0s in-game (~9-10 GB VRAM, mid-range PC)
- Cascade fallback L1→L2→L3 (full LLM → FastRoute → 40 hardcoded skeletons)

### v7.7 Phase 1 SHIPPED (foundation)
- [x] 1.1 — `data/ai/scenario_skeleton.gbnf` (GBNF for `{title, beats:[5×{n, summary, faction_tilt, emotion}]}`)
- [x] 1.2 — `addons/merlin_ai/scenario_planner.gd` (~310 LOC) :
  - `generate_titles(biome) -> Array[{title, ogham}]×3` with LLM err / parse fail / overlong-line fallback
  - `generate_skeleton(biome, title) -> Dictionary` GBNF-constrained, fallback to `FALLBACK_SKELETONS` const
  - `generate_card_for_beat(skeleton, beat_idx, player_state) -> Dictionary` delegates to v7.6 BiBrainPipeline
  - `judge_divergence(...)` Phase 2 stub (returns false)
  - `replan_from_beat(...)` Phase 2 stub (returns skeleton unchanged)
  - `BEAT_ACT_SEQUENCE` const single-source-of-truth for 5-beat → act_type mapping
- [x] Code-reviewer agent : 0 CRITICAL / 0 HIGH / 3 MEDIUM all fixed (const for beat seq, push_warning for biome miss, MAX_TITLE_LENGTH guard)

### v7.7 Phase 2 (next session)
- [ ] 2.1 — Loading screen scene `scenes/ScenarioLoading.tscn` (3 titles + Merlin streaming text + steps progress)
- [ ] 2.2 — Wire `ScenarioPlanner` into `board_narration.gd` run start flow (before `_on_biome_picked`)
- [ ] 2.3 — Extend `BiBrainPipeline` to accept beat-context Dictionary (faction_tilt + emotion + summary) injected into GM + Narrator prompts
- [ ] 2.4 — Implement `judge_divergence` (3rd brain mini qwen3.5:2b, ~2s budget)
- [ ] 2.5 — Implement `replan_from_beat` (regen beats[from..5] preserving 1..from-1)
- [x] 2.3 — beat-context injection in BiBrainPipeline (commit 8dbbe1cc)
- [x] 2.4 — judge_divergence hybrid LLM+heuristic (commit 8dbbe1cc + c6f2196d HIGH fix)
- [x] 2.5 — replan_from_beat real implementation (commit 8dbbe1cc, variable size in 70ce9f80)
- [x] 2.6 — FALLBACK_SKELETONS expanded 1→8 biomes (commit 8dbbe1cc)
- [x] 2.7 — Variable beat count 5-10 (GBNF flex + chain-of-thought + clamp) (commit 70ce9f80)
- [ ] 2.8 — Smoke + capture validation (loading screen + variable-card playthrough)

### v7.7 Phase 2.1 SPEC (locked 2026-05-15 part 23 via 8 AskUserQuestion answers)

**Run start flow finalized** :
1. Empty scene → plateau materialize (v7.5 digital-upload, shipped)
2. Biome selector (existing)
3. Backdrop assets cascade reveal (v7.5, shipped)
4. **Scene change to `scenes/ScenarioLoading.tscn`** (NEW)
5. 3 parchemins 3D floating in front of camera (LiveCard3D-style) — unfurl + ink-write animation
6. Player picks 1 parchemin (title + ogham glyph)
7. **Quill phase** — CPUParticles3D dorées + Merlin speech-bar pulsing + TTS robot voice
8. LLM writes 5/7/10-beat skeleton (chain-of-thought decides ambition)
9. Transition back to BoardNarration with skeleton loaded
10. JIT per-beat cards via BiBrainPipeline + judge + replan (Phase 2.3/2.4/2.5 shipped)

**Phase 2.1 deliverables (~600 LOC + 1 .tscn + 1 .gdshader)** :
- [ ] 2.1.1 — `scenes/ScenarioLoading.tscn` skeleton (Node3D root + Camera3D + DirectionalLight3D + UI CanvasLayer)
- [ ] 2.1.2 — `scripts/scenario_loading.gd` — controller : instantiate ScenarioPlanner, run titles+skeleton flow, handle parchemin picks
- [ ] 2.1.3 — 3D parchemin mesh (PlaneMesh + parchment NoiseTexture + ogham glyph Label3D + title Label3D) — apply CelShadingManager
- [ ] 2.1.4 — Parchemin unfurl animation : scale Y 0→1 over 0.5s, ink-write typewriter on title 30 cps
- [ ] 2.1.5 — Merlin speech-bar widget (2D Control + .gdshader fragment shader for pulse-on-amplitude glow #d4a868 — EDI/GLaDOS style)
- [ ] 2.1.6 — TTS pipeline : route via `use_my_voice` skill + AudioEffectChorus + Distortion for robot effect
- [ ] 2.1.7 — CPUParticles3D quill node : 30 particles, gold albedo, gravity=0, lifetime 2s, emission ring
- [ ] 2.1.8 — Wire `board_narration._on_biome_picked` → set `_PARAMS` autoload biome_id → scene change to ScenarioLoading
- [ ] 2.1.9 — Wire ScenarioLoading completion → return to BoardNarration with skeleton in `_run_data["scenario_skeleton"]`
- [ ] 2.1.10 — Smoke + capture validation : titles render, parchemin unfurl visible, speech-bar pulses, particles drift, transition smooth

---

## ACTIVE: v7.7 outline coverage audit (2026-05-15 part 24)

**Audit summary (Wave 1 agent)** : 57 spawn sites, 14 covered, **43 missing** outline. Skip list : 5 (billboards, fog quads, dev tools, grass shader, god-rays). Real gaps : **38 across 13 files**.

### Batch 1 SHIPPED — 14 sites (4 files, this session)
- [x] sigle_token.gd : 4 sites (base + body + head + accessory)
- [x] scenario_loading.gd : 1 site (parchemin PlaneMesh)
- [x] merlin_cabin_hub.gd : 5 sites (floor + cauldron + crystal + tapestry + wall_map + lanterns + walls) — via agent
- [x] forest_asset_spawner.gd : 5 sites (procedural trunk + canopy + fallback trunk + crown loop + shrub) — via agent

### Batch 2 BACKLOG — 24 remaining sites (9 files, next session orchestration)
- [ ] broceliande_forest_3d.gd : 2 (rocks + grass patches)
- [ ] broc_chunk_manager.gd : 2 (vegetation MM + canopy spheres MM) — needs `MultiMeshOutlineHelper.build_pair` refactor
- [ ] broc_creature_spawner.gd : 1 (voxel creature pixel)
- [ ] broc_events.gd : 3 (firefly + mushroom circle + shadow figure)
- [ ] broc_extra_decor.gd : 4 (crystal + glow orb + stone pillar + ground rune)
- [ ] broc_event_vfx.gd : 3 (shadow pass + spawn glow orbs + mushroom circle VFX)
- [ ] forest_merlin_npc.gd : 1 (voxel Merlin NPC)
- [ ] forest_zone_builder.gd : 1 (water cylinder)
- [ ] forest_terrain_builder.gd : 3 (main ground + rolling hills + path MM)
- [ ] vegetation_manager.gd : 2 (canopy MM + generic vegetation MM)

### Orchestration plan next session
Spawn 3 parallel agents :
- **Agent A** : `broc_events.gd` + `broc_event_vfx.gd` + `broc_extra_decor.gd` (10 sites, MEDIUM/HIGH)
- **Agent B** : `broc_creature_spawner.gd` + `forest_merlin_npc.gd` + `forest_zone_builder.gd` + `broceliande_forest_3d.gd` (5 sites, mixed)
- **Agent C** : MultiMesh refactor — `broc_chunk_manager.gd` + `forest_terrain_builder.gd` + `vegetation_manager.gd` (7 sites, HIGH, requires `MultiMeshOutlineHelper.build_pair` API migration)
Then smoke verify + commit.

### UI Slack audit (deferred)
Per user request "UI slack très limitée" — separate audit needed of `board_narration.gd` HUD / `scenario_loading.gd` UI / `merlin_cabin_hub.gd` HUD against bible §21.1 minimal (≤7 affordances). Spawn `ux_flow.md` agent in next session.

### Visual polish audit (deferred)
Per user request "beaux effets visuels" — survey lighting / post-process / particle FX / transitions for polish opportunities. Spawn `motion_designer.md` + `vis_particle.md` agents in next session.
