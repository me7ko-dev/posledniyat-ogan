extends RefCounted
## Светът: снежна земя, лунна светлина, мъгла, падащ сняг и гората наоколо (само за красота).

const Models := preload("res://scripts/models.gd")
const B := preload("res://scripts/balance.gd")


static func build(root: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#131a30")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#a9b9e6")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("#27335a")
	env.fog_density = 0.016
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.08
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#c9d6ff")
	moon.light_energy = 0.75
	moon.rotation_degrees = Vector3(-58, 28, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 30.0
	root.add_child(moon)

	# снежна земя с леки петна
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(90, 90)
	ground.mesh = pm
	var noise := FastNoiseLite.new()
	noise.frequency = 0.035
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color("#b3c1dc"), Color("#e6edf8")])
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.color_ramp = ramp
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = tex
	gm.uv1_scale = Vector3(10, 10, 1)
	gm.roughness = 0.95
	ground.material_override = gm
	root.add_child(ground)

	# утъпкан кръг около огъня
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 5.0
	cm.bottom_radius = 5.0
	cm.height = 0.02
	cm.radial_segments = 48
	ring.mesh = cm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color("#a3b0ca")
	rm.roughness = 1.0
	ring.material_override = rm
	ring.position.y = 0.005
	root.add_child(ring)

	# гората наоколо — не се сече
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var placed := 0
	var tries := 0
	while placed < 90 and tries < 3000:
		tries += 1
		var p := Vector3(rng.randf_range(-26, 28), 0, rng.randf_range(-30, 9))
		var inside := p.x > B.BOUNDS.position.x - 2.0 and p.x < B.BOUNDS.end.x + 2.0 \
			and p.z > B.BOUNDS.position.y - 2.0 and p.z < B.BOUNDS.end.y + 3.0
		if inside:
			continue
		var t := Models.prop("tree-tall" if rng.randf() < 0.5 else "tree", rng.randf_range(0.9, 1.4))
		t.position = p
		t.rotation.y = rng.randf() * TAU
		root.add_child(t)
		placed += 1


## Сняг, който вали около камерата.
static func snow() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 320
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.visibility_aabb = AABB(Vector3(-16, -12, -16), Vector3(32, 16, 32))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(13, 0.5, 13)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 20.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0.35, -0.3, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.1, 0.1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = Models.soft_dot()
	m.albedo_color = Color(1, 1, 1, 0.9)
	q.material = m
	p.draw_pass_1 = q
	return p
