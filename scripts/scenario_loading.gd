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

# v7.7 Phase 2.1.3 — 3 parchemin 3D meshes (PlaneMesh + parchment NoiseTexture +
# title Label3D + ogham Label3D). Player clicks one to pick the title.
var _parchemins: Array = []       # Array of MeshInstance3D
var _pick_buttons: Array = []     # 3 floating 2D Buttons synced to parchemin positions
var _pending_pick: int = -1       # set by _on_parchemin_clicked, polled by _run_flow
var _aborted: bool = false        # v7.7.1 C4 — set by back button to break the pick wait loop


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

	# v7.7.1 C4 — back button so the player can escape if title generation hangs
	# or the parchemin choice is no longer wanted. Routes directly to Hub.
	var back_btn := Button.new()
	back_btn.name = "BackBtn"
	back_btn.text = "← Retour Hub"
	back_btn.anchor_left = 0.02
	back_btn.anchor_top = 0.02
	back_btn.offset_right = 220.0
	back_btn.offset_bottom = 56.0
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.78, 0.85))
	back_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.78, 1.0))
	back_btn.pressed.connect(_on_back_to_hub_pressed)
	_ui_layer.add_child(back_btn)


# ═════════ Foundation flow (Phase 2.1.1+2.1.2+2.1.8+2.1.9) ═══════════════════

func _run_flow() -> void:
	# Step 1 : generate 3 titles
	_info_label.text = "Le sage Merlin consulte les Oghams…\n(génération des titres)"
	_titles = await _planner.generate_titles(_biome_id)
	if _aborted:
		return
	if _titles.is_empty():
		# v7.7.1 C4 — LLM cascade fully exhausted (Ollama down + fallback bug).
		# Dispatch a minimal skeleton so BoardNarration's idempotency guard prevents
		# infinite ScenarioLoading re-entry (board would otherwise see no skeleton
		# and re-launch this scene, looping forever).
		push_warning("[ScenarioLoading] No titles returned — using fallback skeleton")
		_dispatch_fallback_skeleton()
		_return_to_board()
		return

	# v7.7 Phase 2.1.3 — Spawn 3 parchemin 3D meshes + wait for player click.
	# Foundation auto-pick replaced with real player choice via floating buttons.
	_info_label.text = "Choisis ta voie…"
	_build_parchemin_meshes(_titles)
	_build_pick_buttons()
	# Wait for click — _on_parchemin_clicked sets _pending_pick to chosen index.
	# v7.7.1 C4 — also break on _aborted (back button) to prevent infinite poll.
	_pending_pick = -1
	while _pending_pick < 0 and not _aborted:
		await get_tree().process_frame
	if _aborted:
		return
	# Cleanup pick UI + record choice.
	var chosen: Dictionary = _titles[_pending_pick] as Dictionary
	_chosen_title = str(chosen.get("title", ""))
	_clear_pick_buttons()
	# Subtle confirmation animation : selected parchemin pulses, others fade out.
	for i in range(_parchemins.size()):
		var p: MeshInstance3D = _parchemins[i] as MeshInstance3D
		if p == null or not is_instance_valid(p):
			continue
		if i == _pending_pick:
			var pulse := create_tween().set_parallel(true)
			pulse.tween_property(p, "scale", Vector3.ONE * 1.10, 0.25).set_trans(Tween.TRANS_BACK)
			pulse.tween_property(p, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_SINE).set_delay(0.25)
		else:
			var mat: StandardMaterial3D = p.material_override as StandardMaterial3D
			if mat:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				create_tween().tween_property(mat, "albedo_color:a", 0.0, 0.4)
	await get_tree().create_timer(0.5).timeout
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


# ═════════ v7.7.1 C4 — back button + fallback skeleton helpers ═══════════════

func _on_back_to_hub_pressed() -> void:
	# Set abort flag to break the pick wait loop, then route to Hub. The flag
	# also short-circuits the post-await _aborted checks in _run_flow.
	_aborted = true
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/MerlinCabinHub.tscn")


func _dispatch_fallback_skeleton() -> void:
	# Minimal hardcoded skeleton — non-empty so the board's idempotency guard
	# (Store.state.run.scenario_skeleton presence) prevents ScenarioLoading re-entry.
	# fallback=true lets BoardNarration log/treat this as a degraded run if needed.
	if _store == null or not _store.has_method("dispatch"):
		return
	var fallback: Dictionary = {
		"title": "Un voyage sans nom",
		"biome": _biome_id,
		"beats": [],
		"fallback": true,
	}
	_store.dispatch({
		"type": "SET_SCENARIO_SKELETON",
		"skeleton": fallback,
		"chosen_title": "Un voyage sans nom",
	})


# ═════════ Phase 2.1.3 — 3D parchemin meshes + click handling ════════════════

const PARCHEMIN_W := 1.20
const PARCHEMIN_H := 1.70
const PARCHEMIN_GAP := 1.60         # horizontal spacing between centers
const PARCHEMIN_Y := 1.20           # height above plateau plane
const PARCHEMIN_Z := 1.5            # forward of origin, in front of camera (camera at z=4.5)
const PARCHMENT_COLOR := Color("#f0e2c4")  # cream parchment per bible §13
const INK_DARK := Color("#0a0500")  # outline noir signature bible §20

## Spawn 3 floating 3D parchemins side-by-side in front of camera.
## Each parchemin = PlaneMesh + NoiseTexture parchment + Label3D for title + ogham.
## Phase 2.1.4 will add unfurl + ink-write animations (foundation : static reveal).
func _build_parchemin_meshes(titles: Array) -> void:
	_parchemins.clear()
	for i in range(min(3, titles.size())):
		var entry: Dictionary = titles[i] as Dictionary
		var title_text: String = str(entry.get("title", "?"))
		var ogham_id: String = str(entry.get("ogham", ""))
		var mi := _build_single_parchemin(title_text, ogham_id, i)
		_parchemins.append(mi)


func _build_single_parchemin(title_text: String, ogham_id: String, idx: int) -> MeshInstance3D:
	# Mesh = PlaneMesh acting as a flat parchment card.
	var mi := MeshInstance3D.new()
	mi.name = "Parchemin_%d" % idx
	var plane := PlaneMesh.new()
	plane.size = Vector2(PARCHEMIN_W, PARCHEMIN_H)
	plane.orientation = PlaneMesh.FACE_Z  # face forward, toward camera
	mi.mesh = plane
	# Position : centered row of 3 at y=PARCHEMIN_Y, z=PARCHEMIN_Z.
	var center_offset: float = (idx - 1) * PARCHEMIN_GAP  # idx 0 → left, 1 → center, 2 → right
	mi.position = Vector3(center_offset, PARCHEMIN_Y, PARCHEMIN_Z)
	# Procedural parchment material (parchment cream + noise grain).
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PARCHMENT_COLOR
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.015
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 256
	tex.height = 256
	mat.albedo_texture = tex
	mat.roughness = 0.92
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)
	# v7.7 outline audit fix — bible §20 signature on the parchemins (first 3D
	# asset player sees per run, pre-skeleton). PlaneMesh outline thickness slim
	# (0.005) to keep silhouette discreet on the flat face.
	CelShadingManager.apply(mi, {"outline_thickness": 0.005})
	# Title Label3D (top half of parchemin)
	var lbl := Label3D.new()
	lbl.text = title_text
	lbl.modulate = INK_DARK
	lbl.outline_modulate = Color(1, 1, 1, 0.5)
	lbl.outline_size = 4
	lbl.font_size = 36
	lbl.pixel_size = 0.0025
	lbl.width = 380
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector3(0, 0.15, 0.01)
	lbl.no_depth_test = true
	mi.add_child(lbl)
	# Ogham glyph (bottom — uses ogham_id as text, future : map to celtic font/glyph).
	if ogham_id != "":
		var ogham_lbl := Label3D.new()
		ogham_lbl.text = "᚛" + ogham_id.to_upper() + "᚜"
		ogham_lbl.modulate = Color("#d4a868")  # accent gold (bible §22)
		ogham_lbl.font_size = 28
		ogham_lbl.pixel_size = 0.0028
		ogham_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ogham_lbl.position = Vector3(0, -0.55, 0.01)
		ogham_lbl.no_depth_test = true
		mi.add_child(ogham_lbl)
	# Subtle reveal : scale-in TRANS_BACK with staggered delay per parchemin.
	mi.scale = Vector3.ZERO
	var t := create_tween()
	t.tween_interval(float(idx) * 0.18)
	t.tween_property(mi, "scale", Vector3.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return mi


## Build 3 floating 2D Buttons on the UI layer, positioned at the unproject of each
## parchemin's center on screen. Updates per-frame via _process to follow camera.
func _build_pick_buttons() -> void:
	_clear_pick_buttons()
	for i in range(_parchemins.size()):
		var btn := Button.new()
		btn.name = "PickBtn_%d" % i
		btn.text = ""
		btn.flat = true
		btn.custom_minimum_size = Vector2(220, 360)  # roughly the parchemin footprint
		var idx: int = i
		btn.pressed.connect(func() -> void: _on_parchemin_clicked(idx))
		_ui_layer.add_child(btn)
		_pick_buttons.append(btn)


func _clear_pick_buttons() -> void:
	for b in _pick_buttons:
		if is_instance_valid(b):
			(b as Node).queue_free()
	_pick_buttons.clear()


func _on_parchemin_clicked(idx: int) -> void:
	if _pending_pick >= 0:
		return  # already picked, ignore subsequent clicks
	_pending_pick = clampi(idx, 0, _parchemins.size() - 1)


## v7.7 Phase 2.1.3 — sync the 3 pick buttons to the parchemin screen positions
## each frame so they remain clickable as the parchemin reveal tweens play.
func _process(_delta: float) -> void:
	if _camera == null or _pick_buttons.is_empty():
		return
	for i in range(_pick_buttons.size()):
		var btn: Button = _pick_buttons[i] as Button
		var p: MeshInstance3D = _parchemins[i] if i < _parchemins.size() else null
		if btn == null or p == null or not is_instance_valid(p):
			continue
		if _camera.is_position_behind(p.global_position):
			btn.visible = false
			continue
		var screen: Vector2 = _camera.unproject_position(p.global_position)
		btn.visible = true
		btn.position = screen - Vector2(btn.size.x * 0.5, btn.size.y * 0.5)
