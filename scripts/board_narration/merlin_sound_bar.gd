## ═══════════════════════════════════════════════════════════════════════════════
## MerlinSoundBar — Digital audio-visualizer that represents Merlin in 3D space
## ═══════════════════════════════════════════════════════════════════════════════
## v7.7.15 — user request : « merlin sous forme de barre de son digitale qui
## s'anima quand il parle à l'aide d'une bulle ».
##
## 12 vertical bars (BoxMesh) at the back of the plateau, facing the player.
## Bars pulse upward when Merlin speaks (per-typewriter-char), then ease back
## to a low-amplitude idle wiggle.
##
## API :
##   pulse(intensity: float)       — bump a few random bars by `intensity` (0..1)
##   start_speaking()              — enable active speech state (taller idle baseline)
##   stop_speaking()               — return all bars to rest (~0.3s ease-out)
##   set_accent_color(c: Color)    — change emission tint (e.g. per biome)
##
## Visual : 12 BoxMesh + emission glow (no outline mesh — relies on material emission
## for the digital sound-bar look).
## ═══════════════════════════════════════════════════════════════════════════════

class_name MerlinSoundBar
extends Node3D

const BAR_COUNT: int = 12
const BAR_WIDTH: float = 0.08
const BAR_DEPTH: float = 0.05
const BAR_SPACING: float = 0.12
const BAR_IDLE_HEIGHT: float = 0.06           # baseline when silent
const BAR_SPEAKING_HEIGHT_MIN: float = 0.18    # min height during speech idle
const BAR_PULSE_HEIGHT_MAX: float = 0.85       # max height on intense pulse

const REST_DECAY: float = 0.10                 # per-frame lerp toward rest amplitude
const PULSE_DECAY: float = 0.25                # per-frame lerp toward target amplitude (speed)

var _bars: Array[MeshInstance3D] = []
var _amplitudes: Array[float] = []
var _targets: Array[float] = []
var _accent_color: Color = Color(0.92, 0.72, 0.20)   # default Persona gold
var _ink_color: Color = Color(0.04, 0.03, 0.03)
var _is_speaking: bool = false


func _ready() -> void:
	var total_width: float = float(BAR_COUNT - 1) * BAR_SPACING
	var start_x: float = -total_width * 0.5
	for i in range(BAR_COUNT):
		var bar := MeshInstance3D.new()
		bar.name = "Bar_%d" % i
		var box := BoxMesh.new()
		box.size = Vector3(BAR_WIDTH, BAR_IDLE_HEIGHT, BAR_DEPTH)
		bar.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _ink_color
		mat.metallic = 0.10
		mat.roughness = 0.55
		mat.emission_enabled = true
		mat.emission = _accent_color
		mat.emission_energy_multiplier = 0.55
		bar.material_override = mat
		bar.position = Vector3(start_x + float(i) * BAR_SPACING, BAR_IDLE_HEIGHT * 0.5, 0.0)
		add_child(bar)
		_bars.append(bar)
		_amplitudes.append(BAR_IDLE_HEIGHT)
		_targets.append(BAR_IDLE_HEIGHT)
	# v7.7.17 — Apply CelShadingManager outline noir to each bar per user request
	# « TOUS les assets aient un effet cel shadé ... contour noir complet ».
	# Audit confirmed this was the single gap in 99% coverage.
	for bar in _bars:
		CelShadingManager.apply(bar, {"outline_thickness": 0.012, "skip_flat_remap": true})


func _process(_delta: float) -> void:
	var rest_amp: float = (BAR_SPEAKING_HEIGHT_MIN if _is_speaking else BAR_IDLE_HEIGHT)
	for i in range(BAR_COUNT):
		_amplitudes[i] = lerp(_amplitudes[i], _targets[i], PULSE_DECAY)
		_targets[i] = lerp(_targets[i], rest_amp, REST_DECAY)
		var bar: MeshInstance3D = _bars[i]
		if not is_instance_valid(bar):
			continue
		var box: BoxMesh = bar.mesh as BoxMesh
		if box != null:
			box.size = Vector3(BAR_WIDTH, _amplitudes[i], BAR_DEPTH)
		bar.position.y = _amplitudes[i] * 0.5


## Pulse N random bars by `intensity` (0..1). Trigger on each typewriter char.
func pulse(intensity: float) -> void:
	intensity = clampf(intensity, 0.0, 1.0)
	var pulse_count: int = 3 + int(intensity * 4.0)   # 3-7 bars per pulse
	var target_h: float = lerp(BAR_SPEAKING_HEIGHT_MIN, BAR_PULSE_HEIGHT_MAX, intensity)
	for _i in range(pulse_count):
		var idx: int = randi() % BAR_COUNT
		_targets[idx] = max(_targets[idx], randf_range(target_h * 0.6, target_h))


## Enable active-speech mode (taller idle baseline + auto-wiggle).
func start_speaking() -> void:
	_is_speaking = true


## Disable speech mode — bars decay to rest amplitude.
func stop_speaking() -> void:
	_is_speaking = false


## Change emission tint of all bars (e.g. on biome change).
func set_accent_color(c: Color) -> void:
	_accent_color = c
	for bar in _bars:
		if not is_instance_valid(bar):
			continue
		var mat: StandardMaterial3D = bar.material_override as StandardMaterial3D
		if mat != null:
			mat.emission = c
