## ═══════════════════════════════════════════════════════════════════════════════
## ScenarioLoading — Phase 2.1 scenario pre-game flow (v7.7, 2026-05-15 part 23)
## ═══════════════════════════════════════════════════════════════════════════════
## Scène dédiée chargée entre BoardNarration biome-pick et le démarrage du run.
## Réf spec : task_plan.md v7.7 Phase 2.1 SPEC (8 AskUserQuestion answers locked).
##
## Flow runtime :
##   1. _ready : lit biome_id depuis MerlinStore.state.run.current_biome
##   2. ScenarioPlanner.generate_titles(biome_id) → 3 titres + ogham glyphs
##   3. Affiche 3 parchemins 3D (unfurl + ink-write) — placeholder 2D pour foundation
##   4. Player click → planner.generate_skeleton(biome_id, chosen_title)
##   5. Quill phase : CPUParticles3D + Merlin speech-bar + TTS robot voice (sub-iter)
##   6. Skeleton complete → Store dispatch SET_SCENARIO_SKELETON
##   7. change_scene_to_file → res://scenes/BoardNarration.tscn
##
## Cascade fallback : si LLM indisponible, planner retombe sur FALLBACK_SKELETONS
## (8 biomes shipped Phase 2.6). User flow never blocks.
##
## Phase 2.1.1 + 2.1.2 + 2.1.8 + 2.1.9 livrés ici (foundation).
## Phase 2.1.3-2.1.7 (parchemins 3D, speech-bar shader, TTS, particles) en sub-iter.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node3D

const FALLBACK_BIOME := "foret_broceliande"

var _planner: ScenarioPlanner = null
var _merlin_ai: Node = null
var _rag: Node = null
var _store: Node = null
var _biome_id: String = ""
var _titles: Array = []           # [{title: String, ogham: String}, ×3]
var _chosen_title: String = ""
var _skeleton: Dictionary = {}

var _ui_layer: CanvasLayer = null
var _info_label: Label = null     # foundation : displays current step textually
var _camera: Camera3D = null


func _ready() -> void:
	_resolve_autoloads()
	_biome_id = _read_biome_from_store()
	_setup_world()
	_setup_ui()
	_planner = ScenarioPlanner.new(_merlin_ai, _rag)
	# Foundation flow : titles → auto-pick first → skeleton → dispatch → scene change.
	# Sub-iteration 2.1.3+ replaces auto-pick with parchemin UI player interaction.
	_run_flow()


func _resolve_autoloads() -> void:
	_merlin_ai = get_node_or_null("/root/MerlinAI")
	_rag = get_node_or_null("/root/RAGManager")
	_store = get_node_or_null("/root/MerlinStore")


func _read_biome_from_store() -> String:
	if _store == null or not (_store.get("state") is Dictionary):
		push_warning("[ScenarioLoading] No store available — fallback biome '%s'" % FALLBACK_BIOME)
		return FALLBACK_BIOME
	var state: Dictionary = _store.state
	var run: Dictionary = state.get("run", {})
	var b: String = str(run.get("current_biome", FALLBACK_BIOME))
	if b == "":
		b = FALLBACK_BIOME
	return b


func _setup_world() -> void:
	# Minimal 3D world : key light + camera. Parchemins 3D land here in 2.1.3.
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color("#f0c878")  # warm amber per bible §23 mood
	key.light_energy = 1.4
	add_child(key)
	# look_at_from_position requires the node to be inside the tree (reads
	# global transform). Call AFTER add_child to avoid "Node not inside tree" ERROR.
	key.look_at_from_position(Vector3(0.5, 4.5, 1.5), Vector3.ZERO, Vector3.UP)

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.current = true
	_camera.position = Vector3(0.0, 2.0, 4.5)
	add_child(_camera)
	# look_at requires the node to be inside the tree — call AFTER add_child.
	_camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)


func _setup_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	_ui_layer.layer = 110
	add_child(_ui_layer)

	_info_label = Label.new()
	_info_label.name = "InfoLabel"
	_info_label.anchor_left = 0.0
	_info_label.anchor_right = 1.0
	_info_label.anchor_top = 0.4
	_info_label.anchor_bottom = 0.6
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 28)
	_info_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.82))
	_info_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 1.0))
	_info_label.add_theme_constant_override("outline_size", 8)
	_info_label.text = "Le sage Merlin consulte les Oghams…"
	_ui_layer.add_child(_info_label)


# ═════════ Foundation flow (Phase 2.1.1+2.1.2+2.1.8+2.1.9) ═══════════════════

func _run_flow() -> void:
	# Step 1 : generate 3 titles
	_info_label.text = "Le sage Merlin consulte les Oghams…\n(génération des titres)"
	_titles = await _planner.generate_titles(_biome_id)
	if _titles.is_empty():
		push_warning("[ScenarioLoading] No titles returned — aborting to BoardNarration with fallback")
		_return_to_board()
		return

	# Step 2 (foundation) : auto-pick first title.
	# Sub-iteration 2.1.3+ replaces this with parchemin UI player interaction.
	var first: Dictionary = _titles[0] as Dictionary
	_chosen_title = str(first.get("title", ""))
	_info_label.text = "Titre choisi : %s\n(Merlin écrit le scénario…)" % _chosen_title

	# Step 3 : generate skeleton
	_skeleton = await _planner.generate_skeleton(_biome_id, _chosen_title)
	if _skeleton.is_empty():
		push_warning("[ScenarioLoading] Empty skeleton — using planner fallback")

	# Step 4 : write skeleton into Store + return to BoardNarration
	_dispatch_skeleton()
	_info_label.text = "Le scénario est écrit. La forêt t'attend…"
	# Small pause for the player to see the transition message.
	await get_tree().create_timer(1.2).timeout
	_return_to_board()


func _dispatch_skeleton() -> void:
	if _store == null or not _store.has_method("dispatch"):
		return
	# Save the skeleton into Store so BoardNarration can pick it up on next _ready.
	# Uses a new SET_SCENARIO_SKELETON action ; if merlin_store has no handler yet,
	# the dispatch falls through harmlessly per Redux-like no-op semantics.
	_store.dispatch({
		"type": "SET_SCENARIO_SKELETON",
		"skeleton": _skeleton,
		"chosen_title": _chosen_title,
	})


func _return_to_board() -> void:
	get_tree().change_scene_to_file("res://scenes/BoardNarration.tscn")
