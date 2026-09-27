extends Node3D
## Малка лента над главата, винаги с лице към камерата.
## Камерата не се завърта встрани, затова изместването по X е „наляво“ на екрана.

const Models := preload("res://scripts/models.gd")
const W := 0.9
const H := 0.14

var _fill: MeshInstance3D


func _ready() -> void:
	var bg := _quad(Vector2(W + 0.06, H + 0.06), Color(0, 0, 0, 0.6), 1)
	add_child(bg)
	_fill = _quad(Vector2(W, H), Color(1.0, 0.62, 0.2), 2)
	add_child(_fill)
	set_value(0.0)


func set_color(c: Color) -> void:
	var m: StandardMaterial3D = _fill.material_override
	if m.albedo_color != c:
		m.albedo_color = c


func set_value(v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	_fill.scale.x = maxf(v, 0.001)
	_fill.position.x = -W * (1.0 - v) * 0.5


static func _quad(size: Vector2, color: Color, priority: int) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var m := Models.unshaded(color, true)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = priority
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
