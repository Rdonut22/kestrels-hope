extends Node3D

## Drives Gana's body (character/gana/gana.glb, a Mixamo rig) from the
## player's movement. The player calls set_move() every frame with 0 (still)
## to 1 (full speed), and play_action() for one-shot gestures like
## "Interact" (skipped if the body has no such animation).
##
## Animations: "Idle", "Walk", and optionally "Run" and "Interact"
## (tools/import_gana.gd). Without a Run, the walk is sped up (up to
## max_walk_rate) at higher speeds.

## Emitted when a foot touches down during the walk or run animation.
signal footstep

## Generic bone names used by other scripts (menu.gd's seated pose, the
## robot arm) and their names on the Mixamo rig.
const BONES := {
	"UpperLeg.L": "mixamorig_LeftUpLeg", "UpperLeg.R": "mixamorig_RightUpLeg",
	"LowerLeg.L": "mixamorig_LeftLeg", "LowerLeg.R": "mixamorig_RightLeg",
	"Foot.L": "mixamorig_LeftFoot", "Foot.R": "mixamorig_RightFoot",
	"Abdomen": "mixamorig_Spine", "Hips": "mixamorig_Hips",
	"UpperArm.R": "mixamorig_RightArm", "LowerArm.R": "mixamorig_RightForeArm", "Wrist.R": "mixamorig_RightHand",
}

@export var walk_threshold := 0.05
@export var run_threshold := 0.55
@export var blend_time := 0.2
## The player's top speed (player.gd SPEED), m/s, for matching the feet.
@export var full_speed := 5.0
## Ground speed the walk animation was made for, m/s (its stride / length).
@export var walk_speed := 0.99
## Ground speed of the run animation, if there is one.
@export var run_speed := 3.6
## Fastest the walk is played when there's no run (higher slides the feet).
@export var max_walk_rate := 1.8

var anim: AnimationPlayer
var _move := 0.0
var _current := ""
var _action_left := 0.0
var _skel: Skeleton3D
var _feet := []  # [bone index, last height, was descending, contact height]


func _ready() -> void:
	anim = find_children("*", "AnimationPlayer", true, false)[0]
	_skel = find_children("*", "Skeleton3D", true, false)[0]
	_attach_robot_arm()
	for n in ["Idle", "Walk", "Run"]:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	for side in ["L", "R"]:
		var b := bone("Foot." + side)
		if b >= 0:
			_feet.append([b, 0.0, false, _foot_height(b, true) + 0.05])
	_play("Idle")


## Index of a bone by generic name ("UpperLeg.L", ...) or its own name.
func bone(name: String) -> int:
	var i := _skel.find_bone(name)
	if i < 0 and BONES.has(name):
		i = _skel.find_bone(BONES[name])
	return i


## Height of the hips above the feet when standing, in metres.
func hip_height() -> float:
	var hips := bone("Hips")
	return _foot_height(hips, true) if hips >= 0 else 0.9


## Hold a frame of an animation (posing a still character).
func hold(name: String, time: float) -> void:
	if anim.has_animation(name):
		anim.play(name)
		anim.seek(time, true)
		anim.pause()


func set_move(amount: float) -> void:
	_move = clampf(amount, 0.0, 1.0)


func play_action(name: String) -> void:
	if anim.has_animation(name):
		_current = name
		anim.speed_scale = 1.0
		anim.play(name, 0.1)
		_action_left = anim.get_animation(name).length * 0.8


func _process(delta: float) -> void:
	if _action_left > 0.0:
		_action_left -= delta
		if _move < walk_threshold:
			return
		_action_left = 0.0
	_detect_footsteps()
	var speed := _move * full_speed
	if _move < walk_threshold:
		_play("Idle")
		anim.speed_scale = 1.0
	elif _move >= run_threshold and anim.has_animation("Run"):
		_play("Run")
		anim.speed_scale = clampf(speed / run_speed, 0.7, 1.4)
	else:
		_play("Walk")
		anim.speed_scale = clampf(speed / walk_speed, 0.7, max_walk_rate)


func _play(name: String) -> void:
	if name != _current and anim.has_animation(name):
		_current = name
		anim.play(name, blend_time)


# Moves each RobotArm part group onto the bone named in its "bone" metadata,
# so the cybernetic arm follows the animations.
func _attach_robot_arm() -> void:
	var arm := get_node_or_null("RobotArm")
	if arm == null:
		return
	for holder: Node3D in arm.get_children():
		var att := BoneAttachment3D.new()
		att.bone_name = _skel.get_bone_name(bone(holder.get_meta("bone")))
		_skel.add_child(att)
		holder.reparent(att, false)


## A bone's height above the character's feet (origin), in metres.
func _foot_height(b: int, rest := false) -> float:
	var pose := _skel.get_bone_global_rest(b) if rest else _skel.get_bone_global_pose(b)
	return (_skel.global_transform * pose.origin).y - global_position.y


# A foot touches down when its height stops falling and starts rising
# while it's near the ground.
func _detect_footsteps() -> void:
	var moving := _move >= walk_threshold and _action_left <= 0.0
	for foot in _feet:
		var y := _foot_height(foot[0])
		var descending: bool = y < foot[1]
		if moving and foot[2] and not descending and y < foot[3]:
			footstep.emit()
		foot[1] = y
		foot[2] = descending
