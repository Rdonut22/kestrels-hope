extends SceneTree

## The hover bike (world/vehicles/hoverbike.gd): it hovers, Gana gets on with
## E, rides (throttle, steering, coasting), can't drive through the wreck,
## gets off with E onto the ground and walks again; saving while riding and
## loading puts him back on the bike where it was.
##   godot --path . -s tools/hoverbike_playtest.gd [-- <shots dir>]

var out := "user://playtest_shots/"
var player: CharacterBody3D
var bike: CharacterBody3D
var fails := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	Game.state().reset()
	change_scene_to_file("res://crash_site.tscn")
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _check(c: bool, what: String) -> void:
	print(("PASS " if c else "FAIL ") + what)
	if not c:
		fails += 1


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await process_frame


func _hold(actions: Array, secs: float) -> void:
	for a in actions:
		Input.action_press(a)
	await _wait(int(secs * 60))
	for a in actions:
		Input.action_release(a)


func _ground(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 10.0)
	q.exclude = [bike.get_rid(), player.get_rid()]
	var hit := root.get_world_3d().direct_space_state.intersect_ray(q)
	return float(hit.position.y) if hit else -999.0


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))


func _side_shot(name: String, from: Vector3) -> void:
	var cam := Camera3D.new()
	cam.fov = 50
	current_scene.add_child(cam)
	var target := bike.global_position + Vector3(0, 1.1, 0)
	cam.global_position = bike.global_transform * from
	cam.look_at(target)
	cam.make_current()
	await _wait(3)
	await _shot(name)
	cam.queue_free()
	player.get_node("CameraPivot/SpringArm3D/Camera3D").make_current()


func _run() -> void:
	while current_scene == null:
		await process_frame
	await _wait(30)
	var scene := current_scene
	var wake := scene.get_node_or_null("WakeUp")
	if wake:
		wake.queue_free()
	player = scene.get_node("Player")
	bike = scene.get_tree().get_first_node_in_group("hoverbike")
	_check(bike != null, "the hover bike is in the crash site")
	if bike == null:
		_finish()
		return
	var clock := scene.get_node_or_null("DayNight")
	if clock:
		clock.skip_to(14.0)
	await _wait(60)
	var gap: float = bike.global_position.y - _ground(bike.global_position)
	_check(absf(gap) < 0.15, "parked, it floats steady over the ground (origin %.2f m off the ground)" % gap)

	# Walk up beside it and look at it.
	var side: Vector3 = bike.global_transform * Vector3(-2.0, 0, 0)
	player.global_position = Vector3(side.x, _ground(side) + 1.05, side.z)
	var to: Vector3 = bike.global_position - player.global_position
	player.pivot.rotation = Vector3(-0.2, atan2(-to.x, -to.z), 0)
	await _wait(10)
	var target: Node = player.get("current_target")
	_check(target != null and target.get_parent() == bike, "looking at the bike targets it")
	await _shot("hoverbike_1_parked")
	await _press("interact")
	await _wait(30)
	_check(player.get("_bike") == bike and bike.get("rider") == player, "E gets Gana on the bike")
	await _shot("hoverbike_2_mounted")
	await _side_shot("hoverbike_3_mounted_side", Vector3(-3.2, 1.4, 0.6))
	await _side_shot("hoverbike_4_mounted_front", Vector3(-1.6, 1.6, -3.2))

	# Ride forward (the bike starts facing east, away from the wreck).
	var start: Vector3 = bike.global_position
	await _hold(["move_forward"], 3.0)
	var went: float = start.distance_to(bike.global_position)
	_check(went > 15.0, "W drives it forward (%.1f m in 3 s)" % went)
	gap = bike.global_position.y - _ground(bike.global_position)
	_check(absf(gap) < 0.35, "it keeps hovering while it moves (%.2f m off)" % gap)
	var rider_off: float = (player.get_node("Model") as Node3D).global_position.distance_to(bike.global_position)
	_check(rider_off < 1.5, "Gana stays on it (%.2f m from the bike)" % rider_off)
	await _shot("hoverbike_5_riding")
	var yaw0: float = bike.rotation.y
	await _hold(["move_forward", "move_left"], 1.5)
	var turned: float = absf(angle_difference(yaw0, bike.rotation.y))
	_check(turned > 0.5, "A steers (%.2f rad)" % turned)
	await _side_shot("hoverbike_6_turning", Vector3(2.5, 1.3, 3.5))
	await _wait(240)
	_check(absf(float(bike.get("speed"))) < 2.0, "letting go, it coasts to a stop (%.1f m/s)" % float(bike.get("speed")))

	# It can't go through the wreck.
	bike.global_position = Vector3(26.0, _ground(Vector3(26, 0, 0)), 0.0)
	bike.rotation = Vector3(0, PI / 2, 0)   # facing -X, at the wreck
	bike.set("speed", 0.0)
	await _wait(10)
	await _hold(["move_forward"], 4.0)
	_check(bike.global_position.x > 12.0, "it stops at the wreck's hull (x %.1f)" % bike.global_position.x)
	await _wait(60)

	# Get off.
	await _press("interact")
	await _wait(40)
	_check(player.get("_bike") == null and bike.get("rider") == null, "E gets Gana off")
	_check(player.is_on_floor(), "he lands standing on the ground")
	_check(player.global_position.distance_to(bike.global_position) < 3.5, "beside the bike (%.1f m)" % player.global_position.distance_to(bike.global_position))
	await _shot("hoverbike_7_dismounted")
	var before: Vector3 = player.global_position
	player.pivot.rotation.y = bike.rotation.y + PI / 2
	await _hold(["move_forward"], 1.0)
	_check(before.distance_to(player.global_position) > 2.0, "and walks off again")

	# Saving while riding, then loading.
	var side2: Vector3 = bike.global_transform * Vector3(-2.0, 0, 0)
	player.global_position = Vector3(side2.x, _ground(side2) + 1.05, side2.z)
	player.mount(bike)
	await _wait(20)
	var saved_at: Vector3 = bike.global_position
	_check(Game.state().save_game(), "it saves while riding")
	Game.state().load_game()
	await _wait(90)
	player = current_scene.get_node("Player")
	bike = current_scene.get_tree().get_first_node_in_group("hoverbike")
	_check(bike != null and bike.global_position.distance_to(saved_at) < 1.0, "loading puts the bike back where it was")
	_check(bike != null and player.get("_bike") == bike, "and Gana back on it")
	_finish()


func _finish() -> void:
	Input.action_release("move_forward")
	Input.action_release("move_left")
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
