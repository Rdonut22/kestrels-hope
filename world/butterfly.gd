extends Node3D

## Flutters around its starting point. The wings flap in its shader
## (world/butterfly.gdshader). At night its wings glow (day_night.gd calls
## set_night on the "night_glow" group).

@export var wander := 4.0
@export var speed := 1.2

var _home: Vector3
var _target: Vector3
var _t := 0.0


func _ready() -> void:
	_home = position
	_t = randf() * 10.0
	_pick()


var _glow := 0.0
var _glow_tween: Tween


func set_night(night: bool) -> void:
	if _glow_tween:
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.tween_method(_set_glow, _glow, 1.0 if night else 0.0, 3.0)


func _set_glow(v: float) -> void:
	_glow = v
	var body := get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	for i in body.get_surface_override_material_count():
		var m := body.get_surface_override_material(i) as ShaderMaterial
		if m:
			m.set_shader_parameter("glow", v)


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
