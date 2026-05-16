# M.E.R.L.I.N. — UI/UX Charter (v7.7.18)

> Single source of truth for the game's visual identity. Every Button / Label /
> Panel / overlay in every scene MUST comply with this charter.

**User intent (verbatim)** : *« une charte complète digitale pour l'UI / UX qui
sera toujours similaire dans le jeu et cross scene ... quelque chose de digital
/ pc retro mais très lisible et IAesque »*

---

## 0. Intraitable spec (v7.7.20 — single source of truth)

**User mandate** : *« bordure gold, texte en blanc entouré de noir sur fond légèrement assombri pour facilité la lecture »*

Every Button / Panel positioned anywhere uses **exactly** this spec :

| Token | Value | Role |
|---|---|---|
| `UI_GOLD` | `Color(0.92, 0.75, 0.30)` | bordure gold |
| `UI_GOLD_BRIGHT` | `Color(1.00, 0.85, 0.40)` | hover border |
| `UI_WHITE` | `Color(0.97, 0.97, 0.94)` | texte en blanc |
| `UI_BLACK` | `Color(0.02, 0.02, 0.02)` | outline noir + dark bg base |
| `UI_BG_DARK` | `Color(0.05, 0.04, 0.03, 0.92)` | fond légèrement assombri |
| `UI_BG_HOVER` | `Color(0.10, 0.08, 0.05, 0.95)` | hover bg |
| `UI_CRIMSON` | `Color(0.78, 0.16, 0.18)` | danger + pressed flash |
| `UI_OUTLINE_SIZE` | `3` | black text outline thickness |
| `UI_BORDER_NORMAL` | `4` | gold border |
| `UI_BORDER_HOVER` | `6` | hover bumps border |

Constants exposed at `scripts/autoload/merlin_visual.gd:711-720`.

**ALL kinds (primary/secondary/danger) share white text + black outline + dark bg.** Only the border color varies (gold / gold-dim / crimson). No other variation allowed.

Inspirations : Dredge gothic gold + Disco Elysium gold borders + Inscryption digital terminal + Mörk Borg high-contrast.

**THE FACTORY IS THE LAW.** Never style buttons inline — always `MerlinVisual.digital_button(text, kind)`.

---

## 1. Aesthetic directive

**Digital / PC retro / AI — very readable.**

Inspirations :
- VT220 amber terminals (phosphor glow, monochrome)
- Persona 5 (sharp edges, bold typography, NO rounded corners)
- Inscryption (monospace, gold-on-black, occult-tech)
- Outer Wilds Nomai inscriptions (gold ink, dark substrate)
- M.E.R.L.I.N. signature : Ogham runes + AI/LLM presence

**Forbidden** : magazine-editorial Persona slashes (dropped v7.7.17), gradients,
drop shadows >2px, rounded corners (radius > 0), neon glow, hand-drawn brush.

---

## 2. Palette (verbatim from `scripts/autoload/merlin_visual.gd` CRT_PALETTE)

### Structural (backgrounds)
| Token | Value | Usage |
|---|---|---|
| `bg_dark` | `Color(0.04, 0.04, 0.04)` | Primary scene background |
| `bg_panel` | `Color(0.08, 0.06, 0.05)` | Panel / button bg |
| `bg_deep` | `Color(0.10, 0.08, 0.06)` | Deeper container bg |
| `bg_highlight` | `Color(0.16, 0.12, 0.08)` | Hover / active state |

### Phosphor (primary accent — gold)
| Token | Value | Usage |
|---|---|---|
| `phosphor` | `Color(0.90, 0.75, 0.30)` | Primary text / borders / data |
| `phosphor_dim` | `Color(0.55, 0.45, 0.18)` | Secondary text / disabled |
| `phosphor_bright` | `Color(1.00, 0.85, 0.40)` | Hover / emphasis |

### Secondary accents
| Token | Value | Usage |
|---|---|---|
| `amber` | `Color(0.85, 0.65, 0.30)` | Tertiary accent / glow |
| `crimson` | `Color(0.80, 0.20, 0.15)` | Warning / danger / urgent CTAs |
| `gold` | `Color(0.78, 0.62, 0.20)` | Currency / Ogham / mystic |

### Text
| Token | Value | Usage |
|---|---|---|
| `ink` | `Color(0.02, 0.02, 0.02)` | Text on light bg (parchments) |
| `cream` | `Color(0.96, 0.92, 0.78)` | Text on dark bg (default) |

**Per-biome overrides** : `BiomePalettes.get_palette(biome_id)` provides
biome-specific structural + accent colors (8 biomes). Use these for biome-tinted
UI elements (button bg, biome card border). The 6 palette keys are : 4 narrative
tones + `accent` (gold) + `outline` (black).

---

## 3. Typography

| Role | Size | Family | Weight | Case |
|---|---|---|---|---|
| **Title** | 130-52px | VT323 (monospace) | bold | UPPERCASE / Mixed |
| **Subtitle / header** | 28-30px | VT323 | bold | Mixed |
| **Body** | 22px | VT323 | regular | Sentence |
| **Button** | 17-36px | VT323 | bold | UPPERCASE |
| **Label** | 15-18px | VT323 | regular | Sentence |
| **Data readout** | 13-14px | VT323 monospace | regular | UPPERCASE / hex |
| **Hint** | 11-13px | VT323 | regular italic | Sentence |

**Outline (text shadow / contour)** :
- Title : `outline_size = 4` max (was 6-8 pre-v7.7.18 — those broke charter)
- Body / button : `outline_size = 2-3`
- Data readout : `outline_size = 2`
- Outline color : `Color(0, 0, 0, 0.9)` (deep ink) OR `bg_dark`

---

## 4. Component specs

### 4.1 Button — 3 states (normal / hover / pressed)

```gdscript
# Charter-compliant button (use MerlinVisual.digital_button(text) factory v7.7.18+).
var sb := StyleBoxFlat.new()
sb.bg_color = bg_dark                   # or bg_panel for secondary
sb.border_color = phosphor              # or biome accent for biome-tinted
sb.set_border_width_all(4)              # v7.7.18 standard (was 1-2 pre-v7.7.17)
sb.set_corner_radius_all(0)             # CHARTER LAW — never > 0
sb.set_content_margin_all(12)

var sb_hover := sb.duplicate()
sb_hover.bg_color = bg_highlight
sb_hover.border_color = phosphor_bright
sb_hover.set_border_width_all(6)        # +2 on hover

var sb_pressed := sb.duplicate()
sb_pressed.bg_color = crimson           # pressed = brief crimson flash
```

**Anti-patterns** :
- ❌ `corner_radius > 0` — broke v7.7.18 fix on SelectionSauvegarde
- ❌ `border_width < 4` on primary CTAs — too thin for charter
- ❌ Drop shadows > 2px offset
- ❌ Gradient backgrounds — use solid colors only

### 4.2 Panel / Container

Same `StyleBoxFlat` rules as buttons, but :
- `border_width_all = 2-3` (less aggressive than CTAs)
- `bg_color = bg_panel` typically
- `shadow_size = 0` (no soft shadows ; if needed, use a deeper-bg ColorRect behind)

### 4.3 Scanline overlay (CRT veil)

Apply globally to UI layers for "PC retro" feel :
- Source : `MerlinVisual.scanline_overlay_node()` factory (v7.7.18 — Phase 3)
- Structure : 60+ thin `ColorRect` lines, 1px tall, spaced 2-3px vertically
- Alpha : 0.07-0.10
- Color : `ink` or `bg_dark`
- Animated : modulate flicker 0.85↔1.0 over 1.4s loop

### 4.4 Glitch flash (transitions / RGB-split)

For state transitions, brief RGB-split bands :
- Two `ColorRect` full-width : `Color(0, 1, 1, 0.30)` cyan + `Color(1, 0.1, 0.2, 0.30)` red
- `offset_left/right` randomised ±12px for jitter
- Fade-out 0.12s after 0.06s hold
- Reusable factory : `MerlinVisual.glitch_flash_burst()` (v7.7.18+)

### 4.5 Data readout panel

For "AI terminal" presence (top corners, ambient) :
- Monospace 13-14px gold-on-black
- 3-5 rows : `KEY : VALUE`
- Cycles values every 1.5s for "live system" feel
- Right-aligned, top-right anchor
- Example (MenuTest v7.7.17) :
  ```
  SYS  : ONLINE
  RUNE : 9/9
  FATE : 0xDEADBEEF
  ```

### 4.6 Inverse-hull outline (3D meshes)

For ALL 3D assets (mandatory per bible §20.6) :
- Use `CelShadingManager.apply(mesh, opts)` static API
- `DEFAULT_OUTLINE_THICKNESS = 0.022` (post-multiplier)
- `OUTLINE_THICKNESS_MULTIPLIER = 1.4` global knob (v7.7.17 — tune for "contour noir complet")
- Outline color = `Color.BLACK`

### 4.7 DigitalPickerCard — Unified picker component (v7.7.21)

Single source of truth for "choose one of N narrative paths" interactions
(biome picker, scenario picker, future card-draw screens). Replaces the
inconsistent 3D parchment vs 2D button drift from v7.7.

**Script** : `scripts/ui/digital_picker_card.gd` (`class_name DigitalPickerCard`).

**Geometry (fixed, intraitable) :**
- Size : `320 × 400 px`
- Charter compliant : `border 4 → 6 hover`, `radius 0`, `bg = UI_BG_DARK`
- Per-card accent override : `accent_color` arg (defaults to `UI_GOLD`)

**Layout (top→bottom, padding=20px) :**
1. Ogham glyph 40px, accent color, black outline (optional ; "" to skip)
2. Title 26px white + black outline `UI_OUTLINE_SIZE`
3. Accent separator 2px line, full width
4. Body description 16px white + outline, autowrap (2-3 lines)
5. Hint footer 12px dim accent, right-aligned ("▸ ENTRER" or "✕ VERROUILLÉ")

**Interactions :**
- Hover : border 4→6 + bg lighten + scale 1.03 TRANS_BACK
- Click : `mark_chosen()` plays scale pulse 1.0→1.08→1.0 + crimson flash, then emits `selected(card_id)`
- Locked : `setup(locked=true)` → dimmed glyph/title/body, "✕ VERROUILLÉ" hint, clicks ignored
- Cascade reveal : `animate_in(delay)` staggers fade-in + scale punch

**Public API :**

```gdscript
signal selected(card_id: String)

func setup(card_id, title, body, ogham_glyph,
           accent_color := UI_GOLD, locked := false, lock_message := "") -> void
func animate_in(delay: float = 0.0) -> void
func mark_chosen() -> void
func dim_unselected() -> void
```

**How to use** (preload + set_script pattern — avoids class_name race) :

```gdscript
const DIGITAL_PICKER_CARD_SCRIPT := preload("res://scripts/ui/digital_picker_card.gd")

var card := PanelContainer.new()
card.set_script(DIGITAL_PICKER_CARD_SCRIPT)
parent_container.add_child(card)
card.call("setup", "biome_id", "Le Bois qui Murmure",
    "Les arbres murmurent\nles secrets des druides.", "ᚁ",
    BiomePalettes.get_palette("foret_broceliande")["accent"])
card.connect("selected", _on_biome_picked)
card.call("animate_in", 0.0)
```

**v7.7.21 deployments :**
- `scripts/scenario_loading.gd` — 3 cards in HBox (replaces 3D PlaneMesh parchments)
- `scripts/board_narration/board_narration.gd` — 8 cards in 4×2 grid (replaces 8 Button widgets)

---

## 5. Cross-scene consistency table

| Element | MenuTest | ScenarioLoading | BoardNarration | SelectionSauvegarde | MenuOptions |
|---|---|---|---|---|---|
| Bg color | `bg_dark` | `bg_dark` | `bg_dark` | `bg_dark` | `bg_dark` |
| Title size | 130px | 28px | 36px | 30px | 28px |
| Title outline | 4 (v7.7.18) | 4 (v7.7.18) | 4-9 | 4 | 4 |
| Button border | 4-6 | 4-6 | 4-6 | 4-6 (v7.7.18) | TBD |
| Button radius | 0 | 0 | 0 | 0 (v7.7.18) | TBD |
| Scanline overlay | ✅ v7.7.13 | ⚠ partial | ❌ to add | ❌ to add | ❌ to add |

---

## 6. How to USE the charter

**ALWAYS use the `MerlinVisual.digital_*` factories (v7.7.18+)** rather than
inline StyleBoxFlat. This guarantees charter compliance and centralises future
changes :

```gdscript
# DON'T (inline styling — easy to drift from charter)
var btn := Button.new()
var sb := StyleBoxFlat.new()
sb.bg_color = Color(0.04, 0.04, 0.04)
sb.set_border_width_all(2)              # charter mandates 4, drifted
sb.set_corner_radius_all(4)             # charter mandates 0, drifted
btn.add_theme_stylebox_override("normal", sb)

# DO (factory — automatic charter compliance)
var btn := MerlinVisual.digital_button("ENTRER", "primary")
```

**Per-biome overrides** : pass biome_id to the factory to get biome-tinted
button while keeping charter geometry (border/radius/margins identical).

```gdscript
var btn := MerlinVisual.digital_button("Forêt", "biome", {"biome_id": "foret_broceliande"})
# → bg_color = forest green palette, border = accent gold, radius=0, border_width=4
```

---

## 7. Migration history

| Version | Date | Change |
|---|---|---|
| v7.7.11 | 2026-05-16 | First Persona-celtique slashes (rotated -8°) |
| v7.7.13 | 2026-05-16 | Digital animations : typewriter, glitch, scanline |
| v7.7.15 | 2026-05-16 | Boot prelude + Merlin sound bar |
| v7.7.17 | 2026-05-16 | DA terminal/cyberpunk : drop slashes → data readout |
| **v7.7.18** | 2026-05-16 | **THIS CHARTER + 3 violations fixed + factories** |

---

## 8. Compliance audit (post v7.7.18)

Run `grep -rn "set_corner_radius_all" scripts/` and verify every match has `(0)`.

Run `grep -rn "outline_size" scripts/` and verify every value is `<= 4`.

Run `grep -rn "set_border_width_all" scripts/` and verify primary CTAs are `>= 4`.

No new Button / Panel should be styled inline — use `MerlinVisual.digital_*`.
