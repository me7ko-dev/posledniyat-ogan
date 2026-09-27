extends Node3D
## Човече от Kenney Mini Characters: анимации, посока на гледане, брадва и ръце за носене.
## Моделите гледат към +Z.

const Models := preload("res://scripts/models.gd")
const ArmsHold := preload("res://scripts/arms_hold.gd")
const LOOPED := ["idle", "walk", "sprint", "sit", "holding-both"]
const TURN_SPEED := 14.0

var anim: AnimationPlayer
var skeleton: Skeleton3D
var _arms: SkeletonModifier3D
var _axe_slot: BoneAttachment3D
var _axe: Node3D
var _current := ""
var _one_shot := 0.0  # докато е > 0, тече еднократна анимация (удар, поздрав)


func setup(model_name: String) -> void:
	var m := Models.character(model_name)
	add_child(m)
	anim = m.find_children("*", "AnimationPlayer", true, false)[0]
	skeleton = m.find_children("*", "Skeleton3D", true, false)[0]
	for a: String in LOOPED:
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_arms = ArmsHold.new()
	_arms.pose_from(anim, "holding-both", model_name)
	_arms.influence = 0.0
	skeleton.add_child(_arms)
	play("idle")


func _process(delta: float) -> void:
	if _one_shot > 0.0:
		_one_shot -= delta


func play(anim_name: String, blend := 0.15) -> void:
	if _one_shot > 0.0 or _current == anim_name:
		return
	_current = anim_name
	anim.play(anim_name, blend)


## Еднократна анимация (удар с брадва, поздрав). Не се прекъсва от ходенето.
func play_once(anim_name: String, speed := 1.0) -> void:
	_current = anim_name
	anim.play(anim_name, 0.05, speed)
	anim.seek(0.0, true)
	_one_shot = anim.get_animation(anim_name).length / speed


func busy() -> bool:
	return _one_shot > 0.0


## Плавно се обръща по посоката на движение.
func face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() > 0.0001:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-delta * TURN_SPEED))


func face_now(point: Vector3) -> void:
	var d := point - global_position
	rotation.y = atan2(d.x, d.z)


func set_carrying(on: bool) -> void:
	var target := 1.0 if on else 0.0
	if not is_equal_approx(_arms.influence, target):
		_arms.influence = move_toward(_arms.influence, target, get_process_delta_time() * 6.0)


## Брадва в дясната ръка. `model` е „tool-axe“ или „tool-axe-upgraded“.
func hold_axe(model: String) -> void:
	if _axe_slot == null:
		_axe_slot = BoneAttachment3D.new()
		_axe_slot.bone_name = "arm-right"
		skeleton.add_child(_axe_slot)
	if _axe:
		_axe.queue_free()
	_axe = load("res://models/survival/%s.glb" % model).instantiate()
	_axe.position = Vector3(-0.02, -0.12, 0.03)
	_axe.rotation_degrees = Vector3(90, 0, 0)
	_axe_slot.add_child(_axe)


func show_axe(on: bool) -> void:
	if _axe:
		_axe.visible = on
