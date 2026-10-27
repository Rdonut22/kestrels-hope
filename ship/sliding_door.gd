extends Node3D

## Sci-fi sliding door: the two leaves part sideways into the wall when the
## player comes near and close again once they've left. Built by the scene
## builder with a Frame, LeafLeft/LeafRight bodies and a Sensor area.

## Seconds to go fully open or shut.
@export var open_time := 0.45
## How far each leaf slides (in the door's local units).
@export var travel := 1.25
## Low power: the leaves stutter partway before finishing.
@export var sluggish := false

var _open := 0.0
var _target := 0.0
var _inside := 0
var _left: Node3D
var _right: Node3D
var _left_z := 0.0
var _right_z := 0.0
var _sound: AudioStreamPlayer3D

func _ready() -> void:
	_left = $LeafLeft
	_right = $LeafRight
	_left_z = _left.position.z
	_right_z = _right.position.z
	_sound = get_node_or_null("Sound")
	var sensor: Area3D = $Sensor
	sensor.body_entered.connect(_on_body_entered)
	sensor.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_inside += 1
		_set_target(1.0)

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_inside = maxi(_inside - 1, 0)
		if _inside == 0:
			_set_target(0.0)

func _set_target(t: float) -> void:
	if t == _target:
		return
	_target = t
	if _sound:
		_sound.pitch_scale = randf_range(0.95, 1.05) * (0.8 if sluggish else 1.0)
		_sound.play()

func _physics_process(delta: float) -> void:
	if is_equal_approx(_open, _target):
		return
	var speed := delta / open_time
	# A sluggish door catches for a moment around the halfway mark.
	if sluggish and _target > _open and absf(_open - 0.45) < 0.05:
		speed *= 0.08
	_open = move_toward(_open, _target, speed)
	var e := _open * _open * (3.0 - 2.0 * _open)
	_left.position.z = _left_z - travel * e
	_right.position.z = _right_z + travel * e
