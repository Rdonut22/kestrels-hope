extends SkeletonModifier3D

## Small procedural touches layered on top of Gana's animations (runs after
## the AnimationTree each frame; character_model.gd feeds it):
## - the chest and head lead into a turn,
## - when standing still the head drifts toward where the camera looks,
## - a hard landing folds the upper body forward and back up,
## - the prosthetic right arm swings with a little extra weight.
## Rotations are applied around the character's own up / right axes, so they
## don't depend on how each bone's local axes happen to be set up.

## -1..1: turning left (+) or right (-), scaled by speed.
var turn := 0.0
## 0..1: landing compression, decaying back to 0.
var land := 0.0
## Radians of extra forearm swing (spring-driven by character_model.gd).
var arm_swing := 0.0
## 0..1: how fast he's moving (0 = standing).
var speed := 0.0
## Radians from the body's facing to where the camera points.
var look_yaw := 0.0

@export_range(0.0, 1.0) var strength := 1.0
## How far the head turns toward the camera when idle (degrees, max).
@export var head_look := 55.0

var _head := 0.0
var _chest := 0.0
var _bones := {}


func _bone(name: String) -> int:
	if not _bones.has(name):
		_bones[name] = get_skeleton().find_bone(name)
	return _bones[name]


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if not sk:
		return
	var model := sk.get_parent()
	while model and not model.has_method("set_locomotion"):
		model = model.get_parent()
	if not model:
		return
	# Character axes in skeleton space (the model faces -Z).
	var to_skel := sk.global_transform.basis.inverse() * (model as Node3D).global_transform.basis
	var up := (to_skel * Vector3.UP).normalized()
	var right := (to_skel * Vector3.RIGHT).normalized()
	var k := minf(1.0, delta * 6.0)
	# Chest leads a turn; head leads a little further.
	_chest = lerpf(_chest, turn * 0.22, k)
	# Standing: glance toward where the camera's looking (within reason).
	var idle := 1.0 - clampf(speed * 3.0, 0.0, 1.0)
	var want_head := clampf(look_yaw, -deg_to_rad(head_look), deg_to_rad(head_look)) * idle
	if absf(look_yaw) > deg_to_rad(150.0):
		want_head = 0.0  # camera looking at his face: don't twist round
	_head = lerpf(_head, want_head + turn * 0.18, minf(1.0, delta * 3.0))
	var s := strength
	_rotate(sk, "Chest", up, _chest * 0.6 * s)
	_rotate(sk, "Neck", up, _head * 0.4 * s)
	_rotate(sk, "Head", up, _head * 0.6 * s)
	# Landing: fold forward at the abdomen and chest, then recover.
	if land > 0.001:
		var fold := sin(minf(land, 1.0) * PI * 0.5) * land * 0.35 * s
		_rotate(sk, "Abdomen", right, -fold * 0.5)
		_rotate(sk, "Chest", right, -fold * 0.5)
		_rotate(sk, "Head", right, fold * 0.4)
	# Heavier prosthetic: extra forearm swing on starts and stops.
	if absf(arm_swing) > 0.0005:
		_rotate(sk, "UpperArm.R", right, arm_swing * 0.5 * s)
		_rotate(sk, "LowerArm.R", right, arm_swing * 0.8 * s)


func _rotate(sk: Skeleton3D, bone_name: String, axis: Vector3, angle: float) -> void:
	var b := _bone(bone_name)
	if b < 0 or absf(angle) < 0.00001:
		return
	var g := sk.get_bone_global_pose(b)
	g.basis = Basis(axis, angle) * g.basis
	sk.set_bone_global_pose(b, g)
