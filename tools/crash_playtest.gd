extends SceneTree

const OUT := "user://playtest_shots/"
var player: CharacterBody3D
var hud: Node
var ship: Node3D
var fails := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://crash_site.tscn")
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await physics_frame


func _check(c: bool, what: String) -> void:
	print(("PASS " if c else "FAIL ") + what)
	if not c:
		fails += 1


func _place(local: Vector3, yaw: float, pitch := -0.15) -> void:
	player.global_position = ship.to_global(local)
	player.velocity = Vector3.ZERO
	player.pivot.rotation = Vector3(pitch, yaw, 0)
	await _wait(12)


func _walk(yaw: float, secs: float) -> void:
	player.pivot.rotation.y = yaw
	Input.action_press("move_forward")
	await _wait(int(secs * 60))
	Input.action_release("move_forward")
	await _wait(10)


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(OUT + name + ".png")


func _cam_shot(eye: Vector3, target: Vector3, name: String) -> void:
	var cam := Camera3D.new()
	cam.fov = 65
	current_scene.add_child(cam)
	cam.global_position = eye
	cam.look_at(target)
	cam.make_current()
	await _wait(4)
	await _shot(name)
	cam.queue_free()
	player.get_node("CameraPivot/SpringArm3D/Camera3D").make_current()


func _run() -> void:
	await _wait(40)
	player = current_scene.get_node("Player")
	hud = current_scene.get_node("HUD")
	ship = current_scene.get_node("Ship")
	_check(player.is_on_floor(), "wakes up on the quarters floor at %s" % player.global_position)
	await _shot("x1_wake")

	await _place(Vector3(-0.15, 1.1, -6.5), PI)
	await _walk(PI, 1.0)
	var lp := ship.to_local(player.global_position)
	_check(lp.z > -5.0, "quarters -> deck (local z %.1f)" % lp.z)
	await _place(Vector3(0.0, 1.1, 1.0), -PI / 2)
	await _walk(-PI / 2, 1.0)
	lp = ship.to_local(player.global_position)
	_check(lp.x > 3.0, "deck -> lounge (local x %.1f)" % lp.x)
	await _place(Vector3(4.2, 1.1, 2.4), -PI / 2)
	await _walk(-PI / 2, 2.0)
	lp = ship.to_local(player.global_position)
	_check(lp.x > 9.0 and player.is_on_floor(), "out through the breach onto the ground (local x %.1f, y %.2f)" % [lp.x, player.global_position.y])
	await _walk(-PI / 2, 2.0)
	_check(player.global_position.x > 13.0, "keep walking into the forest (x %.1f)" % player.global_position.x)
	await _place(Vector3(13.0, 1.0, 2.4), PI / 2)
	await _walk(PI / 2, 2.6)
	lp = ship.to_local(player.global_position)
	_check(lp.x < 6.0, "walk back in through the breach (local x %.1f)" % lp.x)

	await _place(Vector3(4.3, 1.1, -8.4), -PI / 2)
	_check(hud.prompt_label.text == "[E] Use ship computer", "computer prompt: '%s'" % hud.prompt_label.text)
	await _place(Vector3(0.9, 1.1, 0.6), 0.0)
	_check(hud.prompt_label.text.begins_with("[E]"), "fallen panel prompt: '%s'" % hud.prompt_label.text)

	await _place(Vector3(2.0, 1.1, 2.4), -PI / 2, -0.1)
	await _shot("x2_lounge_breach")
	await _place(Vector3(0.0, 1.1, 7.5), 0.0, -0.1)
	await _shot("x3_deck")
	await _place(Vector3(4.0, 1.1, -8.6), 0.0, 0.0)
	await _shot("x4_cockpit")
	await _cam_shot(ship.to_global(Vector3(20, 4, 9)), ship.to_global(Vector3(2, 0.5, 0)), "x5_outside")
	await _cam_shot(ship.to_global(Vector3(14, 1.7, 2.5)), ship.to_global(Vector3(5, 1.2, 2.4)), "x6_breach_outside")
	await _cam_shot(Vector3(-12, 38, 48), Vector3(4, 0, 0), "x7_overview")
	await _cam_shot(ship.to_global(Vector3(0.6, 1.6, 3.0)), ship.to_global(Vector3(0.9, 1.4, -0.6)), "x8_sparks")
	await _cam_shot(Vector3(12, 1.7, 9), Vector3(22, 2.5, 1), "x9_meadow")
	await _cam_shot(Vector3(16, 1.6, -6), Vector3(0, 2.5, 10), "x10_toward_ship")
	await _cam_shot(Vector3(10, 1.7, 6), Vector3(40, 14, -6), "x11_treeline")
	await _cam_shot(Vector3(20, 1.7, -14), Vector3(-10, 12, 20), "x12_back_view")
	print("FAILS: ", fails)
	quit()
