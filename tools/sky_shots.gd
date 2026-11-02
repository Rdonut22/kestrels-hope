extends SceneTree

## Renders the crash-site sky from a few fixed views (for tuning the clouds).
## Run without --headless under xvfb-run:
##   godot --path . -s tools/sky_shots.gd -- <out_dir> [hour] [settle_frames]

var out := "user://sky_shots/"
var hour := 11.0
var settle := 90


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		hour = float(args[1])
	if args.size() > 2:
		settle = int(args[2])
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://crash_site.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(5)
	var scene := current_scene
	var clock: Node = scene.get_node("DayNight")
	clock.skip_to(hour)
	clock.set_process(false)
	var player: CharacterBody3D = scene.get_node("Player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	scene.get_node("HUD").visible = false
	var cam := Camera3D.new()
	cam.fov = 70
	cam.far = 4000.0
	scene.add_child(cam)
	cam.current = true
	var t0 := Time.get_ticks_msec()
	await _frames(settle)
	print("settle ms: ", Time.get_ticks_msec() - t0)
	# name, position, yaw (deg, 0 = north/-Z, 90 = east/+X), pitch (deg)
	var views := [
		["east", Vector3(26, 1.7, 8), 90.0, 12.0],
		["north", Vector3(26, 1.7, 8), 0.0, 14.0],
		["west", Vector3(26, 1.7, 8), -90.0, 14.0],
		["south", Vector3(26, 1.7, 8), 180.0, 14.0],
		["up", Vector3(26, 1.7, 8), 30.0, 50.0],
	]
	for v in views:
		cam.global_position = v[1]
		cam.rotation = Vector3(deg_to_rad(v[3]), -deg_to_rad(v[2]), 0.0)
		await _frames(int(OS.get_environment("SHOT_FRAMES")) if OS.get_environment("SHOT_FRAMES") != "" else 6)
		var t := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		var img := get_root().get_texture().get_image()
		img.save_png(out.path_join("%s.png" % v[0]))
		print("shot ", v[0], " frame us ", Time.get_ticks_usec() - t)
	quit()
