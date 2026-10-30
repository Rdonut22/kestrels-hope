extends Node3D

## Flutters around its starting point. The wings flap in its shader
## (world/butterfly.gdshader).

@export var wander := 4.0
@export var speed := 1.2

var _home: Vector3
var _target: Vector3
var _t := 0.0


func _ready() -> void:
	_home = position
	_t = randf() * 10.0
	_pick()


func _pick() -> void:
	_target = _home + Vector3(randf_range(-wander, wander), randf_range(-0.4, 1.2), randf_range(-wander, wander))


func _process(delta: float) -> void:
	_t += delta
	var to := _target - position
	if to.length() < 0.3:
		_pick()
	var step := to.normalized() * speed * delta
	step.y += sin(_t * 5.0) * 0.6 * delta
	position += step
	if Vector2(to.x, to.z).length() > 0.01:
		rotation.y = atan2(-to.x, -to.z)
