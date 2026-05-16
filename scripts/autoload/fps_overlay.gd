## ═══════════════════════════════════════════════════════════════════════════════
## FPSOverlay — Tiny debug FPS counter (top-right corner)
## ═══════════════════════════════════════════════════════════════════════════════
## v7.7.16 — User request : « le jeu doit etre en 60 fps constants ».
## Diagnostic overlay to verify framerate stability + detect dips.
##
## Activation : `--debug-fps` cmdline arg OR `MERLIN_DEBUG_FPS=1` env var.
## Hidden by default in production builds.
## Reports current FPS + min FPS over last 5 seconds (sliding window).
## ═══════════════════════════════════════════════════════════════════════════════

extends CanvasLayer

const HISTORY_DURATION: float = 5.0   # seconds of sliding window for min FPS

var _label: Label = null
var _history: Array[float] = []
var _history_timestamps: Array[float] = []
var _min_fps: float = 60.0


func _ready() -> void:
	layer = 200   # above everything (above SceneSelector layer=101, ScreenEffects=100)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var enabled := args.has("--debug-fps") or OS.has_environment("MERLIN_DEBUG_FPS")
	if not enabled:
		visible = false
		set_process(false)
		return
	_label = Label.new()
	_label.name = "FPSLabel"
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.anchor_top = 0.0
	_label.anchor_bottom = 0.0
	_label.offset_left = -160.0
	_label.offset_right = -10.0
	_label.offset_top = 10.0
	_label.offset_bottom = 50.0
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.5))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_label.add_theme_constant_override("outline_size", 3)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_label)


func _process(_delta: float) -> void:
	if _label == null:
		return
	var fps: float = Engine.get_frames_per_second()
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	_history.append(fps)
	_history_timestamps.append(now)
	while not _history_timestamps.is_empty() and now - _history_timestamps[0] > HISTORY_DURATION:
		_history.pop_front()
		_history_timestamps.pop_front()
	_min_fps = 999.0
	for v in _history:
		if v < _min_fps:
			_min_fps = v
	if _min_fps > 998.0:
		_min_fps = fps
	var color: Color
	if fps >= 58.0 and _min_fps >= 58.0:
		color = Color(0.0, 1.0, 0.5)
	elif fps >= 50.0 and _min_fps >= 50.0:
		color = Color(1.0, 0.85, 0.20)
	else:
		color = Color(1.0, 0.30, 0.20)
	_label.add_theme_color_override("font_color", color)
	_label.text = "%d FPS\nmin %d (5s)" % [int(fps), int(_min_fps)]
