## ═══════════════════════════════════════════════════════════════════════════════
## NarrativePion3D — Card-typed physics pion for BoardNarration v5.5 (Round B)
## ═══════════════════════════════════════════════════════════════════════════════
## Replaces the faction-mapped SigleToken with a card-content-driven pion.
## Pion type derived from the resolved card (creature / event / blessing / mort).
## Each pion is a RigidBody3D with type-specific mesh + accent light + idle anim.
## Per user feedback (2026-05-14 part 12) : pions doivent avoir physique et type.
## ═══════════════════════════════════════════════════════════════════════════════

class_name NarrativePion3D
extends Node3D

enum PionType { CREATURE, EVENT, BLESSING, MORT }

const PION_COLORS := {
	PionType.CREATURE: Color(0.65, 0.85, 0.45),
	PionType.EVENT:    Color(0.85, 0.75, 0.30),
	PionType.BLESSING: Color(0.45, 0.78, 0.95),
	PionType.MORT:     Color(0.55, 0.20, 0.22),
}

var _body: RigidBody3D = null
var _mesh: MeshInstance3D = null
var _light: OmniLight3D = null
var _type: int = PionType.CREATURE
var _idle_tween: Tween = null


func setup(pion_type: int, _hint: String = "") -> void:
	_type = pion_type
	_build_body()
	_build_mesh_for_type()
	_build_accent_light()
	_start_idle_animation()


func _build_body() -> void:
	_body = RigidBody3D.new()
	_body.name = "Body"
	_body.mass = 0.20
	_body.gravity_scale = 1.0
	_body.linear_damp = 0.6
	_body.angular_damp = 0.8
	_body.can_sleep = true
	var coll := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.14
	coll.shape = shape
	_body.add_child(coll)
	add_child(_body)


func _build_mesh_for_type() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "Mesh"
	var col: Color = PION_COLORS.get(_type, Color.WHITE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.30
	mat.roughness = 0.6
	mat.metallic = 0.05
	match _type:
		PionType.CREATURE:
			var caps := CapsuleMesh.new()
			caps.radius = 0.10
			caps.height = 0.28
			_mesh.mesh = caps
			mat.roughness = 0.85
			mat.emission_energy_multiplier = 0.10
		PionType.EVENT:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.12
			cone.height = 0.26
			_mesh.mesh = cone
			mat.emission_energy_multiplier = 0.55
		PionType.BLESSING:
			var sphere := SphereMesh.new()
			sphere.radius = 0.10
			sphere.height = 0.20
			_mesh.mesh = sphere
			mat.emission_energy_multiplier = 0.70
		PionType.MORT:
			var box := BoxMesh.new()
			box.size = Vector3(0.16, 0.22, 0.10)
			_mesh.mesh = box
			mat.emission = Color(0.65, 0.20, 0.20)
			mat.emission_energy_multiplier = 0.45
	_mesh.material_override = mat
	_body.add_child(_mesh)
	# v7.1 — Cel-shading + outline noir per bible §20 (marque de fabrique).
	CelShadingManager.apply(_mesh, {"outline_thickness": 0.035})


func _build_accent_light() -> void:
	_light = OmniLight3D.new()
	_light.name = "AccentLight"
	_light.light_color = PION_COLORS.get(_type, Color.WHITE)
	_light.light_energy = 0.55
	_light.omni_range = 0.9
	_light.omni_attenuation = 1.6
	_light.position = Vector3(0, 0.30, 0)
	_body.add_child(_light)


func _start_idle_animation() -> void:
	match _type:
		PionType.BLESSING:
			_idle_tween = create_tween().set_loops()
			_idle_tween.tween_property(_body, "position:y", 0.06, 1.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_idle_tween.tween_property(_body, "position:y", 0.0, 1.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		PionType.EVENT:
			_idle_tween = create_tween().set_loops()
			_idle_tween.tween_method(_set_emission_energy, 0.30, 0.85, 1.5) \
				.set_trans(Tween.TRANS_SINE)
			_idle_tween.tween_method(_set_emission_energy, 0.85, 0.30, 1.5) \
				.set_trans(Tween.TRANS_SINE)
		PionType.CREATURE:
			_idle_tween = create_tween().set_loops()
			_idle_tween.tween_property(_body, "rotation:z", deg_to_rad(2.0), 1.4) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_idle_tween.tween_property(_body, "rotation:z", deg_to_rad(-2.0), 1.4) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		PionType.MORT:
			_idle_tween = create_tween().set_loops()
			_idle_tween.tween_property(_light, "light_energy", 0.20, 2.0) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_idle_tween.tween_property(_light, "light_energy", 0.65, 2.0) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_emission_energy(v: float) -> void:
	if _mesh and _mesh.material_override is StandardMaterial3D:
		(_mesh.material_override as StandardMaterial3D).emission_energy_multiplier = v


## Drop the pion from above onto its target marker position.
func drop_in_from_above(target_world_pos: Vector3, delay: float = 0.0) -> void:
	if _body == null:
		return
	_body.sleeping = false
	_body.position = Vector3(target_world_pos.x, target_world_pos.y + 2.5, target_world_pos.z) - global_position
	_body.rotation_degrees = Vector3(
		randf_range(-30, 30),
		randf_range(-180, 180),
		randf_range(-30, 30)
	)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	_body.apply_central_impulse(Vector3(
		randf_range(-0.1, 0.1),
		-0.4,
		randf_range(-0.1, 0.1)
	))
	_body.apply_torque_impulse(Vector3(
		randf_range(-0.2, 0.2),
		randf_range(-0.4, 0.4),
		randf_range(-0.2, 0.2)
	))


## Brief highlight pulse — call attention to the most recently spawned pion.
func highlight() -> void:
	if _mesh == null:
		return
	var t := create_tween()
	t.tween_property(_mesh, "scale", Vector3.ONE * 1.25, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_mesh, "scale", Vector3.ONE * 1.0, 0.20) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Derive pion type from a card dict's act_type + tags.
## Priority : tag-based override (ankou/niamh) > act_type heuristic.
static func derive_type_from_card(card: Dictionary) -> int:
	var act_type: String = str(card.get("act_type", "standard"))
	var tags: Array = card.get("tags", [])
	for t in tags:
		var ts: String = str(t).to_lower()
		if ts == "ankou" or ts == "mort" or ts == "death":
			return PionType.MORT
		if ts == "niamh" or ts == "blessing" or ts == "water":
			return PionType.BLESSING
	match act_type:
		"boss":
			return PionType.MORT
		"shop":
			return PionType.BLESSING
		"event":
			return PionType.EVENT
		_:
			return PionType.CREATURE
