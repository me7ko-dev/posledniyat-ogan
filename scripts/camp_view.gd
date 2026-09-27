extends Control
## Лагерът: снежна поляна, борове, огънят, оцелелите около него и снегът.
## Всичко е рисувано с код. Поляната и боровете стигат до краищата на прозореца.

signal tapped(local_pos: Vector2)

const SurvivorLayer := preload("res://scripts/survivor_layer.gd")

const SNOW := Color(0.30, 0.35, 0.48)
const PINE := Color(0.035, 0.06, 0.13)
const STONE := Color(0.33, 0.34, 0.39)
const LOG := Color(0.36, 0.22, 0.12)

var fire_level := 1
var cold := false
var survivors := 0

var _intensity := 0.9
var _boost := 0.0  # кратко пламване при ново ниво на огъня
var _t := 0.0
var _trees := []  # [x от 0 до 1, височина, оттенък]
var _back: Node2D
var _front: Node2D
var _fire: Node2D
var _glow: Sprite2D
var _flames: CPUParticles2D
var _core: CPUParticles2D
var _sparks: CPUParticles2D
var _chips: CPUParticles2D
var _snow: CPUParticles2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for k in 26:
		_trees.append([rng.randf(), rng.randf_range(0.55, 1.1), rng.randf()])
	_trees.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])

	var soft := radial_texture(64, [Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_back = SurvivorLayer.new()
	add_child(_back)

	_glow = Sprite2D.new()
	_glow.texture = radial_texture(256,
		[Color(1.0, 0.55, 0.2, 0.5), Color(1.0, 0.4, 0.1, 0.14), Color(1.0, 0.3, 0.1, 0.0)], [0.0, 0.45, 1.0])
	_glow.material = add_material()
	add_child(_glow)

	_fire = Node2D.new()
	add_child(_fire)
	_flames = _make_flames(soft)
	_fire.add_child(_flames)
	_core = _make_core(soft)
	_fire.add_child(_core)
	_sparks = _make_sparks(soft)
	_fire.add_child(_sparks)

	_chips = _make_chips()
	add_child(_chips)

	_front = SurvivorLayer.new()
	_front.front = true
	add_child(_front)

	_snow = _make_snow(soft)
	add_child(_snow)

	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()


func fire_pos() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.66)


## Целият прозорец в координатите на лагера (за поляната, боровете и снега).
func _view_rect() -> Rect2:
	return Rect2(-global_position, get_viewport_rect().size)


func _layout() -> void:
	var c := fire_pos()
	_fire.position = c
	_glow.position = c + Vector2(0, -30)
	_back.center = c
	_front.center = c
	var v := _view_rect()
	_snow.position = Vector2(v.get_center().x, -20.0)
	_snow.emission_rect_extents = Vector2(v.size.x * 0.5 + 60.0, 10.0)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_boost = maxf(0.0, _boost - delta * 0.6)
	var target := 0.35 if cold else minf(0.85 + 0.12 * (fire_level - 1), 2.0)
	_intensity = lerpf(_intensity, target + _boost, 1.0 - exp(-delta * 2.5))

	var flicker := 1.0 + 0.05 * sin(_t * 11.0) + 0.04 * sin(_t * 17.3 + 1.0) + 0.03 * sin(_t * 5.1)
	_fire.scale = Vector2.ONE * _intensity
	_glow.scale = Vector2(3.0, 2.1) * (0.55 + 0.45 * _intensity) * flicker
	_glow.modulate.a = clampf(0.4 + 0.3 * _intensity, 0.3, 0.9)
	_fire.modulate = _fire.modulate.lerp(Color(1.0, 0.65, 0.55) if cold else Color.WHITE, delta * 2.0)

	for layer in [_back, _front]:
		layer.warmth = _intensity
		layer.count = survivors


## Трески при удар с брадвата.
func burst(at: Vector2) -> void:
	_chips.position = at
	_chips.restart()


func burst_fire() -> void:
	burst(fire_pos() + Vector2(0, -10))


## Огънят пламва за миг (при ново ниво).
func flare() -> void:
	_boost = 0.7


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(event.position)
		accept_event()


func _draw() -> void:
	var c := fire_pos()
	var v := _view_rect()
	var horizon := c.y - 125.0

	# далечни борове по цялата ширина на прозореца
	for tr: Array in _trees:
		var col := PINE.lerp(Color(0.07, 0.1, 0.19), tr[2])
		_draw_pine(Vector2(v.position.x + tr[0] * v.size.x, horizon + 14.0), 120.0 * tr[1], col)

	# снежна поляна (продължава надолу зад менюто)
	var ground := PackedVector2Array()
	var steps := 24
	for k in steps + 1:
		var x := v.position.x + v.size.x * k / steps
		ground.append(Vector2(x, horizon + 6.0 * sin(x * 0.02)))
	ground.append(Vector2(v.end.x, v.end.y + 50.0))
	ground.append(Vector2(v.position.x, v.end.y + 50.0))
	draw_colored_polygon(ground, SNOW)

	# жарава под огъня
	draw_set_transform(c + Vector2(0, -2), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 36.0, Color(0.55, 0.18, 0.08, 0.9) if cold else Color(1.0, 0.45, 0.12, 0.9))
	draw_set_transform_matrix(Transform2D.IDENTITY)

	# кръг от камъни
	for k in 12:
		var a := TAU * k / 12.0
		var p := c + Vector2(cos(a) * 50.0, sin(a) * 17.0 + 4.0)
		draw_set_transform(p, 0.0, Vector2(1.0, 0.7))
		draw_circle(Vector2.ZERO, 9.0, STONE.darkened(0.25) if sin(a) > 0.0 else STONE)
		draw_set_transform_matrix(Transform2D.IDENTITY)

	# цепеници на кръст
	for rot in [0.38, -0.38]:
		draw_set_transform(c + Vector2(0, 2), rot, Vector2.ONE)
		draw_rect(Rect2(-42, -7, 84, 14), LOG)
		draw_circle(Vector2(-42, 0), 7.0, LOG.lightened(0.25))
		draw_circle(Vector2(42, 0), 7.0, LOG.lightened(0.25))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_pine(base: Vector2, h: float, col: Color) -> void:
	draw_rect(Rect2(base + Vector2(-3, -h * 0.12), Vector2(6, h * 0.12)), col)
	for k in 3:
		var bottom := base.y - h * 0.1 - h * 0.25 * k
		var half := h * 0.26 * (1.0 - k * 0.22)
		draw_colored_polygon(PackedVector2Array([
			Vector2(base.x - half, bottom),
			Vector2(base.x + half, bottom),
			Vector2(base.x, bottom - h * 0.42),
		]), col)


# --- Частици ---

## Външните пламъци: оранжеви езици, които се стесняват нагоре.
func _make_flames(tex: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 1.0
	p.preprocess = 1.0
	p.local_coords = true
	p.texture = tex
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(28, 4)
	p.direction = Vector2(0, -1)
	p.spread = 8.0
	p.gravity = Vector2(0, -70)
	p.initial_velocity_min = 45.0
	p.initial_velocity_max = 95.0
	p.radial_accel_min = -70.0  # дърпа пламъците към средата — стават на език
	p.radial_accel_max = -45.0
	p.scale_amount_min = 0.55
	p.scale_amount_max = 0.85
	p.scale_amount_curve = curve([Vector2(0, 0.7), Vector2(0.2, 1.0), Vector2(1, 0.15)])
	p.color_ramp = gradient(
		[Color(1, 0.78, 0.25, 0.9), Color(1, 0.48, 0.1, 0.8), Color(0.85, 0.2, 0.05, 0.45), Color(0.3, 0.05, 0.02, 0)],
		[0.0, 0.3, 0.65, 1.0])
	return p


## Светлата сърцевина на огъня.
func _make_core(tex: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 22
	p.lifetime = 0.6
	p.preprocess = 1.0
	p.local_coords = true
	p.texture = tex
	p.material = add_material()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(16, 3)
	p.direction = Vector2(0, -1)
	p.spread = 6.0
	p.gravity = Vector2(0, -60)
	p.initial_velocity_min = 35.0
	p.initial_velocity_max = 70.0
	p.radial_accel_min = -60.0
	p.radial_accel_max = -40.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.55
	p.scale_amount_curve = curve([Vector2(0, 1.0), Vector2(1, 0.2)])
	p.color_ramp = gradient([Color(1, 0.95, 0.7, 0.55), Color(1, 0.75, 0.3, 0.35), Color(1, 0.5, 0.1, 0)], [0.0, 0.5, 1.0])
	return p


func _make_sparks(tex: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 14
	p.lifetime = 1.8
	p.preprocess = 2.0
	p.local_coords = true
	p.texture = tex
	p.material = add_material()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(20, 4)
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2(0, -25)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 140.0
	p.damping_min = 20.0
	p.damping_max = 40.0
	p.tangential_accel_min = -40.0
	p.tangential_accel_max = 40.0
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.15
	p.color_ramp = gradient([Color(1, 0.9, 0.5, 1), Color(1, 0.5, 0.1, 0.8), Color(1, 0.3, 0.05, 0)], [0.0, 0.5, 1.0])
	return p


func _make_chips() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 1.0
	p.amount = 12
	p.lifetime = 0.7
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, 700)
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 280.0
	p.angular_velocity_min = -500.0
	p.angular_velocity_max = 500.0
	p.scale_amount_min = 5.0
	p.scale_amount_max = 9.0
	p.color = Color(0.82, 0.62, 0.38)
	p.color_ramp = gradient([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 0.7, 1.0])
	return p


## Снегът вали пред лагера, но зад менюто — не пречи на надписите.
func _make_snow(tex: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 90
	p.lifetime = 30.0
	p.preprocess = 30.0
	p.texture = tex
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0.15, 1.0)
	p.spread = 12.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 35.0
	p.initial_velocity_max = 70.0
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.17
	p.color_ramp = gradient([Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)], [0.0, 0.85, 1.0])
	return p


static func radial_texture(px: int, colors: Array, offsets: Array = []) -> GradientTexture2D:
	var t := GradientTexture2D.new()
	t.gradient = gradient(colors, offsets)
	t.width = px
	t.height = px
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


static func gradient(colors: Array, offsets: Array = []) -> Gradient:
	var g := Gradient.new()
	if offsets.is_empty():
		for k in colors.size():
			offsets.append(float(k) / (colors.size() - 1))
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g


static func curve(points: Array) -> Curve:
	var c := Curve.new()
	for p: Vector2 in points:
		c.add_point(p)
	return c


static func add_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m
