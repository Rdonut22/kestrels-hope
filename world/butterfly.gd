extends Node3D

## Flutters around its starting point, flapping two wings.

@export var wander := 4.0
@export var speed := 1.2

var _home: Vector3
var _target: Vector3
var _t := 0.0

@onready var wing_l: Node3D = $WingL
@onready var wing_r: Node3D = $WingR


func _ready() -> void:
	_home = position
	_t = randf() * 10.0
	_pick()


func _pick() -> void:
	_target = _home + Vector3(randf_range(-wander, wander), randf_range(-0.4, 1.2), randf_range(-wander, wander))


func _process(delta: float) -> void:
	_t += delta
	var flap := sin(_t * 18.0) * 0.9
	wing_l.rotation.z = flap
	wing_r.rotation.z = -flap
	var to := _target - position
	if to.length() < 0.3:
		_pick()
	var step := to.normalized() * speed * delta
	step.y += sin(_t * 5.0) * 0.6 * delta
	position += step
	if Vector2(to.x, to.z).length() > 0.01:
		rotation.y = atan2(-to.x, -to.z)
