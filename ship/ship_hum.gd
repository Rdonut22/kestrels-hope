extends AudioStreamPlayer

## Low hum of the ship in space, looped.

func _ready() -> void:
	stream = load("res://audio/space_hum.ogg")
	if "loop" in stream:
		stream.loop = true
	volume_db = -12.0
	play()
