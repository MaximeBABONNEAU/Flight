## ═══════════════════════════════════════════════════════════════════════════════
## SigleToken — Ogham sigil token displayed on the BoardNarration plateau.
## ═══════════════════════════════════════════════════════════════════════════════
## One token = one card-event from the run replay.
## Visual = Label3D billboard with Unicode Ogham glyph + OmniLight3D for glow.
## Behaviour:
##   - animate_in(delay)   : pop-in scale + light ramp
##   - highlight()         : pulse + intense glow during narration of this card
##   - dim_to_idle()       : settle back to ambient state once narrated
## Sigles are always visible (emissive Label3D), legibility holds across biomes.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node3D
class_name SigleToken

signal token_clicked(token: SigleToken)

# Faction tint — falls back to neutral phosphor green if no dominant faction.
const FACTION_COLORS := {
	"druides":   Color(0.42, 0.84, 0.42),
	"anciens":   Color(0.92, 0.70, 0.32),
	"korrigans": Color(0.80, 0.50, 0.20),
	"niamh":     Color(0.40, 0.72, 0.92),
	"ankou":     Color(0.62, 0.42, 0.74),
	"":          Color(0.72, 0.88, 0.55),
}

const DEFAULT_GLYPH := "ᚁ"   # Beith ᚁ — neutral starter glyph fallback
const GLYPH_PIXEL_SIZE := 192
const LIGHT_RANGE := 1.8
const LIGHT_ENERGY_DIM := 0.25
const LIGHT_ENERGY_IDLE := 0.65
const LIGHT_ENERGY_HIGHLIGHT := 2.6
const SCALE_IDLE := 0.34
const SCALE_HIGHLIGHT := 0.54
const ANIM_IN_TIME := 0.55
const ANIM_HIGHLIGHT_TIME := 0.30
const ANIM_DIM_TIME := 0.55

var ogham_id: String = ""
var card_id: String = ""
var faction: String = ""

var _label: Label3D = null
var _light: OmniLight3D = null
var _current_tween: Tween = null


func _ready() -> void:
	_ensure_nodes()


func _ensure_nodes() -> void:
	if _label == null:
		var existing_label := get_node_or_null("Label3D") as Label3D
		if existing_label:
			_label = existing_label
		else:
			_label = Label3D.new()
			_label.name = "Label3D"
			add_child(_label)
	if _light == null:
		var existing_light := get_node_or_null("OmniLight3D") as OmniLight3D
		if existing_light:
			_light = existing_light
		else:
			_light = OmniLight3D.new()
			_light.name = "OmniLight3D"
			add_child(_light)


func setup(p_ogham_id: String, p_card_id: String, p_faction: String = "") -> void:
	_ensure_nodes()
	ogham_id = p_ogham_id
	card_id = p_card_id
	faction = p_faction

	# Resolve glyph from constants (with safety fallback).
	var glyph := DEFAULT_GLYPH
	if ClassDB.class_exists("MerlinConstants"):
		var spec_dict: Dictionary = MerlinConstants.OGHAM_FULL_SPECS
		if spec_dict.has(p_ogham_id):
			glyph = str(spec_dict[p_ogham_id].get("unicode", DEFAULT_GLYPH))

	var tint: Color = FACTION_COLORS.get(p_faction, FACTION_COLORS[""])

	_label.text = glyph
	_label.font_size = GLYPH_PIXEL_SIZE
	_label.outline_size = 10
	_label.outline_modulate = Color(0.02, 0.04, 0.02, 1.0)
	_label.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.shaded = false
	_label.no_depth_test = false
	_label.fixed_size = false
	_label.pixel_size = 0.005

	_light.light_color = tint
	_light.light_energy = 0.0
	_light.omni_range = LIGHT_RANGE
	_light.omni_attenuation = 2.0

	scale = Vector3.ZERO


func animate_in(delay: float = 0.0) -> void:
	_ensure_nodes()
	_kill_tween()
	_current_tween = create_tween().set_parallel(true)
	if delay > 0.0:
		_current_tween.tween_interval(delay)
	_current_tween.chain()
	_current_tween.set_parallel(true)
	_current_tween.tween_property(self, "scale", Vector3.ONE * SCALE_IDLE, ANIM_IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(_label, "modulate:a", 0.7, ANIM_IN_TIME * 0.8)
	_current_tween.tween_property(_light, "light_energy", LIGHT_ENERGY_DIM, ANIM_IN_TIME)


func highlight() -> void:
	_ensure_nodes()
	_kill_tween()
	_current_tween = create_tween().set_parallel(true)
	_current_tween.tween_property(self, "scale", Vector3.ONE * SCALE_HIGHLIGHT, ANIM_HIGHLIGHT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(_light, "light_energy", LIGHT_ENERGY_HIGHLIGHT, ANIM_HIGHLIGHT_TIME)
	_current_tween.tween_property(_label, "modulate:a", 1.0, ANIM_HIGHLIGHT_TIME)


func dim_to_idle() -> void:
	_ensure_nodes()
	_kill_tween()
	_current_tween = create_tween().set_parallel(true)
	_current_tween.tween_property(self, "scale", Vector3.ONE * SCALE_IDLE, ANIM_DIM_TIME)
	_current_tween.tween_property(_light, "light_energy", LIGHT_ENERGY_IDLE, ANIM_DIM_TIME)
	_current_tween.tween_property(_label, "modulate:a", 0.6, ANIM_DIM_TIME)


func get_glyph() -> String:
	if _label == null:
		return DEFAULT_GLYPH
	return _label.text


func _kill_tween() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	_current_tween = null
