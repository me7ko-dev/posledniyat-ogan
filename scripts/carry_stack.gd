extends Node3D
## Купчината цепеници, която човечето носи пред гърдите.
## `incoming` са цепениците, които още летят към купчината (броят се към пълнотата).

const Models := preload("res://scripts/models.gd")
const STEP := 0.15

var capacity := 6
var incoming := 0
var _items: Array[Node3D] = []


func count() -> int:
	return _items.size()


func full() -> bool:
	return _items.size() + incoming >= capacity


func is_empty() -> bool:
	return _items.is_empty()


## Къде ще легне следващата цепеница (за летящите към нас).
func next_global() -> Vector3:
	return to_global(_slot(_items.size() + incoming))


## Върхът на купчината — там каца летящата цепеница.
func top_global() -> Vector3:
	return to_global(_slot(_items.size()))


func add() -> void:
	var piece := Models.prop("resource-wood", 1.15)
	piece.position = _slot(_items.size())
	piece.rotation.y = randf_range(-0.15, 0.15)
	add_child(piece)
	_items.append(piece)


## Маха горната цепеница и връща къде е била (оттам литва към огъня).
func remove_top() -> Vector3:
	var piece: Node3D = _items.pop_back()
	var p := piece.global_position
	piece.queue_free()
	return p


func _slot(i: int) -> Vector3:
	return Vector3(0, i * STEP, 0)
