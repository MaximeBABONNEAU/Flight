## ═══════════════════════════════════════════════════════════════════════════════
## ScenarioPlanner — Front-loaded scenario generator (v7.7, 2026-05-15 part 21)
## ═══════════════════════════════════════════════════════════════════════════════
## Réf user AskUserQuestion 2026-05-15 part 21 :
##   - 3 titres + glyph ogham (minimal, mystérieux)
##   - Skeleton 5 beats avec faction_tilt + emotion arc
##   - Loading UX : Merlin live narration (Narrator stream en parallèle)
##   - Pre-fetch carte N+1 immédiat après render N (zero-latency in-game)
##   - LLM-judge brain pour divergence detection (Phase 2 stub ici)
##   - Adaptive : LLM ré-écrit beats restants si player diverge (Phase 2 stub ici)
##
## Cascade fallback 3-niveaux :
##   L1 : full LLM (titles → skeleton → JIT cards via BiBrainPipeline)
##   L2 : skeleton OK, cartes via FastRoute pool filtré par biome+beat-tag
##   L3 : skeleton hardcoded (FALLBACK_SKELETONS const ; 1 biome Phase 1, 8 Phase 2)
##
## API Phase 1 (foundation) :
##   var planner := ScenarioPlanner.new(merlin_ai, rag, fastroute_pool)
##   var titles: Array = await planner.generate_titles(biome_id)
##   var skeleton: Dictionary = await planner.generate_skeleton(biome_id, chosen_title)
##   var card: Dictionary = await planner.generate_card_for_beat(skeleton, beat_idx, player_state)
##   var diverged: bool = await planner.judge_divergence(...)  # Phase 2 stub returns false
##   var new_skeleton: Dictionary = await planner.replan_from_beat(...)  # Phase 2 stub returns unchanged
## ═══════════════════════════════════════════════════════════════════════════════

class_name ScenarioPlanner
extends RefCounted

const GBNF_SKELETON_PATH := "res://data/ai/scenario_skeleton.gbnf"
const TITLES_TIMEOUT_S := 8.0
const SKELETON_TIMEOUT_S := 15.0
const JUDGE_TIMEOUT_S := 4.0

# v7.7 Phase 2.6 — 8 fallback skeletons (1 per biome, baseline emotional arc).
# Each biome leans on its 1-2 dominant factions per the lore. Curiosité→sagesse
# arc preserves the classic 5-act tension. Used by L3 cascade fallback when both
# LLM (L1) and FastRoute pool (L2) are unavailable.
const FALLBACK_SKELETONS: Dictionary = {
	"foret_broceliande": {
		"title": "La Voix de Brocéliande",
		"beats": [
			{"n": 1, "summary": "Tu pénètres la forêt — une présence te guette.", "faction_tilt": "neutre", "emotion": "curiosite"},
			{"n": 2, "summary": "Une rencontre te révèle un secret du chêne.", "faction_tilt": "druides", "emotion": "tension"},
			{"n": 3, "summary": "Un choix moral te divise entre nature et soi.", "faction_tilt": "korrigans", "emotion": "peur"},
			{"n": 4, "summary": "L'épreuve du chêne ancien se dresse devant toi.", "faction_tilt": "ankou", "emotion": "fascination"},
			{"n": 5, "summary": "La forêt te juge — tu deviens ou tu disparais.", "faction_tilt": "niamh", "emotion": "sagesse"},
		],
	},
	"landes_bruyere": {
		"title": "Le Vent de Bruyère",
		"beats": [
			{"n": 1, "summary": "Le vent te porte vers un cairn battu par les bourrasques.", "faction_tilt": "neutre", "emotion": "curiosite"},
			{"n": 2, "summary": "Un voile d'Ankou rôde entre les pierres dressées.", "faction_tilt": "ankou", "emotion": "tension"},
			{"n": 3, "summary": "Une voix t'appelle hors du chemin tracé.", "faction_tilt": "anciens", "emotion": "melancolie"},
			{"n": 4, "summary": "La lande s'ouvre — un seul cairn t'attend.", "faction_tilt": "ankou", "emotion": "peur"},
			{"n": 5, "summary": "Tu choisis : te coucher avec les morts ou marcher.", "faction_tilt": "anciens", "emotion": "sagesse"},
		],
	},
	"cotes_sauvages": {
		"title": "L'Appel des Falaises",
		"beats": [
			{"n": 1, "summary": "Les vagues s'écrasent — un naufrage récent fume sur la grève.", "faction_tilt": "neutre", "emotion": "curiosite"},
			{"n": 2, "summary": "Une grotte béante chante des chants korrigans.", "faction_tilt": "korrigans", "emotion": "fascination"},
			{"n": 3, "summary": "La marée monte — un choix s'impose à toi.", "faction_tilt": "korrigans", "emotion": "tension"},
			{"n": 4, "summary": "Un dieu des profondeurs émerge du brouillard.", "faction_tilt": "ankou", "emotion": "peur"},
			{"n": 5, "summary": "Tu t'élances vers ou tu fuis l'horizon noir.", "faction_tilt": "niamh", "emotion": "espoir"},
		],
	},
	"villages_celtes": {
		"title": "Le Foyer des Anciens",
		"beats": [
			{"n": 1, "summary": "Tu approches d'un village où le feu danse haut.", "faction_tilt": "neutre", "emotion": "curiosite"},
			{"n": 2, "summary": "Un ancien te raconte une légende oubliée.", "faction_tilt": "anciens", "emotion": "emerveillement"},
			{"n": 3, "summary": "Un conflit éclate entre tribus — tu dois trancher.", "faction_tilt": "druides", "emotion": "tension"},
			{"n": 4, "summary": "La nuit tombe — l'épreuve du feu sacré arrive.", "faction_tilt": "druides", "emotion": "fascination"},
			{"n": 5, "summary": "L'aube te trouve allié ou banni.", "faction_tilt": "anciens", "emotion": "sagesse"},
		],
	},
	"cercles_pierres": {
		"title": "Le Chœur des Menhirs",
		"beats": [
			{"n": 1, "summary": "Un cercle de pierres vibre sous tes pas — équinoxe.", "faction_tilt": "neutre", "emotion": "emerveillement"},
			{"n": 2, "summary": "Les ogham gravés s'éveillent en lichen lumineux.", "faction_tilt": "druides", "emotion": "curiosite"},
			{"n": 3, "summary": "Un gardien minéral te défie de prouver ta voie.", "faction_tilt": "anciens", "emotion": "tension"},
			{"n": 4, "summary": "Le ciel ouvre une porte au-dessus du dolmen central.", "faction_tilt": "niamh", "emotion": "fascination"},
			{"n": 5, "summary": "Tu deviens initié ou tu disparais entre les pierres.", "faction_tilt": "druides", "emotion": "sagesse"},
		],
	},
	"marais_korrigans": {
		"title": "La Lumière qui Trompe",
		"beats": [
			{"n": 1, "summary": "La tourbière t'engloutit jusqu'à mi-jambe — une lueur vacille.", "faction_tilt": "neutre", "emotion": "tension"},
			{"n": 2, "summary": "Un will-o-wisp t'invite à le suivre dans les roseaux.", "faction_tilt": "korrigans", "emotion": "fascination"},
			{"n": 3, "summary": "Une voix d'enfant chante — mais sous l'eau.", "faction_tilt": "korrigans", "emotion": "peur"},
			{"n": 4, "summary": "La boue te révèle ce qu'elle a gardé.", "faction_tilt": "ankou", "emotion": "melancolie"},
			{"n": 5, "summary": "Tu sors illuminé ou tu rejoins la danse.", "faction_tilt": "korrigans", "emotion": "sagesse"},
		],
	},
	"collines_dolmens": {
		"title": "Sous le Souffle des Ancêtres",
		"beats": [
			{"n": 1, "summary": "Les collines verdoyantes s'étalent — un dolmen massif perce le ciel.", "faction_tilt": "neutre", "emotion": "curiosite"},
			{"n": 2, "summary": "Un mégalithe s'ouvre — l'écho d'un ancêtre te nomme.", "faction_tilt": "anciens", "emotion": "emerveillement"},
			{"n": 3, "summary": "Un rite tribal te demande de prouver ta lignée.", "faction_tilt": "anciens", "emotion": "tension"},
			{"n": 4, "summary": "Une vision te montre ce que tu pourrais devenir.", "faction_tilt": "druides", "emotion": "fascination"},
			{"n": 5, "summary": "Tu acceptes l'héritage ou tu t'en libères.", "faction_tilt": "anciens", "emotion": "sagesse"},
		],
	},
	"iles_mystiques": {
		"title": "Le Chant de Niamh",
		"beats": [
			{"n": 1, "summary": "Une brume éclatante t'enveloppe — l'île dérive au-dessus de l'eau.", "faction_tilt": "neutre", "emotion": "emerveillement"},
			{"n": 2, "summary": "Une fée te tend une fleur qui ne saurait flétrir.", "faction_tilt": "niamh", "emotion": "fascination"},
			{"n": 3, "summary": "Tu réalises que la brume avale les heures qui passent.", "faction_tilt": "niamh", "emotion": "tension"},
			{"n": 4, "summary": "Niamh elle-même t'offre l'éternité — à un prix.", "faction_tilt": "niamh", "emotion": "espoir"},
			{"n": 5, "summary": "Tu rentres mortel ou tu restes fée.", "faction_tilt": "niamh", "emotion": "sagesse"},
		],
	},
}

# 18 ogham glyphs — picked at random for the 3 titles displayed at run start.
const OGHAM_GLYPHS: Array = ["beith", "luis", "quert", "fearn", "saille", "nuin",
	"huath", "duir", "tinne", "coll", "muin", "gort", "ngetal", "straif", "ruis",
	"ailm", "ohn", "ur"]

# v7.7 (code-review MEDIUM fix #3) : 5-beat → act_type mapping as a single
# source-of-truth const, not buried in a match statement. Decision 2026-05-15
# part 21 : [standard, shop, standard, event, boss]. If the bible §1 evolves
# to change this sequence, this const is the single point of edit.
const BEAT_ACT_SEQUENCE: Array = ["standard", "shop", "standard", "event", "boss"]

# v7.7 (code-review MEDIUM fix #6) : max acceptable title length from LLM
# (defensive against LLM emitting a synopsis instead of a 3-7 word title).
const MAX_TITLE_LENGTH := 60

var _merlin_ai: Node
var _rag: Node
var _fastroute_pool: Array = []
var _bi_brain: BiBrainPipeline = null
var _gbnf_skeleton: String = ""


func _init(merlin_ai_ref: Node, rag_ref: Node = null, fastroute: Array = []) -> void:
	_merlin_ai = merlin_ai_ref
	_rag = rag_ref
	_fastroute_pool = fastroute
	_bi_brain = BiBrainPipeline.new(merlin_ai_ref, rag_ref)
	_load_gbnf()


func _load_gbnf() -> void:
	if not FileAccess.file_exists(GBNF_SKELETON_PATH):
		push_warning("[ScenarioPlanner] Skeleton GBNF missing : " + GBNF_SKELETON_PATH)
		return
	var f := FileAccess.open(GBNF_SKELETON_PATH, FileAccess.READ)
	if f:
		_gbnf_skeleton = f.get_as_text()
		f.close()


# ═════════ Phase 1.1 : Generate 3 titles + ogham glyphs ══════════════════════

func generate_titles(biome_id: String) -> Array:
	if _merlin_ai == null or not _merlin_ai.has_method("generate_with_system"):
		return _fallback_titles(biome_id)
	var system_prompt: String = (
		"Tu produis EXACTEMENT 3 titres mystérieux pour une aventure dans le biome %s.\n" +
		"Format STRICT : 1 ligne par titre, 3-7 mots chacun, francais, ton druidique.\n" +
		"Pas de numérotation, pas de synopsis, pas de tirets. Une ligne = un titre."
	) % biome_id
	var user_input: String = "Génère 3 titres pour ce biome."
	var params: Dictionary = {
		"max_tokens": 80,
		"temperature": 0.95,
		"timeout_ms": int(TITLES_TIMEOUT_S * 1000),
	}
	var result: Dictionary = await _merlin_ai.generate_with_system(system_prompt, user_input, params)
	if result.get("error", "") != "":
		push_warning("[ScenarioPlanner] Title LLM error : %s — falling back" % result.get("error"))
		return _fallback_titles(biome_id)
	var raw: String = str(result.get("text", result.get("output", ""))).strip_edges()
	return _parse_titles_with_oghams(raw, biome_id)


func _parse_titles_with_oghams(raw: String, biome_id: String) -> Array:
	var lines: Array = []
	for ln in raw.split("\n", false):
		var s: String = (ln as String).strip_edges()
		# Strip leading numbering/bullets defensively.
		if s.length() > 2 and (s[0].is_valid_int() or s[0] == "-" or s[0] == "*"):
			var i: int = 1
			while i < s.length() and (s[i] == "." or s[i] == ")" or s[i] == " "):
				i += 1
			s = s.substr(i).strip_edges()
		# v7.7 (code-review MEDIUM fix #6) : reject overlong lines that signal
		# the LLM emitted a synopsis instead of a title. Silently dropped lines
		# cascade to _fallback_titles via the size<3 check below.
		if s != "" and s.length() <= MAX_TITLE_LENGTH:
			lines.append(s)
	if lines.size() < 3:
		return _fallback_titles(biome_id)
	var ogham_pool: Array = OGHAM_GLYPHS.duplicate()
	ogham_pool.shuffle()
	var out: Array = []
	for i in range(3):
		out.append({"title": str(lines[i]), "ogham": str(ogham_pool[i])})
	return out


func _fallback_titles(biome_id: String) -> Array:
	# Level-3 cascade : 3 hardcoded titles per biome (8 × 3 = 24 templates).
	var bank: Dictionary = {
		"foret_broceliande": ["La Voix de Brocéliande", "Le Chêne Brisé", "L'Ombre des Korrigans"],
		"landes_bruyere": ["Le Cairn Oublié", "Sous le Vent d'Ankou", "La Bruyère qui Saigne"],
		"cotes_sauvages": ["L'Appel des Falaises", "Naufrage Ancien", "La Grotte Bleue"],
		"villages_celtes": ["Le Conteur du Foyer", "La Veille des Anciens", "Le Feu qui Dure"],
		"cercles_pierres": ["L'Équinoxe Oublié", "Les Pierres qui Parlent", "Le Cercle Brisé"],
		"marais_korrigans": ["Le Marais des Mensonges", "Voix dans la Tourbière", "La Lumière qui Trompe"],
		"collines_dolmens": ["Sous le Dolmen", "L'Écho des Ancêtres", "La Colline qui Respire"],
		"iles_mystiques": ["L'Île de Niamh", "La Brume Éternelle", "Le Chant des Fées"],
	}
	var titles: Array = bank.get(biome_id, bank["foret_broceliande"])
	var ogham_pool: Array = OGHAM_GLYPHS.duplicate()
	ogham_pool.shuffle()
	var out: Array = []
	for i in range(3):
		out.append({"title": str(titles[i]), "ogham": str(ogham_pool[i])})
	return out


# ═════════ Phase 1.2 : Generate 5-beat skeleton ═══════════════════════════════

func generate_skeleton(biome_id: String, chosen_title: String) -> Dictionary:
	if _merlin_ai == null or not _merlin_ai.has_method("generate_with_system"):
		return _fallback_skeleton(biome_id, chosen_title)
	var system_prompt: String = _skeleton_system_prompt(biome_id, chosen_title)
	var user_input: String = "Génère le skeleton du scénario pour le titre choisi."
	var params: Dictionary = {
		"grammar": _gbnf_skeleton,
		"max_tokens": 500,
		"temperature": 0.8,
		"timeout_ms": int(SKELETON_TIMEOUT_S * 1000),
	}
	var result: Dictionary = await _merlin_ai.generate_with_system(system_prompt, user_input, params)
	if result.get("error", "") != "":
		push_warning("[ScenarioPlanner] Skeleton LLM error : %s — falling back" % result.get("error"))
		return _fallback_skeleton(biome_id, chosen_title)
	var raw: String = str(result.get("text", result.get("output", "")))
	return _parse_skeleton(raw, biome_id, chosen_title)


func _skeleton_system_prompt(biome_id: String, chosen_title: String) -> String:
	return ("Tu es le Gamemaster M.E.R.L.I.N..\n" +
		"Génère un SKELETON narratif au format JSON strict (GBNF imposé) pour le titre :\n" +
		"  \"%s\" (biome : %s)\n\n" +
		"Structure : {title, beats:[5]}. Chaque beat = {n, summary, faction_tilt, emotion}.\n" +
		"Beats : 1=ouverture/curiosite, 2=développement/tension, 3=twist, 4=climax, 5=résolution.\n" +
		"faction_tilt ∈ {druides, anciens, korrigans, niamh, ankou, neutre}.\n" +
		"emotion ∈ {curiosite, tension, peur, espoir, sagesse, fascination, colere, melancolie, emerveillement}.\n" +
		"Summaries : 1 phrase 10-20 mots, narratif celtique évocateur."
	) % [chosen_title, biome_id]


func _parse_skeleton(raw_text: String, biome_id: String, chosen_title: String) -> Dictionary:
	var trimmed: String = raw_text.strip_edges()
	if trimmed.begins_with("```"):
		var first_nl: int = trimmed.find("\n")
		if first_nl >= 0:
			trimmed = trimmed.substr(first_nl + 1)
		if trimmed.ends_with("```"):
			trimmed = trimmed.substr(0, trimmed.length() - 3)
	var json := JSON.new()
	var err: Error = json.parse(trimmed)
	if err != OK:
		push_warning("[ScenarioPlanner] Skeleton JSON parse error : %s — falling back" % json.get_error_message())
		return _fallback_skeleton(biome_id, chosen_title)
	var parsed = json.data
	if not (parsed is Dictionary):
		return _fallback_skeleton(biome_id, chosen_title)
	var dict: Dictionary = parsed as Dictionary
	var beats = dict.get("beats", [])
	if not (beats is Array) or (beats as Array).size() != 5:
		return _fallback_skeleton(biome_id, chosen_title)
	# Override title to match user pick (in case LLM rewrote it).
	dict["title"] = chosen_title
	return dict


func _fallback_skeleton(biome_id: String, chosen_title: String) -> Dictionary:
	# v7.7 (code-review MEDIUM fix #4) : surface thematic mismatch when a biome
	# falls back to Brocéliande (Phase 2 will fill the 7 missing biomes).
	if not FALLBACK_SKELETONS.has(biome_id):
		push_warning("[ScenarioPlanner] No fallback skeleton for biome '%s' — using Brocéliande baseline. Phase 2 TODO." % biome_id)
	var base: Dictionary = FALLBACK_SKELETONS.get(biome_id, FALLBACK_SKELETONS["foret_broceliande"])
	var out: Dictionary = base.duplicate(true)
	out["title"] = chosen_title  # respect user choice
	return out


# ═════════ Phase 1.3 : Per-beat card generation (delegates to BiBrainPipeline) ═

## Generate the card for beat[beat_idx] using the skeleton context + player state.
## v7.7 Phase 2.3 : passes the full beat Dict (faction_tilt + emotion + summary)
## as beat_context to BiBrainPipeline → GM + Narrator system prompts inject it.
func generate_card_for_beat(skeleton: Dictionary, beat_idx: int, player_state: Dictionary) -> Dictionary:
	if _bi_brain == null:
		return {}
	var beats: Array = skeleton.get("beats", [])
	if beat_idx < 0 or beat_idx >= beats.size():
		return {}
	var beat: Dictionary = beats[beat_idx]
	var act_type: String = _beat_to_act_type(int(beat.get("n", beat_idx + 1)))
	var ogham_used: String = str(player_state.get("active_ogham", ""))
	var biome_id: String = str(player_state.get("biome", "foret_broceliande"))
	return await _bi_brain.generate_card(biome_id, act_type, ogham_used, beat)


static func _beat_to_act_type(beat_n: int) -> String:
	# v7.7 (code-review MEDIUM fix #3) : driven from BEAT_ACT_SEQUENCE const so
	# the 5-beat → act_type mapping is single-source-of-truth and visible at the
	# top of the file. To change the sequence, edit BEAT_ACT_SEQUENCE.
	var idx: int = beat_n - 1
	if idx < 0 or idx >= BEAT_ACT_SEQUENCE.size():
		return "standard"
	return str(BEAT_ACT_SEQUENCE[idx])


# ═════════ Phase 2 stubs : judge + replan (TODO) ══════════════════════════════

## v7.7 Phase 2.4 — LLM-judge primary + heuristic fallback.
## Hybrid : if MerlinAI available → mini LLM call (~1-2s, qwen3.5:2b via narrator path).
## Else → heuristic comparison of dominant faction in player_choice.effects vs beat.faction_tilt.
## Returns true if the player diverged from the expected arc (caller should replan).
##
## Conservative defaults : returns false on any error or ambiguous signal.
## "neutre" beats never count as diverged (any choice is on-arc).
func judge_divergence(skeleton: Dictionary, beat_idx: int,
		_last_card: Dictionary, player_choice: Dictionary) -> bool:
	var beats: Array = skeleton.get("beats", [])
	if not (beats is Array) or beat_idx < 0 or beat_idx >= beats.size():
		return false
	var beat: Dictionary = beats[beat_idx]
	var expected_tilt: String = str(beat.get("faction_tilt", "neutre"))
	# Neutral beats accept anything — no divergence possible.
	if expected_tilt == "neutre":
		return false

	# Step 1 : extract dominant faction signal from player's choice effects.
	var effects: Array = player_choice.get("effects", [])
	var actual_dominant: String = _extract_dominant_faction_from_effects(effects)
	# If no faction signal at all, heuristic = no divergence.
	if actual_dominant == "":
		return false

	# Step 2 : LLM-judge if available, heuristic otherwise.
	if _merlin_ai != null and _merlin_ai.has_method("generate_with_system"):
		return await _llm_judge_divergence(expected_tilt, actual_dominant,
			str(beat.get("emotion", "")), player_choice)
	# Heuristic fallback : direct comparison.
	return actual_dominant != expected_tilt


static func _extract_dominant_faction_from_effects(effects: Array) -> String:
	# Sum ADD_REPUTATION amounts per faction, return the faction the player
	# STRENGTHENED the most (max POSITIVE signed delta). Ignores HEAL/DAMAGE/ANAM.
	#
	# v7.7 code-review HIGH fix (commit 8dbbe1cc) : was `abs(int)` which incorrectly
	# returned the BURNED faction as "dominant" when the player penalized it.
	# Example pre-fix : card with [-10 druides, +5 ankou] → returned "druides"
	# (|-10|=10 > 5). Judge compared "druides" == expected_tilt="druides" → false
	# divergence. WRONG : the player actively chose against the druide arc.
	# Post-fix : returns "ankou" (the faction the player actually strengthened).
	# If no faction has a positive net delta, returns "" → judge defaults to no
	# divergence (conservative — the player only burned factions, no alignment signal).
	var deltas: Dictionary = {}
	for e in effects:
		if not (e is Dictionary):
			continue
		var ed: Dictionary = e as Dictionary
		if str(ed.get("type", "")) != "ADD_REPUTATION":
			continue
		var fac: String = str(ed.get("faction", ""))
		if fac == "":
			continue
		var amt: int = int(ed.get("amount", 0))
		deltas[fac] = int(deltas.get(fac, 0)) + amt
	if deltas.is_empty():
		return ""
	var best: String = ""
	var best_signed: int = 0  # only positive deltas qualify as "strengthened"
	for fac in deltas.keys():
		var v: int = int(deltas[fac])
		if v > best_signed:
			best_signed = v
			best = str(fac)
	return best


func _llm_judge_divergence(expected_tilt: String, actual_dominant: String,
		expected_emotion: String, player_choice: Dictionary) -> bool:
	var label: String = str(player_choice.get("label", "?"))
	var system_prompt: String = ("Tu juges si le choix du joueur a dévié de l'arc narratif attendu.\n" +
		"Beat attendu : faction_tilt=%s, emotion=%s\n" +
		"Joueur a fait : \"%s\" → faction dominante du choix=%s\n" +
		"Le joueur a-t-il DÉVIÉ ? Réponds UNIQUEMENT par OUI ou NON. Pas d'explication."
	) % [expected_tilt, expected_emotion, label, actual_dominant]
	var params: Dictionary = {
		"max_tokens": 8,
		"temperature": 0.1,  # déterministe pour décision binaire
		"timeout_ms": int(JUDGE_TIMEOUT_S * 1000),
	}
	var result: Dictionary = await _merlin_ai.generate_with_system(system_prompt, "Réponds.", params)
	if result.get("error", "") != "":
		# LLM fail → fallback heuristic.
		# Heuristic semantics (intentional) : ANY faction mismatch counts as
		# divergence. The 5 factions are independent axes (bible §13) — there
		# are no "family groups" of aligned factions, so cross-faction = divergent.
		return actual_dominant != expected_tilt
	var raw: String = str(result.get("text", result.get("output", ""))).strip_edges().to_lower()
	# Look for explicit OUI / YES tokens. Default to false (conservative).
	if raw.begins_with("oui") or raw.begins_with("yes"):
		return true
	if raw.begins_with("non") or raw.begins_with("no"):
		return false
	# Ambiguous response → fall back to heuristic.
	return actual_dominant != expected_tilt


## v7.7 Phase 2.5 — Re-plan beats[from_beat..4] given player divergence.
## Preserves beats[0..from_beat-1] (already played), regenerates the remainder
## via LLM with context = preserved beats + player_state (faction_rep + life).
## Falls back to the original skeleton on any failure (graceful).
##
## from_beat is 0-indexed in the `beats` array (NOT the 1-indexed `n` field).
func replan_from_beat(skeleton: Dictionary, from_beat: int,
		player_state: Dictionary) -> Dictionary:
	# Guard rails.
	var beats: Array = skeleton.get("beats", [])
	if not (beats is Array) or beats.size() != 5:
		return skeleton
	if from_beat <= 0 or from_beat >= beats.size():
		# from_beat==0 means "regenerate from start" → equivalent to a fresh skeleton.
		# from_beat>=5 means nothing to replan (last beat or beyond).
		return skeleton
	if _merlin_ai == null or not _merlin_ai.has_method("generate_with_system"):
		return skeleton

	# Build the divergence-aware system prompt.
	var preserved: Array = beats.slice(0, from_beat)
	var biome_id: String = str(player_state.get("biome", "foret_broceliande"))
	var chosen_title: String = str(skeleton.get("title", "L'Aventure"))
	var system_prompt: String = _replan_system_prompt(
		biome_id, chosen_title, preserved, player_state
	)
	var user_input: String = "Régénère le skeleton avec les nouveaux beats post-divergence."
	var params: Dictionary = {
		"grammar": _gbnf_skeleton,
		"max_tokens": 500,
		"temperature": 0.85,
		"timeout_ms": int(SKELETON_TIMEOUT_S * 1000),
	}
	var result: Dictionary = await _merlin_ai.generate_with_system(system_prompt, user_input, params)
	if result.get("error", "") != "":
		push_warning("[ScenarioPlanner] Replan LLM error : %s — keeping original skeleton" % result.get("error"))
		return skeleton
	var raw: String = str(result.get("text", result.get("output", "")))
	var fresh: Dictionary = _parse_skeleton(raw, biome_id, chosen_title)
	var fresh_beats: Array = fresh.get("beats", [])
	if not (fresh_beats is Array) or fresh_beats.size() != 5:
		return skeleton

	# Splice : preserve [0..from_beat-1] + take fresh [from_beat..4].
	var out_beats: Array = []
	for i in range(from_beat):
		out_beats.append(beats[i])
	for j in range(from_beat, 5):
		out_beats.append(fresh_beats[j])
	# Renumber n to stay 1..5 in case LLM emitted different n values.
	for k in range(out_beats.size()):
		(out_beats[k] as Dictionary)["n"] = k + 1

	var out: Dictionary = skeleton.duplicate(true)
	out["beats"] = out_beats
	return out


func _replan_system_prompt(biome_id: String, chosen_title: String,
		preserved_beats: Array, player_state: Dictionary) -> String:
	var faction_rep: Dictionary = player_state.get("faction_rep", {})
	var life: int = int(player_state.get("life_essence", 100))
	var rep_lines: Array = []
	for fac in ["druides", "anciens", "korrigans", "niamh", "ankou"]:
		var v: int = int(faction_rep.get(fac, 0))
		if v != 0:
			rep_lines.append("  - %s: %+d" % [fac, v])
	var preserved_summary: Array = []
	for b in preserved_beats:
		if b is Dictionary:
			preserved_summary.append("  - beat %d (%s) : %s" % [
				int(b.get("n", 0)), str(b.get("faction_tilt", "?")), str(b.get("summary", ""))
			])
	return ("Tu es le Gamemaster M.E.R.L.I.N.. Le joueur a DIVERGÉ de l'arc initial.\n" +
		"Tu régénères le skeleton complet (5 beats) en PRÉSERVANT les beats déjà vécus.\n" +
		"Format JSON strict imposé par GBNF.\n\n" +
		"Titre : \"%s\" (biome : %s)\n" +
		"Vie joueur actuelle : %d/100\n" +
		"Réputations factions :\n%s\n\n" +
		"Beats déjà vécus (REPRENDS-LES TELS QUELS dans la sortie) :\n%s\n\n" +
		"Les beats restants doivent réagir à la trajectoire actuelle du joueur."
	) % [chosen_title, biome_id, life,
		"\n".join(rep_lines) if not rep_lines.is_empty() else "  (aucune)",
		"\n".join(preserved_summary)]
