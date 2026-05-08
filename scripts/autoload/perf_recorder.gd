extends Node
## PerfRecorder — Periodic FPS + memory sampling (autoload, env-gated).
##
## Activation:
##   MERLIN_PERF_OUT=/abs/path/to/scene.json  godot --path . scene.tscn --quit-after 30
##
## Optional env vars:
##   MERLIN_PERF_INTERVAL_MS  (default 250)
##
## Samples Performance.TIME_FPS and Performance.MEMORY_STATIC every interval_ms via
## a Timer. On tree_exiting (scene unload / app quit), dumps a JSON file containing:
##   {fps_samples, fps_avg, fps_min, fps_max, mem_peak_mb, mem_avg_mb, scene_name}
##
## When MERLIN_PERF_OUT is unset/empty, this autoload disables itself with zero
## overhead. Mirrors the no-op-by-default style of CaptureRecorder so production
## smokes/tests pay no cost.

var _enabled: bool = false
var _out_path: String = ""
var _interval_ms: int = 250
var _fps_samples: Array[float] = []
var _mem_samples_mb: Array[float] = []
var _mem_peak_mb: float = 0.0
var _start_ms: int = 0


func _ready() -> void:
	set_process(false)  # Timer drives sampling, not _process
	_out_path = OS.get_environment("MERLIN_PERF_OUT")
	if _out_path.is_empty():
		return
	# Read optional interval knob
	var interval_env: String = OS.get_environment("MERLIN_PERF_INTERVAL_MS")
	if not interval_env.is_empty() and interval_env.is_valid_int():
		_interval_ms = max(50, int(interval_env))
	# Ensure parent dir exists (creates intermediate dirs if needed)
	var out_dir: String = _out_path.get_base_dir()
	if not out_dir.is_empty() and not DirAccess.dir_exists_absolute(out_dir):
		var err: int = DirAccess.make_dir_recursive_absolute(out_dir)
		if err != OK:
			push_warning("[PerfRecorder] Cannot create dir '%s' err=%d - disabled" % [out_dir, err])
			return
	_enabled = true
	_start_ms = Time.get_ticks_msec()
	# Timer-driven sampling: independent of frame rate / scene _process.
	var t: Timer = Timer.new()
	t.name = "PerfTimer"
	t.wait_time = float(_interval_ms) / 1000.0
	t.one_shot = false
	t.autostart = true
	t.process_callback = Timer.TIMER_PROCESS_IDLE
	add_child(t)
	t.timeout.connect(_on_sample_tick)
	# Connect tree_exiting to flush the JSON before the engine tears down.
	tree_exiting.connect(_on_tree_exiting)
	print("[PerfRecorder] active out=%s interval=%dms" % [_out_path, _interval_ms])


func _on_sample_tick() -> void:
	if not _enabled:
		return
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var mem_bytes: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var mem_mb: float = mem_bytes / (1024.0 * 1024.0)
	_fps_samples.append(fps)
	_mem_samples_mb.append(mem_mb)
	if mem_mb > _mem_peak_mb:
		_mem_peak_mb = mem_mb


func _on_tree_exiting() -> void:
	if not _enabled:
		return
	_enabled = false
	_flush_report()


func _flush_report() -> void:
	# Compute aggregates with safe defaults for empty sample sets (e.g. instant quit).
	var fps_avg: float = 0.0
	var fps_min: float = 0.0
	var fps_max: float = 0.0
	if _fps_samples.size() > 0:
		var fps_sum: float = 0.0
		fps_min = _fps_samples[0]
		fps_max = _fps_samples[0]
		for v in _fps_samples:
			fps_sum += v
			if v < fps_min:
				fps_min = v
			if v > fps_max:
				fps_max = v
		fps_avg = fps_sum / float(_fps_samples.size())
	var mem_avg_mb: float = 0.0
	if _mem_samples_mb.size() > 0:
		var mem_sum: float = 0.0
		for v in _mem_samples_mb:
			mem_sum += v
		mem_avg_mb = mem_sum / float(_mem_samples_mb.size())
	var scene_name: String = ""
	if is_inside_tree():
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			scene_name = current_scene.name
	var report: Dictionary = {
		"scene_name": scene_name,
		"duration_ms": Time.get_ticks_msec() - _start_ms,
		"sample_count": _fps_samples.size(),
		"interval_ms": _interval_ms,
		"fps_samples": _fps_samples,
		"fps_avg": fps_avg,
		"fps_min": fps_min,
		"fps_max": fps_max,
		"mem_peak_mb": _mem_peak_mb,
		"mem_avg_mb": mem_avg_mb,
	}
	var f: FileAccess = FileAccess.open(_out_path, FileAccess.WRITE)
	if f == null:
		push_warning("[PerfRecorder] Cannot open '%s' for write - report lost" % _out_path)
		return
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("[PerfRecorder] dumped %d samples -> %s (fps_avg=%.1f mem_peak=%.1fMB)" % [
		_fps_samples.size(), _out_path, fps_avg, _mem_peak_mb,
	])
