extends Node3D
## Дървар-помощник: сам сече дърва и ги носи в огъня.

const B := preload("res://scripts/balance.gd")
const Avatar := preload("res://scripts/avatar.gd")
const CarryStack := preload("res://scripts/carry_stack.gd")

enum S { FIND, TO_TREE, CHOP, TO_FIRE, FEED }

var main: Node
var model := "character-male-c"
var state := S.FIND
var tree = null
var avatar: Avatar
var stack: CarryStack
var _t := 0.0


func _ready() -> void:
	avatar = Avatar.new()
	add_child(avatar)
	avatar.setup(model)
	avatar.hold_axe("tool-axe")
	stack = CarryStack.new()
	stack.capacity = B.HELPER_CARRY
	stack.position = Vector3(0, 0.85, 0.42)
	avatar.add_child(stack)
	var tag := Label3D.new()
	tag.text = "Дървар"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 40
	tag.outline_size = 10
	tag.pixel_size = 0.006
	tag.modulate = Color("#d7f0c4")
	tag.position.y = 2.6
	add_child(tag)


func _process(delta: float) -> void:
	avatar.set_carrying(not stack.is_empty() or stack.incoming > 0)
	match state:
		S.FIND:
			if stack.full():
				state = S.TO_FIRE
				return
			tree = main.free_tree_for(self, global_position)
			if tree == null:
				if not stack.is_empty():
					state = S.TO_FIRE
				else:
					avatar.play("idle")
				return
			tree.reserved = self
			state = S.TO_TREE
		S.TO_TREE:
			if tree == null or not tree.has_logs():
				_forget_tree()
				state = S.FIND
				return
			var away: Vector3 = global_position - tree.global_position
			away.y = 0.0
			if away.length() < 0.01:
				away = Vector3.BACK
			if _move_to(tree.global_position + away.normalized() * 1.1, delta):
				state = S.CHOP
				_t = 0.2
		S.CHOP:
			if tree == null or not tree.has_logs() or stack.full():
				_forget_tree()
				state = S.TO_FIRE if stack.full() else S.FIND
				return
			avatar.face_now(tree.global_position)
			_t -= delta
			if _t <= 0.0:
				_t = B.HELPER_CHOP_EVERY
				avatar.play_once("attack-melee-right", 1.5)
				if tree.take_log():
					main.fly_log_to_stack(tree.global_position + Vector3(0, 1.2, 0), stack)
			elif not avatar.busy():
				avatar.play("idle")
		S.TO_FIRE:
			var f: Vector3 = main.fire.global_position
			var off: Vector3 = global_position - f
			off.y = 0.0
			if off.length() < 0.01:
				off = Vector3.BACK
			if _move_to(f + off.normalized() * (B.FIRE_RANGE - 0.6), delta):
				state = S.FEED
				_t = 0.1
		S.FEED:
			if stack.is_empty() and stack.incoming == 0:
				state = S.FIND
				return
			avatar.face_now(main.fire.global_position)
			avatar.play("idle")
			_t -= delta
			if _t <= 0.0 and not stack.is_empty() and main.fire.can_take():
				_t = B.FEED_EVERY * 2.0
				main.fly_log_to_fire(stack.remove_top())


func _forget_tree() -> void:
	if tree != null and tree.reserved == self:
		tree.reserved = null
	tree = null


## Върви към точката. Връща true, когато е стигнал.
func _move_to(p: Vector3, delta: float) -> bool:
	var d := p - global_position
	d.y = 0.0
	var step := B.HELPER_SPEED * delta
	if d.length() <= step:
		position = Vector3(p.x, 0.0, p.z)
		return true
	if avatar.busy():
		return false
	var dir := d.normalized()
	position = main.keep_in_bounds(position + dir * step, 0.4, false)
	avatar.face(dir, delta)
	avatar.play("walk" if stack.is_empty() else "sprint")
	return false
