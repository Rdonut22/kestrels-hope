extends SceneTree

## Renders ship/kestrel_v2_test.tscn from the sketch angles (back, iso) and
## a few more. godot --path . -s tools/ship_shots.gd -- <out_dir>

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://ship_shots"
	DirAccess.make_dir_recursive_absolute(out)
	var root: Node3D = (load("res://ship/kestrel_v2_test.tscn") as PackedScene).instantiate()
	get_root().add_child(root)
	# Daylight like the crash site: sky, soft sky-coloured fill, a warm sun
	# with shadows.
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.42, 0.75)
	sky_mat.sky_horizon_color = Color(0.62, 0.74, 0.86)
	sky_mat.ground_horizon_color = Color(0.55, 0.62, 0.55)
	sky_mat.ground_bottom_color = Color(0.3, 0.38, 0.25)
	sky.sky_material = sky_mat
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = sky
	# Fill and reflections as at the crash site (tools/build_scenes.gd).
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.68, 0.66)
	env.environment.ambient_light_energy = 0.6
	env.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment.tonemap_exposure = 0.9
	get_root().add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	get_root().add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 60
	get_root().add_child(cam)
	cam.current = true
	_run.call_deferred(cam, out)


func _run(cam: Camera3D, out: String) -> void:
	var c := Vector3(0.5, 1.8, 1)
	var views := {"1_back": Vector3(0, 3.0, 38), "2_iso_front": Vector3(24, 16, -26), "3_side_starboard": Vector3(36, 2.5, 1), "4_top": Vector3(0, 46, 1.01), "5_port_front": Vector3(-24, 7, -16), "6_port_close": Vector3(-14, 6.5, -9), "7_port_low": Vector3(-24, 0.5, 12), "8_nose": Vector3(4, 4.5, -22), "9_port_win": Vector3(-14, 3.0, -2), "a_pilot": Vector3(2.8, -0.55, -12.0), "b_lounge": Vector3(1.9, -0.6, 0.6), "c_gunner": Vector3(-3.5, 0.2, 4.5), "d_starboard": Vector3(30, 2.0, -2)}
	var only := OS.get_environment("VIEWS")
	var look_at := {"8_nose": Vector3(4.7, 4.0, -11.0), "9_port_win": Vector3(-7.7, 2.3, -1.0), "a_pilot": Vector3(3.3, 1.0, -20.0), "b_lounge": Vector3(9.0, 1.3, 2.0), "c_gunner": Vector3(-12.0, 2.0, 5.5)}
	for nm in views:
		if only != "" and not only.contains(nm.substr(0, 1)):
			continue
		cam.position = c + views[nm]
		cam.look_at(look_at.get(nm, c))
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(out.path_join(nm + ".png"))
	quit()
