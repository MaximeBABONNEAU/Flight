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

	var title := Label3D.new()
	title.name = "Title"
	title.text = "M.E.R.L.I.N."
	title.font_size = 96
	title.outline_size = 10
	title.modulate = Color(0.96, 0.85, 0.45)
	title.outline_modulate = Color(0.08, 0.04, 0.02, 1.0)
	title.pixel_size = 0.0042
	title.no_depth_test = true
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector3(0, 0.55, 0)
	add_child(title)

	var sub := Label3D.new()
	sub.name = "Subtitle"
	sub.text = "— Le Jeu des Oghams —"
	sub.font_size = 36
	sub.outline_size = 4
	sub.modulate = Color(0.72, 0.62, 0.40, 0.92)
	sub.outline_modulate = Color(0.05, 0.03, 0.01, 1.0)
	sub.pixel_size = 0.0035
	sub.no_depth_test = true
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector3(0, 0.10, 0)
	add_child(sub)


# ─── 2D UI overlay (single TESTER button) ────────────────────────────────────

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "UI"
	_ui.layer = 10
	add_child(_ui)

	# v7.7.2.2 — Primary visible title via 2D Label in CanvasLayer (guaranteed
	# render even if global overlays misbehave or 3D camera culls the Label3D).
	# The 3D Label3D in _build_3d_scene now plays a decorative role only.
	var title2d := Label.new()
	title2d.name = "Title2D"
	title2d.text = "M.E.R.L.I.N."
	title2d.anchor_left = 0.0
	title2d.anchor_right = 1.0
	title2d.anchor_top = 0.18
	title2d.anchor_bottom = 0.32
	title2d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title2d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title2d.add_theme_font_size_override("font_size", 96)
	title2d.add_theme_color_override("font_color", Color(0.96, 0.85, 0.45))
	title2d.add_theme_color_override("font_outline_color", Color(0.10, 0.06, 0.02))
	title2d.add_theme_constant_override("outline_size", 8)
	_ui.add_child(title2d)

	var sub2d := Label.new()
	sub2d.name = "Subtitle2D"
	sub2d.text = "— Le Jeu des Oghams —"
	sub2d.anchor_left = 0.0
	sub2d.anchor_right = 1.0
	sub2d.anchor_top = 0.34
	sub2d.anchor_bottom = 0.40
	sub2d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub2d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub2d.add_theme_font_size_override("font_size", 28)
	sub2d.add_theme_color_override("font_color", Color(0.72, 0.62, 0.40))
	sub2d.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.01))
	sub2d.add_theme_constant_override("outline_size", 4)
	_ui.add_child(sub2d)

	var btn := Button.new()
	btn.name = "BtnTester"
	btn.text = "TESTER UN RUN"
	btn.anchor_left = 0.5
	btn.anchor_right = 0.5
	btn.anchor_top = 0.7
	btn.anchor_bottom = 0.7
	btn.offset_left = -180
	btn.offset_right = 180
	btn.offset_top = -36
	btn.offset_bottom = 36
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color(0.96, 0.85, 0.45))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.55))
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.70, 0.30))
	# v7.7.2.1 — no borders per user feedback ("bordures à enlever"). Use only
	# a subtle bg color shift on hover for affordance. Border width = 0 across states.
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.06, 0.04, 0.40)
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(14)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.18, 0.12, 0.06, 0.70)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.04, 0.03, 0.02, 0.85)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.pressed.connect(_on_tester_pressed)
	_ui.add_child(btn)

	var hint := Label.new()
	hint.text = "Le sage Merlin t'attend dans la pièce sombre…"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 0.92
	hint.anchor_bottom = 0.97
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.55, 0.45, 0.32, 0.7))
	_ui.add_child(hint)


func _on_tester_pressed() -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file(RUN_SCENE)
