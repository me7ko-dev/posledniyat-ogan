extends Node3D
## Дърво за сечене: дава няколко цепеници, после остава пън и след малко израства ново.

const B := preload("res://scripts/balance.gd")
const Models := preload("res://scripts/models.gd")
const Fx := preload("res://scripts/fx.gd")

var logs := B.TREE_LOGS
var reserved: Node = null  # дърварят, който е тръгнал към него
var model := "tree"
var _tree: Node3D
var _stump: Node3D
var _regrow := 0.0


func _ready() -> void:
	_tree = Models.prop(model, randf_range(1.0, 1.15))
	_tree.rotation.y = randf() * TAU
	add_child(_tree)
	_stump = Models.prop("tree-trunk", 1.4)
	_stump.visible = false
	add_child(_stump)


func has_logs() -> bool:
	return logs > 0


## Взима една цепеница. Връща false, ако дървото е отсечено.
func take_log() -> bool:
	if logs <= 0:
		return false
	logs -= 1
	if logs == 0:
		_tree.visible = false
		_stump.visible = true
		Fx.pop(_stump, 0.25)
		_regrow = B.TREE_REGROW
		reserved = null
	else:
		var tw := create_tween()
		tw.tween_property(_tree, "rotation:z", 0.09, 0.05)
		tw.tween_property(_tree, "rotation:z", -0.06, 0.07)
		tw.tween_property(_tree, "rotation:z", 0.0, 0.08)
	return true


func _process(delta: float) -> void:
	if logs > 0:
		return
	_regrow -= delta
	if _regrow <= 0.0:
		logs = B.TREE_LOGS
		_stump.visible = false
		_tree.visible = true
		Fx.pop(_tree, 0.5)
