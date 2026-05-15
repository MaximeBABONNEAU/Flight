## ═══════════════════════════════════════════════════════════════════════════════
## JuiceHelpers — Persona/Yakuza animation helpers for BoardNarration v4
## ═══════════════════════════════════════════════════════════════════════════════
## Drop-in helpers extracted from docs/BOARD_NARRATION_JUICE.md.
## All Tween-based. Host scene must expose : _ui_layer (CanvasLayer),
## _camera (Camera3D), _floating_fx_layer (Control).
## ═══════════════════════════════════════════════════════════════════════════════

class_name JuiceHelpers
extends RefCounted

const PARCHMENT   := Color("#f0e2c4")
const INK         := Color("#1c1208")
const BRONZE      := Color("#8a6a3a")
const FACTION_COL := {
	"druides":   Color("#5fa650"),
	"anciens":   Color("#7a7a8c"),
	"korrigans": Color("#c46b3a"),
	"niamh":     Color("#3a7ac4"),
	"ankou":     Color("#6a3a3a"),
}

const ACT_COLOR := {
	"standard": Color(0.96, 0.92, 0.74),
	"shop":     Color(0.90, 0.68, 0.30),
	"event":    Color(0.65, 0.85, 1.00),
	"boss":     Color(0.85, 0.30, 0.30),
}

const ACT_ICON := {
	"standard": "❦",
	"shop":     "⚱",
	"event":    "✶",
	"boss":     "☠",
}

const ACT_LABEL := {
	"standard": "Carte narrative",
	"shop":     "Boutique des Korrigans",
	"event":    "Rencontre rare",
	"boss":     "Confrontation finale",
}


## Returns a translucent variant of the faction color for screen flash.
static func faction_flash_col(faction: String) -> Color:
	var c: Color = FACTION_COL.get(faction, BRONZE)
	return Color(c.r, c.g, c.b, 0.35)


## v5.7 — "Computer-generated" materialize reveal for 3D nodes.
## Effect : node spawns at scale=0 + invisible, brief white emissive "outline"
## flash, scale-in with TRANS_BACK overshoot, settle to scale=1. Total ~0.6s.
## Per user feedback (2026-05-14 part 13) : "donne l'impression que c'est généré
## par un ordinateur, effet qui construit et charge".
##
## node  : the Node3D to reveal (works with MeshInstance3D children too)
## delay : seconds to wait before starting the reveal (for sequential staggering)
## flash_color : the brief emissive flash color (default white)
static func materialize_reveal(host: Node, node: Node3D, delay: float = 0.0,
		flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)) -> void:
	if node == null or not is_instance_valid(node):
		return
	# Save original scale + visibility.
	var original_scale: Vector3 = node.scale
	node.visible = false
	node.scale = Vector3.ZERO
	# Collect mesh children to flash (recursive walk, max 8 deep).
	var meshes: Array = []
	_collect_meshes_recursive(node, meshes, 0)
	# Save original materials and apply white emissive material.
	# v7.5 — Cast to GeometryInstance3D so both MeshInstance3D + MultiMeshInstance3D work.
	for m in meshes:
		var gi: GeometryInstance3D = m as GeometryInstance3D
		if gi == null:
			continue
		var prev: Material = gi.material_override
		gi.set_meta("_prev_mat", prev)
		var flash_mat := StandardMaterial3D.new()
		flash_mat.albedo_color = flash_color
		flash_mat.emission_enabled = true
		flash_mat.emission = flash_color
		flash_mat.emission_energy_multiplier = 3.0
		flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flash_mat.albedo_color.a = 0.75
		gi.material_override = flash_mat
	# Wait the stagger delay.
	if delay > 0.0:
		await host.get_tree().create_timer(delay).timeout
	if not is_instance_valid(node):
		return
	node.visible = true
	# Phase 1 : scale-in with TRANS_BACK overshoot
	var t := host.create_tween().set_parallel(true)
	t.tween_property(node, "scale", original_scale, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Phase 2 : after flash, restore original materials with fade
	await host.get_tree().create_timer(0.35).timeout
	if not is_instance_valid(node):
		return
	for m in meshes:
		# v7.5 — GeometryInstance3D covers both MeshInstance3D + MultiMeshInstance3D.
		var gi: GeometryInstance3D = m as GeometryInstance3D
		if gi == null or not is_instance_valid(gi):
			continue
		var prev: Material = gi.get_meta("_prev_mat", null) as Material
		# Smoothly fade out the flash by dropping its emission
		var current_mat: StandardMaterial3D = gi.material_override as StandardMaterial3D
		if current_mat:
			var fade := host.create_tween()
			fade.tween_method(func(v: float) -> void:
				current_mat.emission_energy_multiplier = v
				current_mat.albedo_color.a = lerp(0.75, 1.0, 1.0 - v / 3.0),
				3.0, 0.0, 0.25)
			fade.tween_callback(func() -> void:
				if is_instance_valid(gi):
					gi.material_override = prev)


## Recursive walk to collect all GeometryInstance3D children (capped at depth=8).
## v7.5 — Now collects MultiMeshInstance3D too so MM-batched assets (trees, foliage)
## get the white emissive flash like individual MeshInstance3D spawns.
## Both classes inherit GeometryInstance3D and expose `material_override`.
static func _collect_meshes_recursive(node: Node, out_meshes: Array, depth: int) -> void:
	if depth > 8 or node == null:
		return
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		out_meshes.append(node)
	for child in node.get_children():
		_collect_meshes_recursive(child, out_meshes, depth + 1)


## Card deal-in : slam onto table with rotation + scale overshoot.
## v5.2 — position tween REMOVED (broke anchor-based layouts : setting
## panel.position to Vector2.ZERO overrides the anchor system and places the
## top-left at screen (0,0). For bottom-anchored panels this displaced the card
## to the top of screen. Pure scale+rotation+alpha respects the anchor.
## panel : the CardPanel under _card_overlay
## host  : the Node (BoardNarration scene) that owns the tweens.
static func deal_in_card(host: Node, panel: Control) -> void:
	if panel == null:
		return
	panel.pivot_offset = panel.size * 0.5
	panel.rotation_degrees = 8.0
	panel.scale = Vector2(0.88, 0.88)
	panel.modulate.a = 0.0
	var tw := host.create_tween().set_parallel(true)
	tw.tween_property(panel, "rotation_degrees", -1.0, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2(1.04, 1.04), 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.22)
	var land := host.create_tween()
	land.tween_interval(0.32)
	land.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.13) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	land.parallel().tween_property(panel, "rotation_degrees", 0.0, 0.13)


## Yakuza hit-stop : 80ms time-freeze + camera kick + faction flash + radial burst + button swell.
static func choice_impact(host: Node, ui_layer: CanvasLayer, camera: Camera3D,
		fx_layer: Control, btn: Control, dominant_faction: String) -> void:
	# Engine freeze. Use ignore_time_scale=true so the unfreeze timer measures
	# 80ms of WALL-CLOCK time — otherwise the timer is scaled by time_scale=0.08
	# and the freeze actually lasts ~1.0s (12x longer than intended).
	# Signature : create_timer(time_sec, process_always=true, process_in_physics=false, ignore_time_scale=false)
	Engine.time_scale = 0.08
	var unfreeze := host.get_tree().create_timer(0.08, true, false, true)
	unfreeze.timeout.connect(func() -> void: Engine.time_scale = 1.0)
	# Camera kick
	if camera:
		var origin: Vector3 = camera.position
		var kick_dir := Vector3(randf_range(-0.04, 0.04), 0.03, -0.05)
		var ck := host.create_tween()
		ck.tween_property(camera, "position", origin + kick_dir, 0.05) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		ck.tween_property(camera, "position", origin, 0.11) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Faction screen flash
	if ui_layer:
		var flash := ColorRect.new()
		flash.color = faction_flash_col(dominant_faction)
		flash.anchor_right = 1.0
		flash.anchor_bottom = 1.0
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.modulate.a = 0.0
		ui_layer.add_child(flash)
		var ft := host.create_tween()
		ft.tween_property(flash, "modulate:a", 1.0, 0.04)
		ft.tween_property(flash, "modulate:a", 0.0, 0.28)
		ft.tween_callback(flash.queue_free)
	# Radial ink-line burst
	if fx_layer and btn:
		_radial_burst(host, fx_layer, btn.global_position + btn.size * 0.5, dominant_faction)
	# Button swell-settle
	if btn:
		btn.pivot_offset = btn.size * 0.5
		var sw := host.create_tween()
		sw.tween_property(btn, "scale", Vector2(1.18, 1.18), 0.08) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		sw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.10) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


static func _radial_burst(host: Node, fx_layer: Control, centre: Vector2, faction: String) -> void:
	var col: Color = FACTION_COL.get(faction, BRONZE)
	for i in range(6):
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = col
		var ang := (PI * 2.0 / 6.0) * i + randf_range(-0.1, 0.1)
		var dir := Vector2(cos(ang), sin(ang))
		line.points = PackedVector2Array([centre, centre + dir * 18.0])
		line.z_index = 50
		fx_layer.add_child(line)
		var t := host.create_tween().set_parallel(true)
		t.tween_method(func(p: float) -> void:
			line.points = PackedVector2Array([
				centre + dir * (p * 18.0),
				centre + dir * (p * 90.0)
			]), 0.0, 1.0, 0.32) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(line, "modulate:a", 0.0, 0.32) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.chain().tween_callback(line.queue_free)


## Parabolic floating label with rotation — replaces vertical rise+fade.
static func spawn_floating_label_arc(host: Node, fx_layer: Control,
		text: String, color: Color, pos: Vector2, delay: float) -> void:
	if fx_layer == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", INK)
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.modulate.a = 0.0
	lbl.pivot_offset = Vector2(20, 12)
	fx_layer.add_child(lbl)
	var dx := randf_range(40.0, 80.0) * (1.0 if randf() > 0.5 else -1.0)
	var apex_y := pos.y - 80.0
	var t := host.create_tween().set_parallel(true)
	t.tween_interval(delay)
	t.chain().set_parallel(true)
	t.tween_property(lbl, "modulate:a", 1.0, 0.12)
	t.tween_property(lbl, "rotation_degrees", randf_range(-25.0, 25.0), 1.2)
	t.tween_method(func(p: float) -> void:
		var y_offset: float = (apex_y - pos.y) * (1.0 - pow(1.0 - p, 2.0)) \
			+ (pos.y - apex_y) * pow(p, 2.0) * 0.6
		lbl.position = Vector2(pos.x + dx * p, pos.y + y_offset),
		0.0, 1.0, 1.4).set_trans(Tween.TRANS_SINE)
	t.chain().tween_property(lbl, "modulate:a", 0.0, 0.35)
	t.chain().tween_callback(lbl.queue_free)


## HUD life-bar ticker — counts from old_v to new_v over 0.6s with chevron wave.
static func hud_life_ticker(host: Node, bar: ProgressBar, value_label: Label,
		from_v: int, to_v: int) -> void:
	if bar == null:
		return
	var tw := host.create_tween().set_parallel(true)
	tw.tween_method(func(v: float) -> void:
		bar.value = v
		if value_label:
			value_label.text = "%d/100" % int(round(v)),
		float(from_v), float(to_v), 0.60) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if value_label:
		value_label.pivot_offset = value_label.size * 0.5
		tw.tween_property(value_label, "scale", Vector2(1.4, 1.4), 0.10)
		tw.chain().tween_property(value_label, "scale", Vector2(1.0, 1.0), 0.12)
	# Chevron wave
	var poly := Polygon2D.new()
	poly.color = BRONZE
	poly.polygon = PackedVector2Array([Vector2(0, 0), Vector2(10, 9), Vector2(0, 18)])
	poly.modulate.a = 0.85
	bar.add_child(poly)
	var going_up := to_v > from_v
	var start_x := -10.0 if going_up else bar.size.x
	var end_x := bar.size.x if going_up else -10.0
	poly.position = Vector2(start_x, 0)
	var t := host.create_tween().set_parallel(true)
	t.tween_property(poly, "position:x", end_x, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(poly, "modulate:a", 0.0, 0.55)
	t.chain().tween_callback(poly.queue_free)


## Faction-label flip animation : vertical flip + color flash + value swap mid-flip.
static func faction_flip(host: Node, lbl: Label, faction: String, new_v: int,
		hud_labels: Dictionary) -> void:
	if lbl == null:
		return
	var col: Color = FACTION_COL.get(faction, Color.WHITE)
	lbl.pivot_offset = lbl.size * 0.5
	var flash := col
	flash.a = 0.85
	var t := host.create_tween()
	t.tween_property(lbl, "scale:y", -1.0, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		lbl.text = "%s %d" % [str(hud_labels.get(faction, faction)), new_v]
		lbl.add_theme_color_override("font_color", flash))
	t.tween_property(lbl, "scale:y", 1.0, 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		lbl.add_theme_color_override("font_color", col))


## Act indicator badge — top-center, color-coded by act type.
static func update_act_indicator(host: Node, label: Label, act_idx: int,
		total_acts: int, act_type: String) -> void:
	if label == null:
		return
	var icon: String = ACT_ICON.get(act_type, "❦")
	var label_text: String = ACT_LABEL.get(act_type, "Carte")
	var color: Color = ACT_COLOR.get(act_type, Color.WHITE)
	label.text = "%s  Acte %d / %d — %s" % [icon, act_idx + 1, total_acts, label_text]
	label.add_theme_color_override("font_color", color)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.6, 0.6)
	label.modulate.a = 0.0
	var t := host.create_tween().set_parallel(true)
	t.tween_property(label, "scale", Vector2(1.0, 1.0), 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "modulate:a", 1.0, 0.30)


## Compute per-card stat readout from the existing card schema.
## Returns Dictionary { difficulty, risk_pct, faction_pressure, reward_hint, ogham_glyph, act_type }.
static func compute_stat_readout(card: Dictionary) -> Dictionary:
	var options: Array = card.get("options", [])
	var max_dmg := 0
	var max_heal := 0
	var max_fac_gain := 0
	var max_fac_name := ""
	var fac_pressure := {"druides": 0, "anciens": 0, "korrigans": 0, "niamh": 0, "ankou": 0}
	var dmg_options := 0
	for opt in options:
		if not (opt is Dictionary):
			continue
		var dmg := 0
		var heal := 0
		for fx in opt.get("effects", []):
			match str(fx.get("type", "")):
				"DAMAGE_LIFE":
					dmg += int(fx.get("amount", 0))
				"HEAL_LIFE":
					heal += int(fx.get("amount", 0))
				"ADD_REPUTATION":
					var f: String = str(fx.get("faction", ""))
					var amt: int = int(fx.get("amount", 0))
					if amt > int(fac_pressure.get(f, -999)):
						fac_pressure[f] = signi(amt)
					if amt > max_fac_gain:
						max_fac_gain = amt
						max_fac_name = f
		max_dmg = maxi(max_dmg, dmg)
		max_heal = maxi(max_heal, heal)
		if dmg > heal:
			dmg_options += 1
	var opt_count: int = maxi(options.size(), 1)
	return {
		"difficulty": clampi(1 + (max_dmg / 3) + (1 if max_fac_gain >= 10 else 0), 1, 5),
		"risk_pct": clampi(int(round(100.0 * float(dmg_options) / float(opt_count))), 0, 100),
		"faction_pressure": fac_pressure,
		"reward_hint": {"max_life": max_heal, "max_faction": max_fac_gain, "faction_name": max_fac_name},
		"ogham_glyph": str(card.get("ogham_used", "")),
		"act_type": str(card.get("act_type", "standard")),
	}
