extends OmniLight3D

## Randomly flickers, like a light on a damaged circuit.

@export var base_energy := 0.6

var _timer := 0.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		var off := randf() < 0.3
		light_energy = 0.0 if off else base_energy * randf_range(0.5, 1.2)
		_timer = randf_range(0.03, 0.12) if randf() < 0.7 else randf_range(0.6, 2.0)
