extends Node3D

## Drives Gana's animations from the player's movement (player.gd calls
## set_locomotion() every physics frame).
##
## An AnimationTree blends Idle -> Walk -> Run by actual ground speed and
## speeds each cycle up or down so the feet stay planted (the cycles were
## measured: Walk covers ~1.3 m/s, Run ~2.5 m/s at normal playback). In the
## air it holds a stride pose; landing dips the body and recovers. On top,
## gana_motion.gd (a skeleton modifier) adds the small things: leaning into
## turns, weight shifting forward and back with speed changes, the chest
## and head leading a turn, a look toward where the camera points when
## standing, and follow-through on the heavy prosthetic arm.
##
## The model has no jump, fall, land, turn-in-place, start/stop or
## walk-backwards animations; see the notes at the end of this file.

const PREFIX := "CharacterArmature|"

## Emitted when a foot touches down during the walk or run animation.
signal footstep

@export_group("Animation")
## Ground speed the Walk and Run cycles were authored for (m/s at 1x).
@export var walk_natural_speed := 1.3
@export var run_natural_speed := 2.5
## How fast the blend follows speed changes.
@export var blend_smoothing := 10.0
## Point in the Run cycle (0..1) held as the in-air pose.
@export_range(0.0, 1.0) var air_pose := 0.12

@export_group("Body motion")
## Lean into turns (degrees at a full-speed turn).
@export var turn_lean := 7.0
## Lean forward when speeding up, back when slowing down (degrees).
@export var accel_lean := 4.0
## How far the body dips on a hard landing (metres).
@export var landing_dip := 0.07

var _move := 0.0  # 0..1 for footstep detection and actions
var _speed := 0.0
var _gait := 0.0  # 0 idle .. 1 walk .. 2 run
var _air := 0.0
var _land := 0.0
var _lean := 0.0
var _pitch := 0.0
var _arm := 0.0
var _arm_vel := 0.0
var _base_y := 0.0
var _action_left := 0.0
var _skel: Skeleton3D
var _feet := []  # [bone index, last height, was descending]
var _tree: AnimationTree
var _motion: SkeletonModifier3D

@onready var anim: AnimationPlayer = $Adventurer/AnimationPlayer


func _ready() -> void:
	_base_y = position.y
	_attach_robot_arm()
	_skel = find_children("*", "Skeleton3D", true, false)[0]
	for bone in ["Foot.L", "Foot.R"]:
		_feet.append([_skel.find_bone(bone), 0.0, false])
	for name in ["Idle", "Walk", "Run"]:
		var a := anim.get_animation(PREFIX + name)
		if a:
			a.loop_mode = Animation.LOOP_LINEAR
	_build_tree()
	_motion = SkeletonModifier3D.new()
	_motion.set_script(load("res://character/gana_motion.gd"))
	_motion.name = "GanaMotion"
	_skel.add_child(_motion)


func _clip(name: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = PREFIX + name
	return n


func _build_tree() -> void:
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	loco.add_blend_point(_clip("Idle"), 0.0, -1, "idle")
	loco.add_blend_point(_clip("Walk"), 1.0, -1, "walk")
	loco.add_blend_point(_clip("Run"), 2.0, -1, "run")
	loco.min_space = 0.0
	loco.max_space = 2.0
	loco.sync = true
	bt.add_node("loco", loco, Vector2(0, 0))
	bt.add_node("loco_speed", AnimationNodeTimeScale.new(), Vector2(200, 0))
	bt.connect_node("loco_speed", 0, "loco")
	# In the air: a frozen stride from the Run cycle.
	bt.add_node("air_clip", _clip("Run"), Vector2(0, 200))
	bt.add_node("air_seek", AnimationNodeTimeSeek.new(), Vector2(200, 200))
	bt.add_node("air_hold", AnimationNodeTimeScale.new(), Vector2(400, 200))
	bt.connect_node("air_seek", 0, "air_clip")
	bt.connect_node("air_hold", 0, "air_seek")
	bt.add_node("air", AnimationNodeBlend2.new(), Vector2(600, 0))
	bt.connect_node("air", 0, "loco_speed")
	bt.connect_node("air", 1, "air_hold")
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.15
	shot.fadeout_time = 0.25
	bt.add_node("action", shot, Vector2(800, 0))
	bt.add_node("action_clip", _clip("Interact"), Vector2(600, 200))
	bt.connect_node("action", 0, "air")
	bt.connect_node("action", 1, "action_clip")
	bt.connect_node("output", 0, "action")
	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	_tree.tree_root = bt
	anim.get_parent().add_child(_tree)
	_tree.anim_player = _tree.get_path_to(anim)
	_tree.set("parameters/air_hold/scale", 0.0)
	_tree.active = true


## Called every physics frame by player.gd.
func set_locomotion(speed: float, walk_speed: float, jog_speed: float, grounded: bool, turn_rate: float, accel: float) -> void:
	_speed = speed
	_move = clampf(speed / maxf(jog_speed, 0.01), 0.0, 1.0)
	var gait := speed / maxf(walk_speed, 0.01)
	if speed > walk_speed:
		gait = 1.0 + clampf((speed - walk_speed) / maxf(jog_speed - walk_speed, 0.01), 0.0, 1.0)
	_gait = gait
	_air = 0.0 if grounded else 1.0
	var full := clampf(speed / maxf(jog_speed, 0.01), 0.0, 1.0)
	_lean = clampf(turn_rate * 0.25, -1.0, 1.0) * full
	_pitch = clampf(accel / 9.0, -1.0, 1.0)


## Old interface (seated, or other callers): 0 = still, 1 = full jog.
func set_move(amount: float) -> void:
	set_locomotion(amount * 3.6, 1.45, 3.6, true, 0.0, 0.0)


func jumped() -> void:
	_air = 1.0


## Touched down after falling at `impact` m/s.
func landed(impact: float) -> void:
	_land = clampf(impact / 7.0, 0.2, 1.0)


func play_action(name: String) -> void:
	if name == "Interact" and _tree:
		_tree.set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		_action_left = anim.get_animation(PREFIX + name).length * 0.8


func _process(delta: float) -> void:
	if not _tree:
		return
	var k := minf(1.0, delta * blend_smoothing)
	var g: float = lerpf(_tree.get("parameters/loco/blend_position"), _gait, k)
	_tree.set("parameters/loco/blend_position", g)
	# Playback speed matched to ground speed, so feet don't slide.
	var scale := 1.0
	if g > 1.0:
		scale = _speed / lerpf(walk_natural_speed, run_natural_speed, g - 1.0)
	elif g > 0.05:
		scale = maxf(_speed / walk_natural_speed, 0.6)
	_tree.set("parameters/loco_speed/scale", clampf(scale, 0.5, 1.7))
	# In the air: ease into the stride pose; ease back out on landing.
	var air: float = lerpf(_tree.get("parameters/air/blend_amount"), _air, minf(1.0, delta * (8.0 if _air > 0.5 else 14.0)))
	_tree.set("parameters/air/blend_amount", air)
	_tree.set("parameters/air_seek/seek_request", air_pose * anim.get_animation(PREFIX + "Run").length)
	# Body: lean into turns and with speed changes, dip on landing.
	_land = move_toward(_land, 0.0, delta * 3.2)
	var dip := sin(minf(_land, 1.0) * PI * 0.5) * landing_dip * _land
	position.y = _base_y - dip
	rotation.z = lerp_angle(rotation.z, deg_to_rad(turn_lean) * _lean, minf(1.0, delta * 6.0))
	rotation.x = lerp_angle(rotation.x, -deg_to_rad(accel_lean) * _pitch, minf(1.0, delta * 5.0))
	# The prosthetic arm is heavier: it lags behind starts and stops.
	_arm_vel += (-_pitch * 0.35 - _arm) * 60.0 * delta
	_arm_vel *= exp(-9.0 * delta)
	_arm += _arm_vel * delta
	if _motion:
		_motion.set("turn", _lean)
		_motion.set("land", _land)
		_motion.set("arm_swing", _arm)
		_motion.set("speed", _move)
		var pivot := get_parent().get_node_or_null("CameraPivot") as Node3D
		if pivot:
			_motion.set("look_yaw", wrapf(pivot.global_rotation.y - global_rotation.y, -PI, PI))
	if _action_left > 0.0:
		_action_left -= delta
	_detect_footsteps()


# Moves each RobotArm part group onto the bone named in its "bone" metadata,
# so the cybernetic arm follows the animations.
func _attach_robot_arm() -> void:
	var arm := get_node_or_null("RobotArm")
	if arm == null:
		return
	var skel: Skeleton3D = find_children("*", "Skeleton3D", true, false)[0]
	for holder: Node3D in arm.get_children():
		var att := BoneAttachment3D.new()
		att.bone_name = holder.get_meta("bone")
		skel.add_child(att)
		holder.reparent(att, false)


# A foot touches down when its height stops falling and starts rising
# while it's near the ground.
func _detect_footsteps() -> void:
	var moving := _gait > 0.3 and _air < 0.5 and _action_left <= 0.0
	for foot in _feet:
		var y: float = _skel.get_bone_global_pose(foot[0]).origin.y
		var descending: bool = y < foot[1]
		if moving and foot[2] and not descending and y < 0.06:
			footstep.emit()
		foot[1] = y
		foot[2] = descending

# Missing animations (the Adventurer model only has Idle, Walk, Run, Run
# strafes/back, Interact, Roll and combat moves):
# - Jump start / fall loop / land: stood in for by a held Run stride, the
#   landing dip and torso compression.
# - Turn in place and start/stop steps: stood in for by limited turn speed,
#   slowing down to pivot and the weight-shift lean.
# - Walk backwards / walk strafes: not needed while Gana turns to face where
#   he's going (Run_Back / Run_Left / Run_Right exist but only at a run).
