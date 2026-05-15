## ═══════════════════════════════════════════════════════════════════════════════
## BoardBiomeAmbience — Per-biome lighting / particles / plateau material presets.
## ═══════════════════════════════════════════════════════════════════════════════
## Static helper. Applied by board_narration.gd._apply_biome().
##
## Each biome preset specifies:
##   main_light_color        : DirectionalLight3D tint
##   main_light_energy       : intensity
##   main_light_direction    : (x, y, z) unit vector
##   ambient_color           : Environment ambient
##   plateau_albedo          : plateau MeshInstance material albedo
##   plateau_emission        : low emissive accent
##   particle_color          : drifting particle tint (RGBA)
##   particle_amount         : GPUParticles3D amount cap
##   particle_velocity       : initial velocity Y component
##   particle_gravity        : gravity Y component
##   mood_label              : 1-2 word descriptor for narration prompt
##
## All eight bible v2.4 biomes are covered with distinct presets.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name BoardBiomeAmbience

const DEFAULT_BIOME := "foret_broceliande"

const PRESETS := {
	"foret_broceliande": {
		"main_light_color": Color(0.62, 0.86, 0.55),
		"main_light_energy": 1.4,
		"main_light_direction": Vector3(-0.45, -0.78, -0.30),
		"ambient_color": Color(0.10, 0.18, 0.12),
		"plateau_albedo": Color(0.16, 0.22, 0.14),
		"plateau_emission": Color(0.05, 0.10, 0.04),
		"particle_color": Color(0.55, 0.82, 0.45, 0.75),
		"particle_amount": 120,
		"particle_velocity": -0.20,
		"particle_gravity": -0.10,
		"mood_label": "verdoyant",
	},
	"landes_bruyere": {
		"main_light_color": Color(0.95, 0.68, 0.42),
		"main_light_energy": 1.7,
		"main_light_direction": Vector3(0.65, -0.45, -0.30),
		"ambient_color": Color(0.22, 0.14, 0.10),
		"plateau_albedo": Color(0.28, 0.20, 0.14),
		"plateau_emission": Color(0.12, 0.06, 0.02),
		"particle_color": Color(0.92, 0.65, 0.38, 0.65),
		"particle_amount": 180,
		"particle_velocity": 0.80,
		"particle_gravity": 0.0,
		"mood_label": "venteux",
	},
	"cotes_sauvages": {
		"main_light_color": Color(0.62, 0.80, 0.95),
		"main_light_energy": 1.6,
		"main_light_direction": Vector3(0.20, -0.88, -0.40),
		"ambient_color": Color(0.10, 0.14, 0.22),
		"plateau_albedo": Color(0.16, 0.22, 0.28),
		"plateau_emission": Color(0.04, 0.08, 0.12),
		"particle_color": Color(0.72, 0.88, 0.98, 0.55),
		"particle_amount": 60,
		"particle_velocity": 0.40,
		"particle_gravity": -0.05,
		"mood_label": "iode",
	},
	"villages_celtes": {
		"main_light_color": Color(0.95, 0.55, 0.30),
		"main_light_energy": 1.5,
		"main_light_direction": Vector3(0.0, -0.65, 0.75),
		"ambient_color": Color(0.20, 0.12, 0.06),
		"plateau_albedo": Color(0.24, 0.16, 0.10),
		"plateau_emission": Color(0.18, 0.08, 0.02),
		"particle_color": Color(0.98, 0.62, 0.22, 0.85),
		"particle_amount": 90,
		"particle_velocity": 1.20,
		"particle_gravity": 0.05,
		"mood_label": "ardent",
	},
	"cercles_pierres": {
		"main_light_color": Color(0.58, 0.66, 0.82),
		"main_light_energy": 1.2,
		"main_light_direction": Vector3(0.10, -0.92, -0.20),
		"ambient_color": Color(0.08, 0.10, 0.16),
		"plateau_albedo": Color(0.20, 0.22, 0.26),
		"plateau_emission": Color(0.05, 0.06, 0.10),
		"particle_color": Color(0.62, 0.72, 0.85, 0.45),
		"particle_amount": 140,
		"particle_velocity": -0.05,
		"particle_gravity": 0.0,
		"mood_label": "mineral",
	},
	"marais_korrigans": {
		"main_light_color": Color(0.66, 0.78, 0.32),
		"main_light_energy": 1.3,
		"main_light_direction": Vector3(0.55, -0.55, -0.55),
		"ambient_color": Color(0.10, 0.14, 0.06),
		"plateau_albedo": Color(0.18, 0.20, 0.10),
		"plateau_emission": Color(0.08, 0.12, 0.04),
		"particle_color": Color(0.78, 0.88, 0.30, 0.80),
		"particle_amount": 60,
		"particle_velocity": 0.10,
		"particle_gravity": -0.20,
		"mood_label": "trompeur",
	},
	"collines_dolmens": {
		"main_light_color": Color(0.82, 0.72, 0.48),
		"main_light_energy": 1.4,
		"main_light_direction": Vector3(0.0, -0.95, -0.20),
		"ambient_color": Color(0.16, 0.14, 0.10),
		"plateau_albedo": Color(0.30, 0.26, 0.20),
		"plateau_emission": Color(0.10, 0.08, 0.04),
		"particle_color": Color(0.85, 0.78, 0.55, 0.50),
		"particle_amount": 80,
		"particle_velocity": -0.05,
		"particle_gravity": -0.02,
		"mood_label": "ancestral",
	},
	"iles_mystiques": {
		"main_light_color": Color(0.55, 0.85, 0.92),
		"main_light_energy": 1.5,
		"main_light_direction": Vector3(0.10, -0.80, -0.20),
		"ambient_color": Color(0.06, 0.12, 0.14),
		"plateau_albedo": Color(0.08, 0.10, 0.14),
		"plateau_emission": Color(0.04, 0.10, 0.12),
		"particle_color": Color(0.78, 0.92, 0.98, 0.65),
		"particle_amount": 60,
		"particle_velocity": -0.30,
		"particle_gravity": -0.05,
		"mood_label": "ethere",
	},
}


## Returns the preset dictionary for a biome, with safe fallback.
static func get_preset(biome_id: String) -> Dictionary:
	if PRESETS.has(biome_id):
		return PRESETS[biome_id]
	push_warning("[BoardBiomeAmbience] Unknown biome '%s', falling back to %s" % [biome_id, DEFAULT_BIOME])
	return PRESETS[DEFAULT_BIOME]


## Apply a biome preset to a DirectionalLight3D + Environment + plateau MeshInstance3D + GPUParticles3D.
## Any node may be null — applies what it can.
static func apply_to_nodes(
		biome_id: String,
		light: DirectionalLight3D,
		env: Environment,
		plateau: MeshInstance3D,
		particles: GPUParticles3D
	) -> void:
	var preset: Dictionary = get_preset(biome_id)

	if light:
		light.light_color = preset["main_light_color"]
		light.light_energy = float(preset["main_light_energy"])
		var dir: Vector3 = preset["main_light_direction"]
		# Guard against zero-vector direction (look_at crashes with "origin and target too close").
		if dir.length_squared() > 0.0001:
			# Pick a stable UP that is not parallel to dir (avoid gimbal singularity).
			var up: Vector3 = Vector3.UP
			if absf(dir.normalized().dot(Vector3.UP)) > 0.99:
				up = Vector3.FORWARD
			light.look_at_from_position(light.position, light.position + dir, up)

	if env:
		env.ambient_light_color = preset["ambient_color"]
		env.ambient_light_energy = 0.6
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.02, 0.04, 0.05)
		env.glow_enabled = true
		env.glow_intensity = 0.6
		env.glow_bloom = 0.10

	if plateau:
		var mat: StandardMaterial3D = plateau.get_active_material(0) as StandardMaterial3D
		if mat == null:
			mat = StandardMaterial3D.new()
			plateau.set_surface_override_material(0, mat)
		mat.albedo_color = preset["plateau_albedo"]
		mat.emission_enabled = true
		mat.emission = preset["plateau_emission"]
		mat.emission_energy_multiplier = 0.4
		mat.roughness = 0.85
		mat.metallic = 0.05

	if particles:
		particles.amount = int(preset["particle_amount"])
		particles.lifetime = 6.0
		particles.preprocess = 2.0
		particles.visibility_aabb = AABB(Vector3(-6, -2, -6), Vector3(12, 6, 12))
		var pmat: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
		if pmat == null:
			pmat = ParticleProcessMaterial.new()
			particles.process_material = pmat
		pmat.direction = Vector3(0, 1, 0)
		pmat.spread = 90.0
		pmat.initial_velocity_min = abs(float(preset["particle_velocity"])) * 0.5
		pmat.initial_velocity_max = abs(float(preset["particle_velocity"])) + 0.5
		pmat.gravity = Vector3(0, float(preset["particle_gravity"]), 0)
		pmat.color = preset["particle_color"]
		pmat.scale_min = 0.04
		pmat.scale_max = 0.12

		var draw_mesh: SphereMesh = particles.draw_pass_1 as SphereMesh
		if draw_mesh == null:
			draw_mesh = SphereMesh.new()
			draw_mesh.radius = 0.04
			draw_mesh.height = 0.08
			draw_mesh.radial_segments = 6
			draw_mesh.rings = 4
			particles.draw_pass_1 = draw_mesh
		var dmat: StandardMaterial3D = draw_mesh.material as StandardMaterial3D
		if dmat == null:
			dmat = StandardMaterial3D.new()
			draw_mesh.material = dmat
		dmat.albedo_color = preset["particle_color"]
		dmat.emission_enabled = true
		dmat.emission = preset["particle_color"]
		dmat.emission_energy_multiplier = 1.2
		dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

		particles.emitting = true


static func get_mood_label(biome_id: String) -> String:
	return str(get_preset(biome_id).get("mood_label", ""))
