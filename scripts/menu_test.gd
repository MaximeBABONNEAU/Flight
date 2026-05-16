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

	# v7.7.17 — DA strict terminal/cyberpunk per user request « digitaliser ».
	# Persona-magazine rotated slashes DROPPED. Replaced by digital data-readout
	# elements : flat horizontal bands (no rotation), monospace data labels,
	# hex code drift. AI-terminal aesthetic, zero editorial geometry.
	# AccentGold + AccentCrimson nodes KEPT (named the same) so the existing
	# intro reveal / idle loops still find them — they're now thin horizontal
	# bands instead of rotated slashes, evoking signal-bars not magazine cuts.

	# Top data band — thin horizontal gold strip (was rotated -8°, now flat).
	var accent_gold := ColorRect.new()
	accent_gold.name = "AccentGold"
	accent_gold.color = p_gold
	accent_gold.anchor_left = 0.0
	accent_gold.anchor_right = 1.0
	accent_gold.anchor_top = 0.22
	accent_gold.anchor_bottom = 0.225   # 0.5% of viewport height — thin bar
	accent_gold.modulate = Color(1, 1, 1, 0.85)
	accent_gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(accent_gold)

	# Bottom data band — thin horizontal crimson strip below title.
	var accent_crimson := ColorRect.new()
	accent_crimson.name = "AccentCrimson"
	accent_crimson.color = p_crimson
	accent_crimson.anchor_left = 0.0
	accent_crimson.anchor_right = 1.0
	accent_crimson.anchor_top = 0.355
	accent_crimson.anchor_bottom = 0.358
	accent_crimson.modulate = Color(1, 1, 1, 0.80)
	accent_crimson.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(accent_crimson)

	# v7.7.17 — Data readout panel : 3 monospace rows in top-right corner.
	# Shows fake "system status" lines that cycle subtly (digital terminal feel).
	_build_data_readout_panel(p_gold, p_ink)

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
	title2d.add_theme_constant_override("outline_size", 4)   # v7.7.18 charter : was 6, max 4
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
	# v7.7.19 — Charter v7.7.18 mandates border_width >= 4 on primary CTAs.
	# Was 0 (violates charter). Bumped to 4 + amber color for visibility.
	normal.set_border_width_all(4)
	normal.border_color = p_gold
	normal.set_corner_radius_all(0)
	normal.set_content_margin_all(14)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.10, 0.08, 0.08, 1.0)
	hover.border_color = p_crimson
	hover.set_border_width_all(6)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = p_crimson
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.pressed.connect(_on_tester_pressed)
	btn_box.add_child(btn)

	# Footer minimal — pas de subtitle.
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "Le sage t'attend"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 0.92
	hint.anchor_bottom = 0.97
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.45, 0.38, 0.30, 0.55))
	_ui.add_child(hint)

	# v7.7.12 — Ambient dust particles (8 floating gold motes drift upward).
	_build_dust_particles(p_gold)

	# v7.7.12 — Hover/leave FX on button (scale + stripe expansion).
	btn.mouse_entered.connect(_on_btn_hover.bind(btn_box, stripe))
	btn.mouse_exited.connect(_on_btn_leave.bind(btn_box, stripe))

	# v7.7.15 — Boot construction prelude (~0.85s, PC-power-on feel) + intro reveal.
	# User feedback : « pas de transition mais des popups d'elements successifs qui
	# produisent le menu, comme si un PC s'allumait ». Prelude pops BIOS-style
	# system messages, then schedules _animate_intro_reveal at t=0.85s.
	# Hide all menu elements FIRST so prelude is the only thing visible at boot.
	_set_menu_elements_hidden_for_prelude()
	_play_boot_prelude()
	# Idle loops start IMMEDIATELY (dust + scanline) — they're ambient and don't
	# overlap the prelude visually since dust is faint and scanline is overlay.
	_start_idle_loops()


## v7.7.17 — Data readout panel : 3 monospace rows top-right showing fake
## system status. Cycles values every 1.5s for "live system" feel.
const DATA_READOUT_TEMPLATES := [
	"SYS  : %s",
	"RUNE : %d/9",
	"FATE : 0x%s",
]
const DATA_READOUT_SYS_STATES := ["ONLINE", "BIND", "WEAVE", "TRACE"]
const DATA_READOUT_FATE_TOKENS := ["BEITH", "LUIS", "FEARN", "SAIL", "NION", "HUATH", "DUIR", "TINNE", "QUERT", "COLL"]

func _build_data_readout_panel(gold: Color, ink: Color) -> void:
	var panel := VBoxContainer.new()
	panel.name = "DataReadoutPanel"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.04
	panel.offset_left = -260.0
	panel.offset_right = -16.0
	panel.add_theme_constant_override("separation", 2)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(panel)
	var labels: Array[Label] = []
	# Each template has exactly 1 placeholder — initial values vary per row.
	var initial_values: Array = [DATA_READOUT_SYS_STATES[0], 9, "DEADBEEF"]
	for i in range(3):
		var lbl := Label.new()
		lbl.text = DATA_READOUT_TEMPLATES[i] % initial_values[i]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", gold)
		lbl.add_theme_color_override("font_outline_color", ink)
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		panel.add_child(lbl)
		labels.append(lbl)
	# Live cycle : update values every 1.5s.
	var tw := create_tween().bind_node(panel).set_loops()
	tw.tween_callback(_cycle_data_readout.bind(labels))
	tw.tween_interval(1.5)


func _cycle_data_readout(labels: Array) -> void:
	if labels.is_empty():
		return
	var sys_state: String = DATA_READOUT_SYS_STATES[randi() % DATA_READOUT_SYS_STATES.size()]
	var rune_count: int = randi_range(6, 9)
	var fate: String = DATA_READOUT_FATE_TOKENS[randi() % DATA_READOUT_FATE_TOKENS.size()]
	if is_instance_valid(labels[0]):
		(labels[0] as Label).text = DATA_READOUT_TEMPLATES[0] % sys_state
	if is_instance_valid(labels[1]):
		(labels[1] as Label).text = DATA_READOUT_TEMPLATES[1] % rune_count
	if is_instance_valid(labels[2]):
		(labels[2] as Label).text = DATA_READOUT_TEMPLATES[2] % fate


## v7.7.15 — Hide all menu elements BEFORE the prelude pops them in.
## Without this, the slashes/title/button flash for 1 frame at scene start
## before _animate_intro_reveal sets them to scale 0 / alpha 0.
func _set_menu_elements_hidden_for_prelude() -> void:
	for n in ["AccentGold", "AccentCrimson", "Title2D", "BtnContainer", "Hint"]:
		var el: CanvasItem = _ui.get_node_or_null(n) as CanvasItem
		if el != null:
			el.visible = false


## v7.7.15 — Boot construction prelude (~0.85s).
## Sequence per kind-humming-peach.md Phase A :
##   0.0s : black screen (handled by _disable_global_overlays + hidden elements)
##   0.1s : horizontal scanline appears mid-screen (white, 2px tall)
##   0.2s : scanline expands vertically to fill viewport (0.18s ease-out)
##   0.3s : 5 boot system Labels pop in top-left, hard-cut, 100ms apart
##          ["BOOT v7", "KERNEL OK", "LOADING DRUID_CORE", "INIT 5/5", "READY"]
##   0.80s : glitch flash + boot lines fade out
##   0.85s : unhide menu elements + call _animate_intro_reveal()
const BOOT_PRELUDE_LINES := [
	"> BOOT v7              [OK]",
	"> KERNEL DRUID         [OK]",
	"> LOAD MERLIN_CORE     [OK]",
	"> INIT FACTIONS  5/5   [OK]",
	"> READY                [GO]",
]
const BOOT_PRELUDE_LINE_INTERVAL := 0.10
const BOOT_PRELUDE_TOTAL_DURATION := 0.85

func _play_boot_prelude() -> void:
	# v7.7.15 prelude — PC power-on feel. Hard cuts only, no fades.
	var p_gold := Color(0.92, 0.72, 0.20)
	var p_cream := Color(0.98, 0.94, 0.82)
	var p_ink := Color(0.04, 0.03, 0.03)
	# 1. Scanline that appears mid-screen then expands to fill viewport
	var scanline := ColorRect.new()
	scanline.name = "BootScanline"
	scanline.color = p_cream
	scanline.anchor_left = 0.0
	scanline.anchor_right = 1.0
	scanline.anchor_top = 0.5
	scanline.anchor_bottom = 0.5
	scanline.offset_top = -1.0
	scanline.offset_bottom = 1.0
	scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scanline.modulate.a = 0.0
	_ui.add_child(scanline)
	# Delay appearance to t=0.10
	get_tree().create_timer(0.10).timeout.connect(func() -> void:
		if not is_instance_valid(scanline):
			return
		scanline.modulate.a = 1.0
		# Expand to fill viewport over 0.18s
		var tw := create_tween().bind_node(scanline).set_parallel(true)
		tw.tween_property(scanline, "offset_top", -540.0, 0.18) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(scanline, "offset_bottom", 540.0, 0.18) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		# Then fade the white wash to expose the boot lines bg
		tw.chain().tween_property(scanline, "color", p_ink, 0.10).set_trans(Tween.TRANS_LINEAR)
		tw.tween_property(scanline, "modulate:a", 0.0, 0.40).set_trans(Tween.TRANS_LINEAR).set_delay(0.40)
		tw.tween_callback(func() -> void:
			if is_instance_valid(scanline):
				scanline.queue_free()
		)
	)
	# 2. Boot system lines pop in top-left at 0.30s + 0.10s per line
	var boot_box := VBoxContainer.new()
	boot_box.name = "BootLines"
	boot_box.anchor_left = 0.0
	boot_box.anchor_right = 0.0
	boot_box.anchor_top = 0.0
	boot_box.anchor_bottom = 0.0
	boot_box.offset_left = 36.0
	boot_box.offset_top = 36.0
	boot_box.add_theme_constant_override("separation", 4)
	boot_box.modulate.a = 0.0
	boot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(boot_box)
	# Pre-create 5 hidden labels, reveal one per timer tick
	var line_labels: Array[Label] = []
	for line_text in BOOT_PRELUDE_LINES:
		var lbl := Label.new()
		lbl.text = line_text
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", p_gold)
		lbl.add_theme_color_override("font_outline_color", p_ink)
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.visible = false
		boot_box.add_child(lbl)
		line_labels.append(lbl)
	# Reveal each line at 0.30, 0.40, 0.50, 0.60, 0.70
	get_tree().create_timer(0.30).timeout.connect(func() -> void:
		if is_instance_valid(boot_box):
			boot_box.modulate.a = 1.0
	)
	for i in range(line_labels.size()):
		var delay: float = 0.30 + float(i) * BOOT_PRELUDE_LINE_INTERVAL
		var lbl_ref: Label = line_labels[i]
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(lbl_ref):
				lbl_ref.visible = true
			_play_boot_prelude_glitch_blip()
		)
	# 3. At t=0.80s, glitch flash + start fading the boot box
	get_tree().create_timer(0.80).timeout.connect(func() -> void:
		_play_boot_prelude_glitch_flash()
		if is_instance_valid(boot_box):
			var fadebt := create_tween().bind_node(boot_box)
			fadebt.tween_property(boot_box, "modulate:a", 0.0, 0.25) \
				.set_trans(Tween.TRANS_LINEAR)
			fadebt.tween_callback(func() -> void:
				if is_instance_valid(boot_box):
					boot_box.queue_free()
			)
	)
	# 4. At t=BOOT_PRELUDE_TOTAL_DURATION (0.85s), unhide menu + run reveal
	get_tree().create_timer(BOOT_PRELUDE_TOTAL_DURATION).timeout.connect(func() -> void:
		for n in ["AccentGold", "AccentCrimson", "Title2D", "BtnContainer", "Hint"]:
			var el: CanvasItem = _ui.get_node_or_null(n) as CanvasItem
			if el != null:
				el.visible = true
		_animate_intro_reveal()
	)


## Tiny 1-frame blip (white flash, alpha 0.10) per boot line pop — terminal feel.
func _play_boot_prelude_glitch_blip() -> void:
	if _ui == null:
		return
	var blip := ColorRect.new()
	blip.color = Color(1.0, 1.0, 1.0, 0.08)
	blip.anchor_left = 0.0
	blip.anchor_right = 1.0
	blip.anchor_top = 0.0
	blip.anchor_bottom = 1.0
	blip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(blip)
	var bt := create_tween().bind_node(blip)
	bt.tween_property(blip, "modulate:a", 0.0, 0.06).set_trans(Tween.TRANS_LINEAR)
	bt.tween_callback(func() -> void:
		if is_instance_valid(blip):
			blip.queue_free()
	)


## Bigger glitch flash at t=0.80s — cyan + crimson RGB-split bands like
## v7.7.13 digital animations. Marks the transition prelude → menu reveal.
func _play_boot_prelude_glitch_flash() -> void:
	if _ui == null:
		return
	for band_color in [Color(0.0, 1.0, 1.0, 0.30), Color(1.0, 0.10, 0.20, 0.30)]:
		var band := ColorRect.new()
		band.color = band_color
		band.anchor_left = 0.0
		band.anchor_right = 1.0
		band.anchor_top = 0.0
		band.anchor_bottom = 1.0
		var jitter: float = randf_range(-12.0, 12.0)
		band.offset_left = jitter
		band.offset_right = jitter
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(band)
		var bt := create_tween().bind_node(band)
		bt.tween_interval(0.06)
		bt.tween_property(band, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_LINEAR)
		bt.tween_callback(func() -> void:
			if is_instance_valid(band):
				band.queue_free()
		)


## v7.7.12 — 8 floating gold dust motes drifting upward.
## Zero asset cost. Adds ambient motion without overwhelming the layout.
var _dust_particles: Array[ColorRect] = []

func _build_dust_particles(gold: Color) -> void:
	var layer := Control.new()
	layer.name = "DustLayer"
	layer.anchor_left = 0.0
	layer.anchor_right = 1.0
	layer.anchor_top = 0.0
	layer.anchor_bottom = 1.0
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(layer)
	_ui.move_child(layer, 0)   # behind everything else
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	for i in range(8):
		var mote := ColorRect.new()
		mote.name = "Mote_%d" % i
		mote.color = gold
		mote.modulate = Color(1, 1, 1, randf_range(0.12, 0.32))
		mote.custom_minimum_size = Vector2(randf_range(2.0, 5.0), randf_range(2.0, 5.0))
		mote.size = mote.custom_minimum_size
		mote.position = Vector2(
			randf_range(40.0, vp_size.x - 40.0),
			randf_range(vp_size.y * 0.4, vp_size.y - 40.0)
		)
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(mote)
		_dust_particles.append(mote)
		_animate_dust_mote(mote, vp_size)


## Single dust mote : drift upward + horizontal sway + alpha pulse. Recursive loop.
func _animate_dust_mote(mote: ColorRect, vp_size: Vector2) -> void:
	if not is_instance_valid(mote):
		return
	var duration: float = randf_range(8.0, 14.0)
	var sway: float = randf_range(-30.0, 30.0)
	var target_y: float = -20.0
	var target_x: float = mote.position.x + sway
	var alpha_peak: float = randf_range(0.25, 0.55)
	var tw := create_tween().bind_node(mote).set_parallel(true)
	tw.tween_property(mote, "position:y", target_y, duration) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(mote, "position:x", target_x, duration) \
		.set_trans(Tween.TRANS_SINE)
	tw.chain().tween_property(mote, "modulate:a", alpha_peak, duration * 0.25)
	tw.tween_property(mote, "modulate:a", alpha_peak, duration * 0.50)
	tw.tween_property(mote, "modulate:a", 0.0, duration * 0.25)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(mote):
			return
		mote.position = Vector2(randf_range(40.0, vp_size.x - 40.0), vp_size.y + 20.0)
		mote.modulate.a = 0.0
		_animate_dust_mote(mote, vp_size)
	)


## v7.7.13 — DIGITAL intro reveal (replaces smooth cinematic version).
## User feedback : « Il faut que les animations soient digitales »
##
## Technique : motion is QUANTIZED to discrete steps (no smooth lerp), text
## appears via TYPEWRITER (char by char), glitch flash 1-frame chromatic offset,
## cursor blink after typing. Total ~1.8s. Feels like a computer redrawing
## the UI, not a Hollywood cinematic.
const TITLE_FULL := "M.E.R.L.I.N."
const TITLE_TYPEWRITER_INTERVAL := 0.075   # 75ms per char = staccato terminal feel
const SLASH_STEP_COUNT := 8                # slash draws in 8 hard jumps
const SLASH_STEP_DURATION := 0.075         # 75ms per step → 0.6s total

var _typewriter_timer: Timer = null
var _typewriter_idx: int = 0
var _cursor_blink_timer: Timer = null
var _scanline_overlay: ColorRect = null

func _animate_intro_reveal() -> void:
	var slash_gold := _ui.get_node_or_null("AccentGold") as ColorRect
	var slash_crimson := _ui.get_node_or_null("AccentCrimson") as ColorRect
	var title := _ui.get_node_or_null("Title2D") as Label
	var btn_box := _ui.get_node_or_null("BtnContainer") as Control
	var hint := _ui.get_node_or_null("Hint") as Label
	# Initial hidden state. Note : digital = instant snaps, no soft fades.
	if slash_gold != null:
		slash_gold.scale = Vector2(0.0, 1.0)
		slash_gold.pivot_offset = Vector2.ZERO
	if slash_crimson != null:
		slash_crimson.scale = Vector2(0.0, 1.0)
		slash_crimson.pivot_offset = Vector2.ZERO
	if title != null:
		title.text = ""                        # start blank for typewriter
		title.modulate.a = 1.0                  # full alpha — text reveal is per-char
		title.scale = Vector2.ONE
	if btn_box != null:
		btn_box.modulate.a = 0.0
		btn_box.offset_top = -42.0
		btn_box.offset_bottom = 42.0
	if hint != null:
		hint.modulate.a = 0.0

	# Build the always-on scanline overlay (subtle CRT feel).
	_build_scanline_overlay()

	# Phase 1 : stepped slash draws (gold @ 0.05s, crimson @ 0.20s)
	if slash_gold != null:
		_animate_stepped_slash(slash_gold, 0.05)
	if slash_crimson != null:
		_animate_stepped_slash(slash_crimson, 0.20)

	# Phase 2 : typewriter title (starts @ 0.70s, after slashes settle)
	if title != null:
		_typewriter_idx = 0
		_typewriter_timer = Timer.new()
		_typewriter_timer.wait_time = TITLE_TYPEWRITER_INTERVAL
		_typewriter_timer.one_shot = false
		add_child(_typewriter_timer)
		_typewriter_timer.timeout.connect(_on_typewriter_tick.bind(title))
		# Delay start
		get_tree().create_timer(0.70).timeout.connect(func() -> void:
			if is_instance_valid(_typewriter_timer):
				_typewriter_timer.start()
		)

	# Phase 3 : glitch flash @ 0.65s (just before title types — sets up reveal)
	get_tree().create_timer(0.65).timeout.connect(_play_glitch_flash)

	# Phase 4 : button hard-snap appear @ 1.55s with jitter
	if btn_box != null:
		get_tree().create_timer(1.55).timeout.connect(func() -> void:
			if not is_instance_valid(btn_box):
				return
			# Hard snap alpha 0→1 (no fade), then 2-frame horizontal jitter
			btn_box.modulate.a = 1.0
			var jt := create_tween().bind_node(btn_box)
			jt.tween_property(btn_box, "position:x", btn_box.position.x + 6.0, 0.05) \
				.set_trans(Tween.TRANS_LINEAR)
			jt.tween_property(btn_box, "position:x", btn_box.position.x - 4.0, 0.05) \
				.set_trans(Tween.TRANS_LINEAR)
			jt.tween_property(btn_box, "position:x", btn_box.position.x, 0.05) \
				.set_trans(Tween.TRANS_LINEAR)
		)

	# Phase 5 : hint hard-snap @ 1.75s
	if hint != null:
		get_tree().create_timer(1.75).timeout.connect(func() -> void:
			if is_instance_valid(hint):
				hint.modulate.a = 0.55
		)


## Stepped slash draw : quantize scale.x to discrete steps via Timer ticks
## (not smooth tween). Each step is a HARD jump — visibly digital.
func _animate_stepped_slash(slash: ColorRect, start_delay: float) -> void:
	for step in range(SLASH_STEP_COUNT + 1):
		var target_scale_x: float = float(step) / float(SLASH_STEP_COUNT)
		var delay: float = start_delay + float(step) * SLASH_STEP_DURATION
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(slash):
				slash.scale.x = target_scale_x
		)


## Typewriter tick : append one character to title. Append cursor "_" while typing,
## remove at end. Plays mechanical/terminal feel.
func _on_typewriter_tick(title: Label) -> void:
	if not is_instance_valid(title) or not is_instance_valid(_typewriter_timer):
		return
	if _typewriter_idx >= TITLE_FULL.length():
		# Done typing — stop timer, start cursor blink
		_typewriter_timer.stop()
		_typewriter_timer.queue_free()
		_typewriter_timer = null
		_start_cursor_blink(title)
		return
	_typewriter_idx += 1
	# Show characters typed so far + blinking cursor placeholder
	title.text = TITLE_FULL.substr(0, _typewriter_idx) + "_"


## After typewriter completes, cursor "_" blinks for ~2s then disappears.
func _start_cursor_blink(title: Label) -> void:
	if not is_instance_valid(title):
		return
	_cursor_blink_timer = Timer.new()
	_cursor_blink_timer.wait_time = 0.30
	_cursor_blink_timer.one_shot = false
	add_child(_cursor_blink_timer)
	var blink_count: int = 0
	_cursor_blink_timer.timeout.connect(func() -> void:
		if not is_instance_valid(title) or not is_instance_valid(_cursor_blink_timer):
			return
		blink_count += 1
		var show_cursor := (blink_count % 2 == 0)
		title.text = TITLE_FULL + ("_" if show_cursor else "")
		if blink_count >= 6:   # 6 ticks * 0.3s = 1.8s of blinking
			title.text = TITLE_FULL    # final clean state
			_cursor_blink_timer.stop()
			_cursor_blink_timer.queue_free()
			_cursor_blink_timer = null
	)
	_cursor_blink_timer.start()


## Glitch flash : 2 short colored rectangles offset L/R for 1-2 frames.
## Simulates RGB chromatic split. Cyan/Red bands flash briefly.
func _play_glitch_flash() -> void:
	if _ui == null:
		return
	for band_color in [Color(0.0, 1.0, 1.0, 0.25), Color(1.0, 0.1, 0.2, 0.25)]:
		var band := ColorRect.new()
		band.name = "GlitchBand"
		band.color = band_color
		band.anchor_left = 0.0; band.anchor_right = 1.0
		band.anchor_top = 0.20; band.anchor_bottom = 0.38
		band.position.x = randf_range(-8.0, 8.0)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(band)
		var bt := create_tween().bind_node(band)
		bt.tween_interval(0.05)
		bt.tween_property(band, "modulate:a", 0.0, 0.10).set_trans(Tween.TRANS_LINEAR)
		bt.tween_callback(func() -> void:
			if is_instance_valid(band):
				band.queue_free()
		)


## Always-on scanline overlay : subtle horizontal stripes via shader-less pattern.
## Built from 60 thin ColorRects spread across viewport. Total alpha ~5%.
func _build_scanline_overlay() -> void:
	if _ui == null:
		return
	_scanline_overlay = ColorRect.new()
	_scanline_overlay.name = "ScanlineOverlay"
	_scanline_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_scanline_overlay.anchor_left = 0.0
	_scanline_overlay.anchor_right = 1.0
	_scanline_overlay.anchor_top = 0.0
	_scanline_overlay.anchor_bottom = 1.0
	_scanline_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_scanline_overlay)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var line_count: int = int(vp_size.y / 3.0)   # one line every 3px
	for i in range(line_count):
		var line := ColorRect.new()
		line.color = Color(0.0, 0.0, 0.0, 0.07)
		line.size = Vector2(vp_size.x, 1.0)
		line.position = Vector2(0.0, float(i) * 3.0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scanline_overlay.add_child(line)
	# Subtle flicker on the whole overlay
	var sf := create_tween().bind_node(_scanline_overlay).set_loops()
	sf.tween_property(_scanline_overlay, "modulate:a", 0.85, 1.4).set_trans(Tween.TRANS_LINEAR)
	sf.tween_property(_scanline_overlay, "modulate:a", 1.0, 1.4).set_trans(Tween.TRANS_LINEAR)


## v7.7.13 — DIGITAL idle loops (replaces smooth sinusoidal).
## Title : random flicker (alpha 1.0 → 0.94 → 1.0) at irregular intervals.
## Slashes : STEPPED alpha changes (4 discrete levels, hard jumps).
## Hint : binary alpha toggle (on/off at 1.2s interval).
func _start_idle_loops() -> void:
	var title := _ui.get_node_or_null("Title2D") as Label
	var slash_gold := _ui.get_node_or_null("AccentGold") as ColorRect
	var slash_crimson := _ui.get_node_or_null("AccentCrimson") as ColorRect
	var hint := _ui.get_node_or_null("Hint") as Label

	# Title flicker — random brief dim every 2-4s (digital "signal interference")
	if title != null:
		_schedule_title_flicker(title)

	# Gold slash : stepped alpha 0.92 → 0.96 → 1.0 → 0.96 → 0.92 (4 levels, hard jumps)
	if slash_gold != null:
		var t_gold := create_tween().bind_node(slash_gold).set_loops()
		t_gold.tween_interval(0.8)
		# Each "tween" is instant (TRANS_LINEAR + duration 0.001 — hard jump)
		t_gold.tween_property(slash_gold, "modulate:a", 0.96, 0.001).set_trans(Tween.TRANS_LINEAR)
		t_gold.tween_interval(0.6)
		t_gold.tween_property(slash_gold, "modulate:a", 1.0, 0.001).set_trans(Tween.TRANS_LINEAR)
		t_gold.tween_interval(0.8)
		t_gold.tween_property(slash_gold, "modulate:a", 0.96, 0.001).set_trans(Tween.TRANS_LINEAR)
		t_gold.tween_interval(0.6)
		t_gold.tween_property(slash_gold, "modulate:a", 0.92, 0.001).set_trans(Tween.TRANS_LINEAR)

	# Crimson slash : hard binary toggle (on/dim) at 1.5s interval (clock pulse)
	if slash_crimson != null:
		var t_crim := create_tween().bind_node(slash_crimson).set_loops()
		t_crim.tween_interval(1.5)
		t_crim.tween_property(slash_crimson, "modulate:a", 0.65, 0.001).set_trans(Tween.TRANS_LINEAR)
		t_crim.tween_interval(0.18)   # brief dim
		t_crim.tween_property(slash_crimson, "modulate:a", 0.88, 0.001).set_trans(Tween.TRANS_LINEAR)

	# Hint : terminal cursor-style on/off blink (1.2s on, 0.4s off)
	if hint != null:
		var t_hint := create_tween().bind_node(hint).set_loops()
		t_hint.tween_interval(1.2)
		t_hint.tween_property(hint, "modulate:a", 0.0, 0.001).set_trans(Tween.TRANS_LINEAR)
		t_hint.tween_interval(0.4)
		t_hint.tween_property(hint, "modulate:a", 0.55, 0.001).set_trans(Tween.TRANS_LINEAR)


## Title flicker — random brief dim. Recursive scheduling for natural irregularity.
func _schedule_title_flicker(title: Label) -> void:
	if not is_instance_valid(title):
		return
	var wait: float = randf_range(2.5, 4.5)
	get_tree().create_timer(wait).timeout.connect(func() -> void:
		if not is_instance_valid(title):
			return
		# Single hard dim 50ms, then back to full
		title.modulate.a = 0.86
		get_tree().create_timer(0.05).timeout.connect(func() -> void:
			if is_instance_valid(title):
				title.modulate.a = 1.0
				_schedule_title_flicker(title)   # reschedule
		)
	)


## Hover : scale punch on button + stripe expansion (6 → 10 px).
func _on_btn_hover(btn_box: Control, stripe: ColorRect) -> void:
	if not is_instance_valid(btn_box) or not is_instance_valid(stripe):
		return
	var t := create_tween().bind_node(btn_box).set_parallel(true)
	t.tween_property(btn_box, "scale", Vector2(1.04, 1.04), 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(stripe, "offset_right", 10.0, 0.18) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## Hover-leave : restore scale + stripe.
func _on_btn_leave(btn_box: Control, stripe: ColorRect) -> void:
	if not is_instance_valid(btn_box) or not is_instance_valid(stripe):
		return
	var t := create_tween().bind_node(btn_box).set_parallel(true)
	t.tween_property(btn_box, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_SINE)
	t.tween_property(stripe, "offset_right", 6.0, 0.20).set_trans(Tween.TRANS_SINE)


func _on_tester_pressed() -> void:
	if not is_inside_tree():
		return
	# v7.7.19 — Use PixelTransition for the fade between menu and game.
	# User feedback : « Aucune transition, l'UI n'est pas refaite et harmonisée ».
	# Defensive : fallback to bare change if PixelTransition autoload missing.
	var pt: Node = get_node_or_null("/root/PixelTransition")
	if pt != null and pt.has_method("transition_to"):
		pt.call("transition_to", RUN_SCENE)
	else:
		get_tree().change_scene_to_file(RUN_SCENE)
