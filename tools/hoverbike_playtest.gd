extends SceneTree

## The hover bike (world/vehicles/hoverbike.gd): parked, it rests on the
## ground, off. Gana gets on with E; the switch panel glows, Space flips its
## toggles left then right, and the engine starts and lifts it to hover.
## He rides (throttle twisting the grip, steering, coasting, B braking with
## the lever), can't drive through the wreck, gets off with E (it powers
## down, still hovering, and drops as the power-down sound ends) and walks
## again; getting off at speed, it drifts on first. Saving while riding and loading puts him back on the running
## bike where it was.
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
	_check(absf(gap) < 0.15, "parked, it sits steady on the ground (origin %.2f m off the ground)" % gap)
	_check(not bike.get("running") and _body_drop() > 0.4, "switched off, resting low (body %.2f m down)" % _body_drop())

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
	var cam := root.get_viewport().get_camera_3d()
	_check(cam != null and cam.name == "RideCamera", "riding is seen in first person")
	_check(not (player.get_node("Model") as Node3D).visible, "with Gana's body hidden")
	var key: Node3D = bike.get_node("Seat").get("_key")
	_check(key == null or not key.visible, "and the bike's [E] hint gone")
	var eye: float = cam.global_position.y - bike.global_position.y if cam else 0.0
	# (Switched off, the bike rests on the ground: hover_height lower.)
	_check(eye > 1.0 and eye < 1.75, "from about a seated rider's eye height, the bike resting (%.2f m)" % eye)
	await _shot("hoverbike_2_mounted")
	_check(bike.get("_switches_lit"), "on the bike, the switch panel glows")
	var still: Vector3 = bike.global_position
	await _hold(["move_forward"], 1.0)
	_check(still.distance_to(bike.global_position) < 0.3, "W does nothing until it's started")

	# Start it: Space flips the left toggle, then the right.
	await _press("jump")
	var sw: Array = bike.get("switches")
	_check(sw[0] and not sw[1] and not bike.get("running"), "Space flips the left switch up")
	await _wait(10)
	await _press("jump")
	_check(bike.get("running"), "and again the right one: it starts")
	var start_sound: AudioStreamPlayer3D = bike.get("_start_sound")
	_check(start_sound != null and start_sound.playing, "with its start-up sound")
	await _wait(30)
	_check(_body_drop() > 0.4, "still on the ground while it revs (body %.2f m down)" % _body_drop())
	await _wait(120)
	_check(bike.call("can_drive") and _body_drop() < 0.02, "then it lifts to hover (body %.2f m down)" % _body_drop())
	_check(not bike.get("_switches_lit"), "and the switch panel stops glowing")
	await _wait(360)   # the running sound fades in as the start-up fades out
	var run_sound: AudioStreamPlayer3D = bike.get("_run_sound")
	_check(run_sound != null and run_sound.playing and (run_sound.stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED, "the running sound takes over, looping")
	var idle_db: float = run_sound.volume_db if run_sound else 0.0
	await _shot("hoverbike_3_started")

	# Ride forward (the bike starts facing east, away from the wreck).
	var start: Vector3 = bike.global_position
	var yaw_start: float = bike.rotation.y
	Input.action_press("move_forward")
	await _wait(60)
	var grip: Node3D = bike.get("_twist_grip")
	_check(grip != null and grip.rotation.x > 0.4, "the throttle grip twists (%.2f rad)" % (grip.rotation.x if grip else 0.0))
	var louder: float = run_sound.volume_db - idle_db if run_sound else 0.0
	_check(louder > 4.0 and louder < 14.0, "the engine gets louder speeding up (+%.1f dB)" % louder)
	await _wait(120)
	Input.action_release("move_forward")
	var went: float = start.distance_to(bike.global_position)
	_check(went > 15.0, "W drives it forward (%.1f m in 3 s)" % went)
	gap = bike.global_position.y - _ground(bike.global_position)
	_check(absf(gap) < 0.35, "it keeps hovering while it moves (%.2f m off)" % gap)
	var rider_off: float = player.global_position.distance_to(bike.global_position)
	_check(rider_off < 1.5, "Gana goes with it (%.2f m from the bike)" % rider_off)
	await _shot("hoverbike_5_riding")
	var yaw0: float = bike.rotation.y
	await _hold(["move_forward", "move_left"], 1.5)
	var turned: float = absf(angle_difference(yaw0, bike.rotation.y))
	_check(turned > 0.5, "A steers (%.2f rad)" % turned)
	await _shot("hoverbike_6_turning")
	await _side_shot("hoverbike_6b_turning_outside", Vector3(2.5, 1.3, 3.5))
	await _wait(300)
	_check(absf(float(bike.get("speed"))) < 1.0, "letting go, it coasts to a stop (%.1f m/s)" % float(bike.get("speed")))
	_check(bike.get("running") and _body_drop() < 0.02, "and stays running, hovering")
	_check(run_sound != null and absf(run_sound.volume_db - idle_db) < 1.0, "stopped, the engine is quiet again (%.1f dB, idle %.1f)" % [run_sound.volume_db if run_sound else 0.0, idle_db])

	# The headlight: off by day, on at night while it runs.
	var lamp: SpotLight3D = bike.get("_headlight")
	_check(lamp != null and not lamp.visible, "by day, the headlight is off")
	await _press("headlight")
	await _wait(60)
	_check(lamp != null and lamp.visible, "L switches it on, even by day")
	await _press("headlight")
	await _wait(60)
	_check(lamp != null and not lamp.visible, "and L again off")
	if clock:
		clock.skip_to(23.0)
		await _wait(60)
		_check(lamp != null and lamp.visible and lamp.light_energy > 10.0, "at night, running, the headlight comes on (%.1f)" % (lamp.light_energy if lamp else 0.0))
		await _press("headlight")
		await _wait(60)
		_check(lamp != null and not lamp.visible, "L switches it off at night")
		await _press("headlight")
		await _wait(60)
		_check(lamp != null and lamp.visible, "and on again")
		await _shot("hoverbike_4_headlight")
		clock.skip_to(14.0)
		await _wait(60)
		_check(lamp != null and not lamp.visible, "and off again by day")

	# B brakes hard, pulling the lever in (facing the open ground again).
	bike.rotation.y = yaw_start
	await _hold(["move_forward"], 2.0)
	var fast: float = float(bike.get("speed"))
	Input.action_press("brake")
	await _wait(30)
	var lever: Node3D = bike.get("_lever")
	_check(lever != null and lever.rotation.z > 0.1, "B pulls the brake lever in (%.2f rad)" % (lever.rotation.z if lever else 0.0))
	var slowed: float = fast - float(bike.get("speed"))
	_check(slowed > 7.0, "and brakes hard (%.1f m/s slower in 0.5 s, from %.1f)" % [slowed, fast])
	await _wait(60)
	Input.action_release("brake")
	await _wait(30)
	_check(lever != null and lever.rotation.z < 0.02, "letting go, the lever springs back")

	# It can't go through the wreck (aimed at solid hull, away from the breach).
	bike.global_position = Vector3(26.0, _ground(Vector3(26, 0, -7)), -7.0)
	bike.rotation = Vector3(0, PI / 2, 0)   # facing -X, at the wreck
	bike.set("speed", 0.0)
	await _wait(10)
	await _hold(["move_forward"], 4.0)
	# The hull there is at x 6.3-7; the bike's nose is 1.2 m ahead of its middle.
	_check(bike.global_position.x > 7.2, "it stops at the wreck's hull (x %.1f)" % bike.global_position.x)
	await _wait(60)

	# Get off.
	await _press("interact")
	await _wait(40)
	_check(player.get("_bike") == null and bike.get("rider") == null, "E gets Gana off")
	_check(player.is_on_floor(), "he lands standing on the ground")
	_check((player.get_node("Model") as Node3D).visible, "seen again in third person")
	_check(not bike.get("running"), "getting off stopped, the bike shuts off")
	var down_sound: AudioStreamPlayer3D = bike.get("_down_sound")
	# (Its sound plays in real time, which can run ahead of this slow test, so
	# check that it began and holds the bike up for its length.)
	var left: float = float(bike.get("_powering_down"))
	_check(down_sound != null and left > 2.0 and left < down_sound.stream.get_length(), "powering down for its sound's %.1f s (%.1f s left)" % [down_sound.stream.get_length() if down_sound else 0.0, left])
	await _wait(60)
	_check(_body_drop() < 0.02, "still hovering while it powers down (body %.2f m down)" % _body_drop())
	await _wait(int(down_sound.stream.get_length() * 60.0) - 40 if down_sound else 180)
	_check(_body_drop() > 0.4, "and drops to the ground as the sound ends (body %.2f m down)" % _body_drop())
	_check(player.global_position.distance_to(bike.global_position) < 3.5, "beside the bike (%.1f m)" % player.global_position.distance_to(bike.global_position))
	await _shot("hoverbike_7_dismounted")
	var before: Vector3 = player.global_position
	var away: Vector3 = player.global_position - bike.global_position
	player.pivot.rotation.y = atan2(-away.x, -away.z)
	await _hold(["move_forward"], 1.0)
	_check(before.distance_to(player.global_position) > 2.0, "and walks off again")

	# Getting off at speed: it drifts on a little, then shuts off and settles.
	var side1: Vector3 = bike.global_transform * Vector3(-2.0, 0, 0)
	player.global_position = Vector3(side1.x, _ground(side1) + 1.05, side1.z)
	player.mount(bike)
	await _wait(5)
	bike.call("flip_switch")
	bike.call("flip_switch")
	await _wait(150)
	bike.rotation.y = -PI / 2   # facing +X, away from the wreck
	await _hold(["move_forward"], 1.5)
	var was: Vector3 = bike.global_position
	var at_speed: float = float(bike.get("speed"))
	await _press("interact")
	await _wait(20)
	_check(player.get("_bike") == null and bike.get("running"), "getting off at speed (%.1f m/s), it keeps going a moment" % at_speed)
	await _wait(440)   # drifting, then powering down, then dropping
	var drift: float = was.distance_to(bike.global_position)
	_check(drift > 2.0 and drift < 20.0, "drifting on %.1f m" % drift)
	_check(not bike.get("running") and absf(float(bike.get("speed"))) < 0.3, "then it shuts off and stops")
	_check(_body_drop() > 0.4, "down on the ground (body %.2f m down)" % _body_drop())

	# Saving while riding (started), then loading.
	var side2: Vector3 = bike.global_transform * Vector3(-2.0, 0, 0)
	player.global_position = Vector3(side2.x, _ground(side2) + 1.05, side2.z)
	player.mount(bike)
	await _wait(5)
	bike.call("flip_switch")
	bike.call("flip_switch")
	await _wait(150)
	var saved_at: Vector3 = bike.global_position
	_check(Game.state().save_game(), "it saves while riding")
	Game.state().load_game()
	await _wait(90)
	player = current_scene.get_node("Player")
	bike = current_scene.get_tree().get_first_node_in_group("hoverbike")
	_check(bike != null and bike.global_position.distance_to(saved_at) < 1.0, "loading puts the bike back where it was")
	_check(bike != null and player.get("_bike") == bike, "and Gana back on it")
	_check(bike != null and bike.call("can_drive"), "still running, hovering")
	_finish()


## How far the bike's body is lowered from its hover height (0 hovering,
## its hover height resting on the ground).
func _body_drop() -> float:
	var body: Node3D = bike.get("_body")
	return -body.position.y if body else 0.0


func _finish() -> void:
	Input.action_release("brake")
	Input.action_release("move_forward")
	Input.action_release("move_left")
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
