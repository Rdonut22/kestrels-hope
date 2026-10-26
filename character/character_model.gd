extends Node3D

## Procedural walk/idle animation for the blocky character.
## The player calls set_move() every frame with 0 (still) to 1 (full speed).

@export var stride_speed := 10.0
@export var leg_swing := 0.6
@export var arm_swing := 0.5

var _move := 0.0
var _blend := 0.0
var _phase := 0.0
var _time := 0.0

@onready var rig: Node3D = $Rig
@onready var hip_l: Node3D = $Rig/HipL
@onready var hip_r: Node3D = $Rig/HipR
@onready var shoulder_l: Node3D = $Rig/ShoulderL
@onready var shoulder_r: Node3D = $Rig/ShoulderR


func set_move(amount: float) -> void:
	_move = clampf(amount, 0.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	_blend = lerpf(_blend, _move, 1.0 - exp(-12.0 * delta))
	if _blend > 0.01:
		_phase += delta * stride_speed * (0.4 + 0.6 * _blend)
	else:
		_phase = lerpf(_phase, round(_phase / PI) * PI, 1.0 - exp(-8.0 * delta))

	var s := sin(_phase) * _blend
	hip_l.rotation.x = s * leg_swing
	hip_r.rotation.x = -s * leg_swing
	shoulder_l.rotation.x = -s * arm_swing
	shoulder_r.rotation.x = s * arm_swing

	var step_bob := absf(sin(_phase)) * 0.05 * _blend
	var breathe := sin(_time * 2.0) * 0.008 * (1.0 - _blend)
	rig.position.y = step_bob + breathe
