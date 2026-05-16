## ═══════════════════════════════════════════════════════════════════════════════
## LiveCard3D — Hand of Fate-style 3D card for BoardNarration v6
## ═══════════════════════════════════════════════════════════════════════════════
## Replaces the parchemin overlay 2D (CanvasLayer) with a fully 3D card
## displayed in front of the camera. Title + body + 3 options are rendered
## directly on the card face via Label3D nodes with sépia ink styling.
##
## 3 floating Button2D anchored via _camera.unproject_position on each option's
## Label3D world position (handled by the host scene, not this class).
##
## API:
##   setup(card: Dictionary)            — populate badge, body, 3 options
##   await_choice() -> int              — async, returns option_index 0..2
##   fly_to_marker(target_pos: Vector3) — async, moves card to marker + scale-down
##   get_option_world_positions() -> Array — Vec3 anchors for 2D buttons
##
## Per user feedback (2026-05-14 part 14) : "façon Hands of Fate, tout dans la carte".
## ═══════════════════════════════════════════════════════════════════════════════

class_name LiveCard3D
extends Node3D

signal option_selected(index: int)

const CARD_W := 1.20
const CARD_H := 1.70
const CARD_D := 0.012
const PARCHMENT_COLOR := Color("#f0e2c4")
const INK_COLOR := Color("#1c1208")
const INK_OUTLINE := Color("#3a2410")
const BRONZE := Color("#8a6a3a")

## v7.7.2.1 — body text hard-truncated to MAX_BODY_CHARS per user feedback :
## « limiter le nombre de charactères » + « texte n'est pas strictement contenu dedans »
const MAX_BODY_CHARS: int = 140

var _mesh: MeshInstance3D = null
var _badge_label: Label3D = null
var _body_label: Label3D = null
var _option_labels: Array = []
var _option_texts: Array = []  ## v7.7.2.1 — exposed via get_option_texts() for Button2D
var _idle_tween: Tween = null
var _pending_choice: int = -1


func setup(card: Dictionary) -> void:
	_build_card_mesh()
	_build_badge(card)
	_build_body(card)
	_build_options(card)
	_start_idle_float()


func _build_card_mesh() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "CardFace"
	var box := BoxMesh.new()
	box.size = Vector3(CARD_W, CARD_H, CARD_D)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PARCHMENT_COLOR
	# v6.4 — procedural parchemin texture via FastNoiseLite (cellulose veining)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.width = 256
	noise_tex.height = 384
	noise_tex.color_ramp = _build_parchment_gradient()
	mat.albedo_texture = noise_tex
	# Roughness variation from a second noise layer (gives subtle highlights)
	var rough_noise := FastNoiseLite.new()
	rough_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	rough_noise.frequency = 0.04
	var rough_tex := NoiseTexture2D.new()
	rough_tex.noise = rough_noise
	rough_tex.width = 256
	rough_tex.height = 384
	mat.roughness_texture = rough_tex
	mat.roughness = 0.90
	mat.metallic = 0.02
	mat.emission_enabled = true
	mat.emission = PARCHMENT_COLOR
	mat.emission_energy_multiplier = 0.30
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = mat
	add_child(_mesh)
	# v7.1 — Cel-shading + outline noir (marque de fabrique, bible §20).
	CelShadingManager.apply(_mesh, {"outline_thickness": 0.012})
	# v6.4 — drop shadow via a darkened plane positioned slightly behind card.
	_build_drop_shadow()


## v6.4 — Build a parchment-color gradient for the noise texture so it samples
## between cream (low values) and tan (high values) for aged-parchment look.
static func _build_parchment_gradient() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(0.95, 0.88, 0.72))   # lightest cream
	g.set_color(1, Color(0.78, 0.66, 0.45))   # tan/aged
	return g


## v6.4 — Drop shadow : a slightly larger dark plane behind the card.
func _build_drop_shadow() -> void:
	var shadow := MeshInstance3D.new()
	shadow.name = "DropShadow"
	var box := BoxMesh.new()
	box.size = Vector3(CARD_W * 1.06, CARD_H * 1.04, CARD_D * 0.4)
	shadow.mesh = box
	shadow.position = Vector3(0.04, -0.03, -CARD_D * 0.8)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.0, 0.0, 0.0, 0.55)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.cull_mode = BaseMaterial3D.CULL_BACK
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = smat
	add_child(shadow)


func _build_badge(card: Dictionary) -> void:
	var card_id: String = str(card.get("id", ""))
	var header := card_id.to_upper()
	if header.begins_with("FR_"):
		header = header.substr(3)
	var title: String = str(card.get("title", header))
	var ogham_id: String = str(card.get("ogham_used", card.get("ogham", "")))
	var glyph := ""
	if not ogham_id.is_empty():
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})
		glyph = str(spec.get("unicode", ""))
	var badge_text := title + ("  " + glyph if not glyph.is_empty() else "")
	_badge_label = _make_label3d(
		badge_text,
		Vector3(0, CARD_H * 0.40, CARD_D * 0.6),
		0.06, INK_OUTLINE
	)
	_badge_label.name = "Badge"
	# Badge pixel_size = 0.06 * 0.055 = 0.0033 → width 290 ≈ 0.96m. Title + glyph fit.
	_badge_label.width = 290
	add_child(_badge_label)


func _build_body(card: Dictionary) -> void:
	# v7.7.2.1 — body text hard-truncated to MAX_BODY_CHARS to stop the autowrap
	# from pushing lines DOWN past the card height and overlapping with options.
	# Truncation happens at word boundary when possible + "…" ellipsis.
	var prompt: String = str(card.get("text", card.get("prompt", "Une rune se pose.")))
	if prompt.length() > MAX_BODY_CHARS:
		prompt = _truncate_at_word(prompt, MAX_BODY_CHARS) + "…"
	_body_label = _make_label3d(
		prompt,
		Vector3(0, CARD_H * 0.10, CARD_D * 0.6),
		0.045, INK_COLOR
	)
	_body_label.name = "Body"
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.width = 380  # ~0.94m world width — fits inside CARD_W
	add_child(_body_label)


## v7.7.2.1 — Truncate at the last word boundary within max_chars budget.
static func _truncate_at_word(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	var slice := text.substr(0, max_chars - 1)
	var last_space := slice.rfind(" ")
	# If we found a space in the last quarter, cut there. Otherwise hard cut.
	if last_space > int(max_chars * 0.75):
		return slice.substr(0, last_space).strip_edges()
	return slice.strip_edges()


func _build_options(card: Dictionary) -> void:
	# v7.7.2.1 — options no longer rendered on the card face (Label3D options were
	# overlapping the truncated body when text wrapped 4+ lines, per user feedback
	# « les choix sont sur le côté et illisible et sur la carte elle même aussi »).
	# Instead, we expose the option texts via get_option_texts() and the host
	# (board_narration.gd) renders them as TEXT inside the floating Button2D at
	# fixed screen positions BELOW the card. This guarantees readability + no
	# overlap with body text.
	_option_labels.clear()
	_option_texts.clear()
	var options: Array = card.get("options", [])
	for i in range(3):
		if i >= options.size():
			break
		var opt: Dictionary = options[i] if options[i] is Dictionary else {}
		var raw: String = str(opt.get("text", opt.get("label", "Option %d" % (i + 1))))
		_option_texts.append(raw)
		# Discrete ▸ marker at the bottom-edge of card (no full text — preserves
		# the "card has choices" affordance without overlap).
		var marker: Label3D = _make_label3d(
			"▸",
			Vector3(-CARD_W * 0.30 + float(i) * 0.30, CARD_H * -0.36, CARD_D * 0.6),
			0.05, INK_COLOR
		)
		marker.name = "OptionMarker_%d" % i
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.width = 60
		add_child(marker)
		_option_labels.append(marker)


## v7.7.2.1 — Expose raw option texts so board_narration can put readable text
## inside the floating Button2D (instead of empty buttons on the card side).
func get_option_texts() -> Array:
	return _option_texts.duplicate()


static func _make_label3d(text: String, local_pos: Vector3, size: float,
		color: Color) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.position = local_pos
	# v6.2 — Calibrated for 1.2m-wide card + 32-char body wrap.
	# Body : size=0.045 → pixel_size 0.0025 → glyph ~0.04m, 32 chars = ~1.15m (fits)
	# Badge : size=0.07 → pixel_size 0.004 → glyph ~0.06m, short title fits
	# Options : size=0.045 → pixel_size 0.0025 → fits on left half
	lbl.pixel_size = size * 0.055
	lbl.font_size = 48
	lbl.outline_size = 10
	# v6.3 — outline must CONTRAST with card face (was Color("#f0e2c4") same as
	# parchment cream → invisible). Use VERY DARK outline so sépia ink text pops.
	lbl.modulate = color
	lbl.outline_modulate = Color("#0a0500")
	lbl.no_depth_test = true
	lbl.render_priority = 5
	lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	# v7.1 — Strict containment : default width matches CARD_W 1.20m minus 0.12m
	# margin each side → 0.96m. With pixel_size ≈ 0.0028 (size 0.05 * 0.055),
	# width 340 = 0.95m. Builders override per-label (body 380, options 400, badge 240).
	# Per user feedback : "le texte n'est pas strictement contenu dedans".
	lbl.width = 340
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


static func _wrap_text(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	var words := text.split(" ", false)
	var lines: Array[String] = []
	var current_line := ""
	for w in words:
		if (current_line.length() + str(w).length() + 1) > max_chars:
			lines.append(current_line)
			current_line = str(w)
		else:
			if current_line.is_empty():
				current_line = str(w)
			else:
				current_line += " " + str(w)
	if not current_line.is_empty():
		lines.append(current_line)
	return "\n".join(lines)


func _start_idle_float() -> void:
	var origin_y: float = position.y
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(self, "position:y", origin_y + 0.03, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(self, "position:y", origin_y, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func await_choice() -> int:
	_pending_choice = -1
	while _pending_choice < 0:
		await get_tree().create_timer(0.1).timeout
	return _pending_choice


func resolve_choice(index: int) -> void:
	if _pending_choice >= 0:
		return
	_pending_choice = clampi(index, 0, _option_labels.size() - 1)
	option_selected.emit(_pending_choice)


## v7.7.10 — Parabolic fly-to-marker (was straight-line lerp).
## Card arcs up then dives down to the marker. Feels more tactile + "tossed
## into the world" than a glide. Total duration 0.85s :
## - 0.34s rising arc (origin → apex above midpoint)
## - 0.51s diving arc (apex → marker) with scale-down + Y-rotation spin
const FLY_TOTAL_DURATION: float = 0.85
const FLY_APEX_HEIGHT_BOOST: float = 1.2   # peak Y above midpoint (world units)
const FLY_RISE_RATIO: float = 0.40         # 40% rising, 60% diving (faster descent)

func fly_to_marker(target_world_pos: Vector3) -> void:
	if _idle_tween and is_instance_valid(_idle_tween):
		_idle_tween.kill()
	var start_pos: Vector3 = global_position
	var midpoint: Vector3 = (start_pos + target_world_pos) * 0.5
	# Apex sits above midpoint — the higher above start/end, the more arched.
	var apex: Vector3 = midpoint + Vector3(0.0, FLY_APEX_HEIGHT_BOOST, 0.0)
	var rise_duration: float = FLY_TOTAL_DURATION * FLY_RISE_RATIO
	var dive_duration: float = FLY_TOTAL_DURATION * (1.0 - FLY_RISE_RATIO)
	# Rising arc — origin → apex. Scale stays at 1, slight tilt for tactile feel.
	var t := create_tween().bind_node(self).set_parallel(true)
	t.tween_property(self, "global_position", apex, rise_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "rotation:y", PI * 0.6, rise_duration) \
		.set_trans(Tween.TRANS_SINE)
	await t.finished
	# Diving arc — apex → target marker. Shrink + spin during descent.
	var t2 := create_tween().bind_node(self).set_parallel(true)
	t2.tween_property(self, "global_position", target_world_pos, dive_duration) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	t2.tween_property(self, "scale", Vector3.ONE * 0.1, dive_duration) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	t2.tween_property(self, "rotation:y", PI * 1.4, dive_duration)
	await t2.finished
	queue_free()


func get_option_world_positions() -> Array:
	var positions: Array = []
	for lbl in _option_labels:
		if is_instance_valid(lbl):
			positions.append((lbl as Node3D).global_position)
	return positions
