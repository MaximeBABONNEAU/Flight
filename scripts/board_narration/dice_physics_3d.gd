## ═══════════════════════════════════════════════════════════════════════════════
## DicePhysics3D — Physics-based dice tray for BoardNarration v7.7.3c
## ═══════════════════════════════════════════════════════════════════════════════
## Spawns N RigidBody3D dice next to the plateau. STATIC at rest (freeze=true).
## roll() — async — unfreezes, applies impulse + torque, waits for settle, checks
## for "cocked" landing (dice not flat on a face), re-throws up to 3 times,
## re-freezes when at rest, returns face values.
## Face detection : compare each local face-normal to Vector3.UP after sleeping=true.
## Cocked detection : best face dot < COCKED_THRESHOLD → die is on its edge/corner.
## Per docs/BOARD_NARRATION_PLATEAU_ALIVE.md §3 + user feedback v7.7.3c.
## ═══════════════════════════════════════════════════════════════════════════════

class_name DicePhysics3D
extends Node3D

signal roll_finished(values: Array)

const DICE_SIZE := 0.18
const DICE_COUNT_DEFAULT := 2
const SETTLE_TIMEOUT_S := 3.0
## v7.7.3c — die is "cocked" (not flat) if no face normal projects to UP within
## this dot threshold. 0.85 ≈ 31° tilt allowance. Below that → re-throw.
const COCKED_THRESHOLD := 0.85
const MAX_REROLL_ATTEMPTS := 3

# Local face normals for a 6-sided die (basis-relative). Index 0 = face value 1.
const FACE_NORMALS := [
	Vector3( 0,  1,  0),  # 1 — UP
	Vector3( 1,  0,  0),  # 2 — RIGHT
	Vector3( 0,  0,  1),  # 3 — FORWARD
	Vector3( 0,  0, -1),  # 4 — BACK
	Vector3(-1,  0,  0),  # 5 — LEFT
	Vector3( 0, -1,  0),  # 6 — DOWN
]

var _dice: Array = []  # Array of RigidBody3D


func setup(count: int = DICE_COUNT_DEFAULT) -> void:
	_clear()
	for i in range(count):
		var rb := _build_one_die(i)
		_dice.append(rb)
	_build_tray()
	# v7.7.3c — no idle wobble timer. Dice stay STATIC (frozen) until roll() is
	# called. Previous idle wobble made them visibly nudge every 6-14s which the
	# user described as "les dés qui bouges" — explicitly unwanted.


func _build_one_die(index: int) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.name = "Die_%d" % index
	rb.mass = 0.06
	rb.gravity_scale = 1.5
	rb.linear_damp = 0.4
	rb.angular_damp = 0.6
	rb.can_sleep = true
	# v7.7.3c — frozen by default. roll() unfreezes for the throw, then re-freezes
	# once settled. Keeps the dice perfectly STATIC at rest per user directive.
	rb.freeze = true
	rb.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	var coll := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(DICE_SIZE, DICE_SIZE, DICE_SIZE)
	coll.shape = shape
	rb.add_child(coll)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(DICE_SIZE, DICE_SIZE, DICE_SIZE)
	mesh_instance.mesh = mesh
	# v6.4 — Bois sculpté chaleureux + emission ogham glow subtil
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.42, 0.22)  # darker oak wood
	mat.roughness = 0.88
	mat.metallic = 0.02
	mat.emission_enabled = true
	mat.emission = Color(0.78, 0.45, 0.18)  # warmer amber glow
	mat.emission_energy_multiplier = 0.28
	# Wood-grain noise via NoiseTexture2D
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.4
	var wood_tex := NoiseTexture2D.new()
	wood_tex.noise = noise
	wood_tex.width = 128
	wood_tex.height = 128
	var grad := Gradient.new()
	grad.set_color(0, Color(0.50, 0.34, 0.18))
	grad.set_color(1, Color(0.72, 0.52, 0.30))
	wood_tex.color_ramp = grad
	mat.albedo_texture = wood_tex
	mesh_instance.material_override = mat
	rb.add_child(mesh_instance)
	# v7.1 — Cel-shading + outline noir per bible §20.
	CelShadingManager.apply(mesh_instance, {"outline_thickness": 0.025})
	rb.position = Vector3(index * 0.22 - 0.11, 0.20, randf_range(-0.05, 0.05))
	rb.rotation_degrees = Vector3(randf_range(-30, 30), randf_range(-180, 180), randf_range(-30, 30))
	add_child(rb)
	return rb


func _build_tray() -> void:
	var tray := StaticBody3D.new()
	tray.name = "DiceTray"
	var coll := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 0.04, 0.4)
	coll.shape = shape
	coll.position = Vector3(0, -0.02, 0)
	tray.add_child(coll)
	var rim := MeshInstance3D.new()
	var rim_mesh := BoxMesh.new()
	rim_mesh.size = Vector3(0.8, 0.04, 0.4)
	rim.mesh = rim_mesh
	rim.position = Vector3(0, -0.02, 0)
	# v6.4 — Pierre brute granite : couleur grise + noise texture stratifié
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.40, 0.38)  # granite gray
	mat.roughness = 0.98
	mat.metallic = 0.05
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.8
	var stone_tex := NoiseTexture2D.new()
	stone_tex.noise = noise
	stone_tex.width = 128
	stone_tex.height = 64
	var grad := Gradient.new()
	grad.set_color(0, Color(0.30, 0.28, 0.26))
	grad.set_color(1, Color(0.52, 0.50, 0.48))
	stone_tex.color_ramp = grad
	mat.albedo_texture = stone_tex
	rim.material_override = mat
	tray.add_child(rim)
	# v7.1 — Cel-shading + outline noir per bible §20.
	CelShadingManager.apply(rim, {"outline_thickness": 0.012})
	add_child(tray)


func _clear() -> void:
	for d in _dice:
		if is_instance_valid(d):
			(d as Node).queue_free()
	_dice.clear()


## v7.7.3c — Unfreeze all dice + apply impulse + await settle.
## Internal helper, called by roll() and re-throw retry on cocked dice.
func _throw_once(sfx: Node) -> void:
	if sfx and sfx.has_method("play"):
		sfx.play("dice_roll", 1.0)
	for d in _dice:
		var rb: RigidBody3D = d as RigidBody3D
		if rb == null or not is_instance_valid(rb):
			continue
		rb.freeze = false
		rb.sleeping = false
		rb.apply_central_impulse(Vector3(
			randf_range(-0.20, 0.20),
			randf_range(0.55, 0.80),
			randf_range(-0.20, 0.20)
		))
		rb.apply_torque_impulse(Vector3(
			randf_range(-0.30, 0.30),
			randf_range(-0.30, 0.30),
			randf_range(-0.30, 0.30)
		))
	var deadline := Time.get_ticks_msec() + int(SETTLE_TIMEOUT_S * 1000)
	while Time.get_ticks_msec() < deadline:
		var all_asleep := true
		for d in _dice:
			var rb: RigidBody3D = d as RigidBody3D
			if rb and is_instance_valid(rb) and not rb.sleeping:
				all_asleep = false
				break
		if all_asleep:
			break
		await get_tree().create_timer(0.1).timeout


## Roll all dice. Returns Array[int] of face values once all dice settle.
## v7.7.3c — auto re-throws up to MAX_REROLL_ATTEMPTS times if any die is cocked
## (landed on edge/corner with no face flat to UP within COCKED_THRESHOLD).
## After final read, dice are re-frozen so they remain visibly STATIC.
func roll() -> Array:
	if _dice.is_empty():
		return []
	var sfx: Node = get_tree().root.get_node_or_null("SFXManager")
	# Throw + retry on cocked dice.
	var attempt: int = 0
	while attempt < MAX_REROLL_ATTEMPTS:
		await _throw_once(sfx)
		var any_cocked: bool = false
		for d in _dice:
			if _is_cocked(d as RigidBody3D):
				any_cocked = true
				break
		if not any_cocked:
			break
		attempt += 1
		# Brief pause before re-throw — give the player visual cue that the die
		# was "broken" (cocked) and is being rolled again.
		await get_tree().create_timer(0.35).timeout
	if sfx and sfx.has_method("play"):
		sfx.play("dice_land", 0.9)
	# Read final face values + re-freeze so dice stay statique.
	var values: Array = []
	for d in _dice:
		var rb: RigidBody3D = d as RigidBody3D
		values.append(_read_face_up(rb))
		if rb and is_instance_valid(rb):
			# Freeze in place — dice keep their landed orientation visibly.
			rb.linear_velocity = Vector3.ZERO
			rb.angular_velocity = Vector3.ZERO
			rb.freeze = true
	roll_finished.emit(values)
	return values


## v7.7.3c — Return true if the die is "cocked" : no face normal projects close
## enough to Vector3.UP. Threshold COCKED_THRESHOLD ≈ 31° tilt allowance.
static func _is_cocked(die: RigidBody3D) -> bool:
	if die == null or not is_instance_valid(die):
		return false
	var best_dot: float = -2.0
	for i in range(FACE_NORMALS.size()):
		var local_normal: Vector3 = FACE_NORMALS[i]
		var world_normal: Vector3 = (die.global_transform.basis * local_normal).normalized()
		var dot: float = world_normal.dot(Vector3.UP)
		if dot > best_dot:
			best_dot = dot
	return best_dot < COCKED_THRESHOLD


static func _read_face_up(die: RigidBody3D) -> int:
	if die == null or not is_instance_valid(die):
		return 1
	var best_face := 1
	var best_dot := -2.0
	for i in range(FACE_NORMALS.size()):
		var local_normal: Vector3 = FACE_NORMALS[i]
		var world_normal: Vector3 = (die.global_transform.basis * local_normal).normalized()
		var dot: float = world_normal.dot(Vector3.UP)
		if dot > best_dot:
			best_dot = dot
			best_face = i + 1
	return best_face


func reset_dice() -> void:
	for d in _dice:
		var rb: RigidBody3D = d as RigidBody3D
		if rb == null or not is_instance_valid(rb):
			continue
		rb.sleeping = true
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
