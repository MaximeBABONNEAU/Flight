## ═══════════════════════════════════════════════════════════════════════════════
## CelShadingManager — Low-Poly Flat + Black Outline (v7.3, 2026-05-15)
## ═══════════════════════════════════════════════════════════════════════════════
## Marque de fabrique du jeu — voir GAME_DESIGN_BIBLE §20 (v3.4 pivot).
## Tout asset 3D visible du joueur DOIT passer par CelShadingManager.apply().
##
## v7.3 pivot — user feedback 2026-05-15 :
##   Style : Low-poly flat geometric (Monument Valley / Alto / Tunic) + outline noir.
##   DROPPED : Toon diffuse (DIFFUSE_TOON, SPECULAR_TOON).
##   KEPT    : Inverted-hull outline noir (signature).
##   ADDED   : vertex_color_use_as_albedo = true (Blender per-face vertex colors).
##   ADDED   : SHADING_MODE_PER_VERTEX (Gouraud, lit faceté pas Phong).
##
## API stable (6 sites de wiring ne changent pas) :
##   CelShadingManager.apply(mesh: MeshInstance3D, opts: Dictionary = {})
##   CelShadingManager.apply_recursive(root: Node, opts: Dictionary = {}) -> int
##
## Options :
##   outline_thickness : float — scale offset for the inverted hull (default 0.015)
##   outline_color     : Color — silhouette color (default Color.BLACK)
##   skip_outline      : bool  — skip the hull (decorative-only flat assets)
##   skip_flat_remap   : bool  — keep the source material's shading mode untouched
##                                (use when the asset ships with a custom shader)
##
## Note de nommage : la classe garde son nom historique `CelShadingManager` pour
## éviter de casser les 6 callers existants. La sémantique a pivoté vers low-poly
## flat (bible §20 v3.4) mais l'outline noir reste la marque de fabrique signature.
## ═══════════════════════════════════════════════════════════════════════════════

class_name CelShadingManager
extends Object

## v7.7.17 — User request « contour noir complet ». Bumped default thickness
## and added a global multiplier so all 11 callers get a uniform thicker outline
## without per-call-site changes.
const DEFAULT_OUTLINE_THICKNESS := 0.022   # was 0.015
const OUTLINE_THICKNESS_MULTIPLIER := 1.4   # global uniform bump (A/B tunable)
const OUTLINE_NODE_NAME := "_CelOutline"


## Apply low-poly flat shading + inverted-hull black outline to a MeshInstance3D.
## Idempotent : safe to call twice (second call is a no-op via marker child name).
static func apply(mesh: MeshInstance3D, opts: Dictionary = {}) -> void:
	if mesh == null or not is_instance_valid(mesh):
		return
	if mesh.has_node(OUTLINE_NODE_NAME):
		return
	if not bool(opts.get("skip_flat_remap", false)):
		_apply_flat_to_material(mesh)
	if not bool(opts.get("skip_outline", false)):
		_attach_inverted_hull_outline(mesh, opts)


## Convert the mesh's material(s) to low-poly flat shading.
## - DIFFUSE_LAMBERT (drops the toon banding from v7.1)
## - SHADING_MODE_PER_VERTEX (Gouraud — fast, fits low-poly facetted look)
## - vertex_color_use_as_albedo = true (honors Blender per-face Vertex Paint)
## - SPECULAR_DISABLED (flat assets shouldn't shine)
static func _apply_flat_to_material(mesh: MeshInstance3D) -> void:
	var mat: Material = mesh.material_override
	if mat is StandardMaterial3D:
		_remap_smat(mat as StandardMaterial3D)
		return
	if mat != null:
		return  # custom shader — don't override
	var m: Mesh = mesh.mesh
	if m == null or m.get_surface_count() == 0:
		return
	var s0: Material = m.surface_get_material(0)
	if s0 is StandardMaterial3D:
		var dup: StandardMaterial3D = s0.duplicate() as StandardMaterial3D
		_remap_smat(dup)
		mesh.material_override = dup


static func _remap_smat(smat: StandardMaterial3D) -> void:
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	smat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	smat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# Honor Blender per-face vertex colors (workflow GAME_DESIGN_BIBLE §20.3 v3.4).
	smat.vertex_color_use_as_albedo = true
	# Keep ambient so the mystic-warm key+spot+ambient lighting reads on flat faces.


## Attach an inverted-hull black silhouette as a child MeshInstance3D.
## Child uses the same mesh, scaled by (1 + outline_thickness), CULL_FRONT, unshaded.
static func _attach_inverted_hull_outline(mesh: MeshInstance3D, opts: Dictionary) -> void:
	if mesh.mesh == null:
		return
	# v7.7.17 — Apply global multiplier so all 11 callers get a uniform thicker
	# outline ("contour noir complet" per user request).
	var base_thickness: float = float(opts.get("outline_thickness", DEFAULT_OUTLINE_THICKNESS))
	var thickness: float = base_thickness * OUTLINE_THICKNESS_MULTIPLIER
	var color: Color = opts.get("outline_color", Color.BLACK)
	var outline := MeshInstance3D.new()
	outline.name = OUTLINE_NODE_NAME
	outline.mesh = mesh.mesh
	outline.scale = Vector3.ONE * (1.0 + thickness)
	var omat := StandardMaterial3D.new()
	omat.albedo_color = color
	omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	omat.cull_mode = BaseMaterial3D.CULL_FRONT
	omat.no_depth_test = false
	omat.render_priority = -1
	outline.material_override = omat
	mesh.add_child(outline)


## Convenience batch : apply to all MeshInstance3D descendants of `root`.
static func apply_recursive(root: Node, opts: Dictionary = {}) -> int:
	if root == null:
		return 0
	var count := 0
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back() as Node
		if n is MeshInstance3D:
			apply(n as MeshInstance3D, opts)
			count += 1
		for child in n.get_children():
			if child is Node and child.name != OUTLINE_NODE_NAME:
				stack.append(child)
	return count
