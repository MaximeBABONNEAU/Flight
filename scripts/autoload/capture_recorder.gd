extends Node
## CaptureRecorder — Periodic viewport screenshots (autoload, env-gated).
##
## Activation:
##   MERLIN_CAPTURE_DIR=/abs/path/  godot --path . scene.tscn --quit-after 30
##
## Optional env vars:
##   MERLIN_CAPTURE_INTERVAL_MS  (default 200)
##   MERLIN_CAPTURE_MAX_FRAMES   (default 200)
##
## Saves frame_0000.png, frame_0001.png, … to MERLIN_CAPTURE_DIR.
## When the env var is empty, this autoload disables itself and does nothing.

var _enabled: bool = false
var _out_dir: String = ""
var _interval_ms: int = 200
var _max_frames: int = 200
var _frame_count: int = 0
var _accum_ms: int = 0
var _last_tick_ms: int = 0
# v7.4 — Skip first N _process frames so the viewport renders at least once
# before we try to read it (otherwise all captures are pure-black startup frames).
var _bootstrap_frames: int = 0
const BOOTSTRAP_SKIP := 3


func _ready() -> void:
	_out_dir = OS.get_environment("MERLIN_CAPTURE_DIR")
	if _out_dir.is_empty():
		set_process(false)
		return
	# Read optional knobs
	var interval_env: String = OS.get_environment("MERLIN_CAPTURE_INTERVAL_MS")
	if not interval_env.is_empty() and interval_env.is_valid_int():
		_interval_ms = max(50, int(interval_env))
	var max_env: String = OS.get_environment("MERLIN_CAPTURE_MAX_FRAMES")
	if not max_env.is_empty() and max_env.is_valid_int():
		_max_frames = max(1, int(max_env))
	# Ensure output dir exists
	if not DirAccess.dir_exists_absolute(_out_dir):
		var err := DirAccess.make_dir_recursive_absolute(_out_dir)
		if err != OK:
			push_warning("[CaptureRecorder] Cannot create dir '%s' err=%d — disabled" % [_out_dir, err])
			set_process(false)
			return
	_enabled = true
	# v7.4 — Subtract _interval_ms so the FIRST _process call fires immediately
	# (capture occurs at frame 1 instead of waiting a full interval — important
	# when smoke scenes pause early in cinematic mode).
	_last_tick_ms = Time.get_ticks_msec() - _interval_ms
	# v7.4 — _process-driven (was Timer-driven, but autostart Timer didn't tick
	# reliably in headless smoke runs even with TIMER_PROCESS_IDLE).
	# PROCESS_MODE_ALWAYS bypasses scene-tree pause states (cinematic mode etc.)
	# that would otherwise suppress _process on this autoload.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	print("[CaptureRecorder] active dir=%s interval=%dms max=%d (process-driven, ALWAYS)" % [_out_dir, _interval_ms, _max_frames])


func _process(_delta: float) -> void:
	if not _enabled:
		return
	# v7.4 — Skip first N _process frames so the viewport has rendered at least
	# once before we try to read its texture (otherwise we capture pure black).
	if _bootstrap_frames < BOOTSTRAP_SKIP:
		_bootstrap_frames += 1
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_tick_ms < _interval_ms:
		return
	_last_tick_ms = now_ms
	if _frame_count >= _max_frames:
		_enabled = false
		print("[CaptureRecorder] max frames reached (%d) — stopped at %dms" % [_max_frames, now_ms])
		return
	_capture_frame()


func _capture_frame() -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var tex: ViewportTexture = vp.get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	# Downscale aggressively to keep disk + token cost manageable for visual review.
	if img.get_width() > 480:
		var ratio: float = 480.0 / float(img.get_width())
		img.resize(480, int(float(img.get_height()) * ratio), Image.INTERPOLATE_BILINEAR)
	var fname: String = "%s/frame_%04d.png" % [_out_dir, _frame_count]
	var save_err: Error = img.save_png(fname)
	if save_err != OK:
		push_warning("[CaptureRecorder] save_png failed err=%d at %s" % [save_err, fname])
	_frame_count += 1
