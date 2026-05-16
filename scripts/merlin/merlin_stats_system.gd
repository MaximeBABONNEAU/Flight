## ═══════════════════════════════════════════════════════════════════════════════
## MerlinStatsSystem — Disco-style 4-stat skill check system (v3.6 §25-§26)
## ═══════════════════════════════════════════════════════════════════════════════
## Autoload singleton managing the 4 player stats (Logic / Empathie / Volonté /
## Instinct) per bible v3.6 §25. XP-per-choice growth + white/red check formula.
##
## Persistence : profile JSON field `disco_stats` (cross-run, stats KEEP on death).
##
## API :
##   award_xp(stat_name, amount=1)            # +XP to one stat
##   get_stat_xp(stat_name) -> int            # raw XP
##   get_stat_level(stat_name) -> int         # 0..10 (floor xp/10)
##   get_pass_chance(stat_name) -> float      # 0.5..1.5 (pass_chance)
##   check_pass(stat_name, modifier=0.0)      # roll vs pass_chance
##   reset_to_baseline()                       # all stats = 0 XP
##   sync_from_profile(profile)                # load on profile load
##   write_to_profile(profile) -> Dictionary   # serialize for save
##
## Signals :
##   stat_changed(stat_name, new_xp, new_level)
##   level_up(stat_name, new_level)
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

signal stat_changed(stat_name: String, new_xp: int, new_level: int)
signal level_up(stat_name: String, new_level: int)

## v3.6 §25 — the 4 canonical stats.
const STATS: Array[String] = ["logic", "empathie", "volonte", "instinct"]

## v3.6 §26 — check formula constants.
const BASE_PASS_CHANCE: float = 0.50
const PER_LEVEL_BONUS: float = 0.10
const MAX_LEVEL: int = 10
const XP_PER_LEVEL: int = 10

## Per-stat display name (UI labels).
const STAT_LABELS := {
	"logic":    "Logic",
	"empathie": "Empathie",
	"volonte":  "Volonté",
	"instinct": "Instinct",
}

## Per-stat affine faction (bible §25.1 mapping).
const STAT_FACTIONS := {
	"logic":    "druides",
	"empathie": "niamh",
	"volonte":  "anciens",
	"instinct": "korrigans",
}

## Current XP state. Persisted via sync/write_to_profile.
var _xp: Dictionary = {
	"logic":    0,
	"empathie": 0,
	"volonte":  0,
	"instinct": 0,
}


# ═══════════════════════════════════════════════════════════════════════════════
# XP API
# ═══════════════════════════════════════════════════════════════════════════════

## Award XP to one stat. Emits stat_changed + level_up if level increased.
func award_xp(stat_name: String, amount: int = 1) -> void:
	if not _xp.has(stat_name):
		push_warning("[MerlinStats] unknown stat: %s" % stat_name)
		return
	if amount <= 0:
		return
	var old_level: int = get_stat_level(stat_name)
	_xp[stat_name] = int(_xp[stat_name]) + amount
	var new_level: int = get_stat_level(stat_name)
	stat_changed.emit(stat_name, int(_xp[stat_name]), new_level)
	if new_level > old_level:
		level_up.emit(stat_name, new_level)


func get_stat_xp(stat_name: String) -> int:
	return int(_xp.get(stat_name, 0))


## Stat level = floor(xp / 10), clamped 0..10 per bible v3.6 §25.2.
func get_stat_level(stat_name: String) -> int:
	var xp: int = get_stat_xp(stat_name)
	return clampi(xp / XP_PER_LEVEL, 0, MAX_LEVEL)


# ═══════════════════════════════════════════════════════════════════════════════
# Check API — bible v3.6 §26
# ═══════════════════════════════════════════════════════════════════════════════

## Pass chance formula : stat_level × 10% + 50%.
## Returns 0.5..1.5 (Lv 10 = 150% = auto-pass with criticality bonus).
func get_pass_chance(stat_name: String) -> float:
	var level: int = get_stat_level(stat_name)
	return BASE_PASS_CHANCE + (float(level) * PER_LEVEL_BONUS)


## Roll a check. Returns true on pass. Modifier added to chance (e.g. card +0.2).
func check_pass(stat_name: String, modifier: float = 0.0) -> bool:
	var chance: float = get_pass_chance(stat_name) + modifier
	return randf() < chance


# ═══════════════════════════════════════════════════════════════════════════════
# Profile persistence
# ═══════════════════════════════════════════════════════════════════════════════

## Load XP state from a profile dict. Reads `disco_stats` field if present;
## otherwise resets to baseline (first run with new system).
func sync_from_profile(profile: Dictionary) -> void:
	var ds = profile.get("disco_stats")
	if ds is Dictionary:
		for s in STATS:
			_xp[s] = int(ds.get(s + "_xp", 0))
		return
	# No prior data — baseline 0 XP everywhere.
	reset_to_baseline()


## Serialize current XP into the profile dict's `disco_stats` field.
func write_to_profile(profile: Dictionary) -> Dictionary:
	var ds: Dictionary = {}
	for s in STATS:
		ds[s + "_xp"] = int(_xp[s])
	profile["disco_stats"] = ds
	return profile


func reset_to_baseline() -> void:
	for s in STATS:
		_xp[s] = 0
		stat_changed.emit(s, 0, 0)


# ═══════════════════════════════════════════════════════════════════════════════
# Convenience accessors for UI / external callers
# ═══════════════════════════════════════════════════════════════════════════════

func get_all_levels() -> Dictionary:
	var out: Dictionary = {}
	for s in STATS:
		out[s] = get_stat_level(s)
	return out


func get_all_xp() -> Dictionary:
	var out: Dictionary = {}
	for s in STATS:
		out[s] = get_stat_xp(s)
	return out


## Returns the stat name with the highest level (build archetype detection).
## On ties, returns the first in STATS order.
func get_dominant_stat() -> String:
	var best_name: String = STATS[0]
	var best_level: int = get_stat_level(best_name)
	for s in STATS:
		var lvl: int = get_stat_level(s)
		if lvl > best_level:
			best_level = lvl
			best_name = s
	return best_name
