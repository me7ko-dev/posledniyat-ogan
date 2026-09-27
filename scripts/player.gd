extends Node3D
## Героят: тича с джойстика. Само сече, когато е до дърво, хвърля дървата в огъня,
## прибира монетите и плаща на квадратите, щом стъпи върху тях.

const B := preload("res://scripts/balance.gd")
const Avatar := preload("res://scripts/avatar.gd")
const CarryStack := preload("res://scripts/carry_stack.gd")

const MODEL := "character-male-a"
const STACK_POS := Vector3(0, 0.85, 0.42)  # пред гърдите

var main: Node
var avatar: Avatar
var stack: CarryStack
var sharp := false
var input_dir := Vector2.ZERO  # от джойстика или клавиатурата
var bot_target = null          # автотестът води героя до тази точка (Vector3 или null)
var _chop_t := 0.0
var _feed_t := 0.0
var _coin_t := 0.0
var _pad_t := 0.0
var _full: Label3D


func _ready() -> void:
	avatar = Avatar.new()
	add_child(avatar)
	avatar.setup(MODEL)
	avatar.hold_axe("tool-axe")
	stack = CarryStack.new()
	stack.capacity = B.CAPACITY
	stack.position = STACK_POS
	avatar.add_child(stack)
	_full = Label3D.new()
	_full.text = "ПЪЛНО"
	_full.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_full.no_depth_test = true
	_full.font_size = 48
	_full.outline_size = 14
	_full.pixel_size = 0.006
	_full.modulate = Color("#ffb347")
	_full.position.y = 2.7
	_full.visible = false
	add_child(_full)


func _process(delta: float) -> void:
	var v := input_dir
	if bot_target != null:
		var d: Vector3 = bot_target - global_position
		d.y = 0.0
		v = Vector2(d.x, d.z).normalized() if d.length() > 0.2 else Vector2.ZERO
	if v.length() > 1.0:
		v = v.normalized()
	var moving := v.length() > 0.15
	if moving:
		var move := Vector3(v.x, 0.0, v.y) * B.PLAYER_SPEED
		position = main.keep_in_bounds(position + move * delta, 0.45)
		avatar.face(move, delta)
		avatar.play("sprint" if v.length() > 0.6 else "walk")
	else:
		avatar.play("idle")
	avatar.set_carrying(not stack.is_empty() or stack.incoming > 0)
	_full.visible = stack.full() and stack.incoming == 0
	_chop(delta, moving)
	_feed(delta)
	_coins(delta)
	_pay(delta)


func _chop(delta: float, moving: bool) -> void:
	_chop_t -= delta
	if _chop_t > 0.0 or stack.full():
		return
	var t = main.nearest_tree(global_position, B.CHOP_RANGE)
	if t == null:
		return
	_chop_t = B.CHOP_EVERY_SHARP if sharp else B.CHOP_EVERY
	if not moving:
		avatar.face_now(t.global_position)
	avatar.play_once("attack-melee-right", 1.8)
	if t.take_log():
		main.fly_log_to_stack(t.global_position + Vector3(0, 1.2, 0), stack)
		main.on_player_chop()


func _feed(delta: float) -> void:
	_feed_t -= delta
	if _feed_t > 0.0 or stack.is_empty():
		return
	if global_position.distance_to(main.fire.global_position) > B.FIRE_RANGE or not main.fire.can_take():
		return
	_feed_t = B.FEED_EVERY
	main.fly_log_to_fire(stack.remove_top())
	main.on_player_feed()


func _coins(delta: float) -> void:
	_coin_t -= delta
	if _coin_t > 0.0:
		return
	var pile = main.nearest_pile(global_position, B.COIN_RANGE)
	if pile == null:
		return
	_coin_t = B.COIN_PICK_EVERY
	var from: Vector3 = pile.top_global()
	var n: int = pile.take(maxi(1, pile.count / 8))
	main.fly_coins_to_player(from, n)


func _pay(delta: float) -> void:
	_pad_t -= delta
	if _pad_t > 0.0 or main.coins <= 0:
		return
	var pad = main.pad_under(global_position)
	if pad == null or pad.remaining() <= 0:
		return
	_pad_t = B.PAD_PAY_EVERY
	var n := mini(main.coins, mini(pad.remaining(), maxi(1, ceili(pad.cost / 45.0))))
	main.coins -= n
	pad.incoming += n
	main.fly_coins_to_pad(global_position + Vector3(0, 1.3, 0), pad, n)
