## ═══════════════════════════════════════════════════════════════════════════════
## BiomeLoader — Charge un bundle GLB par biome + détecte MultiMesh sources (v1.0)
## ═══════════════════════════════════════════════════════════════════════════════
## Source de vérité : GAME_DESIGN_BIBLE §22 + docs/BLENDER_WORKFLOW.md §5.
## Réf user AskUserQuestion 2026-05-15 part 18 : "Bundle par biome (1 GLB)".
##
## Contrat d'import GLB (workflow §5.2) :
##   <biome>.glb
##   ├── Plateau               (mesh direct, MeshInstance3D)
##   ├── <Asset>_LP            (mesh source pour instanciation directe)
##   ├── <Asset>_LP_MM         (mesh source pour MultiMesh — au moins 8 instances)
##   └── <Asset>_LP_LOD0/1/2   (variantes LOD du même asset)
##
## API :
##   BiomeLoader.has_bundle(biome_id: String) -> bool
##   BiomeLoader.instantiate_bundle(biome_id: String) -> Node3D (or null)
##   BiomeLoader.extract_mesh_sources(root: Node3D) -> Dictionary
##     Returns : {"direct": [MeshInstance3D...], "multimesh": [MeshInstance3D...]}
##   BiomeLoader.summary(biome_id, root) -> Dictionary (telemetry)
##   BiomeLoader.validate_naming(root) -> Array (CI validator)
##
## Note : Phase 1 = lecteur + detector. La conversion MultiMesh réelle vient
## avec `multimesh_outline_helper.gd` (phase suivante).
## ═══════════════════════════════════════════════════════════════════════════════

class_name BiomeLoader
extends Object

const BUNDLE_DIR := "res://assets/blender/"
const MULTIMESH_SUFFIX := "_MM"
const LOD_SUFFIX_RE := "_LOD[0-9]+$"


## Returns true if a GLB bundle exists for this biome.
static func has_bundle(biome_id: String) -> bool:
	var path: String = BUNDLE_DIR + biome_id + ".glb"
	return ResourceLoader.exists(path)


## Instantiate the GLB bundle for a biome. Returns null if unavailable.
## CelShadingManager.apply_recursive is called on the root so all meshes inherit
## the low-poly flat + outline noir signature (bible §20 v3.4).
static func instantiate_bundle(biome_id: String) -> Node3D:
	var path: String = BUNDLE_DIR + biome_id + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_warning("[BiomeLoader] Bundle '%s' exists but failed to load as PackedScene." % path)
		return null
	var inst: Node = packed.instantiate()
	if inst == null or not (inst is Node3D):
		push_warning("[BiomeLoader] Bundle '%s' instance is not a Node3D root." % path)
		if inst:
			inst.queue_free()
		return null
	var root: Node3D = inst as Node3D
	root.name = biome_id.capitalize().replace("_", "")
	# Apply low-poly flat + outline to every MeshInstance3D under root.
	CelShadingManager.apply_recursive(root, {"outline_thickness": 0.012})
	return root


## Walk the bundle root and classify each MeshInstance3D as either :
##   - "direct"    : MeshInstance3D direct (no MultiMesh conversion)
##   - "multimesh" : mesh source flagged for MultiMesh (suffix _MM)
##
## LOD variants (suffix `_LOD0/1/2`) are NOT classified separately — they are
## kept as sibling surfaces of the same mesh resource. The classifier looks
## only at the BASE name (LOD suffix stripped).
static func extract_mesh_sources(root: Node3D) -> Dictionary:
	var direct: Array = []
	var multimesh: Array = []
	if root == null:
		return {"direct": direct, "multimesh": multimesh}
	var lod_regex := RegEx.new()
	lod_regex.compile(LOD_SUFFIX_RE)
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back() as Node
		if n is MeshInstance3D:
			var base_name: String = lod_regex.sub((n as MeshInstance3D).name, "", false)
			if base_name.ends_with(MULTIMESH_SUFFIX):
				multimesh.append(n)
			else:
				direct.append(n)
		for child in n.get_children():
			# Skip outline children attached by CelShadingManager (marker name).
			if child is Node and child.name != CelShadingManager.OUTLINE_NODE_NAME:
				stack.append(child)
	return {"direct": direct, "multimesh": multimesh}


## Convenience : returns count summary for telemetry / smoke logging.
static func summary(biome_id: String, root: Node3D) -> Dictionary:
	var sources: Dictionary = extract_mesh_sources(root)
	return {
		"biome": biome_id,
		"loaded": root != null,
		"direct_meshes": (sources.get("direct", []) as Array).size(),
		"multimesh_sources": (sources.get("multimesh", []) as Array).size(),
		"palette_keys": BiomePalettes.get_palette(biome_id).keys(),
	}


## Validate that a bundle's mesh names follow the naming convention.
## Used by `tools/cli.py asset validate` (future). Returns list of warnings.
static func validate_naming(root: Node3D) -> Array:
	var warnings: Array = []
	if root == null:
		warnings.append("root is null")
		return warnings
	var seen_plateau := false
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back() as Node
		if n is MeshInstance3D:
			var nm: String = (n as MeshInstance3D).name
			if nm == "Plateau":
				seen_plateau = true
			elif not (nm.ends_with("_LP") or nm.ends_with(MULTIMESH_SUFFIX) or nm.contains("_LOD")):
				warnings.append("Mesh '%s' violates naming : expected <Asset>_LP, <Asset>_LP_MM, ou <Asset>_LP_LOD<N>." % nm)
		for child in n.get_children():
			if child is Node and child.name != CelShadingManager.OUTLINE_NODE_NAME:
				stack.append(child)
	if not seen_plateau:
		warnings.append("Bundle missing 'Plateau' MeshInstance3D (workflow §5.1).")
	return warnings
