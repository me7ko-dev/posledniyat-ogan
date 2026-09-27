extends Node3D
## Премръзнал пътник: идва по пътеката, сяда на пейка до огъня, топли се и плаща.
## Ако огънят е угаснал, чака, трепери и накрая си тръгва без да плати.

const B := preload("res://scripts/balance.gd")
const Avatar := preload("res://scripts/avatar.gd")
const Bar := preload("res://scripts/progress_bar_3d.gd")

enum S { WALK_IN, SIT, LEAVE }

const SIT_Y := 0.18

var main: Node
var seat  # main.Seat
var model := "character-female-a"
var state := S.WALK_IN
var path: Array[Vector3] = []
var warm := 0.0
var patience := B.PATIENCE
var avatar: Avatar
var _bar: Bar
var _cold: Label3D


func _ready() -> void:
	avatar = Avatar.new()
	add_child(avatar)
	avatar.setup(model)
	_bar = Bar.new()
	_bar.position.y = 2.5
	_bar.visible = false
	add_child(_bar)
	_bar.set_color(Color(1.0, 0.7, 0.25))
	_cold = Label3D.new()
	_cold.text = "❄"
	_cold.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cold.no_depth_test = true
	_cold.font_size = 72
	_cold.outline_size = 12
	_cold.pixel_size = 0.006
	_cold.modulate = Color("#bfe3ff")
	_cold.position.y = 2.9
	_cold.visible = false
	add_child(_cold)
	path = main.path_to_seat(seat)


func _process(delta: float) -> void:
	match state:
		S.WALK_IN:
			if _walk(delta):
				state = S.SIT
				position = seat.pos + Vector3(0, SIT_Y, 0)
				avatar.face_now(main.fire.global_position)
				avatar.play("sit")
				_bar.visible = true
		S.SIT:
			if main.fire.burning():
				_cold.visible = false
				warm += delta
				_bar.set_value(warm / B.WARM_TIME)
				if warm >= B.WARM_TIME:
					main.traveller_pays(self)
					_leave(true)
			else:
				_cold.visible = true
				patience -= delta
				avatar.rotation.z = sin(Time.get_ticks_msec() * 0.06) * 0.03  # трепери
				if patience <= 0.0:
					_leave(false)
		S.LEAVE:
			if _walk(delta):
				main.traveller_gone(self)
				queue_free()


func _leave(happy: bool) -> void:
	state = S.LEAVE
	avatar.rotation.z = 0.0
	_bar.visible = false
	_cold.visible = false
	position.y = 0.0
	path = main.path_from_seat(seat)
	main.free_seat(seat)
	if not happy:
		avatar.play_once("emote-no")


## Върви към следващата точка от пътя. Връща true, когато пътят свърши.
func _walk(delta: float) -> bool:
	if path.is_empty():
		return true
	if avatar.busy():
		return false
	var to := path[0]
	var d := to - position
	d.y = 0.0
	var step := B.TRAVELLER_SPEED * delta
	if d.length() <= step:
		position = Vector3(to.x, 0.0, to.z)
		path.pop_front()
		return path.is_empty()
	var dir := d.normalized()
	position += dir * step
	avatar.face(dir, delta)
	avatar.play("walk")
	return false
