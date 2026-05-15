## ═══════════════════════════════════════════════════════════════════════════════
## BiBrainPipeline — GM + Narrator séquentiel pour génération de carte (v1.0, 2026-05-15)
## ═══════════════════════════════════════════════════════════════════════════════
## Source de vérité : docs/VISION_LLM_BI_CERVEAUX.html + bible §13.
## Réf user AskUserQuestion 2026-05-15 part 20 : bi-brain GM+Narrator + GBNF +
## Narrator from-scratch + RAG embeddings + cascade fallback.
##
## Pipeline séquentiel :
##   Phase A : GM brain (qwen3.5:2b, GBNF-constrained) → structured JSON shell
##   Phase B : Narrator brain (qwen3.5:4b + merlin-narrator LoRA) → rich prose
##             reçoit le shell GM + RAG context + génère le `text` from scratch
##   Phase C : Fusion shell + prose → carte finale Dictionary
##
## Fallback cascade :
##   GM fail (timeout / GBNF parse error) → caller pulls FastRoute card
##   Narrator fail (timeout) → return GM shell as-is (text = stub from GM)
##
## API :
##   var pipeline := BiBrainPipeline.new(merlin_ai_ref, rag_manager_ref)
##   var card: Dictionary = await pipeline.generate_card(biome_id, act_type, ogham_used)
##   if card.is_empty(): # caller falls back to FastRoute
## ═══════════════════════════════════════════════════════════════════════════════

class_name BiBrainPipeline
extends RefCounted

const GBNF_CARD_PATH := "res://data/ai/merlin_card.gbnf"
const GM_TIMEOUT_S := 8.0
const NARRATOR_TIMEOUT_S := 12.0

var _merlin_ai: Node  # MerlinAI autoload reference (loose-typed to avoid hard dep)
var _rag: Node        # RAGManager autoload reference
var _gbnf_text: String = ""


func _init(merlin_ai_ref: Node, rag_ref: Node = null) -> void:
	_merlin_ai = merlin_ai_ref
	_rag = rag_ref
	_load_gbnf()


func _load_gbnf() -> void:
	if not FileAccess.file_exists(GBNF_CARD_PATH):
		push_warning("[BiBrain] GBNF file missing : " + GBNF_CARD_PATH)
		return
	var f := FileAccess.open(GBNF_CARD_PATH, FileAccess.READ)
	if f:
		_gbnf_text = f.get_as_text()
		f.close()


## Generate a card via the bi-brain pipeline. Returns empty Dictionary on full failure.
func generate_card(biome_id: String, act_type: String, ogham_used: String = "") -> Dictionary:
	if _merlin_ai == null:
		return {}

	# Phase A : GM brain — structured JSON via GBNF.
	var gm_card: Dictionary = await _call_gm_brain(biome_id, act_type, ogham_used)
	if gm_card.is_empty():
		return {}

	# Phase B : Narrator brain — rich prose from scratch given GM structure.
	var narrative_text: String = await _call_narrator_brain(gm_card, biome_id, act_type)

	# Phase C : fusion. If narrator failed, keep GM text as fallback.
	if narrative_text != "":
		gm_card["text"] = narrative_text

	# Stamp id + biome + tags if GM didn't populate them.
	if not gm_card.has("id") or str(gm_card.get("id", "")).is_empty():
		gm_card["id"] = "bi_%s_%d" % [biome_id, Time.get_ticks_msec()]
	gm_card["biome"] = biome_id
	if not gm_card.has("tags"):
		gm_card["tags"] = [act_type]

	return gm_card


# ═════════ Phase A : GM brain ═════════════════════════════════════════════════

func _call_gm_brain(biome_id: String, act_type: String, ogham_used: String) -> Dictionary:
	if not _merlin_ai.has_method("generate_with_system"):
		return {}
	var system_prompt: String = _gm_system_prompt(biome_id, act_type, ogham_used)
	var user_input: String = _gm_user_input(biome_id, act_type, ogham_used)
	# v1.1 (code-review HIGH fix) : `merlin_ai.generate_with_system` reads
	# `timeout_ms` (not `timeout_s`) and routes brain via `grammar` presence
	# (not `"brain"` key). Grammar set → gamemaster_llm ; grammar empty → narrator_llm.
	var params: Dictionary = {
		"grammar": _gbnf_text,                # selects gamemaster_llm
		"max_tokens": 400,
		"temperature": 0.7,
		"timeout_ms": int(GM_TIMEOUT_S * 1000),
	}
	var result: Dictionary = await _merlin_ai.generate_with_system(system_prompt, user_input, params)
	if result.get("error", "") != "":
		push_warning("[BiBrain] GM brain error : %s" % result.get("error"))
		return {}
	var raw_text: String = str(result.get("text", result.get("output", "")))
	return _parse_gm_json(raw_text)


func _gm_system_prompt(biome_id: String, act_type: String, ogham_used: String) -> String:
	var lines: Array = [
		"Tu es le Gamemaster de M.E.R.L.I.N.. Tu produis UNE carte au format JSON strict.",
		"Format imposé par GBNF : {text, speaker:\"merlin\", options:[3]{label, effects:[1-3]}}.",
		"Effects : DAMAGE_LIFE/HEAL_LIFE/ADD_REPUTATION/ADD_ANAM.",
		"Factions : druides, anciens, korrigans, niamh, ankou.",
		"Biome : %s. Type d'acte : %s." % [biome_id, act_type],
	]
	if ogham_used != "":
		lines.append("Ogham actif : %s — module les effets en accord." % ogham_used)
	var ctx: String = _build_rag_context("gamemaster", biome_id)
	if ctx != "":
		lines.append("Contexte des cartes précédentes :")
		lines.append(ctx)
	return "\n".join(lines)


func _gm_user_input(biome_id: String, act_type: String, _ogham_used: String) -> String:
	match act_type:
		"boss":
			return "Génère une carte BOSS climactique pour le biome %s. Stakes élevés." % biome_id
		"shop":
			return "Génère une carte SHOP (récupération / échange) pour le biome %s." % biome_id
		"event":
			return "Génère une carte ÉVÉNEMENT (rencontre inattendue) pour le biome %s." % biome_id
		_:
			return "Génère une carte STANDARD narrative pour le biome %s." % biome_id


## Parse GM JSON output. GBNF already constrains it; safe-parse anyway.
func _parse_gm_json(raw_text: String) -> Dictionary:
	if raw_text.is_empty():
		return {}
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
		push_warning("[BiBrain] GM JSON parse error : %s" % json.get_error_message())
		return {}
	var parsed = json.data
	if not (parsed is Dictionary):
		return {}
	return parsed as Dictionary


# ═════════ Phase B : Narrator brain ═══════════════════════════════════════════

func _call_narrator_brain(gm_card: Dictionary, biome_id: String, act_type: String) -> String:
	if not _merlin_ai.has_method("generate_with_system"):
		return ""
	var system_prompt: String = _narrator_system_prompt(biome_id, act_type)
	var user_input: String = _narrator_user_input(gm_card, biome_id)
	# v1.1 (code-review HIGH fix) : narrator routing via empty `grammar` (default
	# path in merlin_ai.generate_with_system → narrator_llm). `timeout_ms` not `_s`.
	var params: Dictionary = {
		"max_tokens": 120,
		"temperature": 0.85,
		"timeout_ms": int(NARRATOR_TIMEOUT_S * 1000),
	}
	var result: Dictionary = await _merlin_ai.generate_with_system(system_prompt, user_input, params)
	if result.get("error", "") != "":
		push_warning("[BiBrain] Narrator brain error : %s" % result.get("error"))
		return ""
	return str(result.get("text", result.get("output", ""))).strip_edges()


func _narrator_system_prompt(biome_id: String, _act_type: String) -> String:
	var lines: Array = [
		"Tu es le narrateur de M.E.R.L.I.N.. Tu écris UNE phrase narrative celtique (15-30 mots).",
		"Style : mystique, druidique, évocateur, présent. Pas de méta-commentaire.",
		"Biome : %s. Ton tient compte de la faction dominante." % biome_id,
		"Pas de guillemets internes. Pas de Merlin parlant à la 1ère personne (sauf si requis).",
	]
	var ctx: String = _build_rag_context("narrator", biome_id)
	if ctx != "":
		lines.append("Mémoire récente du joueur :")
		lines.append(ctx)
	return "\n".join(lines)


func _narrator_user_input(gm_card: Dictionary, biome_id: String) -> String:
	var options: Array = gm_card.get("options", [])
	var summary: Array = []
	for opt in options:
		if opt is Dictionary:
			summary.append(str(opt.get("label", "?")))
	return "Pour ce biome %s, le joueur fait face à : [%s]. Écris UNE phrase d'ambiance qui pose la scène." % [
		biome_id, ", ".join(summary)
	]


# ═════════ RAG context injection (intra-run, Phase 1 only) ═══════════════════

func _build_rag_context(brain: String, _biome_id: String) -> String:
	if _rag == null:
		return ""
	if _rag.has_method("retrieve_top_k"):
		var top: Array = _rag.retrieve_top_k(brain, 5)
		if not top.is_empty():
			return _format_context_block(top)
	if _rag.has_method("get") and _rag.get("journal") is Array:
		var journal: Array = _rag.journal
		var slice: Array = journal.slice(max(0, journal.size() - 3), journal.size())
		if not slice.is_empty():
			return _format_context_block(slice)
	return ""


func _format_context_block(entries: Array) -> String:
	var lines: Array = []
	for e in entries:
		if not (e is Dictionary):
			continue
		var t: String = str(e.get("type", ""))
		var d: Dictionary = e.get("data", {}) if e.get("data") is Dictionary else {}
		match t:
			"card_played":
				lines.append("- carte %s (%s)" % [str(d.get("card_id", "?")), str(d.get("biome", "?"))])
			"choice_made":
				lines.append("- choix : %s" % str(d.get("label", "?")))
			"effect_applied":
				lines.append("- effet : %s %+d" % [str(d.get("type", "?")), int(d.get("amount", 0))])
			"ogham_used":
				lines.append("- ogham : %s" % str(d.get("ogham", "?")))
			# v1.1 (code-review MEDIUM fix) : 2 missing journal types per RAGManager.
			"aspect_shifted":
				lines.append("- pôle : %s %+d" % [str(d.get("aspect", "?")), int(d.get("delta", 0))])
			"run_event":
				lines.append("- événement : %s" % str(d.get("label", d.get("kind", "?"))))
			_:
				continue
	return "\n".join(lines) if not lines.is_empty() else ""
