class_name WristRaise
extends SkeletonModifier3D

## Raises Gana's right (mechanical) arm to look at the wrist terminal:
## upper arm tucked in and a little forward, forearm across the front of
## his chest with the terminal turned up towards his face. Applied on top
## of whatever animation is playing, blended by `amount` (0 = arm as
## animated, 1 = fully raised). character_model.gd tweens it.
##
## Directions are in skeleton space: the body faces +Z, his right is -X.

@export_range(0.0, 1.0) var amount := 0.0
## Upper arm: down, slightly forward and out.
@export var upper_dir := Vector3(-0.32, -0.55, 0.78)
## Forearm: forward across the chest, a little up.
@export var fore_dir := Vector3(0.82, 0.42, 0.38)
## Which way the back of the forearm (the terminal's screen) should face:
## up and back towards his eyes.
@export var screen_dir := Vector3(-0.1, 0.75, -0.65)

const SHOULDER := "mixamorig_RightShoulder"
const ARM := "mixamorig_RightArm"
const FORE := "mixamorig_RightForeArm"

var _dorsal_arm := Vector3.BACK
var _dorsal_fore := Vector3.BACK


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_dorsal_arm = _dorsal(sk, sk.find_bone(ARM))
	_dorsal_fore = _dorsal(sk, sk.find_bone(FORE))


## The back of a bone at rest, in its own frame (same as robot_arm.gd, so
## the terminal on the forearm is on this side).
static func _dorsal(sk: Skeleton3D, bone: int) -> Vector3:
	if bone < 0:
		return Vector3.BACK
	var d := sk.get_bone_global_rest(bone).basis.inverse() * Vector3.UP
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.BACK


## Global basis whose +Y points along `dir` and whose local `dorsal` turns
## towards `face`.
static func _aim(dir: Vector3, dorsal: Vector3, face: Vector3, scale: Vector3) -> Basis:
	var y := dir.normalized()
	var z_t := (face - y * face.dot(y)).normalized()
	var x_t := y.cross(z_t).normalized()
	var z_l := dorsal.normalized()
	var x_l := Vector3.UP.cross(z_l).normalized()
	var target := Basis(x_t, y, z_t)
	var local := Basis(x_l, Vector3.UP, z_l)
	return (target * local.inverse()).orthonormalized().scaled(scale)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or amount <= 0.001:
		return
	var sh := sk.find_bone(SHOULDER)
	var arm := sk.find_bone(ARM)
	var fore := sk.find_bone(FORE)
	if sh < 0 or arm < 0 or fore < 0:
		return
	var sh_g := sk.get_bone_global_pose(sh)
	var arm_local := sk.get_bone_pose(arm)
	var fore_local := sk.get_bone_pose(fore)
	# Upper arm: elbow tucked down and forward, its back turned outward.
	var arm_g := _aim(upper_dir, _dorsal_arm, Vector3(-1, 0, -0.3), arm_local.basis.get_scale())
	var arm_target := (sh_g.basis.inverse() * arm_g).get_rotation_quaternion()
	var arm_q := arm_local.basis.get_rotation_quaternion().slerp(arm_target, amount)
	sk.set_bone_pose_rotation(arm, arm_q)
	# Forearm across the chest, the terminal facing his eyes.
	var arm_new := sh_g.basis * Basis(arm_q)
	var fore_g := _aim(fore_dir, _dorsal_fore, screen_dir, fore_local.basis.get_scale())
	var fore_target := (arm_new.inverse() * fore_g).get_rotation_quaternion()
	sk.set_bone_pose_rotation(fore, fore_local.basis.get_rotation_quaternion().slerp(fore_target, amount))
