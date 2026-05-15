## ═══════════════════════════════════════════════════════════════════════════════
## MultiMeshOutlineHelper — Outline noir signature pour MultiMesh (v1.0, 2026-05-15)
## ═══════════════════════════════════════════════════════════════════════════════
## Source de vérité : GAME_DESIGN_BIBLE §20 v3.4 + docs/BLENDER_WORKFLOW.md §6.3.
##
## Problème : CelShadingManager attache un MeshInstance3D enfant pour l'outline.
## Ça ne marche PAS sur MultiMeshInstance3D — il faut un SECOND MultiMeshInstance3D
## identique au premier avec material override outline (cull FRONT, scale 1.015).
##
## API :
##   MultiMeshOutlineHelper.build_pair(mesh, transforms, opts) -> Dictionary
##     Returns : {"main": MultiMeshInstance3D, "outline": MultiMeshInstance3D}
##   MultiMeshOutlineHelper.attach_outline(main_mmi, opts) -> MultiMeshInstance3D
##
## Options :
##   outline_thickness : float — scale offset (default 0.015)
##   outline_color     : Color — silhouette color (default BiomePalettes.OUTLINE_BLACK)
## ═══════════════════════════════════════════════════════════════════════════════

class_name MultiMeshOutlineHelper
extends Object

const DEFAULT_OUTLINE_THICKNESS := 0.015


## Build a main MultiMeshInstance3D + matching outline MultiMeshInstance3D pair.
static func build_pair(mesh: Mesh, transforms: Array, opts: Dictionary = {}) -> Dictionary:
	if mesh == null or transforms.is_empty():
		return {"main": null, "outline": null}
	var thickness: float = float(opts.get("outline_thickness", DEFAULT_OUTLINE_THICKNESS))
	var color: Color = opts.get("outline_color", BiomePalettes.OUTLINE_BLACK)

	# Main MultiMeshInstance3D — Lambert flat from CelShadingManager applied later.
	var main_mm := MultiMesh.new()
	main_mm.transform_format = MultiMesh.TRANSFORM_3D
	main_mm.mesh = mesh
	main_mm.instance_count = transforms.size()
	for i in transforms.size():
		main_mm.set_instance_transform(i, transforms[i])
	var main_mmi := MultiMeshInstance3D.new()
	main_mmi.multimesh = main_mm
	main_mmi.name = "MainMMI"

	# Outline MultiMeshInstance3D — same transforms scaled by (1+thickness).
	var outline_mm := MultiMesh.new()
	outline_mm.transform_format = MultiMesh.TRANSFORM_3D
	outline_mm.mesh = mesh
	outline_mm.instance_count = transforms.size()
	var scale_factor: float = 1.0 + thickness
	for i in transforms.size():
		var t: Transform3D = transforms[i]
		t = t.scaled_local(Vector3(scale_factor, scale_factor, scale_factor))
		outline_mm.set_instance_transform(i, t)
	var outline_mmi := MultiMeshInstance3D.new()
	outline_mmi.multimesh = outline_mm
	outline_mmi.name = "OutlineMMI"
	var omat := StandardMaterial3D.new()
	omat.albedo_color = color
	omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	omat.cull_mode = BaseMaterial3D.CULL_FRONT
	omat.no_depth_test = false
	omat.render_priority = -1
	outline_mmi.material_override = omat

	return {"main": main_mmi, "outline": outline_mmi}


## Attach a sibling outline MultiMeshInstance3D to an existing main MMI.
static func attach_outline(main_mmi: MultiMeshInstance3D, opts: Dictionary = {}) -> MultiMeshInstance3D:
	if main_mmi == null or main_mmi.multimesh == null:
		return null
	var src: MultiMesh = main_mmi.multimesh
	var thickness: float = float(opts.get("outline_thickness", DEFAULT_OUTLINE_THICKNESS))
	var color: Color = opts.get("outline_color", BiomePalettes.OUTLINE_BLACK)
	var scale_factor: float = 1.0 + thickness

	var outline_mm := MultiMesh.new()
	outline_mm.transform_format = src.transform_format
	outline_mm.mesh = src.mesh
	outline_mm.instance_count = src.instance_count
	for i in src.instance_count:
		var t: Transform3D = src.get_instance_transform(i)
		t = t.scaled_local(Vector3(scale_factor, scale_factor, scale_factor))
		outline_mm.set_instance_transform(i, t)
	var outline_mmi := MultiMeshInstance3D.new()
	outline_mmi.multimesh = outline_mm
	outline_mmi.name = "OutlineMMI"
	var omat := StandardMaterial3D.new()
	omat.albedo_color = color
	omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	omat.cull_mode = BaseMaterial3D.CULL_FRONT
	omat.no_depth_test = false
	omat.render_priority = -1
	outline_mmi.material_override = omat
	return outline_mmi
