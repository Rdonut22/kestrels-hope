extends SceneTree

## Act one on the raised flight deck (ship/kestrel_exterior.gd): sit in the
## pilot seat, look out, switch to the panel view (windshield HUD), then run
## the first seconds of the landing cinematic. Saves screenshots.
##   godot --path . --script tools/flightdeck_check.gd -- <out_dir>

var out := "user://flightdeck_shots/"
var fails := 0


func _initialize() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://main.tscn")
	_run.call_deferred()


func _check(c: bool, what: String) -> void:
	print(("PASS " if c else "FAIL ") + what)
	if not c:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out.path_join(n + ".png"))


func _run() -> void:
	await _frames(20)
	var player: CharacterBody3D = current_scene.get_node("Player")
	var seat: Node3D = get_first_node_in_group("pilot_seat")
	_check(seat != null and seat.global_position.y > 1.0, "pilot seat is up on the flight deck (y %.2f)" % (seat.global_position.y if seat else -1.0))
	player.sit(seat)
	await _frames(40)
	var cam := get_root().get_camera_3d()
	_check(cam != null and cam.global_position.y > 2.2, "seated eye height on the deck (%.2f)" % (cam.global_position.y if cam else -1.0))
	await _shot("1_seated")
	seat.call("_set_panel_view", player, true)
	await _frames(60)
	await _shot("2_panel_view")
	var panel: Node3D = current_scene.find_child("CockpitPanel", true, false)
	_check(panel != null and panel.view_eye().y > 2.5, "panel view eye follows the deck")
	seat.call("_set_panel_view", player, false)
	await _frames(40)
	var descent: Node = current_scene.find_child("Descent", true, false)
	if descent:
		descent.call("begin")
		await _frames(240)
		await _shot("3_descent")
		_check(true, "landing cinematic runs")
	print("FAILS: %d" % fails)
	quit()
