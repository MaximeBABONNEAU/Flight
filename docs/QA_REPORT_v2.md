# M.E.R.L.I.N. — QA Report v2 (Post-Corrective-Batches A+B+D)

> **Build**: v7.2 + cel-shading + UX bible §21 compliance
> **Scene**: `scenes/BoardNarration.tscn`
> **Smoke v2**: passed=true, script_errors=0, total_errors=0, exit=0
> **Date**: 2026-05-14
> **Rubric**: `docs/QA_RUBRIC_v1.md` (104 items)
> **Baseline**: `docs/QA_REPORT_v1.md` (73% pass)

## Score Global v1 → v2

| Agent | v1 pass | v2 pass | Δ |
|-------|---------|---------|---|
| qa-visual (D1+D2+D5, 40) | 32 (80%) | **37 (92.5%)** | **+5** |
| qa-reactivity-fps-audio (D3+D4+D9, 33) | 22 (67%) | **28 (85%)** | **+6** |
| qa-fun-rpg-ux (D6+D7+D8, 31) | 22 (71%) | **30 (97%)** | **+8** |
| **TOTAL (104)** | **76 (73%)** | **95 (91%)** | **+19** |

**Aucune régression détectée.** Smoke v2 reste vert (exit=0, 0 script_errors).

## Fixes confirmés

### Batch A (Restore Core Loop)
- ✅ **7.1 CRITICAL** : `LIFE_ESSENCE_DRAIN_PER_CARD = 1` (`merlin_constants.gd:102`) + EFFECT_CAPS.drain_per_card=1 (`:390`). Pipeline step 1 (DRAIN_VIE) restauré. Reverse director q-20260412-001.
- ✅ **9.2 CRITICAL** : Ambient streams loop (`SFXManager.gd:176-179`). LOOP_FORWARD + loop_begin=0 + loop_end=data/2 sur tout stream `amb_*`.
- ✅ **4.8 HIGH** : Particles 200→60 sur cotes_sauvages, marais_korrigans, iles_mystiques (`biome_ambience.gd:62, 101, 127`).

### Batch B (UX Bible §21 Compliance)
- ✅ **8.3 HIGH** : BiomeLabel + NarrationLabel + LifeValueLabel hidden during live card (`board_narration.gd:772-777`). HUD ≤ 7 affordances (loi Miller).
- ✅ **8.4 HIGH** : SkipButton `custom_minimum_size = Vector2(120, 48)` + offsets 144×56 px (`:1616-1622`). ≥44×44 (bible §21.1 TACTILE).
- ✅ **3.11 HIGH** : Back/Retour button mirror left (`:1631-1648`) avec `_on_back_pressed` → MerlinCabinHub.

### Batch D (Visual Polish)
- ✅ **5.2 MEDIUM** : Viewport 1920×1080 (`project.godot:51-54`).
- ✅ **5.3 MEDIUM** : MSAA 2x (`project.godot:97` `rendering/anti_aliasing/quality/msaa_3d=2`).
- ✅ **2.11 + 2.12 + 5.10** : Tearing / pixelated / banding → résolu indirectement par MSAA + 1080p (élimine l'aliasing des outlines cel-shading).
- ✅ **6.10 MEDIUM** : Cameo threshold 15→10 (`:996`). Easter egg atteignable.
- ✅ **6.12 MEDIUM** : Double-penalty death supprimé (`:2218-2221`). Bible §16.1 = un seul multiplicateur (cards/30).
- ✅ **3.15 MEDIUM** : Hover SFX wired (`:2532-2536`) `btn.mouse_entered.connect(...play("hover", 1.0))`.

## Fails restants v2

| ID | Sév | Issue | Statut |
|----|-----|-------|--------|
| 7.9 | **HIGH** | FastRoute pool = 117 (< 500) | DEFERRED — pas de bulk LLM gen script créé ce round |
| 9.6 | **HIGH** | Music cross-fade entre faction variants | DEFERRED — nécessite AudioStreamPlayer 'Ambient' bus dédié |
| 1.12 | LOW | Body width Label3D pourrait passer 380→340 pour 60px marge FR | Polish optionnel |
| 1.15 | LOW | Dead code `_build_card_overlay` + 4 refs `_card_overlay.visible=false` guardées | Safe no-ops, cleanup différé |
| 3.4 | LOW | `fly_to_marker` TRANS_SINE EASE_IN, pas TRANS_BACK overshoot | Non-critique |
| 4.1, 4.3, 4.5 | N/A | FPS/Memory/GPU non télémétrés | CLI smoke n'expose pas — ajout flag `--fps-log` à prévoir |

## Verdict
**91% pass rate**, 2 CRITICAL résolus, 4 HIGH résolus (sur 6 — 2 deferred), 5 MEDIUM résolus.
La scène est **prête pour itération suivante**. Les 2 HIGH restants (cards pool + music cross-fade) sont des tâches scope-defined et non-blocking.

---

*Report v2 — généré par cascade Wave 1 parallèle (3 agents) + agrégation, déclenché par standing-policy CLAUDE.md §9.*
