extends SceneTree

## Renders the ruined greenhouse in the east forest from the trail and its
## clearing (tools/build_scenes.gd _build_greenhouse). Run under xvfb-run:
##   godot --path . -s tools/greenhouse_shots.gd -- <out_dir> [hour]

const GH := Vector2(455.0, 14.5)

var out := "user://greenhouse_shots/"
var hour := 15.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		hour = float(args[1])
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://crash_site.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


static func _trail_z(x: float) -> float:
	return -16.0 + 42.0 * sin(x * 0.0085) + 16.0 * sin(x * 0.023 + 1.0)


func _run() -> void:
	await _frames(5)
	var scene := current_scene
	var clock: Node = scene.get_node("DayNight")
	clock.skip_to(hour)
	clock.set_process(false)
	var T := load("res://world/east_terrain.gd")
	var ground_y: float = (scene.get_node("CrashSite/EastGround") as Node3D).position.y
	var player: CharacterBody3D = scene.get_node("Player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	(player.get("mesh") as Node3D).visible = false
	scene.get_node("HUD").visible = false
	var cam := Camera3D.new()
	cam.fov = 70
	cam.far = 4000.0
	scene.add_child(cam)
	cam.current = true
	var gh_y: float = ground_y + float(T.call("height", GH.x, GH.y))
	# name, camera (x, z), eye height, look-at height
	var views := [
		["1_trail_approach", Vector2(395.0, _trail_z(395.0)), 1.7, 14.0],
		["2_trail_gap", Vector2(GH.x, _trail_z(GH.x)), 1.7, 14.0],
		["3_clearing_edge", Vector2(GH.x - 8.0, GH.y - 46.0), 1.7, 16.0],
		["4_close", Vector2(GH.x + 12.0, GH.y - 34.0), 1.7, 8.0],
	]
	for v in views:
		var p: Vector2 = v[1]
		var eye := Vector3(p.x, ground_y + float(T.call("height", p.x, p.y)) + float(v[2]), p.y)
		player.global_position = eye
		cam.global_position = eye
		cam.look_at(Vector3(GH.x, gh_y + float(v[3]), GH.y))
		await _frames(30)
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(out.path_join("%s.png" % v[0]))
		print("shot ", v[0])
	# Inside (interior coordinates: the model's frame in metres, from the
	# floor; world/greenhouse.gd).
	var inner := scene.get_node("CrashSite/Ruins/Greenhouse/Interior") as Node3D
	var inside := [
		["5_floor_up", Vector3(-2.0, 3.7, -10.0), Vector3(2.0, 24.0, 4.0)],
		["6_floor_across", Vector3(8.0, 3.7, 6.0), Vector3(-12.0, 9.0, -8.0)],
		["7_stairs", Vector3(-12.0, 3.7, -4.0), Vector3(-17.0, 8.0, -13.0)],
		["8_walkway", Vector3(17.5, 19.8, -9.0), Vector3(-10.0, 12.0, 6.0)],
	]
	for v in inside:
		var eye: Vector3 = inner.to_global(v[1])
		player.global_position = eye
		cam.global_position = eye
		cam.look_at(inner.to_global(v[2]))
		await _frames(40)
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(out.path_join("%s.png" % v[0]))
		print("shot ", v[0])
	quit()
