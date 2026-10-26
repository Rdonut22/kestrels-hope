extends SceneTree

const OUT := "user://playtest_shots/"
var fails := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://crash_site.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(c: bool, what: String) -> void:
	print(("PASS " if c else "FAIL ") + what)
	if not c:
		fails += 1


func _run() -> void:
	await _frames(30)
	var clock: Node = current_scene.get_node("DayNight")
	var hud: Node = current_scene.get_node("HUD")
	var player: CharacterBody3D = current_scene.get_node("Player")
	player.set_physics_process(false)
	var t0: float = clock.hour
	await _frames(60)
	_check(clock.hour > t0, "time advances (%.4f -> %.4f)" % [t0, clock.hour])
	var cam := Camera3D.new()
	cam.fov = 70
	current_scene.add_child(cam)
	for h in [9.0, 13.0, 18.3, 19.2, 22.5, 5.6]:
		clock.skip_to(h)
		await _frames(10)
		cam.global_position = Vector3(26, 1.7, 8)
		cam.look_at(Vector3(4, 4, 0))
		cam.make_current()
		await _frames(4)
		root.get_texture().get_image().save_png(OUT + "d_%04.1f_meadow.png" % h)
		cam.global_position = Vector3(3.0, 1.6, 2.4)
		cam.look_at(Vector3(14, 3, 2.4))
		await _frames(4)
		root.get_texture().get_image().save_png(OUT + "d_%04.1f_breach.png" % h)
	clock.skip_to(22.5)
	await _frames(5)
	var flies: CPUParticles3D = current_scene.get_node("CrashSite/Fireflies0")
	var fly: Node3D = current_scene.get_node("CrashSite/Butterfly0")
	_check(flies.visible and flies.emitting, "fireflies out at night")
	_check(not fly.visible, "butterflies gone at night")
	_check(clock.is_night(), "is_night at 22:30")
	var bed: Node = current_scene.get_node("Ship/ShipInterior/Interactables/Bed")
	bed.interact(player)
	await create_timer(1.6).timeout
	_check(absf(clock.hour - 7.0) < 0.2, "sleeping skips to morning (hour %.2f)" % clock.hour)
	await create_timer(5.0).timeout
	_check(fly.visible and not flies.visible, "butterflies back, fireflies gone in the morning")
	var comp: Node = current_scene.get_node("Ship/ShipInterior/Interactables/ShipComputer")
	comp.interact(player)
	await _frames(3)
	_check(hud.entry_body.text.begins_with("Local time"), "computer shows local time")
	print("FAILS: ", fails)
	quit()
