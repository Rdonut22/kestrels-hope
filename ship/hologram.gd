extends Node3D

## Turns the holo-table projection slowly and bobs it a little.

func _process(delta: float) -> void:
	$Globe.rotate_y(delta * 0.35)
	$Orbit.rotate_y(delta * -0.6)
	$Globe.position.y = 0.42 + sin(Time.get_ticks_msec() * 0.0012) * 0.015
