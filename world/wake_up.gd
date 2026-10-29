extends Node

## Coming to after the landing (ship/descent.gd sets "wake_after_crash"
## just before it hands over to this scene). Black and ringing ears, then a
## blurry view from the floor of the quarters that clears and rises to
## Gana's normal view before he gets control back. Starting the crash site
## any other way (e.g. from the menu) skips this.

const FLAG := "wake_after_crash"


func _ready() -> void:
	var gs := Game.state()
	if not gs.has_flag(FLAG):
		return
	gs.flags.erase(FLAG)
	_wake.call_deferred()


func _wake() -> void:
	var scene := get_tree().current_scene
	var player: Node3D = scene.get_node("Player")
	var hud: Node = get_tree().get_first_node_in_group("hud")
	var cam: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")
	# Screen effects, as an overlay so Gana can't move yet.
	var fx := ColorRect.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ui/screen_fx.gdshader")
	mat.set_shader_parameter("dark", 1.0)
	mat.set_shader_parameter("blur", 4.5)
	mat.set_shader_parameter("vignette", 0.9)
	fx.material = mat
	hud.add_overlay(fx)
	var ring := AudioStreamPlayer.new()
	ring.set_script(load("res://ui/ear_ring.gd"))
	add_child(ring)
	ring.set("level", 1.0)
	# Lying on the floor, head turned, looking along the deck.
	await get_tree().process_frame
	var end_xf := cam.global_transform
	var low := Camera3D.new()
	low.fov = cam.fov
	low.near = 0.05
	scene.add_child(low)
	var head := player.global_position + Vector3(0, -0.82, 0)
	var ahead := -end_xf.basis.z
	ahead.y = 0
	ahead = ahead.normalized()
	low.global_transform = Transform3D(Basis.looking_at(ahead + Vector3(0, 0.25, 0), Vector3.UP), head)
	low.rotate_object_local(Vector3.BACK, deg_to_rad(68.0))
	var start_xf := low.global_transform
	low.make_current()
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("dark", 1.0 - v)
		ring.set("level", 1.0 - v * 0.6), 0.0, 1.0, 2.6)
	await tw.finished
	hud.think(["...Ugh."])
	# Blink a couple of times, then push up off the floor.
	for k in 2:
		var b := create_tween()
		b.tween_method(func(v: float) -> void: mat.set_shader_parameter("dark", v), 0.0, 0.85, 0.12)
		b.tween_method(func(v: float) -> void: mat.set_shader_parameter("dark", v), 0.85, 0.0, 0.3)
		await b.finished
		await get_tree().create_timer(0.5).timeout
	var rise := create_tween().set_parallel()
	rise.tween_method(func(v: float) -> void:
		low.global_transform = start_xf.interpolate_with(cam.global_transform, smoothstep(0.0, 1.0, v))
		mat.set_shader_parameter("blur", lerpf(4.5, 0.6, v))
		mat.set_shader_parameter("vignette", lerpf(0.9, 0.35, v))
		ring.set("level", lerpf(0.4, 0.1, v)), 0.0, 1.0, 3.8)
	await rise.finished
	cam.make_current()
	low.queue_free()
	var clear := create_tween()
	clear.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("blur", lerpf(0.6, 0.0, v))
		mat.set_shader_parameter("vignette", lerpf(0.35, 0.0, v))
		ring.set("level", lerpf(0.1, 0.0, v)), 0.0, 1.0, 1.6)
	await clear.finished
	fx.hide()
	fx.queue_free()
	ring.queue_free()
	hud.think(["Still in one piece. Mostly.", "...Where the hell did we come down?"])
