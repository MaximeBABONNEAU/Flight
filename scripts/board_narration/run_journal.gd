## ═══════════════════════════════════════════════════════════════════════════════
## BoardRunJournal — Build + persist narrative journal entries from a completed run.
## ═══════════════════════════════════════════════════════════════════════════════
## A journal entry captures the cinematic replay metadata:
##   run_id        : string "run-<unix>-<9digits>"
##   biome         : biome key
##   ended_at      : ISO-8601 UTC string YYYY-MM-DDTHH:MM:SSZ
##   outcome       : "death" | "victory" | "abandon" | "hard_max" | ""
##   cards_played  : int
##   life_final    : int
##   cards         : Array of {card_id, ogham, option, faction_deltas}
##   narrations    : Array of {card_id, comment, source}
##   final_factions: Dictionary {druides, anciens, korrigans, niamh, ankou}
##
## Persisted to profile.meta.run_history[] (FIFO cap 30).
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name BoardRunJournal

const HISTORY_CAP := 30


## Build a journal entry dictionary from raw run data + narration accumulator.
static func build_entry(run_data: Dictionary, narrations: Array, outcome: String = "") -> Dictionary:
	var biome: String = str(run_data.get("current_biome", run_data.get("biome", "")))
	var cards_played: int = int(run_data.get("cards_played", 0))
	var life_final: int = int(run_data.get("life_essence", 0))

	# Pull story_log → cards summary
	var story_log: Array = run_data.get("story_log", [])
	var cards_summary: Array = []
	for raw in story_log:
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		cards_summary.append({
			"card_id": str(entry.get("card_id", "")),
			"ogham": str(entry.get("ogham_used", entry.get("ogham", ""))),
			"option": int(entry.get("option_index", entry.get("option", 0))),
			"faction_deltas": entry.get("faction_deltas", {}),
		})

	var final_factions: Dictionary = {}
	var run_factions: Dictionary = run_data.get("factions", {})
	for f in ["druides", "anciens", "korrigans", "niamh", "ankou"]:
		final_factions[f] = float(run_factions.get(f, 0.0))

	return {
		"run_id": _generate_run_id(),
		"biome": biome,
		"ended_at": _now_iso8601(),
		"outcome": outcome,
		"cards_played": cards_played,
		"life_final": life_final,
		"cards": cards_summary,
		"narrations": narrations.duplicate(true),
		"final_factions": final_factions,
	}


## Persist the entry to the active profile's meta.run_history (FIFO cap).
## Returns true on success.
static func save_to_profile(save_system: Object, entry: Dictionary) -> bool:
	if save_system == null:
		push_warning("[BoardRunJournal] No save_system provided — entry not persisted")
		return false
	if not save_system.has_method("load_profile") or not save_system.has_method("save_profile"):
		push_warning("[BoardRunJournal] save_system missing load_profile/save_profile")
		return false
	var meta: Dictionary = save_system.load_profile()
	if meta.is_empty():
		push_warning("[BoardRunJournal] Empty profile — cannot save journal")
		return false
	var history_raw = meta.get("run_history", [])
	var history: Array = history_raw if history_raw is Array else []
	history.append(entry)
	if history.size() > HISTORY_CAP:
		history = history.slice(history.size() - HISTORY_CAP)
	meta["run_history"] = history
	var ok: bool = save_system.save_profile(meta)
	if not ok:
		push_warning("[BoardRunJournal] save_profile returned false")
	return ok


static func _now_iso8601() -> String:
	var ts := Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		int(ts.get("year", 1970)),
		int(ts.get("month", 1)),
		int(ts.get("day", 1)),
		int(ts.get("hour", 0)),
		int(ts.get("minute", 0)),
		int(ts.get("second", 0)),
	]


static func _generate_run_id() -> String:
	var unix := int(Time.get_unix_time_from_system())
	var rand_str := str(randi() % 1_000_000_000).pad_zeros(9)
	return "run-%d-%s" % [unix, rand_str]


## Build a mock run_data dict for smoke-testing the scene without a real run.
static func build_mock_run_data() -> Dictionary:
	return {
		"current_biome": "foret_broceliande",
		"cards_played": 5,
		"life_essence": 0,
		"factions": {
			"druides": 42.0, "anciens": 18.0, "korrigans": 7.0,
			"niamh": 33.0, "ankou": 12.0,
		},
		"story_log": [
			{"card_id": "carte_eau_pure", "ogham_used": "beith", "option_index": 0, "faction_deltas": {"druides": 5.0}},
			{"card_id": "carte_pierre", "ogham_used": "luis", "option_index": 1, "faction_deltas": {"anciens": 3.0}},
			{"card_id": "carte_korrigan", "ogham_used": "", "option_index": 2, "faction_deltas": {"korrigans": -2.0}},
			{"card_id": "carte_chant", "ogham_used": "quert", "option_index": 0, "faction_deltas": {"niamh": 4.0}},
			{"card_id": "carte_passage", "ogham_used": "duir", "option_index": 1, "faction_deltas": {"druides": 2.0, "ankou": 1.0}},
		],
	}
