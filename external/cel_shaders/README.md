# Cel Shader Projects — Okami-style outline references (v7.7.16)

> User intent : « tours noirs comme okami + cel shader » — thick sumi-e ink
> outlines plus flat cel-shaded fills. Find Godot 4 compatible projects that
> apply this EASILY to existing assets.

Status (2026-05-16) : 2 projects cloned (MIT). Integration deferred to v7.7.17.

## Cloned projects

### 1. eldskald/godot4-cel-shader (per-mesh shader)

```
external/cel_shaders/eldskald_cel/
```

- **Repo** : https://github.com/eldskald/godot4-cel-shader
- **License** : MIT
- **Last commit** : Oct 2025 (most active Godot 4 cel-shader)
- **Approach** : ShaderMaterial with inverse-hull outline via `next_pass`
- **Outline thickness/color** : exposed as uniforms — tunable to thick sumi-e
- **Per-asset setup** : drop-in for `CelShadingManager.apply_recursive` — walk
  the Node3D tree, assign `surface_override_material[i] = cel_mat` and
  `cel_mat.next_pass = outline_mat`. No UV maps required.

**Integration sketch (deferred to v7.7.17)** :

```gdscript
# scripts/board_narration/cel_shading_manager.gd — proposed swap of
# _attach_inverted_hull_outline() with eldskald shader.
const ELDSKALD_CEL_SHADER := preload("res://external/cel_shaders/eldskald_cel/shaders/cel.gdshader")
const ELDSKALD_OUTLINE_SHADER := preload("res://external/cel_shaders/eldskald_cel/shaders/outline.gdshader")

static func _apply_eldskald_outline(mesh: MeshInstance3D, opts: Dictionary) -> void:
    var outline_mat := ShaderMaterial.new()
    outline_mat.shader = ELDSKALD_OUTLINE_SHADER
    outline_mat.set_shader_parameter("outline_color", opts.get("outline_color", Color.BLACK))
    outline_mat.set_shader_parameter("outline_thickness", opts.get("outline_thickness", 0.025))
    var cel_mat := ShaderMaterial.new()
    cel_mat.shader = ELDSKALD_CEL_SHADER
    cel_mat.next_pass = outline_mat   # chained inverse-hull pass
    mesh.material_override = cel_mat
```

Sumi-e preset values :
- `outline_color` = `Color(0, 0, 0, 1)` (pure black, no anti-alias)
- `outline_thickness` = `0.025` to `0.035` (thick ink stroke)
- `cel_steps` = 2 (binary cel, harshest contrast)

### 2. jocamar/Godot-Post-Process-Outlines (post-process camera)

```
external/cel_shaders/jocamar_pp_outlines/
```

- **Repo** : https://github.com/jocamar/Godot-Post-Process-Outlines
- **License** : MIT
- **Approach** : `PPOutlinesCamera` node — drop in once, ALL scene geometry
  gets uniform black outlines without touching any `MeshInstance3D`.
- **Per-asset setup** : ZERO. Single global toggle.
- **Trade-off** : less control per-mesh, but simplest possible deployment.

**Integration sketch (deferred to v7.7.17)** :

```tscn
# scenes/BoardNarration.tscn — proposed addition
[node name="PPOutlinesCamera" type="Camera3D" parent="."]
script = ExtResource("res://external/cel_shaders/jocamar_pp_outlines/pp_outlines_camera.gd")
outline_color = Color(0, 0, 0, 1)
outline_thickness = 2.0    # screen-space pixels
```

## Decision matrix (v7.7.17 integration)

| Criterion | eldskald (per-mesh) | jocamar (post-process) |
|---|---|---|
| Visual control | High (per-mesh tuning) | Low (global only) |
| Setup complexity | Medium (recursive material swap) | Trivial (one node) |
| Perf cost | +N drawcalls (1 per outlined mesh) | +1 full-screen pass |
| Compatibility with CelShadingManager | Drop-in replacement | Side-by-side (CelShadingManager + camera) |
| Best for | Hero props, plateau, figurines | Global scene outline (all biome decor) |

## Recommendation (deferred)

**Hybrid** : use jocamar PPOutlinesCamera as the BASELINE global outline (covers
KayKit assets that are too numerous to per-mesh-process), and reserve eldskald
cel+outline for HERO meshes (plateau, MerlinSoundBar, figurines) where per-mesh
tuning matters.

## Reverting

If new shaders introduce regressions, the current `CelShadingManager.apply_recursive`
with its inverted-hull pattern at `outline_thickness=0.008` is preserved and is
the fallback. No commit removes it.
