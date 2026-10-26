extends Node3D

## Procedural walk/idle animation for the player character.
## The player calls set_move() every frame with 0 (still) to 1 (full speed).

@export var stride_speed := 10.0
@export var leg_swing := 0.55
@export var knee_bend := 0.9
@export var arm_swing := 0.45
@export var elbow_rest := 0.25

var _move := 0.0
var _blend := 0.0
var _phase := 0.0
var _time := 0.0

@onready var rig: Node3D = $Rig
@onready var chest: Node3D = $Rig/Chest
@onready var head: Node3D = $Rig/Chest/Head
@onready var hip_l: Node3D = $Rig/HipL
@onready var hip_r: Node3D = $Rig/HipR
@onready var knee_l: Node3D = $Rig/HipL/KneeL
@onready var knee_r: Node3D = $Rig/HipR/KneeR
@onready var shoulder_l: Node3D = $Rig/Chest/ShoulderL
@onready var shoulder_r: Node3D = $Rig/Chest/ShoulderR
@onready var elbow_l: Node3D = $Rig/Chest/ShoulderL/ElbowL
@onready var elbow_r: Node3D = $Rig/Chest/ShoulderR/ElbowR


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
	var c := cos(_phase)
	hip_l.rotation.x = s * leg_swing
	hip_r.rotation.x = -s * leg_swing
	# Each knee bends while its leg swings forward.
	knee_l.rotation.x = -maxf(0.0, c) * knee_bend * _blend
	knee_r.rotation.x = -maxf(0.0, -c) * knee_bend * _blend

	shoulder_l.rotation.x = -s * arm_swing
	shoulder_r.rotation.x = s * arm_swing
	elbow_l.rotation.x = elbow_rest + maxf(0.0, -s) * 0.5
	elbow_r.rotation.x = elbow_rest + maxf(0.0, s) * 0.5

	chest.rotation.x = -0.1 * _blend
	chest.rotation.y = s * 0.12
	head.rotation.x = 0.08 * _blend
	head.rotation.y = -s * 0.08

	var step_bob := absf(sin(_phase)) * 0.045 * _blend
	var breathe := sin(_time * 2.0) * 0.006 * (1.0 - _blend)
	rig.position.y = step_bob
	chest.scale = Vector3(1.0, 1.0 + breathe, 1.0 + breathe)
