# M.E.R.L.I.N. — QA Rubric v1 (Human-Test Multi-Agent Evaluation)

> 104 mesurables — Décrété 2026-05-14 part 17.
> Chaque agent évalue son domaine en score 0/1 + commentaire court + référence fichier:ligne quand possible.
> Le rapport aggregé est `docs/QA_REPORT_v1.md`.

## Méthode de scoring
- **1** = critère satisfait (preuve concrète : screenshot, code, log)
- **0** = critère violé (réf fichier:ligne + suggestion)
- **N/A** = non applicable au build courant

---

## Domaine 1 — Cohérence Visuelle (15 items)
| # | Critère | Réf |
|---|---------|-----|
| 1.1 | Outline noir sur tous les MeshInstance3D du plateau | bible §20.1 |
| 1.2 | Cel-shading uniforme — pas un asset PBR isolé | bible §20.2 |
| 1.3 | Palette cohérente Druido-Tech (ambre/bois/cream) | bible §13 |
| 1.4 | Outline = pur `Color.BLACK`, pas gris | bible §20.2 |
| 1.5 | Pas de Z-fighting outline/mesh (offset > 0.005) | bible §20.5 |
| 1.6 | Outline épaisseur cohérente (tolérance ±20%) | bible §20.5 |
| 1.7 | Plateau circulaire centré (0,0,0) | bible §19.1 |
| 1.8 | Dés visibles caméra, position (0, 0.5, -1.4) TOP-BACK | bible §19.1 |
| 1.9 | Deck pioche LEFT-BACK (-2.4, 0.5, -1.4) | bible §19.1 |
| 1.10 | Deck défausse RIGHT-BACK (2.4, 0.5, -1.4) | bible §19.1 |
| 1.11 | LiveCard3D contenu visible (texte lisible) | bible §21.1 |
| 1.12 | Texte STRICTEMENT contenu dans la carte (no overflow) | bible §19.5 |
| 1.13 | Backdrop biome (arbres) hors plateau (Z<-4 ou hors radius 1.4) | bible §19.2 |
| 1.14 | Volumetric fog cohérent avec biome | code |
| 1.15 | Aucun élément décoratif inerte (gros rectangle vide) | bible §21.2 |

## Domaine 2 — Niveau Visuel / Rendu Quality (15 items)
| # | Critère | Réf |
|---|---------|-----|
| 2.1 | Textures procédurales (parchemin, bois, granit, grass) appliquées | code |
| 2.2 | Lighting setup (key + spot + ambient) | code |
| 2.3 | Emission subtle sur dés (ogham amber glow) | code |
| 2.4 | Drop shadows visibles sous LiveCard3D | code |
| 2.5 | Materialize reveal flash blanc fonctionne | juice_helpers |
| 2.6 | Hit-stop visible sur choix | juice_helpers |
| 2.7 | Particules pollen (CPUParticles3D, 24 motes) | biome_backdrop |
| 2.8 | Trees sway visible (rotation Z ±2-3° loop) | biome_backdrop |
| 2.9 | Grass floor texture procédurale non-uniforme | biome_backdrop |
| 2.10 | Camera angle plateau visible (camera tilt -25°) | code |
| 2.11 | Pas de tearing visuel | runtime |
| 2.12 | Pas de texture pixelated inattendue | runtime |
| 2.13 | Cel-shading bands ≤ 3 paliers | bible §20.5 |
| 2.14 | PSX shader preset "medium" sans scanlines forcés | code |
| 2.15 | Color grading warm amber cohérent | code |

## Domaine 3 — Réactivité (Input + Animation) (15 items)
| # | Critère | Réf |
|---|---------|-----|
| 3.1 | Input latency clic bouton <100ms | bible §21.1 |
| 3.2 | Hit-stop ignore time_scale (wall-clock 80ms) | juice_helpers |
| 3.3 | Tween TRANS_BACK overshoot fluide | code |
| 3.4 | Carte fly_to_marker fluide (0.7s) | live_card_3d |
| 3.5 | Card overlay queue_free synchronisé (no orphan) | board_narration |
| 3.6 | Dice roll settle dans 3s max | dice_physics_3d |
| 3.7 | Faction flip animation fluide | juice_helpers |
| 3.8 | Life ticker count-up fluide | juice_helpers |
| 3.9 | Floating fx label parabolic fluide | juice_helpers |
| 3.10 | Skip button toujours visible | board_narration |
| 3.11 | Back button accessible (hors écrans finaux) | bible §21.3 |
| 3.12 | Pas de double-click required | bible §21.2 |
| 3.13 | Pas de bouton qui freeze pendant tween | runtime |
| 3.14 | Buttons toujours visibles (no hover-only) | bible §19.2 |
| 3.15 | Retour visuel sur chaque tap/clic <100ms | bible §21.1 |

## Domaine 4 — Framerate / Performance (10 items)
| # | Critère | Réf |
|---|---------|-----|
| 4.1 | FPS ≥ 60 sur target hardware | runtime |
| 4.2 | Pas de frame drop visible > 2 frames | runtime |
| 4.3 | Memory usage stable <500MB estimé | runtime |
| 4.4 | Pas de leak (10 cartes = stable RAM) | runtime |
| 4.5 | GPU usage raisonnable | runtime |
| 4.6 | Draw calls <1000 par frame | runtime |
| 4.7 | Lights count <8 actifs simultanément | code |
| 4.8 | Particles count <100 simultanés | code |
| 4.9 | Physics bodies sleep correctement | dice_physics_3d |
| 4.10 | Loading time <3s (scene boot) | runtime |

## Domaine 5 — Rendu Pipeline (10 items)
| # | Critère | Réf |
|---|---------|-----|
| 5.1 | Vulkan Forward+ confirmé | project.godot |
| 5.2 | Resolution 1920×1080 native | runtime |
| 5.3 | Anti-aliasing MSAA actif | project.godot |
| 5.4 | Bloom configuré (subtle) | code |
| 5.5 | Volumetric fog rendu correct | code |
| 5.6 | Shadows enabled (key + spot) | code |
| 5.7 | Reflection probes (si présents) configurés | code |
| 5.8 | SSAO subtle (si activé) | code |
| 5.9 | PSX shader preset stable | code |
| 5.10 | Pas de banding / artifacts visibles | runtime |

## Domaine 6 — Amusement / Fun Factor (15 items)
| # | Critère | Réf |
|---|---------|-----|
| 6.1 | Core loop engaging (cartes→choix→effets visibles) | bible §1 |
| 6.2 | Variabilité contenu cartes (LLM + fallback 500+) | bible §13 |
| 6.3 | Choix significatifs (effets distincts) | bible §13 |
| 6.4 | Feedback positif sur réussite (hit-stop + flash + SFX) | juice_helpers |
| 6.5 | Feedback négatif sur échec (drain visible + SFX) | juice_helpers |
| 6.6 | Stakes augmentent (boss = carte 5 = act_type=boss) | bible §1 |
| 6.7 | Rythme tendu (5 actes, ~6-8 min run total) | bible §1 |
| 6.8 | Réjouabilité (factions distinctes, biomes variés) | bible §13 |
| 6.9 | Récompense cross-run (Anam meta currency) | bible §13 |
| 6.10 | Easter eggs / cameos (totems faction ≥15 rep) | board_narration |
| 6.11 | Storyline cohérente (Brocéliande incantation intro) | content |
| 6.12 | Mort pas frustrant (50% Anam consolation) | bible §13 |
| 6.13 | Tension dans choix (pas d'option évidente) | bible §13 |
| 6.14 | Curiosité activée (cards LLM-générées uniques) | bible §13 |
| 6.15 | Achievement implicite (tokens story_log visibles) | board_narration |

## Domaine 7 — Logique RPG (12 items)
| # | Critère | Réf |
|---|---------|-----|
| 7.1 | Vie 0-100, drain -1 / carte au DEBUT du pipeline | bible §13.3 |
| 7.2 | 5 Factions 0-100, cap ±20/carte | bible §13 |
| 7.3 | 18 Oghams disponibles (3 starters gratuits) | bible §13 |
| 7.4 | 1 Ogham/carte max activable | bible §13 |
| 7.5 | Mort = Anam × min(cartes/30, 1.0) | bible §13 |
| 7.6 | 8 Biomes unlock par maturity score | bible §13 |
| 7.7 | MOS soft min 8, target 20-25, hard max 50 | bible §13 |
| 7.8 | Confiance Merlin 0-100, T0-T3, change mid-run | bible §13 |
| 7.9 | FastRoute pool ≥500 cartes | data/ai/fastroute_cards.json |
| 7.10 | Effets distincts implémentés (HEAL/DAMAGE/REP/PROMISE) | merlin_effect_engine |
| 7.11 | Pas de système supprimé re-introduit | bible §13 |
| 7.12 | Pipeline 12 étapes respecté | merlin_effect_engine |

## Domaine 8 — UX 4 Piliers (bible §21.1) (4 items)
| # | Critère | Réf |
|---|---------|-----|
| 8.1 | **FACILE** — actions clés en ≤2 gestes | bible §21.1 |
| 8.2 | **ÉVIDENT** — intention lisible <2s sans tuto | bible §21.1 |
| 8.3 | **MINIMAL** — ≤7 affordances UI simultanées | bible §21.1 |
| 8.4 | **TACTILE + DESKTOP** — ≥44×44 px, no hover-only, retour <100ms | bible §21.1 |

## Domaine 9 — Audio (8 items)
| # | Critère | Réf |
|---|---------|-----|
| 9.1 | SFXManager actif et autoload | scripts/autoload/SFXManager.gd |
| 9.2 | Ambient biome loop joué (forest wind + birds) | board_narration |
| 9.3 | Dice roll SFX déclenché | board_narration |
| 9.4 | Card click SFX déclenché | board_narration |
| 9.5 | Choice impact SFX (low thunk) | juice_helpers |
| 9.6 | Ambient music shift selon faction dominante | board_narration |
| 9.7 | Volume mixed (pas saturé, pas clipping) | runtime |
| 9.8 | SFX adaptive (variants par contexte) | SFXManager |

---

**TOTAL : 104 items mesurables.**

## Format de scoring par agent
```yaml
agent: <nom_agent>
domain: <domaine_assigned>
items_scored: N
passes: X
fails: Y
na: Z
top_issues:
  - id: 1.12
    severity: CRITICAL|HIGH|MEDIUM|LOW
    evidence: "screenshot/log/file:line"
    suggestion: "..."
```
