extends Node3D

## Drives the Adventurer model's animations from the player's movement.
## The player calls set_move() every frame with 0 (still) to 1 (full speed),
## and play_action() for one-shot gestures like "Interact".

const PREFIX := "CharacterArmature|"

## Emitted when a foot touches down during the walk or run animation.
signal footstep

@export var walk_threshold := 0.05
@export var run_threshold := 0.55
@export var blend_time := 0.2

var _move := 0.0
var _current := ""
var _action_left := 0.0
var _skel: Skeleton3D
var _feet := []  # [bone index, last height, was descending]

@onready var anim: AnimationPlayer = $Adventurer/AnimationPlayer


func _ready() -> void:
	_attach_robot_arm()
	_skel = find_children("*", "Skeleton3D", true, false)[0]
	for bone in ["Foot.L", "Foot.R"]:
		_feet.append([_skel.find_bone(bone), 0.0, false])
	for name in ["Idle", "Walk", "Run"]:
		var a := anim.get_animation(PREFIX + name)
		if a:
			a.loop_mode = Animation.LOOP_LINEAR
	_play("Idle")


func set_move(amount: float) -> void:
	_move = clampf(amount, 0.0, 1.0)


func play_action(name: String) -> void:
	if anim.has_animation(PREFIX + name):
		_current = name
		anim.play(PREFIX + name, 0.1)
		_action_left = anim.get_animation(PREFIX + name).length * 0.8


func _process(delta: float) -> void:
	if _action_left > 0.0:
		_action_left -= delta
		if _move < walk_threshold:
			return
		_action_left = 0.0
	_detect_footsteps()
	if _move < walk_threshold:
		_play("Idle")
	elif _move < run_threshold:
		_play("Walk")
	else:
		_play("Run")


func _play(name: String) -> void:
	if name != _current:
		_current = name
		anim.play(PREFIX + name, blend_time)


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
	var moving := _move >= walk_threshold and _action_left <= 0.0
	for foot in _feet:
		var y: float = _skel.get_bone_global_pose(foot[0]).origin.y
		var descending: bool = y < foot[1]
		if moving and foot[2] and not descending and y < 0.06:
			footstep.emit()
		foot[1] = y
		foot[2] = descending
