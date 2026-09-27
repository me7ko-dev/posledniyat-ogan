extends RefCounted
## Летящи предмети по дъга (дърва, монети).


## Мести `node` от `from` до целта. `target` е Callable, който връща текущата точка —
## така целта може да се движи (например купчината в ръцете на тичащия герой).
static func fly(node: Node3D, from: Vector3, target: Callable, dur: float, height := 1.2) -> Tween:
	node.global_position = from
	var spin := randf_range(-8.0, 8.0)
	var step := func(t: float) -> void:
		var to: Vector3 = target.call()
		node.global_position = from.lerp(to, t) + Vector3.UP * height * 4.0 * t * (1.0 - t)
		node.rotation.y = spin * t
	var tw := node.create_tween()
	tw.tween_method(step, 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw


## Малко „изскачане“ при поява.
static func pop(node: Node3D, dur := 0.35) -> void:
	var s := node.scale
	node.scale = s * 0.2
	node.create_tween().tween_property(node, "scale", s, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
