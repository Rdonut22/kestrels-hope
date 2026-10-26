extends SceneTree

const OUT := "user://playtest_shots/"
var player: CharacterBody3D
var hud: Node
var fails := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://main.tscn")
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(OUT + name + ".png")


func _check(cond: bool, what: String) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _place(pos: Vector3, yaw: float, pitch := -0.15) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.pivot.rotation = Vector3(pitch, yaw, 0)
	player.mesh.rotation.y = yaw
	await _wait(10)


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 3:
		await process_frame
	ev = InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)
	for i in 3:
		await process_frame
	await _wait(2)


func _walk(yaw: float, seconds: float) -> void:
	player.pivot.rotation.y = yaw
	Input.action_press("move_forward")
	await _wait(int(seconds * 60))
	Input.action_release("move_forward")
	await _wait(10)


func _walk_check(start: Vector3, yaw: float, secs: float, cond: Callable, what: String) -> void:
	await _place(start, yaw)
	await _walk(yaw, secs)
	var p := player.global_position
	_check(cond.call(p), "%s (ended at %.1f, %.1f)" % [what, p.x, p.z])


func _run() -> void:
	await _wait(30)
	player = current_scene.get_node("Player")
	hud = current_scene.get_node("HUD")
	_check(player.is_on_floor(), "spawns on floor in quarters at %s" % player.global_position)
	await _shot("01_spawn_quarters")

	# Every doorway is walkable.
	await _walk_check(Vector3(-0.15, 1.1, -6.5), PI, 1.0, func(p): return p.z > -5.0, "quarters hatch -> deck")
	await _walk_check(Vector3(-0.15, 1.1, 8.0), 0.0, 2.6, func(p): return p.z < -3.0, "ramp end -> front of deck")
	await _walk_check(Vector3(0.0, 1.1, 1.0), -PI / 2, 1.0, func(p): return p.x > 3.0, "deck -> lounge arch")
	await _walk_check(Vector3(0.5, 1.1, -4.9), -PI / 2, 0.8, func(p): return p.x > 3.0, "deck -> kitchen")
	await _walk_check(Vector3(4.0, 1.1, -5.5), 0.0, 1.2, func(p): return p.z < -8.0, "kitchen -> cockpit")
	await _walk_check(Vector3(-1.0, 1.1, -3.0), PI / 2, 0.8, func(p): return p.x < -3.0, "deck -> bathroom")
	await _walk_check(Vector3(-1.0, 1.1, 1.1), PI / 2, 0.8, func(p): return p.x < -3.0, "deck -> engineering")
	await _walk_check(Vector3(-4.0, 1.1, 2.2), PI, 0.9, func(p): return p.z > 4.2, "engineering -> gunner")

	# Coffee.
	await _place(Vector3(4.4, 1.1, -6.1), -PI / 2)
	_check(hud.prompt_label.text == "[E] Make coffee", "coffee prompt: '%s'" % hud.prompt_label.text)
	await _press("interact")
	await _shot("05_kitchen_brewing")
	await _wait(270)
	await _press("interact")
	_check(player.has_coffee, "got coffee")

	# Computer, log, bed, ramp.
	await _place(Vector3(4.3, 1.1, -8.4), -PI / 2)
	_check(hud.prompt_label.text == "[E] Use ship computer", "computer prompt: '%s'" % hud.prompt_label.text)
	await _press("interact")
	_check(hud.screen.visible, "computer opens")
	await _press("ui_cancel")
	await _place(Vector3(0.6, 1.1, -7.4), -PI / 2)
	_check(hud.prompt_label.text == "[E] Read personal log", "log prompt: '%s'" % hud.prompt_label.text)
	await _place(Vector3(-1.0, 1.1, -7.5), PI / 2)
	_check(hud.prompt_label.text == "[E] Sleep", "bed prompt: '%s'" % hud.prompt_label.text)
	await _place(Vector3(0.0, 1.1, 7.8), PI)
	_check(hud.prompt_label.text == "[E] Boarding ramp", "ramp prompt: '%s'" % hud.prompt_label.text)

	# Views.
	await _place(Vector3(-0.15, 1.1, 8.4), 0.0, -0.05)
	await _shot("02_from_ramp")
	await _place(Vector3(3.0, 1.1, 1.0), -PI / 2, -0.15)
	await _shot("03_lounge")
	await _place(Vector3(4.0, 1.1, -8.6), 0.0, -0.1)
	await _shot("04_cockpit")
	await _place(Vector3(-2.9, 1.1, 1.6), PI / 2, -0.2)
	await _shot("06_engineering")
	await _place(Vector3(-4.0, 1.1, 4.4), PI, -0.2)
	await _shot("07_gunner")
	await _place(Vector3(-2.9, 1.1, -2.8), PI / 2, -0.2)
	await _shot("08_bathroom")
	await _place(Vector3(0.5, 1.1, -0.5), -PI / 2 - 0.5, -0.15)
	await _shot("09_deck_arches")

	print("FAILS: ", fails)
	quit()
