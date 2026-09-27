extends Node2D
## Рисува оцелелите около огъня. Има два такива слоя: зад огъня (осветени от него)
## и пред огъня (тъмни силуети с гръб към нас).

# [брой места, радиус на елипсата] — първо се пълни най-близкият кръг
const RINGS := [[10, Vector2(165, 48)], [14, Vector2(245, 78)], [18, Vector2(320, 108)]]
const COATS := [Color("#7a3b2e"), Color("#3e5c76"), Color("#5b6e3a"), Color("#8a6d3b"), Color("#6b4a7a"), Color("#2f5d5a"), Color("#9a4f2f")]
const HATS := [Color("#c0392b"), Color("#34495e"), Color("#d4a017"), Color("#1e8449"), Color("#e8e8e8"), Color("#884ea0")]
const SKINS := [Color("#f1c9a5"), Color("#e0ac84"), Color("#c68e63"), Color("#f5d6b8")]
const HAIR := Color("#2b1d14")
const FIRE_LIGHT := Color(1.0, 0.62, 0.3)
const APPEAR_TIME := 0.6

var front := false
var center := Vector2.ZERO
var warmth := 1.0  # колко силно свети огънят
var count := 0:
	set(v):
		if _started:
			for i in range(count, v):
				_born[i] = _t
		count = v

var _slots: Array[Vector2] = []
var _born := {}  # индекс → кога се е появил (за анимацията)
var _t := 0.0
var _started := false


func _ready() -> void:
	_slots = _build_slots()


func _process(delta: float) -> void:
	_t += delta
	_started = true
	queue_redraw()


## Местата около огъня в реда, в който се заемат.
static func _build_slots() -> Array[Vector2]:
	var slots: Array[Vector2] = []
	for ring in RINGS:
		var n: int = ring[0]
		var r: Vector2 = ring[1]
		var ring_slots: Array[Vector2] = []
		for k in n:
			var a := TAU * (k + 0.5) / n
			# точно пред и точно зад пламъците не сядат — да не ги закриват
			if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.45 or absf(wrapf(a - PI * 1.5, -PI, PI)) < 0.3:
				continue
			ring_slots.append(Vector2(cos(a) * r.x, sin(a) * r.y))
		ring_slots.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.y < q.y)
		slots.append_array(ring_slots)
	return slots


func _draw() -> void:
	var n := mini(count, _slots.size())
	var order := range(n)
	order.sort_custom(func(i: int, j: int) -> bool: return _slots[i].y < _slots[j].y)
	for i: int in order:
		var p := _slots[i]
		if (p.y >= 0.0) != front:
			continue
		var appear := clampf((_t - float(_born.get(i, -10.0))) / APPEAR_TIME, 0.0, 1.0)
		var depth := inverse_lerp(-110.0, 110.0, p.y)
		_draw_person(i, center + p, lerpf(0.72, 1.12, depth), appear)


func _draw_person(i: int, feet: Vector2, s: float, appear: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = i * 7919 + 13
	var coat: Color = COATS[rng.randi() % COATS.size()]
	var hat: Color = HATS[rng.randi() % HATS.size()]
	var skin: Color = SKINS[rng.randi() % SKINS.size()]
	var tall := rng.randf_range(0.9, 1.1)
	var wide := rng.randf_range(0.9, 1.15)

	# задните гледат към огъня и са осветени; предните са с гръб и са в сянка
	if front:
		coat = coat.darkened(0.45)
		hat = hat.darkened(0.4)
		skin = HAIR
	else:
		var glow := clampf(0.15 * warmth, 0.0, 0.3)
		coat = coat.lerp(FIRE_LIGHT, glow)
		hat = hat.lerp(FIRE_LIGHT, glow * 0.8)
		skin = skin.lerp(FIRE_LIGHT, glow * 0.6)

	# появяване: изскача с малко подскачане
	var pop := 1.0 + 0.25 * sin(appear * PI) if appear < 1.0 else 1.0
	s *= pop * appear
	if s <= 0.01:
		return
	var a := appear
	coat.a = a
	hat.a = a
	skin.a = a

	var bob := sin(_t * 1.6 + i * 1.3) * 1.2 * s
	var h := 56.0 * s * tall

	# сянка на снега
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 17.0 * s * wide, Color(0, 0, 0, 0.35 * a))
	draw_set_transform_matrix(Transform2D.IDENTITY)

	# палто
	var top := feet + Vector2(0, -h + bob)
	var body := PackedVector2Array([
		feet + Vector2(-15.0 * s * wide, 0),
		feet + Vector2(15.0 * s * wide, 0),
		top + Vector2(11.0 * s * wide, 16.0 * s),
		top + Vector2(-11.0 * s * wide, 16.0 * s),
	])
	draw_colored_polygon(body, coat)
	draw_circle(top + Vector2(0, 16.0 * s), 11.0 * s * wide, coat)
	# шал
	draw_rect(Rect2(top + Vector2(-9.0 * s, 9.0 * s), Vector2(18.0 * s, 4.5 * s)), hat)

	# глава и шапка с помпон
	var head := top + Vector2(0, 1.0 * s)
	draw_circle(head, 9.0 * s, skin)
	var cap := PackedVector2Array()
	for k in 13:
		var ang := PI + PI * k / 12.0
		cap.append(head + Vector2(cos(ang) * 9.8 * s, sin(ang) * 10.5 * s - 1.5 * s))
	draw_colored_polygon(cap, hat)
	draw_circle(head + Vector2(0, -12.5 * s), 3.2 * s, hat.lightened(0.35))
