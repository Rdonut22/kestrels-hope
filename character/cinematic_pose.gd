class_name CinematicPose
extends SkeletonModifier3D

## Poses Gana's body for cinematics on top of whatever animation plays
## (his rig has no sitting or yawning animations), blended by amount:
## - sit: thighs swing forward to horizontal, shins hang (menu.gd's
##   seated pose), a slight lean back;
## - yawn: arms lift up and out, head tips back.
## Skeleton space: the body faces +Z.

@export_range(0.0, 1.0) var sit := 0.0
@export_range(0.0, 1.0) var yawn := 0.0

const LEGS := [["mixamorig_LeftUpLeg", "mixamorig_LeftLeg"], ["mixamorig_RightUpLeg", "mixamorig_RightLeg"]]
const ARMS := [["mixamorig_LeftArm", "mixamorig_LeftForeArm", 1.0], ["mixamorig_RightArm", "mixamorig_RightForeArm", -1.0]]


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var right := Vector3.RIGHT
	var forward := Vector3.BACK   # +Z
	if sit > 0.001:
		for leg in LEGS:
			var thigh := sk.find_bone(leg[0])
			var shin := sk.find_bone(leg[1])
			if thigh < 0 or shin < 0:
				continue
			var hip := sk.get_bone_global_pose(thigh)
			var knee := sk.get_bone_global_pose(shin)
			var down := (knee.origin - hip.origin).normalized()
			var swing := Basis(right, down.signed_angle_to(forward, right) * sit)
			hip.basis = swing * hip.basis
			sk.set_bone_global_pose(thigh, hip)
			var knee2 := sk.get_bone_global_pose(shin)
			knee2.basis = swing.inverse() * Basis(right, -0.15 * sit) * knee2.basis
			sk.set_bone_global_pose(shin, knee2)
		var spine := sk.find_bone("mixamorig_Spine")
		if spine >= 0:
			var sp := sk.get_bone_global_pose(spine)
			sp.basis = Basis(right, -0.08 * sit) * sp.basis
			sk.set_bone_global_pose(spine, sp)
	if yawn > 0.001:
		for arm in ARMS:
			var a := sk.find_bone(arm[0])
			var f := sk.find_bone(arm[1])
			if a < 0 or f < 0:
				continue
			var sh := sk.get_bone_global_pose(a)
			var el := sk.get_bone_global_pose(f)
			var dir := (el.origin - sh.origin).normalized()
			var target := (Vector3.UP * 0.85 + Vector3(arm[2], 0, 0) * 0.45 + forward * 0.1).normalized()
			var q := Quaternion(dir, target)
			sh.basis = Basis(Quaternion.IDENTITY.slerp(q, yawn)) * sh.basis
			sk.set_bone_global_pose(a, sh)
		var head := sk.find_bone("mixamorig_Head")
		if head >= 0:
			var hd := sk.get_bone_global_pose(head)
			hd.basis = Basis(right, -0.35 * yawn) * hd.basis
			sk.set_bone_global_pose(head, hd)
