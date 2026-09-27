extends Control
## Нощното небе: преливащ цвят, трептящи звезди и луна.

var _tex: GradientTexture2D
var _stars := []  # [позиция (0..1), радиус, скорост на трептене, фаза]
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color("#070b1c"), Color("#131a36"), Color("#26263f")])
	_tex = GradientTexture2D.new()
	_tex.gradient = g
	_tex.width = 4
	_tex.height = 256
	_tex.fill_from = Vector2(0, 0)
	_tex.fill_to = Vector2(0, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 90:
		_stars.append([Vector2(rng.randf(), rng.randf() * 0.4), rng.randf_range(0.8, 2.2),
			rng.randf_range(0.5, 2.5), rng.randf() * TAU])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
	for s: Array in _stars:
		var a := 0.5 + 0.5 * sin(_t * s[2] + s[3])
		draw_circle(s[0] * size, s[1], Color(1, 1, 1, 0.3 + 0.5 * a))
	var moon := Vector2(size.x * 0.82, size.y * 0.17)
	draw_circle(moon, 70.0, Color(0.8, 0.85, 1.0, 0.05))
	draw_circle(moon, 44.0, Color(0.8, 0.85, 1.0, 0.08))
	draw_circle(moon, 27.0, Color("#e9ecf5"))
	draw_circle(moon + Vector2(-8, -5), 5.0, Color("#d3d7e3"))
	draw_circle(moon + Vector2(7, 8), 3.5, Color("#d3d7e3"))
