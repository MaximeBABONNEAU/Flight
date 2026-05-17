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
	print("[ScenariosRAG] Loaded %d scenarios, %d embeddings (%d-dim, status=%s)" % [
		_scenarios.size(), _embeddings.size(), _embedding_dim, _embedding_status
	])


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
