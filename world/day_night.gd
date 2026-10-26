extends Node

## Day-night cycle: moves the sun, raises the moonlight at night, and
## tints the sky, fog and ambient light to match the time of day.
## Nodes in the "night_only" / "day_only" groups are shown accordingly.

## Real seconds for one full 24-hour day (1440 = 1 game hour per minute).
@export var day_length := 1440.0
@export_range(0.0, 24.0) var hour := 9.0

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _env: Environment
var _sky: ShaderMaterial
var _was_night := false
var _tinted: Array[ShaderMaterial] = []


func _enter_tree() -> void:
	add_to_group("day_night")


func _ready() -> void:
	_sun = get_parent().get_node("Sun")
	_moon = get_parent().get_node("Moon")
	_env = get_parent().get_node("WorldEnvironment").environment
	_sky = _env.sky.sky_material
	_was_night = not is_night()
	# Pixel-art world materials take an explicit tint instead of scene lighting.
	for n in get_parent().find_children("*", "GeometryInstance3D", true, false):
		var m = n.material_override
		if m is ShaderMaterial and m.shader and m.shader.resource_path.begins_with("res://world/") \
				and not _tinted.has(m):
			_tinted.append(m)
	_apply()


## Jump to the given hour, rolling over to the next day if it's already past.
func skip_to(target_hour: float) -> void:
	hour = target_hour
	_apply()


func is_night() -> bool:
	return hour < 5.5 or hour > 19.5


func clock_text() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	return "%02d:%02d" % [h, m]


func _process(delta: float) -> void:
	hour = fmod(hour + delta * 24.0 / day_length, 24.0)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	# T skips an hour ahead (handy for testing).
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		hour = fmod(hour + 1.0, 24.0)
		_apply()


func _apply() -> void:
	# Sun rises in the east (+X) at 6:00, peaks at noon, sets at 18:00.
	var a := (hour - 6.0) / 12.0 * PI
	var to_sun := Vector3(cos(a), sin(a) * 0.9, 0.3).normalized()
	var s := to_sun.y
	var day := smoothstep(-0.12, 0.2, s)
	var dusk := clampf(1.0 - absf(s - 0.03) / 0.28, 0.0, 1.0)

	_sun.basis = Basis.looking_at(-to_sun if s > -0.99 else Vector3.DOWN, Vector3.UP)
	_sun.light_energy = 1.8 * smoothstep(-0.02, 0.18, s)
	_sun.light_color = Color(1.0, 0.5, 0.28).lerp(Color(1.0, 0.95, 0.85), smoothstep(0.0, 0.4, s))
	_sun.visible = _sun.light_energy > 0.01
	_moon.light_energy = 0.32 * (1.0 - day)
	_moon.visible = _moon.light_energy > 0.01

	var night_amb := Color(0.16, 0.2, 0.36)
	var day_amb := Color(0.55, 0.65, 0.55)
	_env.ambient_light_color = night_amb.lerp(day_amb, day).lerp(Color(0.85, 0.55, 0.45), dusk * 0.5)
	_env.ambient_light_energy = lerpf(0.22, 0.55, day)
	var night_fog := Color(0.05, 0.07, 0.13)
	var day_fog := Color(0.52, 0.7, 0.66)
	_env.fog_light_color = night_fog.lerp(day_fog, day).lerp(Color(0.78, 0.5, 0.42), dusk * 0.7)

	var tint := Color(0.2, 0.25, 0.42).lerp(Color(1, 1, 1), day).lerp(Color(1.0, 0.72, 0.58), dusk * 0.5)
	var fog := _env.fog_light_color
	for m in _tinted:
		m.set_shader_parameter("world_tint", tint)
		m.set_shader_parameter("haze", fog)

	_sky.set_shader_parameter("prism", clampf(dusk + (1.0 - day) * 0.5, 0.0, 1.0))
	_sky.set_shader_parameter("day", day)
	_sky.set_shader_parameter("dusk", dusk)
	_sky.set_shader_parameter("sun_dir", to_sun)

	var night := is_night()
	if night != _was_night:
		_was_night = night
		for n in get_tree().get_nodes_in_group("night_only"):
			n.visible = night
			if n is CPUParticles3D:
				n.emitting = night
		for n in get_tree().get_nodes_in_group("day_only"):
			n.visible = not night
