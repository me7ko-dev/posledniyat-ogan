extends Node3D
## Купчинка монети на земята. Героят минава наблизо и ги прибира.

const Models := preload("res://scripts/models.gd")
const MAX_SHOWN := 40
const COLS := [Vector2(-0.17, -0.17), Vector2(0.17, -0.17), Vector2(-0.17, 0.17), Vector2(0.17, 0.17)]
const STEP := 0.055

var count := 0
var _coins: Array[Node3D] = []


func add(n := 1) -> void:
	count += n
	_sync()


## Взима до `n` монети, връща колко е взело.
func take(n: int) -> int:
	n = mini(n, count)
	count -= n
	_sync()
	return n


func top_global() -> Vector3:
	return to_global(Vector3(0, 0.1 + ceili(mini(count, MAX_SHOWN) / 4.0) * STEP, 0))


func _sync() -> void:
	var want := mini(count, MAX_SHOWN)
	while _coins.size() < want:
		var i := _coins.size()
		var c := Models.coin()
		var col: Vector2 = COLS[i % 4]
		c.position = Vector3(col.x + randf_range(-0.02, 0.02), 0.03 + (i / 4) * STEP, col.y + randf_range(-0.02, 0.02))
		c.rotation.y = randf() * TAU
		add_child(c)
		_coins.append(c)
	while _coins.size() > want:
		_coins.pop_back().queue_free()
