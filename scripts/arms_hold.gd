extends SkeletonModifier3D
## Държи ръцете напред като при носене на купчина — върху която и да е анимация (ходене, тичане).
## Колко силно — `influence` (0 = не пипа, 1 = изцяло).

var _rots := {}  # име на кост → завъртане


## Взима позата на ръцете от анимацията `holding-both` на модела.
func pose_from(anim: AnimationPlayer, anim_name: String, model_name: String) -> void:
	var a := anim.get_animation(anim_name)
	for bone in ["arm-left", "arm-right"]:
		var track := a.find_track(NodePath("%s/Skeleton3D:%s" % [model_name, bone]), Animation.TYPE_ROTATION_3D)
		if track >= 0:
			_rots[bone] = a.rotation_track_interpolate(track, 0.0)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for bone: String in _rots:
		var i := sk.find_bone(bone)
		if i >= 0:
			sk.set_bone_pose_rotation(i, _rots[bone])
