## ═══════════════════════════════════════════════════════════════════════════════
## BoardNarration — Post-run cinematic replay controller
## ═══════════════════════════════════════════════════════════════════════════════
## Attached to scenes/BoardNarration.tscn root (Node3D).
## On _ready(): reads MerlinStore.state.run (or mock for smoke), builds the
## scene procedurally (camera + lights + plateau + particles + UI), spawns one
## SigleToken per story_log entry in a spiral layout, and runs the narration
## loop: highlight → LLM call → typewriter → wait click → advance.
## On done: persists a journal entry via BoardRunJournal, emits narration_done.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node3D
class_name BoardNarration

signal narration_done

const SPIRAL_RADIUS_START := 0.6
const SPIRAL_RADIUS_STEP := 0.18
const SPIRAL_ANGLE_STEP_DEG := 55.0
const SPIRAL_HEIGHT := 0.35
const TOKEN_STAGGER_DELAY := 0.18
const NARRATION_TYPEWRITER_CPS := 32.0   # characters per second
const NARRATION_MIN_DURATION := 1.2

# Fallback per Ogham category — used when LLM is unreachable.
const FALLBACK_BY_CATEGORY := {
	"reveal":     "Le voile se leve. Tu as vu ce qui etait cache.",
	"protection": "L'ombre passe sans te toucher. Tu as tenu.",
	"boost":      "Une etincelle gonfle ton souffle. Tu repars plus fort.",
	"narrative":  "Le recit bifurque. Un autre chemin s'ecrit.",
	"":           "Le moment a passe. Tu n'en sors pas indemne.",
}

const FALLBACK_NO_OGHAM := [
	"Le moment a passe sans Ogham — tu as choisi seul.",
	"La rune dort. Tu as marche a ta voix.",
	"Pas de presage, pas de filet. Le choix te suit.",
]

const LLM_PER_CALL_TIMEOUT := 12.0          # Bail to fallback if LLM doesn't return in time.

var _run_data: Dictionary = {}
var _biome_id: String = ""
var _outcome: String = ""
var _save_system: Object = null
var _merlin_ai: Node = null
var _flow_controller: Node = null
var _tokens: Array = []                     # Array of SigleToken
var _narrations: Array = []                 # Accumulator for journal
var _current_index: int = -1
var _is_typing: bool = false
var _accept_clicks: bool = true
var _llm_unavailable: bool = false          # Sticky flag: once LLM fails, skip subsequent calls.
var _narration_done_emitted: bool = false   # Idempotency guard for narration_done.

# Auto-built nodes
var _camera: Camera3D = null
var _world_env: WorldEnvironment = null
var _main_light: DirectionalLight3D = null
var _plateau: MeshInstance3D = null
var _particles: GPUParticles3D = null
var _token_container: Node3D = null
var _ui_layer: CanvasLayer = null
var _biome_label: Label = null
var _stats_label: Label = null
var _narration_label: RichTextLabel = null
var _continue_button: Button = null


func _ready() -> void:
	_build_scene_tree()
	_resolve_dependencies()
	_load_run_data()
	_biome_id = str(_run_data.get("current_biome", _run_data.get("biome", BoardBiomeAmbience.DEFAULT_BIOME)))
	_apply_biome()
	_populate_ui_header()
	_spawn_tokens()
	# Start the narration loop after token entry animations.
	await get_tree().create_timer(0.6 + TOKEN_STAGGER_DELAY * float(_tokens.size())).timeout
	_advance_narration()


func _build_scene_tree() -> void:
	# Camera — slight top-down, 3/4 angle on plateau
	_camera = get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "Camera3D"
		add_child(_camera)
	_camera.position = Vector3(0.0, 3.4, 4.2)
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	_camera.fov = 55.0

	# WorldEnvironment for ambient + glow
	_world_env = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if _world_env == null:
		_world_env = WorldEnvironment.new()
		_world_env.name = "WorldEnvironment"
		add_child(_world_env)
	if _world_env.environment == null:
		_world_env.environment = Environment.new()

	# Main biome-tinted directional light
	_main_light = get_node_or_null("MainLight") as DirectionalLight3D
	if _main_light == null:
		_main_light = DirectionalLight3D.new()
		_main_light.name = "MainLight"
		_main_light.position = Vector3(2.0, 4.0, 2.0)
		_main_light.shadow_enabled = true
		add_child(_main_light)

	# Plateau (cylinder, biome-tinted material)
	_plateau = get_node_or_null("Plateau") as MeshInstance3D
	if _plateau == null:
		_plateau = MeshInstance3D.new()
		_plateau.name = "Plateau"
		add_child(_plateau)
	var cyl: CylinderMesh = _plateau.mesh as CylinderMesh
	if cyl == null:
		cyl = CylinderMesh.new()
		cyl.top_radius = 2.2
		cyl.bottom_radius = 2.0
		cyl.height = 0.18
		cyl.radial_segments = 48
		_plateau.mesh = cyl
	_plateau.position = Vector3(0.0, 0.0, 0.0)

	# Particles container
	_particles = get_node_or_null("BiomeParticles") as GPUParticles3D
	if _particles == null:
		_particles = GPUParticles3D.new()
		_particles.name = "BiomeParticles"
		_particles.position = Vector3(0.0, 1.0, 0.0)
		_particles.amount = 120
		_particles.lifetime = 6.0
		_particles.one_shot = false
		_particles.local_coords = false
		add_child(_particles)

	# Token container
	_token_container = get_node_or_null("TokenContainer") as Node3D
	if _token_container == null:
		_token_container = Node3D.new()
		_token_container.name = "TokenContainer"
		_token_container.position = Vector3(0.0, 0.20, 0.0)
		add_child(_token_container)

	# UI overlay
	_ui_layer = get_node_or_null("UI") as CanvasLayer
	if _ui_layer == null:
		_ui_layer = CanvasLayer.new()
		_ui_layer.name = "UI"
		add_child(_ui_layer)

	_biome_label = _ensure_label(_ui_layer, "BiomeName", Vector2(24, 24), 480, 32)
	_stats_label = _ensure_label(_ui_layer, "RunStats", Vector2(-460, 24), 440, 28)
	if _stats_label:
		_stats_label.anchor_left = 1.0
		_stats_label.anchor_right = 1.0
		_stats_label.size_flags_horizontal = Control.SIZE_SHRINK_END

	_narration_label = get_node_or_null("UI/NarrationBox") as RichTextLabel
	if _narration_label == null:
		_narration_label = RichTextLabel.new()
		_narration_label.name = "NarrationBox"
		_narration_label.bbcode_enabled = true
		_narration_label.fit_content = true
		_narration_label.scroll_active = false
		_narration_label.anchor_left = 0.0
		_narration_label.anchor_right = 1.0
		_narration_label.anchor_top = 1.0
		_narration_label.anchor_bottom = 1.0
		_narration_label.offset_left = 64.0
		_narration_label.offset_right = -64.0
		_narration_label.offset_top = -200.0
		_narration_label.offset_bottom = -80.0
		_narration_label.add_theme_font_size_override("normal_font_size", 24)
		_narration_label.add_theme_color_override("default_color", Color(0.85, 1.0, 0.78))
		_narration_label.modulate = Color(1, 1, 1, 0.95)
		_ui_layer.add_child(_narration_label)

	_continue_button = get_node_or_null("UI/ContinueButton") as Button
	if _continue_button == null:
		_continue_button = Button.new()
		_continue_button.name = "ContinueButton"
		_continue_button.text = "Suite ▶"
		_continue_button.anchor_left = 1.0
		_continue_button.anchor_right = 1.0
		_continue_button.anchor_top = 1.0
		_continue_button.anchor_bottom = 1.0
		_continue_button.offset_left = -200.0
		_continue_button.offset_right = -32.0
		_continue_button.offset_top = -60.0
		_continue_button.offset_bottom = -16.0
		_continue_button.pressed.connect(_on_continue_pressed)
		_ui_layer.add_child(_continue_button)


func _ensure_label(parent: Node, label_name: String, pos: Vector2, width: float, font_size: int) -> Label:
	var lbl: Label = parent.get_node_or_null(label_name) as Label
	if lbl == null:
		lbl = Label.new()
		lbl.name = label_name
		lbl.position = pos
		lbl.custom_minimum_size = Vector2(width, 32)
		lbl.add_theme_font_size_override("font_size", font_size)
		lbl.add_theme_color_override("font_color", Color(0.85, 1.0, 0.78))
		lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.02))
		lbl.add_theme_constant_override("outline_size", 4)
		parent.add_child(lbl)
	return lbl


func _resolve_dependencies() -> void:
	var store: Node = get_node_or_null("/root/MerlinStore")
	if store and store.get("save_system") != null:
		_save_system = store.save_system
	_merlin_ai = get_node_or_null("/root/MerlinAI")
	# Self-wire to GameFlowController autoload so narration_done routes to EndRunScreen.
	# (change_scene_to_file destroys the previous tree — the controller cannot wire us
	# from the outside; we must reach up.)
	_flow_controller = get_node_or_null("/root/GameFlowController")
	if _flow_controller and _flow_controller.has_method("wire_board_narration"):
		_flow_controller.wire_board_narration(self)


func _load_run_data() -> void:
	# Priority: GameFlowController.get_last_run_data() → MerlinStore.state.run → mock
	var flow: Node = get_node_or_null("/root/GameFlowController")
	if flow and flow.has_method("get_last_run_data"):
		var last: Dictionary = flow.get_last_run_data()
		if not last.is_empty():
			_run_data = last.duplicate(true)
			_outcome = str(last.get("reason", ""))
			return
	var store: Node = get_node_or_null("/root/MerlinStore")
	if store and store.get("state") is Dictionary:
		var state: Dictionary = store.state
		var run: Dictionary = state.get("run", {})
		if run.has("story_log") and not (run.get("story_log", []) as Array).is_empty():
			_run_data = run.duplicate(true)
			_outcome = "ongoing"
			return
	# Smoke-test fallback
	_run_data = BoardRunJournal.build_mock_run_data()
	_outcome = "smoke_mock"


func _apply_biome() -> void:
	BoardBiomeAmbience.apply_to_nodes(_biome_id, _main_light, _world_env.environment, _plateau, _particles)


func _populate_ui_header() -> void:
	var biome_name: String = _biome_id
	if ClassDB.class_exists("MerlinConstants"):
		var spec: Dictionary = MerlinConstants.BIOMES.get(_biome_id, {})
		biome_name = str(spec.get("name", _biome_id))
	if _biome_label:
		_biome_label.text = "%s — %s" % [biome_name, BoardBiomeAmbience.get_mood_label(_biome_id)]
	if _stats_label:
		var cards: int = int(_run_data.get("cards_played", 0))
		var life: int = int(_run_data.get("life_essence", 0))
		_stats_label.text = "Cartes : %d  ·  Vie : %d" % [cards, life]


func _spawn_tokens() -> void:
	var story_log: Array = _run_data.get("story_log", [])
	if story_log.is_empty():
		return
	for i in range(story_log.size()):
		var raw = story_log[i]
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		var ogham: String = str(entry.get("ogham_used", entry.get("ogham", "")))
		var card_id: String = str(entry.get("card_id", ""))
		var faction: String = _resolve_dominant_faction(entry.get("faction_deltas", {}))

		var token: SigleToken = SigleToken.new()
		token.name = "Token_%d" % i
		_token_container.add_child(token)
		var pos: Vector3 = _spiral_position(i)
		token.position = pos
		token.setup(ogham, card_id, faction)
		token.animate_in(TOKEN_STAGGER_DELAY * float(i))
		_tokens.append(token)


func _spiral_position(index: int) -> Vector3:
	var angle_rad: float = deg_to_rad(float(index) * SPIRAL_ANGLE_STEP_DEG)
	var radius: float = SPIRAL_RADIUS_START + float(index) * SPIRAL_RADIUS_STEP
	var x: float = cos(angle_rad) * radius
	var z: float = sin(angle_rad) * radius
	return Vector3(x, SPIRAL_HEIGHT, z)


func _resolve_dominant_faction(deltas: Variant) -> String:
	if not (deltas is Dictionary):
		return ""
	var dict: Dictionary = deltas
	var best_key := ""
	var best_abs := 0.0
	for k in dict.keys():
		var val: float = abs(float(dict[k]))
		if val > best_abs:
			best_abs = val
			best_key = str(k)
	return best_key


# ─── Narration loop ────────────────────────────────────────────────────────────

func _advance_narration() -> void:
	if _is_typing:
		# Click during typewriter → fast-forward
		_is_typing = false
		return
	_current_index += 1
	if _current_index >= _tokens.size():
		_finish_narration()
		return
	if _current_index > 0:
		var prev: SigleToken = _tokens[_current_index - 1] as SigleToken
		if prev:
			prev.dim_to_idle()
	var token: SigleToken = _tokens[_current_index] as SigleToken
	if token:
		token.highlight()
	await _narrate_token(_current_index)


func _narrate_token(index: int) -> void:
	if index < 0 or index >= _tokens.size():
		return
	var story_log: Array = _run_data.get("story_log", [])
	if index >= story_log.size():
		return
	var entry_v = story_log[index]
	var entry: Dictionary = entry_v if entry_v is Dictionary else {}
	var card_id: String = str(entry.get("card_id", ""))
	var ogham: String = str(entry.get("ogham_used", entry.get("ogham", "")))

	var comment_text: String = await _request_llm_comment(entry, index, story_log.size())
	var source := "llm"
	if comment_text.is_empty():
		comment_text = _fallback_comment(ogham)
		source = "fallback"

	_narrations.append({
		"card_id": card_id,
		"comment": comment_text,
		"source": source,
	})

	await _typewriter_reveal(comment_text)


func _request_llm_comment(entry: Dictionary, index: int, total: int) -> String:
	# Early exits: no LLM at all, or it failed previously (sticky), or it's already busy.
	if _llm_unavailable:
		return ""
	if _merlin_ai == null or not _merlin_ai.has_method("generate_narrative"):
		_llm_unavailable = true
		return ""
	if _merlin_ai.has_method("is_llm_ready") and not bool(_merlin_ai.is_llm_ready()):
		_llm_unavailable = true
		return ""
	var ogham: String = str(entry.get("ogham_used", entry.get("ogham", "")))
	var ogham_name: String = ogham
	if ClassDB.class_exists("MerlinConstants"):
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham, {})
		ogham_name = str(spec.get("name", ogham))
	var biome_name: String = _biome_id
	if ClassDB.class_exists("MerlinConstants"):
		biome_name = str(MerlinConstants.BIOMES.get(_biome_id, {}).get("name", _biome_id))

	var system_prompt := "Tu es Merlin. Tu relis a voix posee une etape d'une run terminee. " \
		+ "Une phrase courte (12-22 mots), ton druidique sobre, pas de meta. " \
		+ "Pas de questions. Pas de markdown."
	var user_input := "Biome : %s. Carte %d/%d (%s). Ogham : %s. Option : %d. Ambiance : %s." % [
		biome_name, index + 1, total,
		str(entry.get("card_id", "?")),
		ogham_name if not ogham.is_empty() else "aucun",
		int(entry.get("option_index", entry.get("option", 0))),
		BoardBiomeAmbience.get_mood_label(_biome_id),
	]
	var params := {"temperature": 0.7, "max_tokens": 90}
	# Race the LLM against a wall-clock timeout. GDScript has no Promise.race, but we can
	# kick the call as a fire-and-forget Callable and poll a result-holder dict in parallel.
	var holder := {"done": false, "text": ""}
	var llm_task := func() -> void:
		var r_v = await _merlin_ai.generate_narrative(system_prompt, user_input, params)
		if holder.get("done", false):
			return  # timeout already fired; drop the result
		holder["done"] = true
		if r_v is Dictionary and bool(r_v.get("ok", false)):
			holder["text"] = str(r_v.get("text", ""))
	llm_task.call()
	var elapsed := 0.0
	while not bool(holder["done"]) and elapsed < LLM_PER_CALL_TIMEOUT:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	if not bool(holder["done"]):
		holder["done"] = true  # signal coroutine to drop late result
		_llm_unavailable = true
		push_warning("[BoardNarration] LLM timeout %ss — switching to fallback" % LLM_PER_CALL_TIMEOUT)
		return ""
	var text: String = str(holder.get("text", "")).strip_edges()
	if text.is_empty():
		return ""
	var first_line: String = text.split("\n")[0].strip_edges()
	if first_line.length() > 200:
		first_line = first_line.substr(0, 200) + "…"
	return first_line


func _fallback_comment(ogham_id: String) -> String:
	if ogham_id.is_empty():
		var idx: int = _current_index % FALLBACK_NO_OGHAM.size()
		return FALLBACK_NO_OGHAM[idx]
	var category := ""
	if ClassDB.class_exists("MerlinConstants"):
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})
		category = str(spec.get("category", ""))
	return str(FALLBACK_BY_CATEGORY.get(category, FALLBACK_BY_CATEGORY[""]))


func _typewriter_reveal(text: String) -> void:
	if _narration_label == null:
		return
	_narration_label.text = ""
	_is_typing = true
	var total_chars := text.length()
	var delay: float = 1.0 / NARRATION_TYPEWRITER_CPS
	var elapsed := 0.0
	var i := 0
	while i < total_chars and _is_typing:
		_narration_label.text = text.substr(0, i + 1)
		await get_tree().create_timer(delay).timeout
		elapsed += delay
		i += 1
	_is_typing = false
	_narration_label.text = text
	if elapsed < NARRATION_MIN_DURATION:
		await get_tree().create_timer(NARRATION_MIN_DURATION - elapsed).timeout


func _finish_narration() -> void:
	# Critical: prevent double-emit. Disable click paths BEFORE doing anything else.
	_accept_clicks = false
	if _continue_button:
		_continue_button.text = "Reprendre la cabane"
		_continue_button.disabled = true
	if _tokens.size() > 0:
		var last: SigleToken = _tokens[_tokens.size() - 1] as SigleToken
		if last:
			last.dim_to_idle()
	var entry: Dictionary = BoardRunJournal.build_entry(_run_data, _narrations, _outcome)
	if _save_system:
		BoardRunJournal.save_to_profile(_save_system, entry)
	push_warning("[BoardNarration] done — %d tokens, %d narrations, outcome=%s" % [_tokens.size(), _narrations.size(), _outcome])
	_emit_narration_done_once()


func _emit_narration_done_once() -> void:
	if _narration_done_emitted:
		return
	_narration_done_emitted = true
	narration_done.emit()


# ─── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _accept_clicks:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_continue_pressed()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER]:
		_on_continue_pressed()


func _on_continue_pressed() -> void:
	if not _accept_clicks:
		return
	if _current_index >= _tokens.size():
		_emit_narration_done_once()
		return
	_advance_narration()
