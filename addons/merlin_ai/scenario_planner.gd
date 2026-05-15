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

# Hardcoded fallback skeletons (Phase 1 stub — to be expanded in Phase 2 with
# 5 templates per biome × 8 biomes = 40 templates). Currently only Brocéliande.
const FALLBACK_SKELETONS: Dictionary = {
	"foret_broceliande": {
		"title": "La Voix de Brocéliande",
		"beats": [
			{"n": 1, "summary": "Tu pénètres la forêt — une présence te guette.", "faction_tilt": "neutre", "emotion": "curiosite"},
			{"n": 2, "summary": "Une rencontre te révèle un secret.", "faction_tilt": "druides", "emotion": "tension"},
			{"n": 3, "summary": "Un choix moral te divise.", "faction_tilt": "korrigans", "emotion": "peur"},
			{"n": 4, "summary": "L'épreuve se dresse devant toi.", "faction_tilt": "ankou", "emotion": "fascination"},
			{"n": 5, "summary": "La forêt te juge.", "faction_tilt": "niamh", "emotion": "sagesse"},
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
## Delegates to the v7.6 bi_brain_pipeline. Phase 2 will inject the full beat-context
## (faction_tilt + emotion + summary) directly into the bi-brain system prompts.
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
	return await _bi_brain.generate_card(biome_id, act_type, ogham_used)


static func _beat_to_act_type(beat_n: int) -> String:
	# v7.7 (code-review MEDIUM fix #3) : driven from BEAT_ACT_SEQUENCE const so
	# the 5-beat → act_type mapping is single-source-of-truth and visible at the
	# top of the file. To change the sequence, edit BEAT_ACT_SEQUENCE.
	var idx: int = beat_n - 1
	if idx < 0 or idx >= BEAT_ACT_SEQUENCE.size():
		return "standard"
	return str(BEAT_ACT_SEQUENCE[idx])


# ═════════ Phase 2 stubs : judge + replan (TODO) ══════════════════════════════

## Phase 2 (TODO) : LLM-judge brain decides if player choice diverged from
## the expected beat tilt. Returns true if a re-plan is needed.
func judge_divergence(_skeleton: Dictionary, _beat_idx: int,
		_last_card: Dictionary, _player_choice: Dictionary) -> bool:
	# Phase 1 placeholder : always returns false (no replan).
	# Phase 2 will call a 3rd brain (mini qwen3.5:2b) to score divergence.
	return false


## Phase 2 (TODO) : re-plan beats[from_beat..5] given current player state.
## Returns a new skeleton with refreshed remaining beats.
func replan_from_beat(skeleton: Dictionary, _from_beat: int,
		_player_state: Dictionary) -> Dictionary:
	# Phase 1 placeholder : returns the skeleton unchanged.
	return skeleton
