extends Node

## Emergency power until Meki reroutes the backup cell: the ship's lights
## run dim and red and the hum is faint. Then the rooms come back one at a
## time, each with a relay clunk.

@export var lights_path: NodePath
@export var hum_path: NodePath

var _dim := StandardMaterial3D.new()
var _clunk: AudioStreamPlayer


func _ready() -> void:
	_dim.albedo_color = Color(0.25, 0.22, 0.2)
	_clunk = AudioStreamPlayer.new()
	_clunk.stream = load("res://audio/sfx/power_on.ogg")
	_clunk.volume_db = -8.0
	add_child(_clunk)
	if Game.state().power_restored:
		return
	for l in _lights():
		l.set_meta("energy", l.light_energy)
		l.set_meta("color", l.light_color)
		l.light_energy *= 0.22
		l.light_color = l.light_color.lerp(Color(1.0, 0.25, 0.18), 0.75)
		var fixture := l.get_node_or_null("Fixture") as MeshInstance3D
		if fixture:
			fixture.set_meta("mat", fixture.material_override)
			fixture.material_override = _dim
	var hum := get_node_or_null(hum_path)
	if hum:
		hum.volume_db = -26.0
	Game.state().power_restored_changed.connect(_on_power, CONNECT_ONE_SHOT)


func _lights() -> Array:
	var root := get_node_or_null(lights_path)
	return root.get_children().filter(func(n: Node) -> bool: return n is OmniLight3D) if root else []


func _on_power(_on: bool) -> void:
	for l: OmniLight3D in _lights():
		if not l.has_meta("energy"):
			continue
		_clunk.pitch_scale = randf_range(0.9, 1.1)
		_clunk.play()
		var tw := create_tween().set_parallel()
		tw.tween_property(l, "light_energy", l.get_meta("energy"), 0.5)
		tw.tween_property(l, "light_color", l.get_meta("color"), 0.5)
		var fixture := l.get_node_or_null("Fixture") as MeshInstance3D
		if fixture:
			fixture.material_override = fixture.get_meta("mat")
		await get_tree().create_timer(0.35).timeout
	var hum := get_node_or_null(hum_path)
	if hum:
		create_tween().tween_property(hum, "volume_db", -12.0, 2.0)
