## ═══════════════════════════════════════════════════════════════════════════════
## DigitalPickerCard — Unified picker card (v7.7.21, 2026-05-16)
## ═══════════════════════════════════════════════════════════════════════════════
## REUSABLE 2D component shared by BoardNarration biome picker (8 cards) and
## ScenarioLoading scenario picker (3 cards). Single source of truth for the
## "choose one of N narrative paths" interaction in MERLIN.
##
## User intent (verbatim) : « Les menus de selection de biomes et de selection
## de scenarios doivent être les mêmes ... interface claire, détaillé et jolie,
## là c'est rugueux sans aspérité ».
##
## Charter compliance (MerlinVisual.UI_* intraitable spec) :
##   - Border : UI_GOLD (or accent override per biome) — UI_BORDER_NORMAL=4 / HOVER=6
##   - Text   : UI_WHITE + UI_BLACK outline (UI_OUTLINE_SIZE=3)
##   - Bg     : UI_BG_DARK (assombri, transparent .92)
##   - Sharp edges, NO corner radius (Persona/Inscryption aesthetic)
##
## Public API :
##   - signal selected(card_id: String)             — emitted on click (unlocked only)
##   - setup(id, title, body, glyph, accent, locked?, lock_msg?)
##   - animate_in(delay: float)                     — cascade reveal
##   - mark_chosen()                                — selected card pulse + crimson flash
##   - dim_unselected()                             — fade-out for non-chosen cards
##
## Visual layout (320 × 400 px) :
##   ┌──────────────────────────┐
##   │  ᚁ                       │  ← Ogham glyph 40px, accent color
##   │  Le Bois qui Murmure     │  ← Title 26px white + black outline
##   │  ──────────              │  ← 2px accent separator
##   │  Les arbres murmurent    │  ← Body 16px white, autowrap
##   │  les secrets des druides │
##   │                          │
##   │           ▸ ENTRER       │  ← Hint 12px dim gold
##   └──────────────────────────┘
##
## ═══════════════════════════════════════════════════════════════════════════════

extends PanelContainer
class_name DigitalPickerCard

signal selected(card_id: String)

const CARD_W: float = 320.0
const CARD_H: float = 400.0

# Internal state.
var _card_id: String = ""
var _accent: Color = MerlinVisual.UI_GOLD
var _locked: bool = false
var _is_hovered: bool = false
var _is_chosen: bool = false

# Internal nodes (built in setup).
var _stylebox_normal: StyleBoxFlat = null
var _stylebox_hover: StyleBoxFlat = null
var _glyph_label: Label = null
var _title_label: Label = null
var _separator: ColorRect = null
var _body_label: Label = null
var _hint_label: Label = null
var _flash_overlay: ColorRect = null


func _ready() -> void:
	# Charter geometry — fixed across ALL DigitalPickerCard instances.
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Animate-in starts hidden ; animate_in() reveals it.
	modulate.a = 0.0
	scale = Vector2.ONE  # pivot at top-left ; animate_in handles scale
	pivot_offset = Vector2(CARD_W * 0.5, CARD_H * 0.5)
	# Hover / click hooks.
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)


## Configure the card content + accent color. Call ONCE right after instantiation
## (before adding to tree or right after — both work since _ready guards nodes).
##
## @param card_id       Stable id emitted in `selected` signal (biome_id / scenario_idx).
## @param title         Primary heading (e.g. "Le Bois qui Murmure", scenario title).
## @param body          2-3 line description (autowrap). May contain "\n" for forced breaks.
## @param ogham_glyph   Single Ogham unicode char (e.g. "ᚁ"). Empty string = no glyph row.
## @param accent_color  Border + glyph color. Default UI_GOLD ; per-biome accent for variety.
## @param locked        If true, card is dimmed + click does nothing + lock_message shown.
## @param lock_message  Optional tooltip when locked (default "Apprends encore.").
func setup(card_id: String, title: String, body: String, ogham_glyph: String, accent_color: Color = MerlinVisual.UI_GOLD, locked: bool = false, lock_message: String = "") -> void:
	_card_id = card_id
	_accent = accent_color
	_locked = locked
	if not is_inside_tree():
		# Build nodes immediately so callers can position the card before _ready.
		# _ready will run later and connect signals on existing children.
		call_deferred("_apply_setup", title, body, ogham_glyph, lock_message)
	else:
		_apply_setup(title, body, ogham_glyph, lock_message)


func _apply_setup(title: String, body: String, ogham_glyph: String, lock_message: String) -> void:
	# Clear any prior content (idempotent setup). Use free() not queue_free so
	# children are gone THIS frame — avoids one-frame theme/stylebox flicker if
	# setup() is called twice rapidly.
	for child in get_children():
		child.free()

	# Charter-compliant StyleBoxFlat (gold border default, dark bg, sharp).
	_stylebox_normal = StyleBoxFlat.new()
	_stylebox_normal.bg_color = MerlinVisual.UI_BG_DARK
	_stylebox_normal.border_color = _accent if not _locked else Color(_accent.r * 0.45, _accent.g * 0.45, _accent.b * 0.45, 0.85)
	_stylebox_normal.set_border_width_all(MerlinVisual.UI_BORDER_NORMAL)
	_stylebox_normal.set_corner_radius_all(0)
	_stylebox_normal.set_content_margin_all(20)
	add_theme_stylebox_override("panel", _stylebox_normal)

	# Pre-compute hover stylebox (brighter border + lighter bg + thicker border).
	_stylebox_hover = _stylebox_normal.duplicate() as StyleBoxFlat
	_stylebox_hover.bg_color = MerlinVisual.UI_BG_HOVER
	_stylebox_hover.border_color = MerlinVisual.UI_GOLD_BRIGHT
	_stylebox_hover.set_border_width_all(MerlinVisual.UI_BORDER_HOVER)

	# Inner VBoxContainer for content layout.
	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Row 1 — Ogham glyph (optional).
	if ogham_glyph != "":
		_glyph_label = Label.new()
		_glyph_label.name = "Glyph"
		_glyph_label.text = ogham_glyph
		_glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_glyph_label.add_theme_font_size_override("font_size", 40)
		_glyph_label.add_theme_color_override("font_color", _accent)
		_glyph_label.add_theme_color_override("font_outline_color", MerlinVisual.UI_BLACK)
		_glyph_label.add_theme_constant_override("outline_size", MerlinVisual.UI_OUTLINE_SIZE)
		if _locked:
			_glyph_label.modulate.a = 0.45
		vbox.add_child(_glyph_label)

	# Row 2 — Title (charter typography : 26px white + black outline).
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = title
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", MerlinVisual.UI_WHITE)
	_title_label.add_theme_color_override("font_outline_color", MerlinVisual.UI_BLACK)
	_title_label.add_theme_constant_override("outline_size", MerlinVisual.UI_OUTLINE_SIZE)
	if _locked:
		_title_label.modulate.a = 0.55
	vbox.add_child(_title_label)

	# Row 3 — Thin accent separator (2px ColorRect, full width).
	_separator = ColorRect.new()
	_separator.name = "AccentLine"
	_separator.color = _accent
	_separator.custom_minimum_size = Vector2(0, 2)
	_separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _locked:
		_separator.modulate.a = 0.45
	vbox.add_child(_separator)

	# Row 4 — Body description (charter typography : 16px white + autowrap).
	_body_label = Label.new()
	_body_label.name = "Body"
	_body_label.text = body if not _locked else lock_message
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.add_theme_color_override("font_color", MerlinVisual.UI_WHITE)
	_body_label.add_theme_color_override("font_outline_color", MerlinVisual.UI_BLACK)
	_body_label.add_theme_constant_override("outline_size", MerlinVisual.UI_OUTLINE_SIZE)
	if _locked:
		_body_label.modulate.a = 0.65
	vbox.add_child(_body_label)

	# Row 5 — Hint footer ("▸ ENTRER" in dim gold, right-aligned).
	_hint_label = Label.new()
	_hint_label.name = "Hint"
	_hint_label.text = "▸ ENTRER" if not _locked else "✕ VERROUILLÉ"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_font_size_override("font_size", 12)
	var hint_color: Color = Color(_accent.r, _accent.g, _accent.b, 0.85) if not _locked else Color(MerlinVisual.UI_CRIMSON.r, MerlinVisual.UI_CRIMSON.g, MerlinVisual.UI_CRIMSON.b, 0.70)
	_hint_label.add_theme_color_override("font_color", hint_color)
	_hint_label.add_theme_color_override("font_outline_color", MerlinVisual.UI_BLACK)
	_hint_label.add_theme_constant_override("outline_size", MerlinVisual.UI_OUTLINE_SIZE)
	vbox.add_child(_hint_label)

	# Flash overlay for click feedback (full-card crimson burst).
	_flash_overlay = ColorRect.new()
	_flash_overlay.name = "FlashOverlay"
	_flash_overlay.color = Color(MerlinVisual.UI_CRIMSON.r, MerlinVisual.UI_CRIMSON.g, MerlinVisual.UI_CRIMSON.b, 0.0)
	_flash_overlay.anchor_right = 1.0
	_flash_overlay.anchor_bottom = 1.0
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_overlay)

	# Tooltip when locked (Godot displays on hover).
	if _locked:
		tooltip_text = lock_message if lock_message != "" else "Apprends encore."


## Cascade animate-in : fade alpha 0→1 + scale 0.92→1.0 (TRANS_BACK overshoot)
## after an optional delay (seconds). Use for staggered reveal of 8 biome cards
## or 3 scenario cards.
func animate_in(delay: float = 0.0) -> void:
	# Start from hidden + slightly shrunk for the BACK overshoot punch.
	modulate.a = 0.0
	scale = Vector2(0.92, 0.92)
	# Sequential tween_interval(delay) BEFORE switching to parallel so both
	# alpha and scale animations actually start together AFTER the gap. The
	# previous parallel-from-start + set_delay pattern caused scale to animate
	# while alpha was still 0, producing a brief pop-in at full scale.
	var t := create_tween().bind_node(self)
	if delay > 0.0:
		t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Player picked THIS card — pulse + crimson flash + emit signal (handled in click).
## Public so callers can replay the animation without re-emitting (e.g. confirm step).
func mark_chosen() -> void:
	_is_chosen = true
	# Scale pulse 1.0 → 1.08 → 1.0. SEQUENTIAL : punch grows then SINE return,
	# no parallel/set_delay fragility (segment-2 starts exactly when segment-1 ends).
	var pulse := create_tween().bind_node(self)
	pulse.tween_property(self, "scale", Vector2(1.08, 1.08), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(self, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_SINE)
	# Flash overlay : crimson alpha 0 → 0.55 → 0 over 0.45s. Bind to self (the
	# card) — _flash_overlay is a child and will be freed first when card dies,
	# but the tween must outlive the child's queue_free deferral safely.
	if _flash_overlay != null and is_instance_valid(_flash_overlay):
		var flash := create_tween().bind_node(self)
		flash.tween_property(_flash_overlay, "color:a", 0.55, 0.10)
		flash.tween_property(_flash_overlay, "color:a", 0.0, 0.35)
	# Border bumps to UI_GOLD_BRIGHT permanently to signal "locked-in" choice.
	if _stylebox_normal != null:
		_stylebox_normal.border_color = MerlinVisual.UI_GOLD_BRIGHT
		_stylebox_normal.set_border_width_all(MerlinVisual.UI_BORDER_HOVER)


## Player picked a DIFFERENT card — this one fades out.
func dim_unselected() -> void:
	var fade := create_tween().bind_node(self).set_parallel(true)
	fade.tween_property(self, "modulate:a", 0.25, 0.45).set_trans(Tween.TRANS_SINE)
	fade.tween_property(self, "scale", Vector2(0.96, 0.96), 0.45).set_trans(Tween.TRANS_SINE)


# ═════════ Internal hover + click handlers ═══════════════════════════════════

func _on_mouse_entered() -> void:
	if _locked or _is_chosen:
		return
	_is_hovered = true
	if _stylebox_hover != null:
		add_theme_stylebox_override("panel", _stylebox_hover)
	# Subtle scale-up on hover.
	var t := create_tween().bind_node(self)
	t.tween_property(self, "scale", Vector2(1.03, 1.03), 0.15).set_trans(Tween.TRANS_SINE)


func _on_mouse_exited() -> void:
	if _locked or _is_chosen:
		return
	_is_hovered = false
	if _stylebox_normal != null:
		add_theme_stylebox_override("panel", _stylebox_normal)
	var t := create_tween().bind_node(self)
	t.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE)


func _on_gui_input(event: InputEvent) -> void:
	if _locked or _is_chosen:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			mark_chosen()
			selected.emit(_card_id)
