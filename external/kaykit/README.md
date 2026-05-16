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

| Pack | Purpose in MERLIN | Repo |
|---|---|---|
| Adventurers | Druide / hero figurines (pion tokens) | `KayLousberg/KayKit-Adventurers` |
| Mini-Game Variety | Props rituels : runes, potions, coffres, parchemins | `KayLousberg/KayKit-Mini-Game-Variety-Pack` |
| Animated Characters 2 | Animated rigs idle/attack | `KayLousberg/KayKit-Animated-Characters-2.0` |
| Medieval Hexagon | Biome terrain tiles modulaires | `KayLousberg/KayKit-Medieval-Hexagon-Pack` |
| Skeletons | Ankou faction creatures | `KayLousberg/KayKit-Skeletons-Pack` |
| Dungeon Pack | Cabin/temple interiors | `KayLousberg/KayKit-Dungeon-Pack` |

## Clone instructions

Each pack as git submodule under this directory :

```bash
cd external/kaykit
git submodule add https://github.com/KayLousberg/KayKit-Adventurers.git adventurers
git submodule add https://github.com/KayLousberg/KayKit-Mini-Game-Variety-Pack.git mini-game-variety
git submodule add https://github.com/KayLousberg/KayKit-Animated-Characters-2.0.git animated-characters
git submodule add https://github.com/KayLousberg/KayKit-Medieval-Hexagon-Pack.git hexagon
git submodule add https://github.com/KayLousberg/KayKit-Skeletons-Pack.git skeletons
git submodule add https://github.com/KayLousberg/KayKit-Dungeon-Pack.git dungeon
git submodule update --init --recursive
```

**Note** : exact KayKit repo URLs may differ ; verify on https://kaylousberg.com or
https://github.com/kaylousberg . If KayLousberg's source is itch.io (gated), download
manually + place `.blend`/`.glb` files in the appropriate subdirectory.

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

## Status

- [ ] external/kaykit/adventurers (clone pending)
- [ ] external/kaykit/mini-game-variety (clone pending)
- [ ] external/kaykit/animated-characters (clone pending)
- [ ] external/kaykit/hexagon (clone pending)
- [ ] external/kaykit/skeletons (clone pending)
- [ ] external/kaykit/dungeon (clone pending)

**Note** : clones to be performed manually by developer (network-heavy operation,
not auto-cloned in CI). After clone, run a one-shot import script (TBD) to
batch-convert .blend → .glb via godot-blender-exporter.
