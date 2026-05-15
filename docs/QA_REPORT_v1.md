# M.E.R.L.I.N. — QA Report v1 (Multi-Agent Human-Test Playthrough)

> **Build**: v7.1 + cel-shading wiring
> **Scene**: `scenes/BoardNarration.tscn`
> **Smoke evidence**: passed=true, script_errors=0, total_errors=0, exit=0
> **Date**: 2026-05-14
> **Rubric**: `docs/QA_RUBRIC_v1.md` (104 items)

## Score Global
| Agent | Domains | Passes | Fails | N/A | % pass |
|-------|---------|--------|-------|-----|--------|
| qa-visual | 1, 2, 5 | 32 | 7 | 1 | 80% |
| qa-reactivity-fps-audio | 3, 4, 9 | 22 | 8 | 3 | 67% |
| qa-fun-rpg-ux | 6, 7, 8 | 22 | 7 | 2 | 71% |
| **TOTAL** | **9 domains** | **76** | **22** | **6** | **73%** |

## Issues classés par sévérité

### 🔴 CRITICAL (2 issues — gameplay-blocking)
| ID | Domaine | Issue | Evidence | Fix |
|----|---------|-------|----------|-----|
| 7.1 | RPG Logic | `LIFE_ESSENCE_DRAIN_PER_CARD = 0` au lieu de 1. Pipeline step 1 (DRAIN_VIE) = no-op. La pression de survie est CASSÉE. | `merlin_constants.gd:102` + `merlin_game_controller.gd:343` dispatche DAMAGE 0 | Mettre `LIFE_ESSENCE_DRAIN_PER_CARD = 1` et `EFFECT_CAPS.drain_per_card = 1` |
| 9.2 | Audio | Ambient biome stream est un one-shot 1.2s, PAS un loop. L'immersion s'effondre après 1.2 secondes. | `sfx_helpers.gd:18-24` make_stream sans loop_mode; `sfx_recipes_ambient.gd:529` dur=1.20s | `wav.loop_mode = AudioStreamWAV.LOOP_FORWARD` sur les streams `amb_*` |

### 🟠 HIGH (6 issues — strong impact on player experience)
| ID | Domaine | Issue | Evidence | Fix |
|----|---------|-------|----------|-----|
| 7.9 | RPG Logic | FastRoute pool = 117 cartes (bible §13 + CLAUDE.md demande ≥500). | `data/ai/fastroute_cards.json` | Générer 380+ cartes additionnelles via LLM bulk |
| 8.3 | UX MINIMAL | ~11 affordances UI simultanées pendant live card (LifeBar+Value+Anam+Act+CardCount+Biome+Narration+Skip + 3 floating + LiveCard3D) vs cap ≤7 (loi Miller). | `board_narration.gd:800-902, 1573-1614, 2461` | Pendant LIVE CARD : masquer BiomeLabel + NarrationLabel + LifeValueLabel |
| 8.4 | UX TACTILE | SkipButton = 128×32 px viole ≥44×44 (bible §21.1) | `board_narration.gd:1602-1605` offsets | `custom_minimum_size = Vector2(120, 48)` |
| 9.6 | Audio | Ambient music shift = 1.2s one-shot via SFX pool, pas un cross-fade entre streams loopés. | `board_narration.gd:967-973` | AudioStreamPlayer dédié 'Ambient' bus, cross-fade volume_db ~1.5s |
| 3.11 | Réactivité | Pas de bouton Retour/Back vers le hub (seul Skip existe). Bible §21.3 le mandate. | grep `back_button` = 0 matches | Ajouter Button 'Retour' sur _ui_layer top-left avec action scene change → MerlinCabinHub |
| 4.8 | Performance | 200+24 = 224 particules simultanées vs cap <100. | `biome_ambience.gd:62,102,127` PRESETS.particle_amount=200 + `biome_backdrop.gd:204` pollen=24 | Réduire PRESETS.particle_amount à 60 (cotes/iles/marais) |

### 🟡 MEDIUM (5 issues — quality concerns)
| ID | Domaine | Issue | Evidence | Fix |
|----|---------|-------|----------|-----|
| 5.3 | Rendu | Pas de MSAA 3D dans project.godot. Avec viewport 1280×720, les outlines cel-shading aliasent visiblement. | `project.godot:87-94` aucune clé msaa_3d | `rendering/anti_aliasing/quality/msaa_3d=2` |
| 5.2 | Rendu | Viewport déclaré 1280×720, rubric attendait 1920×1080. Mismatch invalide score 5.2 + indirect impact 4.1/2.12. | `project.godot:50-53` | Soit bump à 1920×1080, soit doc 1280×720 comme canonique |
| 6.12 | Fun | Death penalty stack DOUBLE consolation : `min(cards/30, 1.0)` × 0.5 → 15 cartes = 0.25 du base. Bible §16.1 = un seul multiplicateur. | `store_run.gd:399` + `board_narration.gd:2177` | Retirer le 0.5 halving, garder seul `cards/30` |
| 6.10 | Fun | Cameo threshold faction ≥15 trop haut, easter egg invisible dans la plupart des runs. | `board_narration.gd:986` | Baisser à ≥10 OU pre-seed faction biome dominante à +5 |
| 3.15 | Réactivité | Pas de SFX hover sur les floating option buttons. Seul le click. | grep `mouse_entered` = 0 | `btn.mouse_entered.connect(func(): SFXManager.play('hover'))` |

### 🟢 LOW (4 issues — polish)
| ID | Domaine | Issue | Evidence | Fix |
|----|---------|-------|----------|-----|
| 1.15 | Cohérence | Dead code `_build_card_overlay()` toujours défini (jamais appelé après v7.1), 4 refs à `_card_overlay.visible=false` sur null var. | `board_narration.gd:1911-2010, 2082, 2191, 2221, 2432` | Supprimer la fonction et les 4 refs |
| 1.12 | Cohérence | Body/options Label3D width=380 fit la carte mais marge serrée pour strings FR longues. | `live_card_3d.gd:154,176` | Réduire width=340 (60px de marge supp) |
| 4.1 | Performance | Pas de FPS counter dans la sortie smoke — items 4.1-4.5 ne peuvent être prouvés. | `tools/cli.py godot smoke` n'expose pas frames_per_second | Ajouter flag `--fps-log` au smoke CLI |
| 3.4 | Réactivité | `fly_to_marker` utilise TRANS_SINE EASE_IN, pas TRANS_BACK overshoot (rubric §3.3 demande BACK). | `live_card_3d.gd:255-261` | Optionnel — la carte sort de focus, BACK pas critique |

## Recommandations consolidées (4 batches)

### Batch A — "Restore Core Loop" (CRITICAL + 1 HIGH perf)
- 7.1 : `LIFE_ESSENCE_DRAIN_PER_CARD = 1` (un seul edit, impact massif)
- 9.2 : Loop ambient streams (un patch dans sfx_helpers)
- 4.8 : Réduire particle_amount 200 → 60

**Impact** : Restaure la pression RPG + immersion audio + perf. Sans ça, le jeu est cassé sur ses fondamentaux.

### Batch B — "UX Bible §21 Compliance"
- 8.3 : Hide BiomeLabel + NarrationLabel + LifeValueLabel pendant live card
- 8.4 : SkipButton ≥44×44 px
- 3.11 : Add Back/Retour button → MerlinCabinHub

**Impact** : Aligne le HUD avec la nouvelle bible §21. ≤7 affordances + cibles tap saines.

### Batch C — "Replayability Unlock"
- 7.9 : Bulk-générer 380+ cartes fastroute via LLM (Ollama qwen2.5:7b)

**Impact** : Sans ça, les runs se répètent dès la session 2. La réjouabilité dépend littéralement du pool.

### Batch D — "Visual Polish"
- 5.3 : MSAA 2x (project.godot)
- 5.2 : Décider résolution canonique (1920×1080 ou 1280×720 doc)
- 1.15 : Supprimer dead code `_build_card_overlay`
- 6.10 + 6.12 : Tweak cameo threshold + death penalty
- 3.15 : Hover SFX sur boutons
- 9.6 : Music cross-fade dédié

**Impact** : Polish quality-of-life. Tout fonctionne mais le rendu et la fluidité gagnent en lustre.

---

*Report v1 — généré par cascade Wave 1 parallèle (3 agents) + agrégation. Voir CLAUDE.md §9 pour le déclenchement automatique de cette cascade sur tout playthrough/game-design.*
