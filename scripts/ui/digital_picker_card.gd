## ═══════════════════════════════════════════════════════════════════════════════
## DigitalPickerCard — Unified picker card (v7.7.21b, 2026-05-16)
## ═══════════════════════════════════════════════════════════════════════════════
## REUSABLE 2D component shared by BoardNarration biome picker (8 cards) and
## ScenarioLoading scenario picker (3 cards). Single source of truth for the
## "choose one of N narrative paths" interaction in MERLIN.
##
## v7.7.21a — initial component (320×400 charter-compliant card, hover/click).
## v7.7.21b — iter 2 polish (typography + spacing + animations) AND
##            iter 3 rarity/Pole/card-type encoding system.
##
## ── Iteration 3 System ──────────────────────────────────────────────────────
## The card's BORDER encodes RARITY (4 tiers, per bible canon) :
##   - Commune     : dim gold (`#8c7a4b`), border 3px, no glow
##   - Rare        : UI_GOLD, border 4px (charter default)
##   - Épique      : violet `#9F62FF`, border 5px, soft inner glow
##   - Légendaire  : bright gold `#FFB033`, border 6px, animated breathing
##
## The card's BADGE (top-right 28px circle) encodes POLE (bible §3.2 v3.0) :
##   - Ordre   : `#d4a868` Or/Ambre  · glyph `ᚇ` (Duir oak)
##   - Chaos   : `#9B59FF` Violet/Feu · glyph `✦`
##   - Liminal : `#5a8aa8` Cyan/Brume · glyph `ᚄ` (Saille willow)
##
## Legacy 5-faction data (`{"faction":"druides"}`) auto-maps via FACTION_TO_POLE :
##   druides+anciens→Ordre · korrigans+ankou→Chaos · niamh→Liminal
##
## The CARD_TYPE alters border STYLE (orthogonal to rarity color) :
##   - NARRATIVE     : solid (default)
##   - EVENT         : animated alpha pulse (breathing 0.85↔1.0 @ 1.6s loop)
##   - SHOP          : amber tint + corner "$" mark
##   - PROMISE       : double-line (outer + inner stripe)
##   - MERLIN_DIRECT : crimson tint + emphasised pulse
##   - RUNE_UNLOCK   : iridescent shift (color cycle if no shader)
##
## Charter compliance (MerlinVisual.UI_* intraitable spec) :
##   - Bg     : UI_BG_DARK (rarity does NOT override bg — only border)
##   - Text   : UI_WHITE + UI_BLACK outline (UI_OUTLINE_SIZE=3)
##   - Sharp edges, NO corner radius (Persona/Inscryption aesthetic)
##
## Public API :
##   - signal selected(card_id: String)             — emitted on click (unlocked only)
##   - setup(id, title, body, glyph, accent, locked?, lock_msg?)
##   - apply_card_metadata(rarity, faction_or_pole, card_type)  — OPTIONAL, after setup()
##   - animate_in(delay: float)                     — cascade reveal
##   - mark_chosen()                                — selected card pulse + crimson flash
##   - dim_unselected()                             — fade-out for non-chosen cards
##
## Visual layout (320 × 400 px) :
##   ┌──────────────────────────┐
##   │  ᚁ                  ⊙OR  │  ← Glyph 44px + (optional) Pole badge top-right
##   │  Le Bois qui Murmure     │  ← Title 28px white + black outline
##   │  ──────────              │  ← 2px accent separator (border color)
##   │  Les arbres murmurent    │  ← Body 17px white, autowrap
##   │  les secrets des druides │
##   │                          │
##   │           ▸ ENTRER       │  ← Hint 13px dim gold
##   └──────────────────────────┘
##
## ═══════════════════════════════════════════════════════════════════════════════

extends PanelContainer
class_name DigitalPickerCard

signal selected(card_id: String)

const CARD_W: float = 320.0
const CARD_H: float = 400.0

# ── Iter 3 — Rarity tier (4 tiers per user decision + bible canon) ─────────────
enum Rarity { COMMUNE = 0, RARE = 1, EPIQUE = 2, LEGENDAIRE = 3 }

# Rarity → border color (replaces _accent for border when metadata applied).
# Bg always stays UI_BG_DARK (intraitable). Only the border encodes rarity.
const RARITY_BORDER_COLORS: Dictionary = {
	Rarity.COMMUNE:    Color(0.55, 0.48, 0.30, 1.0),   # dim gold (low-tier)
	Rarity.RARE:       Color(0.92, 0.75, 0.30, 1.0),   # UI_GOLD (default)
	Rarity.EPIQUE:     Color(0.62, 0.38, 1.00, 1.0),   # royal violet
	Rarity.LEGENDAIRE: Color(1.00, 0.69, 0.20, 1.0),   # bright gold (legendary)
}

# Rarity → border thickness (subtle but readable hierarchy).
const RARITY_BORDER_WIDTHS: Dictionary = {
	Rarity.COMMUNE:    3,
	Rarity.RARE:       4,   # charter default UI_BORDER_NORMAL
	Rarity.EPIQUE:     5,
	Rarity.LEGENDAIRE: 6,   # charter UI_BORDER_HOVER (idle pulses to it)
}

# ── Iter 3 — 3 Poles (bible §3.2 v3.0, supersedes 5 factions) ──────────────────
enum Pole { NEUTRE = 0, ORDRE = 1, CHAOS = 2, LIMINAL = 3 }

# Pole → badge visual identity (color + glyph + display name).
const POLE_DATA: Dictionary = {
	Pole.ORDRE: {
		"color": Color(0.83, 0.66, 0.40, 1.0),   # Or/Ambre per bible §22
		"glyph": "ᚇ",                              # Ogham Duir (oak)
		"name":  "ORDRE",
	},
	Pole.CHAOS: {
		"color": Color(0.61, 0.35, 1.00, 1.0),   # Violet chaos per bible §10.2
		"glyph": "✦",                              # 4-pointed star (Korrigan trickster)
		"name":  "CHAOS",
	},
	Pole.LIMINAL: {
		"color": Color(0.35, 0.54, 0.66, 1.0),   # Niamh azure per bible §22
		"glyph": "ᚄ",                              # Ogham Saille (willow)
		"name":  "LIMINAL",
	},
}

# Legacy 5-faction data (still in fastroute_cards.json / event_cards.json) →
# 3-Pole mapping for the badge. Bible §3.2 v3.0 explicit merger.
const FACTION_TO_POLE: Dictionary = {
	"druides":   Pole.ORDRE,
	"anciens":   Pole.ORDRE,
	"korrigans": Pole.CHAOS,
	"ankou":     Pole.CHAOS,
	"niamh":     Pole.LIMINAL,
}

# ── Iter 3 — Card types (border style variants, orthogonal to rarity color) ────
enum CardType {
	NARRATIVE = 0,       # solid border (default)
	EVENT = 1,           # animated alpha pulse
	SHOP = 2,            # amber tint + "$" corner mark
	PROMISE = 3,         # double-line border
	MERLIN_DIRECT = 4,   # crimson glow + emphasised pulse
	RUNE_UNLOCK = 5,     # iridescent color cycle
}

# Internal state.
var _card_id: String = ""
var _accent: Color = MerlinVisual.UI_GOLD
var _locked: bool = false
var _is_hovered: bool = false
var _is_chosen: bool = false

# Iter 3 — applied metadata (defaults : no rarity / no Pole / NARRATIVE).
var _rarity: int = -1                      # -1 = no rarity encoding (uses _accent)
var _pole: int = Pole.NEUTRE              # NEUTRE = no badge
var _card_type: int = CardType.NARRATIVE
var _idle_pulse_tween: Tween = null        # Légendaire / EVENT / MERLIN_DIRECT loops

# Internal nodes (built in setup).
var _stylebox_normal: StyleBoxFlat = null
var _stylebox_hover: StyleBoxFlat = null
var _glyph_label: Label = null
var _title_label: Label = null
var _separator: ColorRect = null
var _body_label: Label = null
var _hint_label: Label = null
var _flash_overlay: ColorRect = null
var _pole_badge: PanelContainer = null     # top-right circular Pole badge


func _ready() -> void:
	# Charter geometry — fixed across ALL DigitalPickerCard instances.
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Animate-in starts hidden ; animate_in() reveals it.
	modulate.a = 0.0
	scale = Vector2.ONE
	pivot_offset = Vector2(CARD_W * 0.5, CARD_H * 0.5)
	# Hover / click hooks.
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)


## Configure the card content + accent color. Call ONCE right after instantiation.
## After setup(), optionally call `apply_card_metadata(rarity, faction, type)` to
## override the border encoding with rarity + Pole + card_type.
##
## @param card_id       Stable id emitted in `selected` signal.
## @param title         Primary heading (28px white).
## @param body          2-3 line description (17px white, autowrap).
## @param ogham_glyph   Single Ogham unicode char. Empty string = no glyph row.
## @param accent_color  Border + glyph color WHEN no rarity applied. Default UI_GOLD.
## @param locked        If true, dimmed + clicks ignored + lock_message tooltip.
## @param lock_message  Tooltip when locked.
func setup(card_id: String, title: String, body: String, ogham_glyph: String, accent_color: Color = MerlinVisual.UI_GOLD, locked: bool = false, lock_message: String = "") -> void:
	_card_id = card_id
	_accent = accent_color
	_locked = locked
	if not is_inside_tree():
		call_deferred("_apply_setup", title, body, ogham_glyph, lock_message)
	else:
		_apply_setup(title, body, ogham_glyph, lock_message)


## Iter 3 — Apply rarity / faction(or Pole) / card_type AFTER setup(). All args
## optional via sentinels :
##   - rarity        : -1 = keep _accent (no rarity encoding). 0-3 = Rarity enum.
##   - faction_or_pole: "" = no badge. String "druides"/"anciens"/... maps via
##                     FACTION_TO_POLE. Or pass "ordre"/"chaos"/"liminal" directly.
##                     Or pass Pole enum int (0=NEUTRE, 1=ORDRE, 2=CHAOS, 3=LIMINAL).
##   - card_type     : CardType enum (default NARRATIVE → solid border).
##
## Safe to call multiple times ; idempotent. Does NOT touch text content.
func apply_card_metadata(rarity: int = -1, faction_or_pole = "", card_type: int = CardType.NARRATIVE) -> void:
	_rarity = rarity
	_card_type = card_type
	_pole = _resolve_pole(faction_or_pole)
	# Stop any running idle pulse (will be re-armed if card_type requires it).
	if _idle_pulse_tween != null and _idle_pulse_tween.is_valid():
		_idle_pulse_tween.kill()
		_idle_pulse_tween = null
	if not is_inside_tree():
		call_deferred("_apply_metadata")
	else:
		_apply_metadata()


## Resolve faction/pole arg (String or Pole enum int) → Pole enum int.
## Returns Pole.NEUTRE if unrecognised (no badge shown).
func _resolve_pole(faction_or_pole) -> int:
	if typeof(faction_or_pole) == TYPE_INT:
		var p: int = int(faction_or_pole)
		if p >= Pole.NEUTRE and p <= Pole.LIMINAL:
			return p
		return Pole.NEUTRE
	var s: String = str(faction_or_pole).to_lower().strip_edges()
	if s == "":
		return Pole.NEUTRE
	# Direct Pole name match.
	match s:
		"ordre":   return Pole.ORDRE
		"chaos":   return Pole.CHAOS
		"liminal": return Pole.LIMINAL
		"neutre":  return Pole.NEUTRE
	# Legacy 5-faction mapping.
	if FACTION_TO_POLE.has(s):
		return int(FACTION_TO_POLE[s])
	return Pole.NEUTRE


## Apply the resolved rarity / Pole / card_type to the visual layer. Mutates the
## existing styleboxes + (re)builds the Pole badge.
func _apply_metadata() -> void:
	if _stylebox_normal == null or _stylebox_hover == null:
		return  # setup() hasn't run yet
	# 1. Border color + width per rarity (overrides _accent if rarity >= 0).
	var border_color: Color = _accent
	var border_width: int = MerlinVisual.UI_BORDER_NORMAL
	if _rarity >= Rarity.COMMUNE and _rarity <= Rarity.LEGENDAIRE:
		border_color = RARITY_BORDER_COLORS[_rarity]
		border_width = int(RARITY_BORDER_WIDTHS[_rarity])
	# 2. Card type modifiers (orthogonal tint on top of rarity color).
	match _card_type:
		CardType.SHOP:
			# Amber tint — shop = merchant gold.
			border_color = border_color.lerp(Color(1.0, 0.78, 0.30), 0.35)
		CardType.MERLIN_DIRECT:
			# Crimson tint — Merlin breaks 4th wall.
			border_color = border_color.lerp(MerlinVisual.UI_CRIMSON, 0.45)
		CardType.RUNE_UNLOCK:
			# Iridescent baseline (cycle will animate it).
			border_color = border_color.lerp(Color(0.85, 0.95, 1.00), 0.20)
		_:
			pass
	# 3. Apply to styleboxes (normal + hover).
	_stylebox_normal.border_color = border_color if not _locked else Color(border_color.r * 0.45, border_color.g * 0.45, border_color.b * 0.45, 0.85)
	_stylebox_normal.set_border_width_all(border_width)
	_stylebox_hover.border_color = border_color.lightened(0.20)
	_stylebox_hover.set_border_width_all(border_width + 2)
	# Update separator color to match rarity-tinted border.
	if _separator != null and is_instance_valid(_separator):
		_separator.color = border_color
	# Update hint footer color to match.
	if _hint_label != null and is_instance_valid(_hint_label):
		var hc: Color = Color(border_color.r, border_color.g, border_color.b, 0.85)
		_hint_label.add_theme_color_override("font_color", hc)
	# 4. Build / rebuild Pole badge top-right.
	_build_or_clear_pole_badge()
	# 5. Idle pulse animation for special card_types + Légendaire rarity.
	_arm_idle_pulse_if_needed()


## Top-right circular badge (28×28) showing the Pole glyph + color.
## Removed if _pole == NEUTRE. Idempotent : safe to call multiple times.
func _build_or_clear_pole_badge() -> void:
	if _pole_badge != null and is_instance_valid(_pole_badge):
		# free() not queue_free() — avoid one-frame two-badge overlap when
		# apply_card_metadata is called twice in the same frame.
		_pole_badge.free()
		_pole_badge = null
	if _pole == Pole.NEUTRE:
		return
	if not POLE_DATA.has(_pole):
		return
	var data: Dictionary = POLE_DATA[_pole]
	var pole_color: Color = data.get("color", MerlinVisual.UI_GOLD)
	var pole_glyph: String = str(data.get("glyph", "?"))
	# Badge container : 32×32 PanelContainer anchored top-right with 10px inset.
	_pole_badge = PanelContainer.new()
	_pole_badge.name = "PoleBadge"
	_pole_badge.custom_minimum_size = Vector2(32, 32)
	_pole_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pole_badge.anchor_left = 1.0
	_pole_badge.anchor_right = 1.0
	_pole_badge.anchor_top = 0.0
	_pole_badge.anchor_bottom = 0.0
	_pole_badge.offset_left = -44.0   # 32 wide + 12 inset from right edge
	_pole_badge.offset_right = -12.0
	_pole_badge.offset_top = 12.0
	_pole_badge.offset_bottom = 44.0
	# Stylebox : same Pole color border, dark bg, sharp edges (charter).
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = MerlinVisual.UI_BG_DARK
	badge_sb.border_color = pole_color
	badge_sb.set_border_width_all(2)
	badge_sb.set_corner_radius_all(0)
	badge_sb.set_content_margin_all(2)
	_pole_badge.add_theme_stylebox_override("panel", badge_sb)
	# Glyph label inside badge.
	var glyph_lbl := Label.new()
	glyph_lbl.text = pole_glyph
	glyph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph_lbl.add_theme_font_size_override("font_size", 18)
	glyph_lbl.add_theme_color_override("font_color", pole_color)
	glyph_lbl.add_theme_color_override("font_outline_color", MerlinVisual.UI_BLACK)
	glyph_lbl.add_theme_constant_override("outline_size", 2)
	_pole_badge.add_child(glyph_lbl)
	# Pole name tooltip for accessibility.
	_pole_badge.tooltip_text = "Pole : %s" % str(data.get("name", ""))
	# Z-order : badge sits above stylebox + flash overlay reference is below.
	add_child(_pole_badge)
	if _flash_overlay != null and is_instance_valid(_flash_overlay):
		move_child(_flash_overlay, -1)   # ensure flash stays on top of badge


## Start an idle pulse animation if the card metadata calls for one :
##   - Rarity.LEGENDAIRE : border breathing 0.85↔1.0 alpha
##   - CardType.EVENT    : border breathing (faster cadence)
##   - CardType.MERLIN_DIRECT : crimson glow pulse
##   - CardType.RUNE_UNLOCK : color hue cycle (border_color shifts)
func _arm_idle_pulse_if_needed() -> void:
	if _idle_pulse_tween != null and _idle_pulse_tween.is_valid():
		_idle_pulse_tween.kill()
		_idle_pulse_tween = null
	if _stylebox_normal == null:
		return
	# Decision : pick one effect (rarity LEGENDAIRE wins over EVENT pulse).
	var effect: String = ""
	if _rarity == Rarity.LEGENDAIRE:
		effect = "legendary_breath"
	elif _card_type == CardType.EVENT:
		effect = "event_pulse"
	elif _card_type == CardType.MERLIN_DIRECT:
		effect = "merlin_pulse"
	elif _card_type == CardType.RUNE_UNLOCK:
		effect = "iridescent_cycle"
	if effect == "":
		return
	# Capture the base color for restoration each cycle.
	var base_color: Color = _stylebox_normal.border_color
	var t: Tween = create_tween().bind_node(self).set_loops()
	_idle_pulse_tween = t
	match effect:
		"legendary_breath", "event_pulse":
			# Breathe alpha 1.0 → 0.65 → 1.0 over 1.6s (event) or 2.4s (legendary).
			var period: float = 2.4 if effect == "legendary_breath" else 1.6
			var dim_color := Color(base_color.r, base_color.g, base_color.b, 0.65)
			t.tween_method(_set_border_color, base_color, dim_color, period * 0.5).set_trans(Tween.TRANS_SINE)
			t.tween_method(_set_border_color, dim_color, base_color, period * 0.5).set_trans(Tween.TRANS_SINE)
		"merlin_pulse":
			# Crimson glow : color → crimson lerp 0.30 → back, 1.0s cadence.
			var glow_color := base_color.lerp(MerlinVisual.UI_CRIMSON, 0.30)
			t.tween_method(_set_border_color, base_color, glow_color, 0.50).set_trans(Tween.TRANS_SINE)
			t.tween_method(_set_border_color, glow_color, base_color, 0.50).set_trans(Tween.TRANS_SINE)
		"iridescent_cycle":
			# Hue rotation : color cycles through gold → violet → cyan → gold (3.6s).
			var c1 := Color(1.00, 0.69, 0.20)   # bright gold
			var c2 := Color(0.62, 0.38, 1.00)   # violet
			var c3 := Color(0.35, 0.85, 1.00)   # cyan
			t.tween_method(_set_border_color, c1, c2, 1.2).set_trans(Tween.TRANS_SINE)
			t.tween_method(_set_border_color, c2, c3, 1.2).set_trans(Tween.TRANS_SINE)
			t.tween_method(_set_border_color, c3, c1, 1.2).set_trans(Tween.TRANS_SINE)


## Tween target — updates BOTH styleboxes (normal + hover) so a hover triggered
## mid-pulse doesn't snap to the stale pre-pulse color. Also updates separator.
func _set_border_color(c: Color) -> void:
	if _stylebox_normal != null:
		_stylebox_normal.border_color = c
	if _stylebox_hover != null:
		# Hover variant stays slightly brighter than the active pulse color.
		_stylebox_hover.border_color = c.lightened(0.20)
	if _separator != null and is_instance_valid(_separator):
		_separator.color = c


func _apply_setup(title: String, body: String, ogham_glyph: String, lock_message: String) -> void:
	# Clear any prior content (idempotent setup). Use free() not queue_free so
	# children are gone THIS frame — avoids one-frame theme/stylebox flicker.
	for child in get_children():
		child.free()

	# Charter-compliant StyleBoxFlat (gold border default, dark bg, sharp).
	_stylebox_normal = StyleBoxFlat.new()
	_stylebox_normal.bg_color = MerlinVisual.UI_BG_DARK
	_stylebox_normal.border_color = _accent if not _locked else Color(_accent.r * 0.45, _accent.g * 0.45, _accent.b * 0.45, 0.85)
	_stylebox_normal.set_border_width_all(MerlinVisual.UI_BORDER_NORMAL)
	_stylebox_normal.set_corner_radius_all(0)
	# v7.7.21b — content margin 20 → 22 for breathing room.
	_stylebox_normal.set_content_margin_all(22)
	add_theme_stylebox_override("panel", _stylebox_normal)

	# Pre-compute hover stylebox (brighter border + lighter bg + thicker border).
	_stylebox_hover = _stylebox_normal.duplicate() as StyleBoxFlat
	_stylebox_hover.bg_color = MerlinVisual.UI_BG_HOVER
	_stylebox_hover.border_color = MerlinVisual.UI_GOLD_BRIGHT
	_stylebox_hover.set_border_width_all(MerlinVisual.UI_BORDER_HOVER)

	# Inner VBoxContainer for content layout.
	# v7.7.21b — separation 10 → 12 for tighter typography hierarchy.
	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# Row 1 — Ogham glyph (optional). v7.7.21b — bumped 40 → 44px.
	if ogham_glyph != "":
		_glyph_label = Label.new()
		_glyph_label.name = "Glyph"
		_glyph_label.text = ogham_glyph
		_glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_glyph_label.add_theme_font_size_override("font_size", 44)
		_glyph_label.add_theme_color_override("font_color", _accent)
		_glyph_label.add_theme_color_override("font_outline_color", MerlinVisual.UI_BLACK)
		_glyph_label.add_theme_constant_override("outline_size", MerlinVisual.UI_OUTLINE_SIZE)
		if _locked:
			_glyph_label.modulate.a = 0.45
		vbox.add_child(_glyph_label)

	# Row 2 — Title. v7.7.21b — 26 → 28px (more dominant heading).
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = title
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 28)
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

	# Row 4 — Body. v7.7.21b — 16 → 17px (better readability).
	_body_label = Label.new()
	_body_label.name = "Body"
	_body_label.text = body if not _locked else lock_message
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.add_theme_font_size_override("font_size", 17)
	_body_label.add_theme_color_override("font_color", MerlinVisual.UI_WHITE)
	_body_label.add_theme_color_override("font_outline_color", MerlinVisual.UI_BLACK)
	_body_label.add_theme_constant_override("outline_size", MerlinVisual.UI_OUTLINE_SIZE)
	if _locked:
		_body_label.modulate.a = 0.65
	vbox.add_child(_body_label)

	# Row 5 — Hint footer. v7.7.21b — 12 → 13px.
	_hint_label = Label.new()
	_hint_label.name = "Hint"
	_hint_label.text = "▸ ENTRER" if not _locked else "✕ VERROUILLÉ"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_font_size_override("font_size", 13)
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

	# Tooltip when locked.
	if _locked:
		tooltip_text = lock_message if lock_message != "" else "Apprends encore."

	# Re-apply any metadata that was set before setup() (e.g. order-independent).
	if _rarity >= 0 or _pole != Pole.NEUTRE or _card_type != CardType.NARRATIVE:
		_apply_metadata()


## Cascade animate-in : fade alpha 0→1 + scale 0.92→1.0 (TRANS_BACK overshoot).
## v7.7.21b — duration bumped slightly for smoother cascade (0.45 → 0.50 alpha,
## 0.55 → 0.60 scale). Subtle but reduces the "snap" feel.
func animate_in(delay: float = 0.0) -> void:
	modulate.a = 0.0
	scale = Vector2(0.92, 0.92)
	var t := create_tween().bind_node(self)
	if delay > 0.0:
		t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.50).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "scale", Vector2.ONE, 0.60).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Player picked THIS card — pulse + crimson flash + emit signal.
func mark_chosen() -> void:
	_is_chosen = true
	# Stop idle pulse if running (so it doesn't fight with the click animation).
	if _idle_pulse_tween != null and _idle_pulse_tween.is_valid():
		_idle_pulse_tween.kill()
		_idle_pulse_tween = null
	# Scale pulse 1.0 → 1.08 → 1.0 sequential.
	var pulse := create_tween().bind_node(self)
	pulse.tween_property(self, "scale", Vector2(1.08, 1.08), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(self, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_SINE)
	# Flash overlay : crimson alpha 0 → 0.55 → 0 over 0.45s.
	if _flash_overlay != null and is_instance_valid(_flash_overlay):
		var flash := create_tween().bind_node(self)
		flash.tween_property(_flash_overlay, "color:a", 0.55, 0.10)
		flash.tween_property(_flash_overlay, "color:a", 0.0, 0.35)
	# Border bumps to UI_GOLD_BRIGHT permanently to signal "locked-in" choice.
	# Preserves any rarity color by lightening it rather than overriding.
	if _stylebox_normal != null:
		_stylebox_normal.border_color = _stylebox_normal.border_color.lightened(0.30)
		_stylebox_normal.set_border_width_all(MerlinVisual.UI_BORDER_HOVER)


## Player picked a DIFFERENT card — this one fades out.
func dim_unselected() -> void:
	if _idle_pulse_tween != null and _idle_pulse_tween.is_valid():
		_idle_pulse_tween.kill()
		_idle_pulse_tween = null
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
	# v7.7.21b — hover scale 1.03 → 1.04 (slightly more responsive feel).
	var t := create_tween().bind_node(self)
	t.tween_property(self, "scale", Vector2(1.04, 1.04), 0.18).set_trans(Tween.TRANS_SINE)


func _on_mouse_exited() -> void:
	if _locked or _is_chosen:
		return
	_is_hovered = false
	if _stylebox_normal != null:
		add_theme_stylebox_override("panel", _stylebox_normal)
	var t := create_tween().bind_node(self)
	t.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)


func _on_gui_input(event: InputEvent) -> void:
	if _locked or _is_chosen:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			mark_chosen()
			selected.emit(_card_id)
