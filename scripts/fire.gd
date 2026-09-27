extends Node3D
## Огънят. `fuel` = секунди горене. Повече дърва → по-голям пламък и повече светлина.

const B := preload("res://scripts/balance.gd")
const Models := preload("res://scripts/models.gd")
const Bar := preload("res://scripts/progress_bar_3d.gd")

var fuel := B.FUEL_START
var fuel_max := B.FUEL_MAX
var incoming := 0  # цепеници, които още летят към огъня
var big := false

var _flames: GPUParticles3D
var _flame_pm: ParticleProcessMaterial
var _smoke: GPUParticles3D
var _light: OmniLight3D
var _bar: Bar
var _flash := 0.0
var _t := 0.0


func _ready() -> void:
	add_child(Models.prop("campfire-pit", 1.7))
	# цепеници на куп
	for i in 5:
		var w := Models.prop("resource-wood", 1.6)
		var a := TAU * i / 5.0
		w.position = Vector3(sin(a) * 0.14, 0.08, cos(a) * 0.14)
		w.rotation = Vector3(0.0, a + PI / 2.0, 0.5)
		add_child(w)

	_flames = GPUParticles3D.new()
	_flames.amount = 56
	_flames.lifetime = 0.75
	_flame_pm = ParticleProcessMaterial.new()
	_flame_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_flame_pm.emission_sphere_radius = 0.28
	_flame_pm.direction = Vector3.UP
	_flame_pm.spread = 12.0
	_flame_pm.initial_velocity_min = 1.1
	_flame_pm.initial_velocity_max = 2.0
	_flame_pm.gravity = Vector3(0, 0.8, 0)
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(1.0, 0.15))
	var sct := CurveTexture.new()
	sct.curve = sc
	_flame_pm.scale_curve = sct
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 0.82, 0.4, 0.85), Color(1, 0.45, 0.08, 0.75), Color(0.6, 0.1, 0.03, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	_flame_pm.color_ramp = gt
	_flames.process_material = _flame_pm
	_flames.draw_pass_1 = _particle_quad(0.6, true)
	_flames.position.y = 0.25
	add_child(_flames)

	_smoke = GPUParticles3D.new()
	_smoke.amount = 16
	_smoke.lifetime = 2.2
	var spm := ParticleProcessMaterial.new()
	spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	spm.emission_sphere_radius = 0.2
	spm.direction = Vector3.UP
	spm.spread = 10.0
	spm.initial_velocity_min = 0.5
	spm.initial_velocity_max = 0.9
	spm.gravity = Vector3(0.2, 0.2, 0)
	spm.scale_min = 1.0
	spm.scale_max = 2.0
	spm.color = Color(0.55, 0.58, 0.65, 0.35)
	_smoke.process_material = spm
	_smoke.draw_pass_1 = _particle_quad(0.8, false)
	_smoke.position.y = 0.3
	_smoke.emitting = false
	add_child(_smoke)

	_light = OmniLight3D.new()
	_light.light_color = Color("#ff9a45")
	_light.omni_range = 9.0
	_light.position.y = 1.0
	add_child(_light)

	_bar = Bar.new()
	_bar.position.y = 2.3
	add_child(_bar)


func _particle_quad(size: float, additive: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Models.soft_dot()
	q.material = m
	return q


func burning() -> bool:
	return fuel > 0.0


## Има ли място за още една цепеница (броим и летящите).
func can_take() -> bool:
	return fuel + (incoming + 0.5) * B.FUEL_PER_LOG <= fuel_max + B.FUEL_PER_LOG * 0.5


func add_fuel(amount: float) -> void:
	incoming = maxi(0, incoming - 1)
	fuel = minf(fuel_max, fuel + amount)
	_flash = 1.0


func make_big() -> void:
	big = true
	fuel_max = B.FUEL_MAX_BIG
	for i in 8:
		var r := Models.prop(["rock-a", "rock-b", "rock-c"][i % 3], 0.55)
		var a := TAU * i / 8.0
		r.position = Vector3(sin(a) * 0.95, 0, cos(a) * 0.95)
		r.rotation.y = a
		add_child(r)


func _process(delta: float) -> void:
	_t += delta
	fuel = maxf(0.0, fuel - delta)
	_flash = maxf(0.0, _flash - delta * 3.0)
	var k := clampf(fuel / 30.0, 0.3, 1.0) if fuel > 0.0 else 0.0
	if big:
		k *= 1.25
	_flames.emitting = fuel > 0.0
	_smoke.emitting = fuel <= 0.0
	_flames.amount_ratio = clampf(0.35 + 0.65 * k, 0.0, 1.0)
	_flame_pm.scale_min = 0.5 + 0.9 * k
	_flame_pm.scale_max = 0.9 + 1.2 * k
	_flame_pm.initial_velocity_max = 1.4 + 1.2 * k
	var flicker := 0.85 + 0.15 * sin(_t * 17.0) * sin(_t * 7.3)
	_light.light_energy = (0.5 + 2.4 * k + _flash * 1.5) * flicker if fuel > 0.0 else 0.0
	_bar.set_value(fuel / fuel_max)
	_bar.set_color(Color(0.95, 0.25, 0.15) if fuel < 12.0 else Color(1.0, 0.62, 0.2))
