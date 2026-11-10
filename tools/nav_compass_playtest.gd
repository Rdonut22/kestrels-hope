extends SceneTree

## Navigation compass (ui/nav_compass): headings, cardinal letters, the
## waypoint's bearing and range, hiding behind menus. Saves screenshots.
##   godot --path . -s tools/nav_compass_playtest.gd [-- <out_dir>]

var fails := 0
var out := "user://nav_compass_shots"
var player: CharacterBody3D
var hud: Node
var compass: NavCompass


func _check(c: bool, w: String) -> void:
	print(("PASS " if c else "FAIL ") + w)
	if not c:
		fails += 1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://crash_site.tscn")
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


## Face a heading (degrees clockwise from north); the camera yaw is the
## pivot's (rotating +Y turns -Z towards -X, i.e. west).
func _face(deg: float, pitch := -0.12) -> void:
	player.pivot.rotation = Vector3(pitch, -deg_to_rad(deg), 0)
	player.mesh.rotation.y = player.pivot.rotation.y
	await _wait(4)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out + "/" + name + ".png")


func _letter_x(n: String) -> float:
	var tr: TextureRect = compass.get_node("Cardinals/" + n)
	return tr.position.x + tr.size.x * 0.5


func _run() -> void:
	await _wait(40)
	player = current_scene.get_node("Player")
	hud = current_scene.get_node("HUD")
	compass = hud.get_node_or_null("NavCompass") as NavCompass
	_check(compass != null, "compass is part of the HUD")
	if compass == null:
		print("FAILS: ", fails)
		quit()
		return
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector3(16, 1.0, 10)
	await _face(0.0)
	_check(compass.visible, "compass visible during play")
	var top := compass.get_global_rect().position.y
	_check(top >= 0.0 and top < 60.0 * root.size.y / 1080.0, "compass sits at the top of the screen (y %.0f)" % top)
	_check(absf(compass.heading) < 1.0 or absf(compass.heading - 360.0) < 1.0, "facing north reads 0 (%.1f)" % compass.heading)
	_check(absf(_letter_x("N") - NavCompass.CENTER_X) < 2.0, "N under the marker when facing north")
	_check(absf(_letter_x("E") - (NavCompass.CENTER_X + 90.0 * compass.px_per_degree)) < 2.0, "E 90 degrees to the right")
	_check(absf(_letter_x("W") - (NavCompass.CENTER_X - 90.0 * compass.px_per_degree)) < 2.0, "W 90 degrees to the left")
	_check(not (compass.get_node("Cardinals/S") as CanvasItem).visible, "S hidden when it's behind")
	await _shot("01_north")

	await _face(90.0)
	_check(absf(compass.heading - 90.0) < 1.0, "facing east reads 90 (%.1f)" % compass.heading)
	_check(absf(_letter_x("E") - NavCompass.CENTER_X) < 2.0, "E under the marker when facing east")
	var marker: TextureRect = compass.get_node("PlayerMarker")
	var mx := marker.position.x + marker.size.x * 0.5
	_check(absf(mx - NavCompass.CENTER_X) < 1.0, "player marker stays centred")

	# Waypoint 40 m to the north-east of the camera. (Bearings are from
	# the camera, which swings round Gana on its arm, so place it after
	# turning.)
	await _face(0.0)
	var cam := root.get_camera_3d()
	var wp := NavWaypoint.new()
	current_scene.add_child(wp)
	var c := cam.global_position
	wp.global_position = c + Vector3(1, 0, -1).normalized() * 40.0
	await _wait(2)
	_check(absf(compass.waypoint_bearing - 45.0) < 2.0, "waypoint bearing NE reads 45 (%.1f)" % compass.waypoint_bearing)
	_check(compass.is_waypoint_visible(), "waypoint shown when it's ahead")
	var w: TextureRect = compass.get_node("Waypoint")
	var wx := w.position.x + w.size.x * 0.5
	_check(absf(wx - (NavCompass.CENTER_X + 45.0 * compass.px_per_degree)) < 3.0, "waypoint at its bearing on the strip")
	await _shot("02_waypoint_ahead")
	await _face(70.0)
	wx = w.position.x + w.size.x * 0.5
	_check(wx < NavCompass.CENTER_X, "waypoint moves left when Gana turns right past it")
	await _shot("03_waypoint_left")
	await _face(225.0)
	_check(not compass.is_waypoint_visible(), "waypoint hidden when it's behind")
	await _shot("04_waypoint_behind")

	# A fixed position set from code takes priority over NavWaypoint nodes.
	await _face(270.0)
	compass.set_waypoint(cam.global_position + Vector3(-30, 0, 0))
	await _wait(2)
	_check(absf(compass.waypoint_bearing - 270.0) < 2.0, "set_waypoint(Vector3) tracked (%.1f)" % compass.waypoint_bearing)
	compass.clear_waypoint()
	wp.active = false
	await _wait(2)
	_check(not compass.is_waypoint_visible(), "no waypoint when none is active")

	# Hidden while a menu is up.
	hud.open_screen("TEST", [])
	await _wait(3)
	_check(not compass.visible, "compass hidden while the HUD is busy")
	hud.close_screen()
	await _wait(3)
	_check(compass.visible, "compass back after the menu closes")

	# The ship's own waypoint (at the breach): hidden close to the ship,
	# shown from out in the forest, pointing back at the breach.
	wp.active = false
	var ship_wp: NavWaypoint = current_scene.get_node_or_null("Ship/ShipWaypoint")
	_check(ship_wp != null, "crash site has a ship waypoint")
	if ship_wp:
		player.global_position = ship_wp.global_position + Vector3(4, -0.2, 6)
		await _face(0.0)
		_check(not compass.is_waypoint_visible(), "ship waypoint hidden near the ship")
		player.global_position = Vector3(ship_wp.global_position.x - 45.0, 1.0, ship_wp.global_position.z + 40.0)
		await _face(135.0)
		var cpos := root.get_camera_3d().global_position
		var want := NavCompass.heading_of(ship_wp.global_position - cpos)
		_check(compass.is_waypoint_visible(), "ship waypoint shown from the forest")
		_check(absf(wrapf(compass.waypoint_bearing - want, -180.0, 180.0)) < 1.0,
			"ship waypoint points at the breach (%.1f, want %.1f)" % [compass.waypoint_bearing, want])
		await _shot("05_ship_from_forest")
		ship_wp.active = false

	# Inside the ship too.
	wp.active = true
	var ship: Node3D = current_scene.get_node("Ship")
	player.global_position = ship.to_global(Vector3(-0.15, 1.1, 2.0))
	await _face(30.0, -0.05)
	_check(compass.visible, "compass shows inside the ship")
	await _shot("06_ship_inside")
	print("FAILS: ", fails)
	quit()
