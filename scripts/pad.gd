extends Node3D
## Квадрат за строене: стъпи върху него и монетите ти отиват в него. Когато се напълни — строи.

const Models := preload("res://scripts/models.gd")
const SIZE := 1.8

var id := ""
var title := ""
var icon := ""
var cost := 10
var paid := 0
var incoming := 0  # монети, които летят към квадрата
var _fill: MeshInstance3D
var _label: Label3D


func _ready() -> void:
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(SIZE, 0.04, SIZE)
	base.mesh = bm
	base.material_override = Models.unshaded(Color(0.07, 0.09, 0.17, 0.72))
	add_child(base)
	for i in 4:
		var e := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(SIZE + 0.07, 0.06, 0.08)
		e.mesh = em
		e.material_override = Models.unshaded(Color(1, 1, 1, 0.92))
		e.rotation.y = i * PI / 2.0
		e.position = Vector3(sin(i * PI / 2.0) * SIZE / 2.0, 0.02, cos(i * PI / 2.0) * SIZE / 2.0)
		add_child(e)
	_fill = MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(SIZE - 0.2, 0.05, SIZE - 0.2)
	_fill.mesh = fm
	_fill.material_override = Models.unshaded(Color("#f5c542"))
	_fill.position.y = 0.01
	add_child(_fill)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position.y = 1.0
	_label.font_size = 64
	_label.outline_size = 18
	_label.pixel_size = 0.0055
	_label.modulate = Color("#fff4d6")
	add_child(_label)
	_sync()


func remaining() -> int:
	return cost - paid - incoming


func receive(n: int) -> void:
	incoming = maxi(0, incoming - n)
	paid += n
	_sync()


func done() -> bool:
	return paid >= cost


func _sync() -> void:
	var k := clampf(float(paid) / cost, 0.0, 1.0)
	_fill.visible = k > 0.0
	_fill.scale = Vector3(maxf(k, 0.01), 1.0, maxf(k, 0.01))
	_label.text = "%s %s\n🪙 %d" % [icon, title, cost - paid]
