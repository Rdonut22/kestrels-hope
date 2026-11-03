extends SceneTree

## Renders ship/kestrel_v2_test.tscn from the sketch angles (back, iso) and
## a few more. godot --path . -s tools/ship_shots.gd -- <out_dir>

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://ship_shots"
	DirAccess.make_dir_recursive_absolute(out)
	var root: Node3D = (load("res://ship/kestrel_v2_test.tscn") as PackedScene).instantiate()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.42, 0.43, 0.46)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	get_root().add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -40, 0)
	get_root().add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 45
	get_root().add_child(cam)
	cam.current = true
	_run.call_deferred(cam, out)


func _run(cam: Camera3D, out: String) -> void:
	var c := Vector3(0.5, 1.8, 1)
	var views := {"1_back": Vector3(0, 3.0, 38), "2_iso_front": Vector3(24, 16, -26), "3_side_starboard": Vector3(36, 2.5, 1), "4_top": Vector3(0, 46, 1.01), "5_port_front": Vector3(-24, 7, -16), "6_port_close": Vector3(-17, 1.5, -1), "7_port_low": Vector3(-24, 0.5, 12)}
	var only := OS.get_environment("VIEWS")
	for nm in views:
		if only != "" and not only.contains(nm.substr(0, 1)):
			continue
		cam.position = c + views[nm]
		cam.look_at(c)
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(out.path_join(nm + ".png"))
	quit()
