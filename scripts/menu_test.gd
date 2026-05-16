## ═══════════════════════════════════════════════════════════════════════════════
## MenuTest — Minimal 3D menu for the v7.7.2 plateau test flow
## ═══════════════════════════════════════════════════════════════════════════════
## Single-button gateway between IntroCeltOS and BoardNarration. Dark warm scene
## with the M.E.R.L.I.N. wordmark floating + a single "TESTER UN RUN" button.
##
## Built programmatically — the .tscn is intentionally bare (Node3D + script).
## Same construction pattern as BoardNarration.tscn.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node3D

const RUN_SCENE := "res://scenes/BoardNarration.tscn"

var _ui: CanvasLayer = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# v7.7.2.2 — hide global overlays (ScreenFrame CRT, MerlinBackdrop, ScreenDither)
	# that were obscuring the 3D title rendering per user feedback "menu n'est
	# toujours pas net". Same pattern as BoardNarration._disable_global_overlays.
	_disable_global_overlays()
	# Force PixelTransition to complete state — otherwise a pending fade-in keeps
	# the screen mostly black covering the 3D scene.
	var pt: Node = get_node_or_null("/root/PixelTransition")
	if pt and pt.has_method("_force_complete"):
		pt._force_complete()
	_build_3d_scene()
	_build_ui()


## v7.7.2.2 — Hide CanvasLayer autoloads that would otherwise sit on top of the
## 3D scene and either blank out portions of it (CRT frame mask) or wash it out
## (dither / scanline overlays). Re-shown in _exit_tree.
var _overlay_prev_visible: Dictionary = {}

func _disable_global_overlays() -> void:
	# v7.7.2.2 fix — CanvasLayer does NOT inherit from CanvasItem (only Control
	# and Node2D do). The `as CanvasItem` cast returned null for ScreenFrame
	# (a CanvasLayer autoload) → SCRIPT ERROR at first smoke. CanvasLayer has
	# its OWN `visible` property in Godot 4, so direct property access works.
	for autoload_name in ["ScreenFrame", "MerlinBackdrop", "ScreenDither"]:
		var node: Node = get_node_or_null("/root/" + autoload_name)
		if node == null:
			continue
		if node is CanvasLayer or node is Control:
			_overlay_prev_visible[autoload_name] = node.visible
			node.visible = false


func _exit_tree() -> void:
	# Restore overlay visibility on scene change so they reappear in BoardNarration etc.
	for autoload_name in _overlay_prev_visible.keys():
		var node: Node = get_node_or_null("/root/" + autoload_name)
		if node and (node is CanvasLayer or node is Control):
			node.visible = bool(_overlay_prev_visible[autoload_name])


# ─── 3D scene (dark warm ambiance) ──────────────────────────────────────────

func _build_3d_scene() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnv"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_color = Color(0.18, 0.14, 0.10)  # raised so title isn't washed
	env.ambient_light_energy = 0.55
	# v7.7.2.1 — fog disabled per user feedback ("menu flou"). Fog was bleaching
	# the title outline + giving the whole scene a hazy look. Pure black bg + warm
	# ambient lights the title cleanly.
	env.fog_enabled = false
	world_env.environment = env
	add_child(world_env)

	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.current = true
	cam.fov = 45.0
	cam.position = Vector3(0, 0.2, 3.5)
	add_child(cam)
	cam.look_at(Vector3.ZERO, Vector3.UP)

	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color(0.96, 0.78, 0.42)
	key.light_energy = 0.85
	add_child(key)
	key.look_at_from_position(Vector3(-2.0, 3.5, 2.0), Vector3.ZERO, Vector3.UP)

	# v7.7.2.3 — 3D title + subtitle Label3D REMOVED per user feedback "le titre
	# est doublé". The 2D Label in CanvasLayer (built in _build_ui) is now the
	# sole visible title. The 3D scene keeps only the warm ambient lighting +
	# directional key light as the background mood — no in-scene text nodes.


# ─── 2D UI overlay (single TESTER button) ────────────────────────────────────

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "UI"
	_ui.layer = 10
	add_child(_ui)

	# v7.7.11 — Persona-style menu : digital interface très prononcé, simple, pas surchargé.
	# Subtitle retiré définitivement per user instruction (« on en parle pas »).
	# Palette adaptée : noir profond + or chaud + sang celtique (variante celtique du P5 red/black/gold).
	# Layout :
	#   - Diagonal gold slash derrière le titre (-8°, P5 dynamism)
	#   - Diagonal crimson slash plus mince (-8° offset, visual tension)
	#   - Titre M.E.R.L.I.N. bold uppercase 130px, encre noire sur slash or
	#   - Bouton ENTRER avec stripe crimson à gauche + hover border top/bottom
	#   - Footer hint minimal
	var p_gold := Color(0.92, 0.72, 0.20)
	var p_crimson := Color(0.78, 0.16, 0.18)
	var p_ink := Color(0.04, 0.03, 0.03)
	var p_cream := Color(0.98, 0.94, 0.82)

	# Accent slash 1 — bande or longue derrière le titre.
	var accent_gold := ColorRect.new()
	accent_gold.name = "AccentGold"
	accent_gold.color = p_gold
	accent_gold.anchor_left = 0.0
	accent_gold.anchor_right = 1.0
	accent_gold.anchor_top = 0.22
	accent_gold.anchor_bottom = 0.34
	accent_gold.rotation = deg_to_rad(-8.0)
	accent_gold.modulate = Color(1, 1, 1, 0.92)
	accent_gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(accent_gold)

	# Accent slash 2 — bande crimson plus mince, offset.
	var accent_crimson := ColorRect.new()
	accent_crimson.name = "AccentCrimson"
	accent_crimson.color = p_crimson
	accent_crimson.anchor_left = 0.0
	accent_crimson.anchor_right = 1.0
	accent_crimson.anchor_top = 0.34
	accent_crimson.anchor_bottom = 0.365
	accent_crimson.rotation = deg_to_rad(-8.0)
	accent_crimson.modulate = Color(1, 1, 1, 0.88)
	accent_crimson.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(accent_crimson)

	# Titre M.E.R.L.I.N. — bold uppercase 130px, encre noire sur l'or (lisibilité max).
	var title2d := Label.new()
	title2d.name = "Title2D"
	title2d.text = "M.E.R.L.I.N."
	title2d.anchor_left = 0.0
	title2d.anchor_right = 1.0
	title2d.anchor_top = 0.21
	title2d.anchor_bottom = 0.35
	title2d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title2d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title2d.add_theme_font_size_override("font_size", 130)
	title2d.add_theme_color_override("font_color", p_ink)
	title2d.add_theme_color_override("font_outline_color", p_cream)
	title2d.add_theme_constant_override("outline_size", 6)
	_ui.add_child(title2d)

	# Bouton ENTRER — Persona-style : stripe crimson à gauche + panel noir net.
	var btn_box := Control.new()
	btn_box.name = "BtnContainer"
	btn_box.anchor_left = 0.5
	btn_box.anchor_right = 0.5
	btn_box.anchor_top = 0.68
	btn_box.anchor_bottom = 0.68
	btn_box.offset_left = -200
	btn_box.offset_right = 200
	btn_box.offset_top = -42
	btn_box.offset_bottom = 42
	btn_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(btn_box)

	var stripe := ColorRect.new()
	stripe.name = "BtnStripe"
	stripe.color = p_crimson
	stripe.anchor_top = 0.0
	stripe.anchor_bottom = 1.0
	stripe.offset_left = 0
	stripe.offset_right = 6
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_box.add_child(stripe)

	var btn := Button.new()
	btn.name = "BtnTester"
	btn.text = "ENTRER"
	btn.anchor_left = 0.0
	btn.anchor_right = 1.0
	btn.anchor_top = 0.0
	btn.anchor_bottom = 1.0
	btn.offset_left = 6
	btn.add_theme_font_size_override("font_size", 36)
	btn.add_theme_color_override("font_color", p_cream)
	btn.add_theme_color_override("font_hover_color", p_gold)
	btn.add_theme_color_override("font_pressed_color", p_cream)
	var normal := StyleBoxFlat.new()
	normal.bg_color = p_ink
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(0)   # Persona : bords nets, pas de radius
	normal.set_content_margin_all(14)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.10, 0.08, 0.08, 1.0)
	hover.border_color = p_crimson
	hover.border_width_top = 2
	hover.border_width_bottom = 2
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = p_crimson
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.pressed.connect(_on_tester_pressed)
	btn_box.add_child(btn)

	# Footer minimal — pas de subtitle.
	var hint := Label.new()
	hint.text = "Le sage t'attend"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 0.92
	hint.anchor_bottom = 0.97
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.45, 0.38, 0.30, 0.55))
	_ui.add_child(hint)


func _on_tester_pressed() -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file(RUN_SCENE)
