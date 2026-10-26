extends Node3D

## Drives the Adventurer model's animations from the player's movement.
## The player calls set_move() every frame with 0 (still) to 1 (full speed),
## and play_action() for one-shot gestures like "Interact".

const PREFIX := "CharacterArmature|"

@export var walk_threshold := 0.05
@export var run_threshold := 0.55
@export var blend_time := 0.2

var _move := 0.0
var _current := ""
var _action_left := 0.0

@onready var anim: AnimationPlayer = $Adventurer/AnimationPlayer


func _ready() -> void:
	_attach_robot_arm()
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
