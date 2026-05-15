## ═══════════════════════════════════════════════════════════════════════════════
## CardDeck3D — Visible 3D card deck for BoardNarration v5.2
## ═══════════════════════════════════════════════════════════════════════════════
## Stack of thin box meshes on the plateau (right side by default).
## Each call to `draw_top_card()` :
##   1. lifts the top card (Y += 0.6) over 0.25s
##   2. rotates it 90° on X to face the camera
##   3. slides toward the parchment anchor (center-screen-3D) over 0.55s
##   4. fades out + queue_free
##   5. decrements the visible stack
## The card content itself is NOT carried — this is purely a VISUAL transition
## that runs in parallel with the LLM/fallback fetch + parchemin reveal.
## ═══════════════════════════════════════════════════════════════════════════════

class_name CardDeck3D
extends Node3D

signal card_drawn

# v5.4 — Sizes doubled (was 0.20×0.30×0.005) per user feedback "deck plus visible".
# Stack now sits on a carved wooden socle to mirror the dice tray on the right.
# v5.7 — held position moved CLOSER TO CAMERA + slower flight + hover beat
# so the card is actually visible "devant les yeux" before parchemin appears.
# Per user feedback (2026-05-14 part 13).
const CARD_W := 0.40
const CARD_H := 0.60
const CARD_D := 0.008
const STACK_SPACING := 0.012
# Local-space target : push card up + forward toward camera (camera at (0, 2.6, 4.6)).
# Local origin is at world (-2.0, 0.4, 0.4), so to reach world (0, 1.8, 2.5) we
# need local offset (+2.0, 1.4, 2.1).
const HELD_POSITION_LOCAL := Vector3(2.0, 1.4, 2.1)
const LIFT_TIME := 0.35
const FLIGHT_TIME := 0.90
const HOVER_TIME := 0.6
const FADE_TIME := 0.30

var _stack_visuals: Array = []  # Array of MeshInstance3D
var _remaining: int = 0


func setup(count: int = 12) -> void:
	_clear()
	_remaining = count
	# Socle (carved wood plinth) under the stack — built once on setup.
	_build_socle()
	var visible: int = min(count, 12)
	for i in range(visible):
		var vis := _build_one_card_visual(i)
		_stack_visuals.append(vis)


## Build a small wooden plinth under the stack — mirrors the dice tray on the right.
func _build_socle() -> void:
	var socle := MeshInstance3D.new()
	socle.name = "DeckSocle"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CARD_W + 0.10, 0.06, CARD_H + 0.10)
	socle.mesh = mesh
	socle.position = Vector3(0, -0.04, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.22, 0.12)
	mat.roughness = 0.92
	mat.metallic = 0.03
	socle.material_override = mat
	add_child(socle)
	# v7.1 — Cel-shading + outline noir (marque de fabrique, bible §20).
	CelShadingManager.apply(socle)


func _build_one_card_visual(stack_index: int) -> MeshInstance3D:
	var vis := MeshInstance3D.new()
	vis.name = "Card_%d" % stack_index
	var box := BoxMesh.new()
	box.size = Vector3(CARD_W, CARD_D, CARD_H)
	vis.mesh = box
	vis.position = Vector3(0.0, stack_index * STACK_SPACING, 0.0)
	vis.rotation_degrees = Vector3(0.0, randf_range(-2.5, 2.5), 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.90, 0.82, 0.62)
	mat.roughness = 0.92
	mat.metallic = 0.02
	vis.material_override = mat
	add_child(vis)
	# v7.1 — Cel-shading + outline noir per bible §20. Thinner outline on stacked
	# cards (0.008) to avoid silhouette merging in the pile.
	CelShadingManager.apply(vis, {"outline_thickness": 0.008})
	return vis


func _clear() -> void:
	for v in _stack_visuals:
		if is_instance_valid(v):
			(v as Node).queue_free()
	_stack_visuals.clear()
	_remaining = 0


## Draw the top card : lift, rotate, fly to camera-center anchor, fade out.
## Returns when the animation completes. Caller can then show the parchemin overlay.
## If stack is empty, just emits the signal and returns immediately.
func draw_top_card() -> void:
	if _stack_visuals.is_empty():
		card_drawn.emit()
		return
	var top_vis: MeshInstance3D = _stack_visuals.pop_back() as MeshInstance3D
	if top_vis == null or not is_instance_valid(top_vis):
		card_drawn.emit()
		return
	_remaining -= 1
	# Phase 1 : lift
	var lift := create_tween().set_parallel(true)
	var lifted_pos: Vector3 = top_vis.position + Vector3(0, 0.6, 0)
	lift.tween_property(top_vis, "position", lifted_pos, LIFT_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lift.tween_property(top_vis, "rotation:x", -PI / 2.0, LIFT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await lift.finished
	# Phase 2 : fly to held position (toward camera, larger scale)
	var fly := create_tween().set_parallel(true)
	fly.tween_property(top_vis, "position", HELD_POSITION_LOCAL, FLIGHT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fly.tween_property(top_vis, "scale", Vector3.ONE * 1.8, FLIGHT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Gentle spin during flight for visual interest
	fly.tween_property(top_vis, "rotation:y", PI * 0.5, FLIGHT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fly.finished
	# v5.7 — Phase 2.5 : HOVER beat (0.6s) — card stays in front of camera
	# so the player ACTUALLY SEES IT. Subtle Y bobbing for life.
	var hover := create_tween()
	hover.tween_property(top_vis, "position:y", HELD_POSITION_LOCAL.y + 0.08, HOVER_TIME * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hover.tween_property(top_vis, "position:y", HELD_POSITION_LOCAL.y, HOVER_TIME * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await hover.finished
	# Phase 3 : fade out via material albedo alpha (MeshInstance3D doesn't
	# support `modulate:a` — that's a CanvasItem 2D property).
	# v6.6 — Fix : was silently failing → top_vis stayed at HELD_POSITION and
	# occluded the new LiveCard3D spawning at nearby world position.
	var mat: StandardMaterial3D = top_vis.material_override as StandardMaterial3D
	if mat == null:
		top_vis.queue_free()
		card_drawn.emit()
		return
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var fade := create_tween()
	fade.tween_property(mat, "albedo_color:a", 0.0, FADE_TIME)
	fade.tween_callback(top_vis.queue_free)
	await fade.finished
	card_drawn.emit()


func get_remaining() -> int:
	return _remaining


## v7.0 — Append a visual card to the top of the stack (used by discard pile :
## stack grows by 1 each time a card is played). Hauteur du stack ∝ N cartes.
## Per GAME_DESIGN_BIBLE §19.1+§19.3 (stack heights proportional).
func add_card() -> void:
	var stack_index: int = _stack_visuals.size()
	if stack_index >= 24:  # safety cap
		return
	var vis := _build_one_card_visual(stack_index)
	_stack_visuals.append(vis)
	_remaining += 1
	# Subtle scale-in tween so the card "lands" on the pile.
	vis.scale = Vector3(0.0, 1.0, 1.0)
	var t := create_tween()
	t.tween_property(vis, "scale", Vector3.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
