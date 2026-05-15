## ═══════════════════════════════════════════════════════════════════════════════
## BiomePalettes — 8 sous-palettes adaptives par biome (v1.0, 2026-05-15)
## ═══════════════════════════════════════════════════════════════════════════════
## Source de vérité runtime des palettes définies dans GAME_DESIGN_BIBLE §22 v3.4.
## Réf user AskUserQuestion 2026-05-15 part 18 : "Palette adaptive par biome (8 sous-palettes)".
##
## Règle universelle (bible §22.1) :
##   - 6 slots par palette : 4 narratives + ACCENT_GOLD universel + OUTLINE_BLACK universel.
##   - Contraste min ΔV ≥ 0.15 HSV.
##   - Saturation 0.25-0.65 (clash parchemin LiveCard3D au-delà).
##
## API :
##   BiomePalettes.get_palette(biome_id: String) -> Dictionary
##   BiomePalettes.list_biome_ids() -> PackedStringArray
##   BiomePalettes.accent_gold() -> Color
##   BiomePalettes.outline_black() -> Color
##   BiomePalettes.validate_contrast(biome_id: String) -> bool
## ═══════════════════════════════════════════════════════════════════════════════

class_name BiomePalettes
extends Object

## Accent doré universel (runes, ogham glow, currency, Druides accents).
const ACCENT_GOLD := Color("#d4a868")

## Outline noir universel (signature bible §20).
const OUTLINE_BLACK := Color("#0a0500")


## Brocéliande (foret_broceliande) — warm mystic baseline.
const FORET_BROCELIANDE := {
	"trunk": Color("#3d2817"),
	"foliage": Color("#4a6644"),
	"mist": Color("#5e4a32"),
	"highlight": Color("#8a6a3a"),
	"accent": ACCENT_GOLD,
	"outline": OUTLINE_BLACK,
}


## Landes Bruyère (landes_bruyere) — vent, bruyère, cairns.
const LANDES_BRUYERE := {
	"heather": Color("#6b4a72"),
	"stone": Color("#7a7a72"),
	"sky": Color("#a8b0b8"),
	"shadow": Color("#3a3848"),
	"accent": ACCENT_GOLD,
	"outline": OUTLINE_BLACK,
}


## Côtes Sauvages (cotes_sauvages) — falaises, vagues, korrigans.
const COTES_SAUVAGES := {
	"cliff": Color("#a87848"),
	"sea": Color("#2c5060"),
	"foam": Color("#d8e0d8"),
	"storm": Color("#4a5258"),
	"accent": ACCENT_GOLD,
	"outline": OUTLINE_BLACK,
}


## Villages Celtes (villages_celtes) — feu, foyers, anciens.
const VILLAGES_CELTES := {
	"ember": Color("#cd6438"),
	"thatch": Color("#b89858"),
	"wattle": Color("#5a3c24"),
	"twilight": Color("#384858"),
	"accent": ACCENT_GOLD,
	"outline": OUTLINE_BLACK,
}


## Cercles de Pierres (cercles_pierres) — menhirs, runes, équinoxe.
const CERCLES_PIERRES := {
	"granite": Color("#6a6862"),
	"moss": Color("#586848"),
	"sky": Color("#586a82"),
	"deep": Color("#2a3038"),
	"accent": ACCENT_GOLD,
	"outline": OUTLINE_BLACK,
}


## Marais Korrigans (marais_korrigans) — brume, will-o-wisps, tourbière.
const MARAIS_KORRIGANS := {
	"bog": Color("#465840"),
	"wisp": Color("#c0d8a8"),
	"mire": Color("#3a2c1a"),
	"mist": Color("#86887a"),
	"accent": ACCENT_GOLD,
	"outline": OUTLINE_BLACK,
}


## Collines aux Dolmens (collines_dolmens) — collines vertes, ancêtres.
const COLLINES_DOLMENS := {
	"hill": Color("#5a7848"),
	"earth": Color("#7a5838"),
	"sky": Color("#a8b8c8"),
	"shadow": Color("#3a4030"),
	"accent": ACCENT_GOLD,
	"outline": OUTLINE_BLACK,
}


## Îles Mystiques (iles_mystiques) — Niamh, fées, autre-monde.
const ILES_MYSTIQUES := {
	"azure": Color("#5a8aa8"),
	"pearl": Color("#e8e0d0"),
	"violet": Color("#7a5a88"),
	"teal": Color("#3a6878"),
	"accent": ACCENT_GOLD,
	"outline": OUTLINE_BLACK,
}


## Mapping biome_id → palette dict.
static var _PALETTES: Dictionary = {
	"foret_broceliande": FORET_BROCELIANDE,
	"landes_bruyere": LANDES_BRUYERE,
	"cotes_sauvages": COTES_SAUVAGES,
	"villages_celtes": VILLAGES_CELTES,
	"cercles_pierres": CERCLES_PIERRES,
	"marais_korrigans": MARAIS_KORRIGANS,
	"collines_dolmens": COLLINES_DOLMENS,
	"iles_mystiques": ILES_MYSTIQUES,
}


## Retrieve the palette dict for a given biome.
## Returns FORET_BROCELIANDE as safe fallback if biome_id unknown.
static func get_palette(biome_id: String) -> Dictionary:
	return _PALETTES.get(biome_id, FORET_BROCELIANDE)


## Return ordered list of all 8 biome IDs.
static func list_biome_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for key in _PALETTES.keys():
		ids.append(str(key))
	return ids


## Universal accent gold (runes, ogham, currency).
static func accent_gold() -> Color:
	return ACCENT_GOLD


## Universal outline black (signature bible §20).
static func outline_black() -> Color:
	return OUTLINE_BLACK


## Validate that the 4 narrative slots of a palette satisfy ΔV ≥ 0.15 HSV contrast
## with all their neighbors. Returns true if palette is internally consistent.
static func validate_contrast(biome_id: String) -> bool:
	var p: Dictionary = get_palette(biome_id)
	var narrative_keys: Array = []
	for key in p.keys():
		if key != "accent" and key != "outline":
			narrative_keys.append(key)
	if narrative_keys.size() < 2:
		return false
	for i in narrative_keys.size():
		for j in range(i + 1, narrative_keys.size()):
			var ca: Color = p[narrative_keys[i]]
			var cb: Color = p[narrative_keys[j]]
			var dv: float = absf(ca.v - cb.v)
			if dv < 0.15:
				push_warning("[BiomePalettes] %s : DeltaV %.2f entre %s et %s < 0.15 (bible §22.1)" % [
					biome_id, dv, narrative_keys[i], narrative_keys[j]
				])
				return false
	return true
