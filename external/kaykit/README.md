# KayKit Asset Pipeline — MERLIN v7.7.6

> **Canonical source** for 3D low-poly stylized assets per bible §20.3.
> Pipeline : `.blend` (KayKit) → `vertex_color_master` (paint flat faces) →
> `godot-blender-exporter` (.glb) → Godot import → `CelShadingManager.apply_recursive`
> (outline noir signature bible §20).

## Why KayKit

- **License** : CC0 / MIT (free commercial use)
- **Style consistency** : all KayKit packs share identical low-poly stylization
- **Format ready** : `.blend` + `.glb` shipped, drop-in Godot 4.5 compatible
- **Scale & rigging** : 1 unit = 1 meter, characters rigged for Godot AnimationPlayer
- **Vertex colors** : faces flat-shaded via vertex colors (compatible CelShadingManager)

## Recommended packs (clone as needed)

**Verified GitHub source (2026-05-16)** : `KayKit-Game-Assets` org (NOT `KayLousberg/`).
The personal `KayLousberg/*` repos do not exist on GitHub ; KayKit is split between
itch.io distribution and the `KayKit-Game-Assets` GitHub mirror.

| Pack | Purpose in MERLIN | GitHub Repo | Status |
|---|---|---|---|
| Adventurers v1.0 | Druide / hero figurines (Mage = druide-guardian) | `KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0` | ✓ verified |
| Skeletons v1.0 | Ankou faction creatures | `KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0` | ✓ verified |
| Medieval Hexagon v1.0 | Biome terrain tiles modulaires | `KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0` | ✓ verified |
| Dungeon Remastered v1.0 | Cabin/temple interiors | `KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0` | ✓ verified |
| City Builder Bits v1.0 | (optional) buildings/walls if needed | `KayKit-Game-Assets/KayKit-City-Builder-Bits-1.0` | ✓ verified |
| Prototype Bits v1.0 | (optional) primitives + ramps for greybox | `KayKit-Game-Assets/KayKit-Prototype-Bits-1.0` | ✓ verified |
| Mini-Game Variety | Props rituels | itch.io only (gated) | × not on GitHub |
| Animated Characters 2 | Animated rigs idle/attack | itch.io only (gated) | × not on GitHub |

## Clone instructions (verified URLs)

Each pack is heavy (~140 MB) so they are **gitignored** (not submodules) and
specific `.glb` files used by the game are copied into `Assets/blender/` instead.

```bash
cd external/kaykit
git clone --depth 1 https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0.git adventurers
git clone --depth 1 https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0.git skeletons
git clone --depth 1 https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0.git hexagon
git clone --depth 1 https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0.git dungeon
```

After clone, copy needed `.glb` files into `Assets/blender/` with MERLIN naming :

```bash
# Druide figurines
cp adventurers/addons/kaykit_character_pack_adventures/Characters/gltf/Mage.glb ../../Assets/blender/kaykit_mage.glb
# Skeleton creatures (Ankou)
cp skeletons/addons/kaykit_character_pack_skeletons/Characters/gltf/Skeleton_Warrior.glb ../../Assets/blender/creature_skeleton_warrior.glb
# Tiles
cp hexagon/addons/kaykit_medieval_hexagon_pack/Tiles/gltf/Tile_Forest.glb ../../Assets/blender/tile_forest.glb
```

## Naming convention (MERLIN-specific)

Once assets imported, rename per :
- `druide_*.glb` → `Assets/blender/druide/`
- `prop_*.glb`   → `Assets/blender/props/`
- `tile_*.glb`   → `Assets/blender/tiles/biome_X/`
- `creature_*.glb` → `Assets/blender/creatures/faction_X/`

## Vertex color palette mapping

Use `tools/blender_addons/vertex_color_master` to paint faces with biome-specific
palette from `scripts/board_narration/biome_palettes.gd` :

```
foret_broceliande : primary #4a7c5a, secondary #2d4a35, accent #d4a868
landes_bruyere    : primary #8a6a9c, secondary #5d4670, accent #d4a868
... (see biome_palettes.gd for 8 biomes)
```

## Outline at runtime

After importing the `.glb` into a scene, ALWAYS apply outline noir signature :

```gdscript
# In scene script _ready()
var asset_root: Node3D = $ImportedKaykitAsset
CelShadingManager.apply_recursive(asset_root, {"outline_thickness": 0.012})
```

This is **mandatory per bible §20.3** — no asset ships without outline noir.

## Validation pipeline

Per CLAUDE.md §10 systematic policy :

1. New asset imported → `CelShadingManager.apply_recursive` confirmed via grep
2. Vertex colors painted → no white default faces remaining
3. Material check : 1 StandardMaterial3D per mesh, vertex_color_use_as_albedo = true
4. Smoke scene loading the asset → no SCRIPT ERROR + visible outline

## Status (v7.7.16 — 2026-05-16)

Full KayKit-Game-Assets org library cloned (10 packs, ~540 MB, all gitignored).

- [x] external/kaykit/adventurers — Character-Pack-Adventures-1.0 (Mage = druide)
- [x] external/kaykit/skeletons — Character-Pack-Skeletons-1.0 (Ankou faction)
- [x] external/kaykit/hexagon — Medieval-Hexagon-Pack-1.0 (biome tiles)
- [x] external/kaykit/dungeon — Dungeon-Remastered-1.0 (cabin/temple interiors)
- [x] external/kaykit/city — City-Builder-Bits-1.0 (villages)
- [x] external/kaykit/prototype — Prototype-Bits-1.0 (greybox primitives)
- [x] external/kaykit/halloween — Halloween-Bits-1.0 (cemetery / headstones for ruines)
- [x] external/kaykit/furniture — Furniture-Bits-1.0 (interiors)
- [x] external/kaykit/restaurant — Restaurant-Bits-1.0 (kitchen/food)
- [x] external/kaykit/space — Space-Base-Bits-1.0 (sci-fi, may surprise-fit Niamh archipel)

Complementary repos cloned in `external/lowpoly_assets/` :
- plants (Shapespark-Low-Poly-Exterior-Plants — CC0)
- lowpoly_tree (MechanicalFlower procedural tree — MIT)
- kenney_platformer (Kenney Nature/Platformer GLBs — CC0)
- kenney_hexagons (hex terrain blueprint — CC0)
- awesome_cc0_index (madjin curated index)

Mage.glb still imported as `Assets/blender/kaykit_mage.glb` (kept for revert),
but scene spawn removed in v7.7.16 (user request « enleve le mage des scenes »).

**Note** : clones are gitignored (`external/kaykit/*/` + `external/lowpoly_assets/*/`).
Only specific `.glb` copies in `Assets/blender/` are committed.

### Verified pipeline (v7.7.8)

KayKit `Assets/blender/kaykit_mage.glb` is spawned in `BoardNarration._ready` →
`_spawn_kaykit_guardian()` at position `(3.4, 0.0, 0.6)`, scale `0.55`. The
outline noir is applied via `CelShadingManager.apply_recursive` per bible §20.6.
Smoke + capture confirmed character renders with proper silhouette outline.
