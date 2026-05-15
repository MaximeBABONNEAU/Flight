# M.E.R.L.I.N. — Blender → Godot Workflow (Human-Authored, v1.0)

> **Décrété 2026-05-15 part 18** — workflow standard pour TOUS les assets 3D humain-authorés.
> **Style cible** : Low-poly flat geometric + outline noir (bible §20 v3.4).
> **Optimisations** : Draw calls (MultiMesh) + Texture memory (atlas + 512px max) + Aesthetic fidelity (vertex colors per-face + custom normals).
> **Bundling** : 1 GLB par biome — réf bible §22.
> **Complément** : `BLENDER_PIPELINE.md` couvre la génération autonome headless. Ce doc-ci couvre le workflow manuel.

---

## 1. Cibles techniques (NON-NÉGOCIABLES)

| Métrique | Cible |
|----------|-------|
| **Triangles par asset organique** | ≤ 300 (arbre, dolmen, rocher) |
| **Triangles par asset structurel** | ≤ 1000 (cabane, menhir cluster) |
| **Bundle GLB par biome** | ≤ 2 MB (Draco compressé) |
| **Atlas texture par biome** | 1 fichier 1024×1024 max, mipmaps activés |
| **Texture individuelle** | ≤ 512×512 pixels |
| **Draw calls scène complète** | < 1000 / frame |
| **MultiMesh seuil** | ≥ 8 instances → MultiMeshInstance3D |

---

## 2. Workflow Blender (étape par étape)

### 2.1 Modélisation low-poly
- Géométrie minimale. Mirror modifier appliqué avant export.
- Decimate (Collapse, ratio 0.4-0.7) pour low-poly cible.

### 2.2 Shade Flat (CRUCIAL — bible §20.3)
1. **Object Mode** → asset → `Object → Shade Flat`.
2. **Edit Mode** → `Mesh → Normals → Average → Face Area`.

### 2.3 Vertex Colors per-face
1. **Object Data → Color Attributes** → `+ New` : Color, domain **Face Corner**, Byte Color.
2. **Vertex Paint Mode → Face Select** → picker hex de la palette biome (bible §22) → Paint Mask (K).
3. Grouper par couleur via `Select Linked Faces` + paint en masse.

### 2.4 Custom Split Normals (optionnel)
- **Edit Mode** → toutes faces → `Mesh → Normals → Set Custom Split Normals From Faces`.

### 2.5 Export GLB
- **File → Export → glTF 2.0 (.glb)**.
- Options critiques :
  - Format : `GLB (binary)`.
  - Transform : Y Up ✅.
  - Geometry : Apply Modifiers ✅, UVs ✅, Normals ✅, **Vertex Colors ✅ OBLIGATOIRE**.
  - Materials : Export.
  - Compression Draco : niveau 6.
- Destination : `assets/blender/<biome_name>.glb`.

### 2.6 Workaround Blender 4.1+ vertex colors
Côté Godot : cocher **`Use Vertex Color: Active`** dans l'Import panel, ou installer `Vertex Color Import Swapper` (Asset Library). Voir `external/godot-blender-exporter/`.

---

## 3. Référence palette biome (bible §22)

Avant chaque session Vertex Paint :
1. Ouvrir bible §22 → copier les 6 hex codes du biome cible.
2. Dans Blender Brush settings → `+` palette → entrer chaque hex (`#RRGGBB`).
3. Sauvegarder le set comme `palette_<biome>.blender`.

**Règle** : un asset n'utilise QUE des couleurs de la palette de son biome.

---

## 4. Atlas texture

Quand un asset a besoin d'une texture :
1. 1 atlas par biome : `assets/blender/<biome>_atlas.png`, max 1024×1024.
2. UV unwrap manuel (pas Smart UV Project — gaspille l'espace).
3. Mipmaps activés côté Godot.
4. Compression VRAM (BC7 desktop, ASTC mobile).
5. Textures individuelles ≤ 512×512 (LiveCard3D parchemin).

---

## 5. Bundle GLB par biome

### 5.1 Composition
- Mesh `Plateau`.
- Mesh(es) `Tree_01..N` (variantes, **non instanciés ici** — MultiMesh côté Godot).
- Meshes `Rock_*`, `Dolmen_*`, etc.
- Props `BiomeProp_*`.
- **Aucune light** (gérées par `BiomeAmbience` presets).

### 5.2 Hiérarchie recommandée
```
broceliande.glb
├── Plateau                  (1 instance, MeshInstance3D Godot)
├── TreeOak_LP               (1 mesh, MultiMesh source Godot)
├── TreeBirch_LP             (1 mesh, MultiMesh source)
├── Rock_LP_01..03           (MultiMesh sources)
├── MossPatch_LP             (MultiMesh source)
└── DolmenSmall              (MeshInstance3D direct si rare)
```

### 5.3 Import Godot
- Drag GLB dans `res://assets/blender/`.
- Ouvrir via `BiomeLoader._instantiate_biome("foret_broceliande")` (à créer).

---

## 6. MultiMesh strategy

> Repo : `external/multi_mesh_manager/`.

### 6.1 Seuil
- < 8 instances : MeshInstance3D direct.
- ≥ 8 instances : MultiMeshInstance3D obligatoire.

### 6.2 Code pattern
```gdscript
func _spawn_trees_via_multimesh(tree_mesh: Mesh, positions: Array[Transform3D]) -> void:
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = tree_mesh
    mm.instance_count = positions.size()
    for i in positions.size():
        mm.set_instance_transform(i, positions[i])
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    add_child(mmi)
```

### 6.3 Outline + MultiMesh
Inverted-hull `CelShadingManager.apply` n'agit pas sur MultiMesh. **Solution** : second MultiMesh identique avec material override outline (cull FRONT, scale 1.015 sur chaque transform). À implémenter : `MultiMeshOutlineHelper`.

---

## 7. LOD

> Repo : `external/MeshLodGenerator/`.

### 7.1 Quand activer
- Assets ≥ 300 tris ET visibles à distance variable (≥ 10m).
- BoardNarration : optionnel (caméra ~5m). Brocéliande Forêt 3D : obligatoire foliage lointain.

### 7.2 Génération
3 LODs dans Blender via Decimate :
- LOD0 (1.0 ratio).
- LOD1 (0.5 ratio, activation 8m).
- LOD2 (0.2 ratio, activation 20m).

Export les 3 dans même GLB : `Tree_LP_LOD0`, `Tree_LP_LOD1`, `Tree_LP_LOD2`.

---

## 8. Checklist export final

```
□ Shade Flat partout (pas de smooth normals)
□ Vertex colors per-face peints depuis palette biome (bible §22)
□ Triangle count : organiques ≤ 300, structures ≤ 1000
□ Custom split normals appliqués (optionnel)
□ Export GLB : Y Up + Apply Modifiers + Vertex Colors + Normals + Draco 6
□ Taille fichier < 2 MB
□ Atlas ≤ 1024×1024, mipmaps ON côté Godot
□ Aucune light dans le GLB
□ Aucun PBR metalness > 0
□ Asset gameplay (carte, dé, pion) PAS dans bundle biome — fichier séparé
□ Test import Godot : vertex_color_use_as_albedo bien capté
□ Test CelShadingManager.apply : outline noir visible
```

---

## 9. Repos intégrés (référence)

Voir `external/PERF_REPOS.md` :
- `multi_mesh_manager/` — éditeur-friendly MultiMeshInstance3D manager. Réf §6.
- `MeshLodGenerator/` — addon LOD inline. Réf §7.
- `godot-blender-exporter/` — workflow officiel + fix vertex colors 4.1+. Réf §2.6.

---

## 10. Phases d'implémentation suivantes

1. **`scripts/board_narration/biome_palettes.gd`** — 8 palettes hex codées exposées.
2. **`scripts/board_narration/biome_loader.gd`** — charge un GLB biome + crée MultiMesh sources.
3. **`scripts/board_narration/multimesh_outline_helper.gd`** — outline noir pour MultiMesh.
4. **`assets/blender/broceliande.glb`** — premier bundle biome de référence.
5. **CI check** : `tools/cli.py asset validate --biome broceliande`.

---

*BLENDER_WORKFLOW v1.0 — M.E.R.L.I.N. — Source de vérité pipeline 3D human-authored.*
*Réfs bible : §20 (style) + §22 (palettes) + §23 (mood).*
*Complément à `BLENDER_PIPELINE.md` (autonomous generation pipeline).*
