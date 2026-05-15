## ═══════════════════════════════════════════════════════════════════════════════
## SigleToken — Procedural 3D figurine displayed on the BoardNarration plateau.
## ═══════════════════════════════════════════════════════════════════════════════
## REFONTE v2 (2026-05-13): no more abstract Label3D glyph floating in space.
## Each token is now a small statuette built from primitives:
##   - disc base (CylinderMesh)
##   - robed body (CylinderMesh tapered)
##   - head (SphereMesh)
##   - faction accessory (staff / sword / stone / chalice / scythe)
##   - Ogham glyph billboard ABOVE the head (small, sharp)
##
## States:
##   - hidden    (initial, scale 0, no light)
##   - revealed  (animate_in: scale up, dim spotlight)
##   - highlight (centre of attention: scale + glow + slight float)
##   - dimmed    (already-narrated: ambient only)
##
## Material per faction: solid color + emission accent (Inscryption-like contrast).
## ═══════════════════════════════════════════════════════════════════════════════

extends Node3D
class_name SigleToken

signal token_clicked(token: SigleToken)

# Faction signature: body color, emission accent, accessory mesh key.
const FACTION_SPECS := {
	"druides":   {"body": Color(0.30, 0.62, 0.32), "accent": Color(0.55, 0.95, 0.50), "accessory": "staff"},
	"anciens":   {"body": Color(0.78, 0.62, 0.28), "accent": Color(1.00, 0.85, 0.45), "accessory": "sword"},
	"korrigans": {"body": Color(0.70, 0.42, 0.18), "accent": Color(0.98, 0.66, 0.30), "accessory": "stone"},
	"niamh":     {"body": Color(0.32, 0.58, 0.85), "accent": Color(0.65, 0.85, 1.00), "accessory": "chalice"},
	"ankou":     {"body": Color(0.36, 0.28, 0.42), "accent": Color(0.72, 0.55, 0.85), "accessory": "scythe"},
	"":          {"body": Color(0.55, 0.60, 0.52), "accent": Color(0.80, 0.92, 0.72), "accessory": "staff"},
}

const DEFAULT_GLYPH := "ᚁ"          # Beith fallback
const GLYPH_PIXEL_SIZE := 64
const BODY_HEIGHT := 0.42
const BODY_TOP_RADIUS := 0.05
const BODY_BOTTOM_RADIUS := 0.16
const HEAD_RADIUS := 0.085
const BASE_RADIUS := 0.20
const BASE_HEIGHT := 0.04

const SCALE_HIDDEN := Vector3.ZERO
const SCALE_REVEALED := Vector3.ONE * 1.0
const SCALE_HIGHLIGHT := Vector3.ONE * 1.18
const FLOAT_OFFSET := 0.08            # how high the figurine rises when highlighted
const ANIM_IN_TIME := 0.7
const ANIM_HIGHLIGHT_TIME := 0.5
const ANIM_DIM_TIME := 0.6

var ogham_id: String = ""
var card_id: String = ""
var faction: String = ""
var base_y: float = 0.0               # remembered Y for float animation

var _base_mesh: MeshInstance3D = null
var _body_mesh: MeshInstance3D = null
var _head_mesh: MeshInstance3D = null
var _accessory: MeshInstance3D = null
var _glyph_label: Label3D = null
var _accent_light: OmniLight3D = null
var _current_tween: Tween = null
var _rotation_tween: Tween = null


## Map faction → GLB filename slug. Order matches MerlinConstants.FACTIONS.
const FACTION_GLB_TEMPLATE := "res://assets/blender/figurine_%s.glb"
const PNJ_GLB_TEMPLATE := "res://assets/blender/%s.glb"
const GLB_FACTION_KEYS := {
	"druides":   "druide",
	"anciens":   "anciens",
	"korrigans": "korrigans",
	"niamh":     "niamh",
	"ankou":     "ankou",
}

var biome_id: String = ""


## Setup with optional biome_id. When biome_id is provided and the card's
## faction matches the biome's dominant_faction, the biome's PNJ figurine
## takes precedence over the generic faction figurine (e.g. Gwenn replaces
## the generic Druide in foret_broceliande on druides-aligned cards).
func setup(p_ogham_id: String, p_card_id: String, p_faction: String = "", p_biome_id: String = "") -> void:
	ogham_id = p_ogham_id
	card_id = p_card_id
	faction = p_faction
	biome_id = p_biome_id
	# Try PNJ-by-biome first, then faction GLB, then procedural fallback.
	if not _try_build_pnj_from_biome():
		if not _try_build_from_glb():
			_build_figurine()
	scale = SCALE_HIDDEN


## If the current biome's dominant_faction matches this token's faction, load
## the biome PNJ GLB instead of the generic faction figurine.
func _try_build_pnj_from_biome() -> bool:
	if biome_id.is_empty():
		return false
	var biome_spec: Dictionary = MerlinConstants.BIOMES.get(biome_id, {})
	if biome_spec.is_empty():
		return false
	var dominant: String = str(biome_spec.get("dominant_faction", ""))
	# Only swap to PNJ when this card aligns with the biome (keeps variety).
	if dominant.is_empty() or dominant != faction:
		return false
	var pnj_name: String = str(biome_spec.get("pnj", ""))
	if pnj_name.is_empty():
		return false
	var pnj_path := PNJ_GLB_TEMPLATE % pnj_name.to_lower()
	if not ResourceLoader.exists(pnj_path):
		return false
	return _instantiate_glb_with_glyph_and_light(pnj_path, "PNJ_" + pnj_name)


## Try to load the faction's generic figurine GLB.
func _try_build_from_glb() -> bool:
	var faction_slug: String = str(GLB_FACTION_KEYS.get(faction, ""))
	if faction_slug.is_empty():
		return false
	var path := FACTION_GLB_TEMPLATE % faction_slug
	if not ResourceLoader.exists(path):
		return false
	return _instantiate_glb_with_glyph_and_light(path, "GLB_" + faction_slug)


## Shared GLB instantiation + Ogham glyph billboard + accent light helper.
## Used by both PNJ-by-biome path and faction-fallback path.
func _instantiate_glb_with_glyph_and_light(path: String, instance_name: String) -> bool:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return false
	var instance: Node = packed.instantiate()
	if instance == null:
		return false
	instance.name = instance_name
	add_child(instance)

	# Glyph billboard above head — same pattern as procedural path
	var spec: Dictionary = FACTION_SPECS.get(faction, FACTION_SPECS[""])
	var tint: Color = spec["accent"]
	_glyph_label = Label3D.new()
	_glyph_label.name = "Glyph"
	_glyph_label.text = _resolve_glyph()
	_glyph_label.font_size = GLYPH_PIXEL_SIZE
	_glyph_label.pixel_size = 0.0028
	_glyph_label.outline_size = 6
	_glyph_label.outline_modulate = Color(0.02, 0.03, 0.02, 1.0)
	_glyph_label.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	_glyph_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_glyph_label.shaded = false
	_glyph_label.no_depth_test = false
	_glyph_label.fixed_size = false
	_glyph_label.position = Vector3(0, 0.78, 0)
	_glyph_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_glyph_label)

	# Accent light for highlight effect
	_accent_light = OmniLight3D.new()
	_accent_light.name = "AccentLight"
	_accent_light.light_color = tint
	_accent_light.light_energy = 0.0
	_accent_light.omni_range = 1.4
	_accent_light.omni_attenuation = 1.8
	_accent_light.position = Vector3(0, 0.35, 0)
	add_child(_accent_light)
	return true


func _build_figurine() -> void:
	var spec: Dictionary = FACTION_SPECS.get(faction, FACTION_SPECS[""])
	var body_color: Color = spec["body"]
	var accent_color: Color = spec["accent"]

	# Base disc (pedestal)
	_base_mesh = MeshInstance3D.new()
	_base_mesh.name = "Base"
	var base_cyl := CylinderMesh.new()
	base_cyl.top_radius = BASE_RADIUS
	base_cyl.bottom_radius = BASE_RADIUS
	base_cyl.height = BASE_HEIGHT
	base_cyl.radial_segments = 24
	_base_mesh.mesh = base_cyl
	_base_mesh.position = Vector3(0, BASE_HEIGHT * 0.5, 0)
	_base_mesh.material_override = _make_stone_material(body_color * 0.4)
	add_child(_base_mesh)

	# Body (robed cone)
	_body_mesh = MeshInstance3D.new()
	_body_mesh.name = "Body"
	var body_cyl := CylinderMesh.new()
	body_cyl.top_radius = BODY_TOP_RADIUS
	body_cyl.bottom_radius = BODY_BOTTOM_RADIUS
	body_cyl.height = BODY_HEIGHT
	body_cyl.radial_segments = 12
	_body_mesh.mesh = body_cyl
	_body_mesh.position = Vector3(0, BASE_HEIGHT + BODY_HEIGHT * 0.5, 0)
	_body_mesh.material_override = _make_solid_material(body_color, accent_color, 0.10)
	add_child(_body_mesh)

	# Head
	_head_mesh = MeshInstance3D.new()
	_head_mesh.name = "Head"
	var head := SphereMesh.new()
	head.radius = HEAD_RADIUS
	head.height = HEAD_RADIUS * 2.0
	head.radial_segments = 16
	head.rings = 10
	_head_mesh.mesh = head
	_head_mesh.position = Vector3(0, BASE_HEIGHT + BODY_HEIGHT + HEAD_RADIUS * 0.85, 0)
	_head_mesh.material_override = _make_solid_material(body_color.lerp(Color.WHITE, 0.15), accent_color, 0.05)
	add_child(_head_mesh)

	# Accessory
	_accessory = _build_accessory(str(spec.get("accessory", "staff")), body_color, accent_color)
	if _accessory:
		add_child(_accessory)

	# Ogham glyph above head — small, sharp
	_glyph_label = Label3D.new()
	_glyph_label.name = "Glyph"
	_glyph_label.text = _resolve_glyph()
	_glyph_label.font_size = GLYPH_PIXEL_SIZE
	_glyph_label.pixel_size = 0.0028
	_glyph_label.outline_size = 6
	_glyph_label.outline_modulate = Color(0.02, 0.03, 0.02, 1.0)
	_glyph_label.modulate = Color(accent_color.r, accent_color.g, accent_color.b, 0.0)
	_glyph_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_glyph_label.shaded = false
	_glyph_label.no_depth_test = false
	_glyph_label.position = Vector3(0, BASE_HEIGHT + BODY_HEIGHT + HEAD_RADIUS * 2.5, 0)
	_glyph_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_glyph_label)

	# Accent light (under-glow on the figurine when highlighted)
	_accent_light = OmniLight3D.new()
	_accent_light.name = "AccentLight"
	_accent_light.light_color = accent_color
	_accent_light.light_energy = 0.0
	_accent_light.omni_range = 1.4
	_accent_light.omni_attenuation = 1.8
	_accent_light.position = Vector3(0, BASE_HEIGHT + BODY_HEIGHT * 0.6, 0)
	add_child(_accent_light)


func _resolve_glyph() -> String:
	var spec_dict: Dictionary = MerlinConstants.OGHAM_FULL_SPECS
	if spec_dict.has(ogham_id):
		return str(spec_dict[ogham_id].get("unicode", DEFAULT_GLYPH))
	return DEFAULT_GLYPH


func _build_accessory(kind: String, body_color: Color, accent_color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Accessory_" + kind
	match kind:
		"staff":
			var staff := CylinderMesh.new()
			staff.top_radius = 0.012
			staff.bottom_radius = 0.012
			staff.height = 0.50
			staff.radial_segments = 6
			mi.mesh = staff
			mi.position = Vector3(0.16, BASE_HEIGHT + 0.22, 0)
			mi.material_override = _make_solid_material(Color(0.35, 0.25, 0.15), accent_color, 0.0)
		"sword":
			var blade := BoxMesh.new()
			blade.size = Vector3(0.04, 0.42, 0.012)
			mi.mesh = blade
			mi.position = Vector3(0.18, BASE_HEIGHT + 0.20, 0.04)
			mi.material_override = _make_solid_material(Color(0.78, 0.78, 0.85), accent_color, 0.20)
		"stone":
			var stone := SphereMesh.new()
			stone.radius = 0.08
			stone.height = 0.13
			stone.radial_segments = 8
			stone.rings = 5
			mi.mesh = stone
			mi.position = Vector3(0.16, BASE_HEIGHT + 0.18, 0)
			mi.material_override = _make_stone_material(body_color * 0.6)
		"chalice":
			var cup := SphereMesh.new()
			cup.radius = 0.05
			cup.height = 0.10
			cup.radial_segments = 10
			cup.rings = 6
			mi.mesh = cup
			mi.position = Vector3(0.13, BASE_HEIGHT + 0.32, 0)
			mi.material_override = _make_solid_material(Color(0.90, 0.85, 0.55), accent_color, 0.25)
		"scythe":
			var handle := CylinderMesh.new()
			handle.top_radius = 0.012
			handle.bottom_radius = 0.012
			handle.height = 0.55
			handle.radial_segments = 6
			mi.mesh = handle
			mi.position = Vector3(0.17, BASE_HEIGHT + 0.24, 0)
			mi.rotation = Vector3(0, 0, deg_to_rad(-12.0))
			mi.material_override = _make_solid_material(Color(0.22, 0.18, 0.20), accent_color, 0.10)
		_:
			return null
	return mi


func _make_solid_material(albedo: Color, emission: Color, emission_strength: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.55
	mat.metallic = 0.05
	if emission_strength > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_strength
	return mat


func _make_stone_material(albedo: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.92
	mat.metallic = 0.0
	return mat


func remember_base_y() -> void:
	base_y = position.y


func animate_in(delay: float = 0.0) -> void:
	_kill_tween()
	_current_tween = create_tween()
	if delay > 0.0:
		_current_tween.tween_interval(delay)
	_current_tween.set_parallel(true)
	_current_tween.tween_property(self, "scale", SCALE_REVEALED, ANIM_IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _glyph_label:
		_current_tween.tween_property(_glyph_label, "modulate:a", 0.55, ANIM_IN_TIME * 0.8)
	if _accent_light:
		_current_tween.tween_property(_accent_light, "light_energy", 0.35, ANIM_IN_TIME)


func highlight() -> void:
	_kill_tween()
	_current_tween = create_tween().set_parallel(true)
	_current_tween.tween_property(self, "scale", SCALE_HIGHLIGHT, ANIM_HIGHLIGHT_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(self, "position:y", base_y + FLOAT_OFFSET, ANIM_HIGHLIGHT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _accent_light:
		_current_tween.tween_property(_accent_light, "light_energy", 2.4, ANIM_HIGHLIGHT_TIME)
	if _glyph_label:
		_current_tween.tween_property(_glyph_label, "modulate:a", 1.0, ANIM_HIGHLIGHT_TIME)
	# Slow rotation drift (idle)
	if _rotation_tween and _rotation_tween.is_valid():
		_rotation_tween.kill()
	_rotation_tween = create_tween().set_loops()
	_rotation_tween.tween_property(self, "rotation:y", PI * 2.0, 18.0)


func dim_to_idle() -> void:
	_kill_tween()
	if _rotation_tween and _rotation_tween.is_valid():
		_rotation_tween.kill()
	_current_tween = create_tween().set_parallel(true)
	_current_tween.tween_property(self, "scale", SCALE_REVEALED * 0.92, ANIM_DIM_TIME)
	_current_tween.tween_property(self, "position:y", base_y, ANIM_DIM_TIME)
	if _accent_light:
		_current_tween.tween_property(_accent_light, "light_energy", 0.18, ANIM_DIM_TIME)
	if _glyph_label:
		_current_tween.tween_property(_glyph_label, "modulate:a", 0.45, ANIM_DIM_TIME)


func get_glyph() -> String:
	if _glyph_label == null:
		return DEFAULT_GLYPH
	return _glyph_label.text


func _kill_tween() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	_current_tween = null
