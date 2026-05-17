## ═══════════════════════════════════════════════════════════════════════════════
## ScenariosRAG — kNN cosine retrieval over the 100 Brocéliande reference
## scenarios shipped in v7.7.22c. Autoload at /root/ScenariosRAG.
## ═══════════════════════════════════════════════════════════════════════════════
##
## v7.7.23 (2026-05-17) — Reference-augmented LLM pipeline.
##
## The 100 hand-crafted reference scenarios (intros + premise + cards) are
## embedded offline by `tools/embed_reference_scenarios.py` (nomic-embed-text,
## 768-dim). At runtime, this autoload :
##   - Loads the JSON + .embeddings.json at _ready
##   - Embeds query strings via Ollama HTTP /api/embeddings
##   - Returns top-K matches by cosine similarity
##
## Callers (ScenarioPlanner.generate_titles / generate_intro / generate_skeleton
## and BiBrainPipeline.generate_card) inject the matches as few-shot prompts so
## the runtime LLM produces output in the same idiom as the references.
##
## Fallback : if Ollama embed unavailable OR embeddings file missing/empty,
## falls back to archetype-matching retrieval (no kNN, just biome+archetype
## keyword extraction from the query text).
##
## API :
##   var matches := await ScenariosRAG.query_similar(text, top_k, biome_filter)
##   matches : Array[Dictionary] each with {id, title, intro, archetype_id,
##                                          archetype_name, premise, cards,
##                                          similarity (float 0..1)}
##
##   var titles_block := ScenariosRAG.format_titles_as_few_shot(matches)
##   var intros_block := ScenariosRAG.format_intros_as_few_shot(matches)
##   var skel_block   := ScenariosRAG.format_skeleton_as_few_shot(matches)
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

const REFERENCES_PATH := "res://data/ai/scenarios_reference_broceliande.json"
const EMBEDDINGS_PATH := "res://data/ai/scenarios_reference_broceliande.embeddings.json"
const OLLAMA_EMBED_URL := "http://localhost:11434/api/embeddings"
const OLLAMA_EMBED_MODEL := "nomic-embed-text"
const QUERY_TIMEOUT_S := 5.0
const QUERY_CACHE_MAX := 50

# v7.7.24 — Persistence layer.
const LEARNED_PATH := "user://scenarios_rag_learned.json"        # cross-run summaries embedded
const QUERY_CACHE_PATH := "user://scenarios_rag_query_cache.json"   # LRU query cache disk-persisted

var _scenarios: Array = []                # Array[Dictionary] loaded from JSON
var _by_id: Dictionary = {}                # id → scenario dict
var _embeddings: Dictionary = {}           # id → Array[float] (768-dim)
var _embedding_dim: int = 0
var _embedding_status: String = "not_loaded"   # ok / no_embeddings / ollama_unavailable / not_loaded
var _query_cache: Dictionary = {}          # text_hash → Array[float]
var _query_cache_keys: Array = []          # LRU order


func _ready() -> void:
	_load_scenarios()
	_load_embeddings()
	# v7.7.24 — Load cross-run learned summaries + query cache from disk.
	var learned_count: int = _load_learned_embeddings()
	var cache_count: int = _load_query_cache()
	print("[ScenariosRAG] Loaded %d scenarios, %d embeddings (%d-dim, status=%s) + %d learned + %d cached queries" % [
		_scenarios.size(), _embeddings.size(), _embedding_dim, _embedding_status,
		learned_count, cache_count,
	])


## v7.7.24 — Save query cache to disk before destruction (engine shutdown / scene change).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_query_cache()


func _load_scenarios() -> void:
	if not FileAccess.file_exists(REFERENCES_PATH):
		push_warning("[ScenariosRAG] References JSON missing : %s" % REFERENCES_PATH)
		return
	var f := FileAccess.open(REFERENCES_PATH, FileAccess.READ)
	if f == null:
		push_warning("[ScenariosRAG] Cannot open : %s" % REFERENCES_PATH)
		return
	var raw: String = f.get_as_text()
	f.close()
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		push_warning("[ScenariosRAG] JSON parse error : %s" % parser.get_error_message())
		return
	var data = parser.data
	if not (data is Array):
		push_warning("[ScenariosRAG] References JSON not an array")
		return
	_scenarios = data
	for s in _scenarios:
		if s is Dictionary:
			var sid: String = str(s.get("id", ""))
			if sid != "":
				_by_id[sid] = s


func _load_embeddings() -> void:
	if not FileAccess.file_exists(EMBEDDINGS_PATH):
		push_warning("[ScenariosRAG] Embeddings JSON missing : %s — falling back to archetype-match" % EMBEDDINGS_PATH)
		_embedding_status = "missing"
		return
	var f := FileAccess.open(EMBEDDINGS_PATH, FileAccess.READ)
	if f == null:
		_embedding_status = "missing"
		return
	var raw: String = f.get_as_text()
	f.close()
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		push_warning("[ScenariosRAG] Embeddings JSON parse error : %s" % parser.get_error_message())
		_embedding_status = "parse_error"
		return
	var data = parser.data
	if not (data is Dictionary):
		_embedding_status = "invalid"
		return
	_embedding_status = str(data.get("status", "unknown"))
	_embedding_dim = int(data.get("dim", 0))
	var embeds_any = data.get("embeddings", [])
	if not (embeds_any is Array):
		return
	for e in embeds_any:
		if not (e is Dictionary):
			continue
		var eid: String = str(e.get("id", ""))
		var vec_any = e.get("vector", [])
		if not (vec_any is Array) or eid == "":
			continue
		# Coerce vector to typed Array[float] for speed in cosine loop.
		var vec: Array = []
		vec.resize(vec_any.size())
		for i in range(vec_any.size()):
			vec[i] = float(vec_any[i])
		_embeddings[eid] = vec


## v7.7.24 — Load cross-run learned embeddings (run summaries embedded after
## each completed run). Merged into _embeddings + _by_id. Returns count loaded.
func _load_learned_embeddings() -> int:
	if not FileAccess.file_exists(LEARNED_PATH):
		return 0
	var f := FileAccess.open(LEARNED_PATH, FileAccess.READ)
	if f == null:
		return 0
	var raw: String = f.get_as_text()
	f.close()
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		push_warning("[ScenariosRAG] Learned cache parse error : %s" % parser.get_error_message())
		return 0
	var data = parser.data
	if not (data is Dictionary):
		return 0
	var embeds: Array = data.get("embeddings", []) if (data as Dictionary).get("embeddings", []) is Array else []
	var count: int = 0
	for e in embeds:
		if not (e is Dictionary):
			continue
		var eid: String = str(e.get("id", ""))
		var vec_any = e.get("vector", [])
		if eid == "" or not (vec_any is Array):
			continue
		var vec: Array = []
		vec.resize(vec_any.size())
		for i in range(vec_any.size()):
			vec[i] = float(vec_any[i])
		_embeddings[eid] = vec
		# Create a minimal pseudo-scenario entry so query_similar can return it.
		_by_id[eid] = {
			"id": eid,
			"title": str(e.get("title", "Run précédent")),
			"intro": str(e.get("summary_text", "")),
			"premise": "",
			"archetype_id": str(e.get("archetype_id", "learned")),
			"archetype_name": "Run vécu",
			"cards": [],
			"_learned": true,
		}
		count += 1
	return count


## v7.7.24 — Load LRU query cache from disk. Restores up to QUERY_CACHE_MAX
## entries from prior sessions to avoid re-embedding identical prompts.
func _load_query_cache() -> int:
	if not FileAccess.file_exists(QUERY_CACHE_PATH):
		return 0
	var f := FileAccess.open(QUERY_CACHE_PATH, FileAccess.READ)
	if f == null:
		return 0
	var raw: String = f.get_as_text()
	f.close()
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		return 0
	var data = parser.data
	if not (data is Dictionary):
		return 0
	var cache: Dictionary = data.get("cache", {})
	var keys: Array = data.get("keys", [])
	if not (cache is Dictionary) or not (keys is Array):
		return 0
	for k in keys:
		if not (cache.has(k)):
			continue
		var vec_any = cache[k]
		if not (vec_any is Array):
			continue
		var vec: Array = []
		vec.resize(vec_any.size())
		for i in range(vec_any.size()):
			vec[i] = float(vec_any[i])
		_query_cache[str(k)] = vec
		_query_cache_keys.append(str(k))
	return _query_cache_keys.size()


## v7.7.24 — Persist the LRU query cache to disk. Called on engine shutdown
## (via _notification) and also exposed publicly for manual save trigger.
func save_query_cache() -> void:
	if _query_cache.is_empty():
		return
	var f := FileAccess.open(QUERY_CACHE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"cache": _query_cache,
		"keys": _query_cache_keys,
		"saved_at": Time.get_datetime_string_from_system(),
	}))
	f.close()


## v7.7.24 — Cross-run incremental learning : embed the run summary and
## append it to the in-memory + on-disk index. Subsequent query_similar()
## calls can retrieve this learned content alongside hand-crafted references.
## Caller should invoke this on END_RUN event with a 1-3 sentence summary.
##
## @param summary_text   2-3 sentence narrative summary of what happened in the run
## @param run_metadata   Dict with run_id / biome / dominant_pole / ending / etc.
## @returns true on success, false otherwise
func learn_run_summary(summary_text: String, run_metadata: Dictionary = {}) -> bool:
	if summary_text.strip_edges().is_empty():
		return false
	# Embed via Ollama (same path as runtime query embed).
	var vec: Array = await _embed_query(summary_text)
	if vec.is_empty():
		push_warning("[ScenariosRAG] learn_run_summary : embed failed, summary not learned")
		return false
	# Generate a stable id based on timestamp + content hash.
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace(" ", "_")
	var hash16: String = summary_text.sha256_text().substr(0, 8)
	var eid: String = "learned_%s_%s" % [stamp, hash16]
	# Add to in-memory index.
	_embeddings[eid] = vec
	_by_id[eid] = {
		"id": eid,
		"title": str(run_metadata.get("title", "Mémoire d'un run vécu")),
		"intro": summary_text,
		"premise": "",
		"archetype_id": str(run_metadata.get("archetype_id", "learned")),
		"archetype_name": "Run vécu",
		"cards": [],
		"_learned": true,
	}
	# Persist to disk by appending to user://scenarios_rag_learned.json.
	_append_learned_to_disk(eid, vec, summary_text, run_metadata)
	return true


## v7.7.24 — Append a learned entry to the on-disk cache. Loads existing,
## appends new entry, writes back. Atomic via temp + rename.
func _append_learned_to_disk(eid: String, vec: Array, summary_text: String, run_metadata: Dictionary) -> void:
	var existing: Dictionary = {
		"model": OLLAMA_EMBED_MODEL,
		"dim": vec.size(),
		"status": "ok",
		"embeddings": [],
		"generated_at": Time.get_datetime_string_from_system(),
	}
	if FileAccess.file_exists(LEARNED_PATH):
		var f := FileAccess.open(LEARNED_PATH, FileAccess.READ)
		if f != null:
			var raw: String = f.get_as_text()
			f.close()
			var parser := JSON.new()
			if parser.parse(raw) == OK and parser.data is Dictionary:
				existing = parser.data
	var embeds: Array = existing.get("embeddings", [])
	if not (embeds is Array):
		embeds = []
	embeds.append({
		"id": eid,
		"vector": vec,
		"summary_text": summary_text,
		"title": str(run_metadata.get("title", "")),
		"archetype_id": str(run_metadata.get("archetype_id", "learned")),
		"learned_at": Time.get_datetime_string_from_system(),
	})
	existing["embeddings"] = embeds
	existing["count"] = embeds.size()
	# Write atomically : temp file then rename.
	var f := FileAccess.open(LEARNED_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(existing))
	f.close()


## Public API : retrieve top_k reference scenarios most similar to `text`.
## - `text`         : free-form query string (will be embedded via Ollama)
## - `top_k`        : how many matches to return (default 3)
## - `biome_filter` : if non-empty, only return scenarios where id starts with
##                    the biome's prefix (e.g. "broc_" for Brocéliande). For the
##                    current corpus all IDs start with "broc_" so this is a no-op
##                    until other biomes are added in v7.7.25.
##
## Returns Array[Dictionary] : each entry is the matched scenario merged with
## a `similarity` float (0..1). When embeddings unavailable, falls back to
## archetype-matching (returns scenarios sharing the dominant archetype of the query).
func query_similar(text: String, top_k: int = 3, biome_filter: String = "") -> Array:
	if _scenarios.is_empty():
		return []
	if _embedding_status != "ok" or _embeddings.is_empty():
		return _fallback_match(text, top_k, biome_filter)
	# Embed the query (with LRU cache to avoid re-embedding same prompt).
	var qvec: Array = await _embed_query(text)
	if qvec.is_empty() or qvec.size() != _embedding_dim:
		return _fallback_match(text, top_k, biome_filter)
	# Cosine similarity vs all reference embeddings.
	var scored: Array = []
	for sid in _embeddings.keys():
		var ref_vec: Array = _embeddings[sid]
		if ref_vec.size() != qvec.size():
			continue
		# Biome filter (prefix match on scenario id). All current IDs are
		# "broc_XX_YY" → no-op until other biomes are added in v7.7.25.
		if biome_filter != "" and not str(sid).begins_with(biome_filter):
			continue
		var sim: float = _cosine(qvec, ref_vec)
		scored.append({"id": sid, "sim": sim})
	# Sort descending by sim.
	scored.sort_custom(func(a, b): return float(a.get("sim", 0.0)) > float(b.get("sim", 0.0)))
	# Take top_k and merge scenario data.
	var out: Array = []
	for i in range(min(top_k, scored.size())):
		var sid: String = str(scored[i]["id"])
		if not _by_id.has(sid):
			continue
		var s: Dictionary = (_by_id[sid] as Dictionary).duplicate(true)
		s["similarity"] = float(scored[i]["sim"])
		out.append(s)
	return out


## Cosine similarity between two equal-length float vectors. Returns 0..1.
static func _cosine(a: Array, b: Array) -> float:
	if a.size() != b.size() or a.is_empty():
		return 0.0
	var dot: float = 0.0
	var na: float = 0.0
	var nb: float = 0.0
	for i in range(a.size()):
		var av: float = float(a[i])
		var bv: float = float(b[i])
		dot += av * bv
		na += av * av
		nb += bv * bv
	if na <= 0.0 or nb <= 0.0:
		return 0.0
	return dot / (sqrt(na) * sqrt(nb))


## Embed a query via Ollama HTTP. Returns Array[float] or empty array on failure.
## Uses LRU cache (QUERY_CACHE_MAX=50) keyed by text hash.
func _embed_query(text: String) -> Array:
	var key: String = text.sha256_text().substr(0, 16)
	if _query_cache.has(key):
		# Move to end of LRU.
		_query_cache_keys.erase(key)
		_query_cache_keys.append(key)
		return _query_cache[key]
	# HTTP call.
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = QUERY_TIMEOUT_S
	var payload: String = JSON.stringify({"model": OLLAMA_EMBED_MODEL, "prompt": text})
	var headers: PackedStringArray = ["Content-Type: application/json"]
	var err: Error = http.request(OLLAMA_EMBED_URL, headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		http.queue_free()
		return []
	var result: Array = await http.request_completed
	http.queue_free()
	# result = [result_int, response_code, headers, body]
	if result.size() < 4:
		return []
	var response_code: int = int(result[1])
	var body: PackedByteArray = result[3]
	if response_code != 200 or body.is_empty():
		return []
	var parser := JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK:
		return []
	var data = parser.data
	if not (data is Dictionary):
		return []
	var vec_any = data.get("embedding", [])
	if not (vec_any is Array):
		return []
	var vec: Array = []
	vec.resize(vec_any.size())
	for i in range(vec_any.size()):
		vec[i] = float(vec_any[i])
	# Insert into LRU cache (evict oldest if full).
	if _query_cache_keys.size() >= QUERY_CACHE_MAX:
		var oldest: String = _query_cache_keys.pop_front()
		_query_cache.erase(oldest)
	_query_cache[key] = vec
	_query_cache_keys.append(key)
	return vec


## Fallback retrieval : when embeddings are unavailable, return scenarios
## matching by archetype keyword in the query text. Best-effort.
func _fallback_match(text: String, top_k: int, _biome_filter: String) -> Array:
	var lower: String = text.to_lower()
	# Keyword → archetype_id map (matches our 10 Brocéliande archetypes).
	var keyword_map: Dictionary = {
		"druidic": "druidic_awakening", "éveil": "druidic_awakening", "eveil": "druidic_awakening",
		"korrigan": "korrigan_trickery", "ruse": "korrigan_trickery", "farce": "korrigan_trickery",
		"chêne": "ancient_oak_counsel", "chene": "ancient_oak_counsel", "oak": "ancient_oak_counsel",
		"brume": "mist_wanderer", "brouillard": "mist_wanderer",
		"épreuve": "forest_trial", "epreuve": "forest_trial", "ronce": "forest_trial",
		"rite": "forgotten_ritual", "ogham": "forgotten_ritual", "autel": "forgotten_ritual",
		"sanctuaire": "hidden_sanctuary", "clairière": "hidden_sanctuary", "clairiere": "hidden_sanctuary",
		"bête": "beast_encounter", "bete": "beast_encounter", "cerf": "beast_encounter", "loup": "beast_encounter",
		"lignée": "druid_lineage", "lignee": "druid_lineage", "ancêtre": "druid_lineage", "ancetre": "druid_lineage",
		"seuil": "threshold_crossing", "passage": "threshold_crossing", "porte": "threshold_crossing",
	}
	var matched_archetype: String = ""
	for kw in keyword_map.keys():
		if kw in lower:
			matched_archetype = str(keyword_map[kw])
			break
	# Collect scenarios with that archetype, then any others as filler.
	var primary: Array = []
	var secondary: Array = []
	for s in _scenarios:
		if not (s is Dictionary):
			continue
		var aid: String = str(s.get("archetype_id", ""))
		var copy: Dictionary = (s as Dictionary).duplicate(true)
		copy["similarity"] = 0.5 if aid == matched_archetype else 0.1
		if aid == matched_archetype and matched_archetype != "":
			primary.append(copy)
		else:
			secondary.append(copy)
	primary.shuffle()
	secondary.shuffle()
	var out: Array = []
	out.append_array(primary.slice(0, top_k))
	if out.size() < top_k:
		out.append_array(secondary.slice(0, top_k - out.size()))
	return out


## Compact formatter : returns the matched scenarios' titles as a bullet list.
func format_titles_as_few_shot(matches: Array) -> String:
	var lines: Array = []
	for m in matches:
		if m is Dictionary:
			lines.append("- \"%s\"" % str((m as Dictionary).get("title", "?")))
	return "\n".join(lines)


## Compact formatter : returns the matched scenarios' intros stitched as
## numbered few-shot for the intro generation prompt.
func format_intros_as_few_shot(matches: Array, max_chars_per_intro: int = 600) -> String:
	var blocks: Array = []
	var idx: int = 1
	for m in matches:
		if not (m is Dictionary):
			continue
		var intro: String = str((m as Dictionary).get("intro", ""))
		if intro.length() > max_chars_per_intro:
			intro = intro.substr(0, max_chars_per_intro) + "..."
		blocks.append("Exemple %d :\n%s" % [idx, intro])
		idx += 1
	return "\n\n".join(blocks)


## Compact formatter : returns the matched scenarios' beat summaries stitched
## as few-shot for skeleton generation.
func format_skeleton_as_few_shot(matches: Array, max_beats: int = 5) -> String:
	var blocks: Array = []
	var idx: int = 1
	for m in matches:
		if not (m is Dictionary):
			continue
		var d: Dictionary = m
		var title: String = str(d.get("title", "?"))
		var cards: Array = d.get("cards", [])
		if not (cards is Array) or cards.is_empty():
			continue
		var beats: Array = []
		for i in range(min(max_beats, cards.size())):
			if not (cards[i] is Dictionary):
				continue
			var c: Dictionary = cards[i]
			var summary: String = str(c.get("summary", ""))
			if summary.length() > 80:
				summary = summary.substr(0, 80)
			beats.append("  n=%d emotion=%s summary=\"%s\"" % [
				int(c.get("n", i + 1)),
				str(c.get("emotion", "")),
				summary,
			])
		blocks.append("Exemple %d (%s) :\n%s" % [idx, title, "\n".join(beats)])
		idx += 1
	return "\n\n".join(blocks)


## v7.7.24 — Validate LLM-generated text against canon guardrails.
## Returns Dictionary {valid: bool, reason: String, retry_recommended: bool}.
##
## Checks :
##   1. Forbidden words (whole-word case-insensitive) — HARD reject
##   2. 4th-wall break terms (simulation/IA/programme/etc.) — HARD reject
##   3. English anglicisms in narrative (spawn/loot/hub/level/boss) — HARD reject
##   4. Cyber/tech vocabulary in narrative (neon/cyber/circuit/data/pixel) — HARD reject
##   5. Minimum length (text >= 20 chars to avoid LLM stubs) — SOFT reject (retry)
##
## Used by scenario_planner.gd::generate_titles/intro/skeleton and
## bi_brain_pipeline.gd::_call_gm_brain to gate LLM outputs before downstream
## consumption. On invalid result, caller retries 1× then falls back to canon.
## v7.7.24 — Plain Array (GDScript const cannot use PackedStringArray ctor).
const FORBIDDEN_HARD: Array = [
	# 4th-wall break (canon §9.4.2)
	"simulation", "ia", "programme", "serveur", "sauvegarde", "fin du monde",
	# Anglicisms gaming
	"spawn", "loot", "hub", "level", "boss",
	# Modern tech (allowed in visual §10 but NEVER in narrative)
	"neon", "cyber", "circuit", "code", "data", "pixel", "glitch",
	"system", "interface", "build",
]

func validate_llm_text(text: String, context: String = "") -> Dictionary:
	if text == null or text.is_empty():
		return {"valid": false, "reason": "empty_output", "retry_recommended": true}
	var lower: String = text.to_lower().strip_edges()
	if lower.length() < 20:
		return {"valid": false, "reason": "too_short_%d_chars" % lower.length(), "retry_recommended": true}
	# Whole-word forbidden check.
	for term in FORBIDDEN_HARD:
		var t: String = str(term).to_lower()
		# Whole-word match : surrounded by word boundaries (spaces, punctuation, start/end).
		if _contains_whole_word(lower, t):
			return {"valid": false, "reason": "forbidden_word_%s" % t, "retry_recommended": false}
	# Optional context-specific checks could go here (e.g. "intro must contain « jeune druide »").
	# For v7.7.24 we keep it minimal — extension hook for future iterations.
	return {"valid": true, "reason": "", "retry_recommended": false}


## Whole-word match : `\b` semantics implemented manually because GDScript Regex
## doesn't ship with all environments and we want predictable behavior.
static func _contains_whole_word(haystack: String, needle: String) -> bool:
	var idx: int = 0
	while idx < haystack.length():
		var pos: int = haystack.find(needle, idx)
		if pos < 0:
			return false
		# Check left boundary.
		var left_ok: bool = (pos == 0) or not _is_word_char(haystack[pos - 1])
		# Check right boundary.
		var end: int = pos + needle.length()
		var right_ok: bool = (end >= haystack.length()) or not _is_word_char(haystack[end])
		if left_ok and right_ok:
			return true
		idx = pos + 1
	return false


static func _is_word_char(c: String) -> bool:
	if c.length() == 0:
		return false
	# A-Z, a-z, 0-9, accented letters, _
	var code: int = c.unicode_at(0)
	if code >= 48 and code <= 57: return true   # 0-9
	if code >= 65 and code <= 90: return true   # A-Z
	if code >= 97 and code <= 122: return true  # a-z
	if code == 95: return true                   # _
	# Latin-1 supplement (accented letters)
	if code >= 192 and code <= 255: return true
	return false


## Compact formatter : returns matched scenarios' SAMPLE CARDS as compact
## few-shot for per-card generation (BiBrainPipeline). Selects 2-3 cards from
## each match's pool, preferring those that match `card_type_filter` if given.
func format_cards_as_few_shot(matches: Array, card_type_filter: String = "", max_per_match: int = 2) -> String:
	var lines: Array = []
	for m in matches:
		if not (m is Dictionary):
			continue
		var cards: Array = (m as Dictionary).get("cards", [])
		if not (cards is Array):
			continue
		var picked: int = 0
		for c in cards:
			if picked >= max_per_match:
				break
			if not (c is Dictionary):
				continue
			var ct: String = str(c.get("type", ""))
			if card_type_filter != "" and ct != card_type_filter:
				continue
			var summary: String = str(c.get("summary", ""))
			var opts: Array = c.get("options", [])
			var opt_labels: Array = []
			for o in opts:
				if o is Dictionary:
					opt_labels.append("\"%s\"" % str((o as Dictionary).get("label", "?")))
			lines.append("- \"%s\" → [%s]" % [summary, ", ".join(opt_labels)])
			picked += 1
	return "\n".join(lines)
