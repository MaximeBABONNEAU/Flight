## ═══════════════════════════════════════════════════════════════════════════════
## BoardBiomeBackdrop — Procedural biome decor BEHIND the plateau.
## ═══════════════════════════════════════════════════════════════════════════════
## REFONTE v2 (2026-05-13): user feedback "biome invisible". Plateau alone in
## near-black void was sad. This static helper places 8-20 simple primitive
## meshes in an arc behind the plateau, lit by a separate fill light, to
## suggest the biome's setting (forest, dolmens, sea, etc.).
##
## All meshes are procedural primitives — no GLB imports, no PNG textures.
## Materials are solid colors with biome-specific tints, sized & positioned
## to read as silhouette decor at the player's camera distance.
##
## Entry point: build_into(parent_node, biome_id) — clears parent + builds.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name BoardBiomeBackdrop

const DEFAULT_BIOME := "foret_broceliande"

# Place decor in an arc from z=-5 to z=-3, x from -5 to 5.
const BACKDROP_Z_FAR := -5.5
const BACKDROP_Z_NEAR := -3.2
const BACKDROP_X_HALF := 5.0


## v7.5 — Spawn counter for cascading "digital-upload" reveal effect (bible §20).
## Reset to 0 at every `build_into` call. Each `_spawn` increments + bumps its
## materialize_reveal delay by REVEAL_STAGGER_S so backdrop assets fade in
## sequentially over ~2 seconds, evoking a digital-build animation.
static var _spawn_counter: int = 0
const REVEAL_STAGGER_S := 0.06


## Clears `parent` and (re)builds the biome backdrop into it.
static func build_into(parent: Node, biome_id: String) -> void:
	if parent == null:
		return
	# Wipe any previous decor
	for child in parent.get_children():
		child.queue_free()
	# v7.5 — Reset cascade counter so each build_into runs its own staggered reveal.
	_spawn_counter = 0
	match biome_id:
		"foret_broceliande":
			_build_forest(parent)
		"landes_bruyere":
			_build_heath(parent)
		"cotes_sauvages":
			_build_coast(parent)
		"villages_celtes":
			_build_village(parent)
		"cercles_pierres":
			_build_stones(parent)
		"marais_korrigans":
			_build_marsh(parent)
		"collines_dolmens":
			_build_dolmens(parent)
		"iles_mystiques":
			_build_isles(parent)
		_:
			_build_forest(parent)


# ─── Helpers ─────────────────────────────────────────────────────────────────

static func _spawn(parent: Node, mesh: Mesh, pos: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.metallic = 0.0
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	mi.material_override = mat
	parent.add_child(mi)
	# v7.5 — Bible §20 v3.4 : every spawned asset gets low-poly flat material
	# remap + inverted-hull black outline (signature). Thinner outline (0.010)
	# for small props so they don't look bloated.
	CelShadingManager.apply(mi, {"outline_thickness": 0.010})
	# v7.5 — Progressive "digital-upload" reveal : each asset materializes
	# (scale-in + white emissive flash) staggered by REVEAL_STAGGER_S so the
	# scene builds itself in front of the player. Per user feedback 2026-05-15
	# part 19 : "effet de chargement progressif comme uploadé digitalement".
	var delay: float = float(_spawn_counter) * REVEAL_STAGGER_S
	_spawn_counter += 1
	JuiceHelpers.materialize_reveal(parent, mi, delay)
	return mi


## v7.5 — MultiMesh spawn for repeated identical assets (trees, mounds, rocks).
## Refs `external/multi_mesh_manager/` (richardathome). For 18 trees, this
## creates 2 MultiMeshInstance3D (main + outline) = 2 draw calls instead of 36.
##
## tree_positions : Array of Vector3 ground positions (asset placed on top).
## biome_id       : palette lookup for trunk + foliage tint.
##
## Builds : 1 procedural cone CylinderMesh, sets transforms with random scale +
## yaw + height per instance, applies BiomePalettes color, attaches outline MM.
static func _spawn_multimesh_trees(parent: Node, tree_positions: Array, biome_id: String) -> void:
	if parent == null or tree_positions.is_empty():
		return
	var palette: Dictionary = BiomePalettes.get_palette(biome_id)
	# Pick the "foliage"/"trunk" tinted slot (2nd narrative slot per palette convention).
	var narrative_slots: Array = []
	for k in palette.keys():
		if k != "accent" and k != "outline":
			narrative_slots.append(palette[k])
	var tree_color: Color = narrative_slots[1] if narrative_slots.size() > 1 else Color(0.14, 0.30, 0.16)

	# Build the shared cone mesh once.
	var tree_mesh := CylinderMesh.new()
	tree_mesh.top_radius = 0.02
	tree_mesh.bottom_radius = 0.8
	tree_mesh.height = 2.8
	tree_mesh.radial_segments = 8

	# Build per-instance Transform3D with random scale + yaw + base height offset.
	var transforms: Array = []
	for p in tree_positions:
		var ground: Vector3 = p as Vector3
		var sc: float = randf_range(0.85, 1.15)
		var yaw: float = randf_range(-PI, PI)
		var basis: Basis = Basis().rotated(Vector3.UP, yaw).scaled(Vector3.ONE * sc)
		# Cylinder origin is mesh center → lift by half-height × scale.
		var origin: Vector3 = ground + Vector3(0, tree_mesh.height * 0.5 * sc, 0)
		transforms.append(Transform3D(basis, origin))

	# Pair (main + outline) via MultiMeshOutlineHelper (bible §20 v3.4 signature).
	var pair: Dictionary = MultiMeshOutlineHelper.build_pair(
		tree_mesh, transforms, {"outline_thickness": 0.015}
	)
	var main_mmi: MultiMeshInstance3D = pair.get("main") as MultiMeshInstance3D
	var outline_mmi: MultiMeshInstance3D = pair.get("outline") as MultiMeshInstance3D
	if main_mmi == null:
		return

	# Apply biome-tinted material to the main MMI (single material, all instances).
	var tree_mat := StandardMaterial3D.new()
	tree_mat.albedo_color = tree_color
	tree_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	tree_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	tree_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	tree_mat.roughness = 0.85
	main_mmi.material_override = tree_mat
	main_mmi.name = "TreeForest_MM"

	parent.add_child(main_mmi)
	if outline_mmi:
		parent.add_child(outline_mmi)
	# Cascading reveal alongside individual spawns.
	JuiceHelpers.materialize_reveal(parent, main_mmi, float(_spawn_counter) * REVEAL_STAGGER_S)
	_spawn_counter += 1


static func _arc_z(index: int, total: int) -> float:
	if total <= 1:
		return BACKDROP_Z_FAR
	var t: float = float(index) / float(total - 1)
	return lerp(BACKDROP_Z_NEAR, BACKDROP_Z_FAR, abs(t - 0.5) * 2.0)


# ─── Biome builders ──────────────────────────────────────────────────────────

const FOREST_GLB_DIR := "res://assets/blender/forest/"
const FOREST_TREE_GLBS := [
	"tree_pine.glb",
	"tree_oak.glb",
	"tree_birch.glb",
	"tree_dead.glb",
]
const FOREST_PROP_GLBS := [
	"stump.glb",
	"fern.glb",
	"rock_moss.glb",
	"mushroom_cluster.glb",
]


static func _instantiate_glb_at(parent: Node, glb_path: String, pos: Vector3, scale_v: float = 1.0, rot_y: float = 0.0) -> Node3D:
	if not ResourceLoader.exists(glb_path):
		return null
	var packed: PackedScene = load(glb_path) as PackedScene
	if packed == null:
		return null
	var inst: Node3D = packed.instantiate() as Node3D
	if inst == null:
		return null
	inst.position = pos
	inst.scale = Vector3.ONE * scale_v
	inst.rotation = Vector3(0, rot_y, 0)
	parent.add_child(inst)
	return inst


static func _build_forest(parent: Node) -> void:
	# v6.4 — Procedural grass floor under plateau + pollen particles.
	# v7.4 — Pass biome_id so the floor color comes from BiomePalettes (bible §22).
	_build_grass_floor(parent, "foret_broceliande")
	_spawn_pollen_particles(parent)
	# Use Blender-generated low-poly tree GLBs when available; fall back to
	# procedural cones if the asset pack is missing.
	# v6.4 — Doubled tree count (9 → 18) for denser forest backdrop.
	var tree_positions := [
		# Original 9 (back row + middle)
		Vector3(-4.5, 0, -5.0), Vector3(-3.0, 0, -4.5), Vector3(-1.5, 0, -5.2),
		Vector3(0.0, 0, -5.8), Vector3(1.5, 0, -5.2), Vector3(3.0, 0, -4.5),
		Vector3(4.5, 0, -5.0), Vector3(-2.0, 0, -3.5), Vector3(2.0, 0, -3.5),
		# v6.4 — 9 additional trees, sides + further back for depth
		Vector3(-6.0, 0, -6.5), Vector3(-4.5, 0, -7.0), Vector3(0.0, 0, -7.5),
		Vector3(4.5, 0, -7.0), Vector3(6.0, 0, -6.5),
		Vector3(-5.5, 0, -3.0), Vector3(5.5, 0, -3.0),
		Vector3(-3.0, 0, -6.5), Vector3(3.0, 0, -6.5),
	]
	var glb_ok := ResourceLoader.exists(FOREST_GLB_DIR + FOREST_TREE_GLBS[0])
	if glb_ok:
		for i in range(tree_positions.size()):
			var pos: Vector3 = tree_positions[i]
			var glb_name: String = FOREST_TREE_GLBS[i % FOREST_TREE_GLBS.size()]
			var sc: float = randf_range(0.85, 1.15)
			var ry: float = randf_range(-PI, PI)
			var tree_node: Node3D = _instantiate_glb_at(parent, FOREST_GLB_DIR + glb_name, pos, sc, ry)
			# v6.4 — wind sway anim per tree (random phase, ±2-3° Z rotation, 3-5s loop)
			if tree_node:
				_apply_wind_sway(parent, tree_node)
		# v5.7 — Pushed BEHIND plateau (was Z=-2.4..-2.8 = sur le plateau, "objets
		# inutiles" reported by user). Now Z=-4.0..-4.5 = clearly behind trees,
		# and only 2 props (was 4 — decluttered).
		var prop_positions := [
			Vector3(-3.8, 0, -4.2),
			Vector3(3.5, 0, -4.0),
		]
		for i in range(prop_positions.size()):
			var glb_name: String = FOREST_PROP_GLBS[i % FOREST_PROP_GLBS.size()]
			var sc: float = randf_range(0.9, 1.3)
			var ry: float = randf_range(-PI, PI)
			_instantiate_glb_at(parent, FOREST_GLB_DIR + glb_name, prop_positions[i], sc, ry)
		return
	# v7.5 — Fallback : procedural cones now use MultiMeshInstance3D (refs
	# `external/multi_mesh_manager/`). 18 identical meshes × 2 (main + outline)
	# = 2 draw calls instead of 36 individual MeshInstance3D + outline children.
	# Per user feedback 2026-05-15 part 19 : "Emploie le projet git qui permettait
	# à des elements dupliqués dans la scène d'etre peu consommateur".
	_spawn_multimesh_trees(parent, tree_positions, "foret_broceliande")


## v6.4 — Procedural grass floor under the plateau + extended around forest base.
## 20×20m PlaneMesh with NoiseTexture2D albedo for grass mottling.
## Positioned slightly below plateau (Y=-0.02) so it doesn't clip the plateau circle.
static func _build_grass_floor(parent: Node, biome_id: String = "foret_broceliande") -> void:
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "GrassFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	plane.subdivide_depth = 4
	plane.subdivide_width = 4
	floor_mi.mesh = plane
	floor_mi.position = Vector3(0.0, -0.02, -2.0)  # centered under plateau, extended forest-side
	# v7.4 — Pull base + gradient stops from BiomePalettes (bible §22 v3.4).
	# Look up the "foliage"/"hill"/"bog"/etc. slot per biome — pick the 2nd narrative
	# slot which is typically the ground-organic color in each palette.
	var p_palette: Dictionary = BiomePalettes.get_palette(biome_id)
	var narrative_slots: Array = []
	for k in p_palette.keys():
		if k != "accent" and k != "outline":
			narrative_slots.append(p_palette[k])
	var base_color: Color = narrative_slots[1] if narrative_slots.size() > 1 else Color(0.32, 0.50, 0.22)
	var darker_color: Color = base_color * 0.62
	var brighter_color: Color = base_color.lerp(Color.WHITE, 0.18)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color
	# Noise texture for grass mottling — biome-tinted gradient.
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.12
	noise.fractal_octaves = 3
	var grass_tex := NoiseTexture2D.new()
	grass_tex.noise = noise
	grass_tex.width = 512
	grass_tex.height = 512
	var grad := Gradient.new()
	grad.set_color(0, darker_color)
	grad.set_color(1, brighter_color)
	grass_tex.color_ramp = grad
	mat.albedo_texture = grass_tex
	mat.roughness = 0.96
	mat.metallic = 0.0
	floor_mi.material_override = mat
	parent.add_child(floor_mi)


## v6.4 — CPUParticles3D pollen drifting upward through the scene.
static func _spawn_pollen_particles(parent: Node) -> void:
	var pollen := CPUParticles3D.new()
	pollen.name = "PollenParticles"
	pollen.amount = 24
	pollen.lifetime = 8.0
	pollen.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	pollen.emission_box_extents = Vector3(6.0, 0.1, 4.0)
	pollen.position = Vector3(0.0, 0.5, -1.5)
	pollen.direction = Vector3(0.0, 1.0, 0.0)
	pollen.initial_velocity_min = 0.05
	pollen.initial_velocity_max = 0.12
	pollen.angular_velocity_min = -10.0
	pollen.angular_velocity_max = 10.0
	pollen.gravity = Vector3(0.05, 0.02, 0.0)  # subtle horizontal drift
	pollen.scale_amount_min = 0.02
	pollen.scale_amount_max = 0.05
	pollen.color = Color(0.95, 0.92, 0.55, 0.65)  # soft yellow pollen
	var sphere := SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	pollen.mesh = sphere
	parent.add_child(pollen)


## v6.4 — Apply subtle wind sway animation to a tree node. Tween rotation Z
## ±2° over 3-5s loop with random phase so trees don't sync.
static func _apply_wind_sway(host: Node, tree: Node3D) -> void:
	if tree == null or not is_instance_valid(tree):
		return
	var period: float = randf_range(2.8, 4.2)
	var amplitude: float = deg_to_rad(randf_range(1.5, 3.0))
	var tw := host.create_tween().set_loops()
	tw.tween_property(tree, "rotation:z", amplitude, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(tree, "rotation:z", -amplitude, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func _build_heath(parent: Node) -> void:
	# v7.4 — Pull colors from BiomePalettes (bible §22 v3.4) instead of hardcoded.
	_build_grass_floor(parent, "landes_bruyere")
	var p: Dictionary = BiomePalettes.get_palette("landes_bruyere")
	# Low rolling mounds + sparse tall reeds (bruyère + cairns motif)
	for i in range(8):
		var x: float = lerp(-BACKDROP_X_HALF, BACKDROP_X_HALF, float(i) / 7.0)
		var z: float = _arc_z(i, 8)
		var mound := SphereMesh.new()
		mound.radius = randf_range(0.9, 1.4)
		mound.height = randf_range(0.4, 0.7)
		mound.radial_segments = 12
		mound.rings = 6
		# Alternate between heather (mounds covered in bruyère) and stone (cairn-like).
		var color: Color = p.get("heather", Color(0.42, 0.30, 0.45)) if (i % 2 == 0) \
			else p.get("stone", Color(0.48, 0.48, 0.45))
		_spawn(parent, mound, Vector3(x, mound.height * 0.3, z), color)
	for j in range(5):
		var reed := CylinderMesh.new()
		reed.top_radius = 0.04
		reed.bottom_radius = 0.06
		reed.height = randf_range(1.0, 1.4)
		var rx: float = randf_range(-BACKDROP_X_HALF, BACKDROP_X_HALF)
		_spawn(parent, reed, Vector3(rx, reed.height * 0.5, randf_range(-5, -3)),
			p.get("shadow", Color(0.55, 0.42, 0.20)))


static func _build_coast(parent: Node) -> void:
	# v7.4 — BiomePalettes (bible §22).
	_build_grass_floor(parent, "cotes_sauvages")
	var p: Dictionary = BiomePalettes.get_palette("cotes_sauvages")
	var sea := BoxMesh.new()
	sea.size = Vector3(14.0, 0.2, 4.0)
	_spawn(parent, sea, Vector3(0, -0.4, -6.0), p.get("sea", Color(0.15, 0.30, 0.50)), 0.15)
	for i in range(6):
		var rock := SphereMesh.new()
		rock.radius = randf_range(0.4, 0.9)
		rock.height = randf_range(0.5, 0.9)
		rock.radial_segments = 8
		rock.rings = 5
		var x: float = lerp(-BACKDROP_X_HALF, BACKDROP_X_HALF, float(i) / 5.0) + randf_range(-0.4, 0.4)
		_spawn(parent, rock, Vector3(x, rock.height * 0.3, _arc_z(i, 6)),
			p.get("cliff", Color(0.32, 0.38, 0.42)))


static func _build_village(parent: Node) -> void:
	# v7.4 — BiomePalettes (bible §22).
	_build_grass_floor(parent, "villages_celtes")
	var p: Dictionary = BiomePalettes.get_palette("villages_celtes")
	for i in range(5):
		var x: float = lerp(-BACKDROP_X_HALF, BACKDROP_X_HALF, float(i) / 4.0)
		var z: float = _arc_z(i, 5)
		var wall_h: float = randf_range(0.8, 1.2)
		var wall := BoxMesh.new()
		wall.size = Vector3(1.0, wall_h, 1.0)
		_spawn(parent, wall, Vector3(x, wall_h * 0.5, z),
			p.get("wattle", Color(0.42, 0.30, 0.20)))
		var roof := CylinderMesh.new()
		roof.top_radius = 0.02
		roof.bottom_radius = 0.75
		roof.height = 0.7
		roof.radial_segments = 4
		_spawn(parent, roof, Vector3(x, wall_h + 0.35, z),
			p.get("thatch", Color(0.55, 0.20, 0.12)))
		if i == 2:
			var hearth := SphereMesh.new()
			hearth.radius = 0.18
			hearth.height = 0.32
			# Hearth uses ember slot — warm orange glowing slot of villages palette.
			_spawn(parent, hearth, Vector3(x, 0.4, z + 0.8),
				p.get("ember", Color(0.98, 0.55, 0.18)), 2.0)


static func _build_stones(parent: Node) -> void:
	# v7.4 — BiomePalettes (bible §22).
	_build_grass_floor(parent, "cercles_pierres")
	var p: Dictionary = BiomePalettes.get_palette("cercles_pierres")
	for i in range(7):
		var angle: float = lerp(PI * 0.85, PI * 0.15, float(i) / 6.0)
		var radius: float = 4.8
		var x: float = cos(angle) * radius
		var z: float = -sin(angle) * radius - 1.0
		var stone := BoxMesh.new()
		stone.size = Vector3(randf_range(0.5, 0.9), randf_range(2.0, 3.2), randf_range(0.3, 0.5))
		var mi := _spawn(parent, stone, Vector3(x, stone.size.y * 0.5, z),
			p.get("granite", Color(0.42, 0.46, 0.50)))
		mi.rotation = Vector3(randf_range(-0.05, 0.05), randf_range(-0.2, 0.2), randf_range(-0.05, 0.05))


static func _build_marsh(parent: Node) -> void:
	# v7.4 — BiomePalettes (bible §22).
	_build_grass_floor(parent, "marais_korrigans")
	var p: Dictionary = BiomePalettes.get_palette("marais_korrigans")
	for i in range(7):
		var x: float = lerp(-BACKDROP_X_HALF, BACKDROP_X_HALF, float(i) / 6.0) + randf_range(-0.3, 0.3)
		var z: float = _arc_z(i, 7)
		var mound := SphereMesh.new()
		mound.radius = randf_range(0.8, 1.3)
		mound.height = randf_range(0.5, 0.8)
		mound.radial_segments = 10
		mound.rings = 5
		_spawn(parent, mound, Vector3(x, mound.height * 0.2, z),
			p.get("mire", Color(0.20, 0.28, 0.16)))
	for j in range(3):
		var wisp := SphereMesh.new()
		wisp.radius = 0.12
		wisp.height = 0.22
		# Will-o-wisps use wisp slot — luminescent pale green emissive.
		_spawn(parent, wisp, Vector3(randf_range(-3, 3), randf_range(0.5, 1.5), randf_range(-5, -3)),
			p.get("wisp", Color(0.75, 0.95, 0.40)), 2.5)


static func _build_dolmens(parent: Node) -> void:
	# v7.4 — BiomePalettes (bible §22).
	_build_grass_floor(parent, "collines_dolmens")
	var p: Dictionary = BiomePalettes.get_palette("collines_dolmens")
	var dolmen_color: Color = p.get("earth", Color(0.50, 0.48, 0.42))
	var cap_color: Color = p.get("shadow", Color(0.45, 0.42, 0.36))
	for i in range(3):
		var cx: float = lerp(-3.5, 3.5, float(i) / 2.0)
		var cz: float = _arc_z(i, 3)
		var pillar_h: float = randf_range(1.6, 2.0)
		var left := BoxMesh.new()
		left.size = Vector3(0.55, pillar_h, 0.55)
		_spawn(parent, left, Vector3(cx - 0.55, pillar_h * 0.5, cz), dolmen_color)
		var right := BoxMesh.new()
		right.size = Vector3(0.55, pillar_h, 0.55)
		_spawn(parent, right, Vector3(cx + 0.55, pillar_h * 0.5, cz), dolmen_color)
		var cap := BoxMesh.new()
		cap.size = Vector3(1.7, 0.3, 0.75)
		_spawn(parent, cap, Vector3(cx, pillar_h + 0.15, cz), cap_color)


static func _build_isles(parent: Node) -> void:
	# v7.4 — BiomePalettes (bible §22).
	_build_grass_floor(parent, "iles_mystiques")
	var p: Dictionary = BiomePalettes.get_palette("iles_mystiques")
	var sea := BoxMesh.new()
	sea.size = Vector3(14.0, 0.2, 4.0)
	_spawn(parent, sea, Vector3(0, -0.4, -6.0),
		p.get("teal", Color(0.10, 0.20, 0.35)), 0.20)
	for i in range(5):
		var cone := CylinderMesh.new()
		cone.top_radius = 0.02
		cone.bottom_radius = randf_range(0.7, 1.1)
		cone.height = randf_range(2.0, 3.0)
		cone.radial_segments = 5
		var x: float = lerp(-BACKDROP_X_HALF, BACKDROP_X_HALF, float(i) / 4.0)
		_spawn(parent, cone, Vector3(x, cone.height * 0.5, _arc_z(i, 5)),
			p.get("violet", Color(0.16, 0.20, 0.28)))
	var orb := SphereMesh.new()
	orb.radius = 0.18
	orb.height = 0.36
	# Floating orb = pearl/luminescent — Niamh fey light.
	_spawn(parent, orb, Vector3(0, 2.5, -5.5),
		p.get("pearl", Color(0.65, 0.92, 1.00)), 3.0)
