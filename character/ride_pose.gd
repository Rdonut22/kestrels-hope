class_name RidePose
extends SkeletonModifier3D

## Sits Gana astride a vehicle on top of whatever animation plays (his rig
## has no riding animation): each hand reaches for its grip and each foot for
## its footrest (two-bone reach: shoulder-elbow-hand, hip-knee-foot), and the
## back leans forward. Blended by `amount`.
##
## The targets are world positions, set every frame by the vehicle
## (world/vehicles/hoverbike.gd). `forward` is the vehicle's facing; knees
## bend toward it and elbows away from it.

@export_range(0.0, 1.0) var amount := 0.0
@export var lean := 0.3          # radians the spine tips forward
var left_hand := Vector3.ZERO
var right_hand := Vector3.ZERO
var left_foot := Vector3.ZERO
var right_foot := Vector3.ZERO
var forward := Vector3.FORWARD

const SPINE := ["mixamorig_Spine", "mixamorig_Spine1"]


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or amount < 0.001:
		return
	var to_sk := sk.global_transform.affine_inverse()
	var fwd := (to_sk.basis * forward).normalized()
	var up := (to_sk.basis * Vector3.UP).normalized()
	var right := fwd.cross(up).normalized()
	# Lean the back first, so the arms reach from where the shoulders end up.
	for n in SPINE:
		var b := sk.find_bone(n)
		if b < 0:
			continue
		var g := sk.get_bone_global_pose(b)
		g.basis = Basis(right, -lean * amount * 0.5) * g.basis
		sk.set_bone_global_pose(b, g)
	_reach(sk, "mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot", to_sk * left_foot, fwd)
	_reach(sk, "mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot", to_sk * right_foot, fwd)
	_reach(sk, "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand", to_sk * left_hand, -fwd - up * 0.6 - right * 0.4)
	_reach(sk, "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand", to_sk * right_hand, -fwd - up * 0.6 + right * 0.4)


## Turns the upper and lower bone of a limb so its end reaches `target`
## (skeleton space), the middle joint bending toward `pole` (a direction).
func _reach(sk: Skeleton3D, upper: String, lower: String, end: String, target: Vector3, pole: Vector3) -> void:
	var a := sk.find_bone(upper)
	var b := sk.find_bone(lower)
	var c := sk.find_bone(end)
	if a < 0 or b < 0 or c < 0:
		return
	var ga := sk.get_bone_global_pose(a)
	var gb := sk.get_bone_global_pose(b)
	var gc := sk.get_bone_global_pose(c)
	var la := ga.origin.distance_to(gb.origin)
	var lb := gb.origin.distance_to(gc.origin)
	var to_t := target - ga.origin
	var d := clampf(to_t.length(), absf(la - lb) + 0.001, la + lb - 0.001)
	var dir := to_t.normalized()
	# Where the middle joint goes: on the circle the two lengths allow,
	# on the side of the pole.
	var cos_a := clampf((la * la + d * d - lb * lb) / (2.0 * la * d), -1.0, 1.0)
	var side := (pole - dir * pole.dot(dir))
	if side.length() < 0.001:
		side = (gb.origin - ga.origin) - dir * (gb.origin - ga.origin).dot(dir)
	side = side.normalized()
	var mid := ga.origin + dir * (cos_a * la) + side * (sqrt(1.0 - cos_a * cos_a) * la)
	var end_pos := ga.origin + dir * d
	# Upper bone: from where its child is now to `mid`.
	var q1 := Quaternion((gb.origin - ga.origin).normalized(), (mid - ga.origin).normalized())
	var new_a := Transform3D(Basis(q1) * ga.basis, ga.origin)
	new_a.basis = ga.basis.slerp(new_a.basis.orthonormalized(), amount)
	sk.set_bone_global_pose(a, new_a)
	# Lower bone, from its new place.
	gb = sk.get_bone_global_pose(b)
	gc = sk.get_bone_global_pose(c)
	var want := ga.origin.lerp(end_pos, 1.0) if amount >= 1.0 else gb.origin + ((end_pos - gb.origin).normalized() * lb).lerp(gc.origin - gb.origin, 1.0 - amount)
	var q2 := Quaternion((gc.origin - gb.origin).normalized(), (want - gb.origin).normalized())
	sk.set_bone_global_pose(b, Transform3D(Basis(q2) * gb.basis, gb.origin))
