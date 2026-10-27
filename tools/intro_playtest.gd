extends SceneTree
const OUT := "user://playtest_shots/"
var fails := 0
func _check(c: bool, w: String) -> void:
	print(("PASS " if c else "FAIL ") + w)
	if not c: fails += 1
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://menu.tscn")
	_run.call_deferred()
func _run() -> void:
	for i in 20: await process_frame
	current_scene._on_new_game()
	await create_timer(2.5).timeout
	_check(current_scene.scene_file_path == "res://intro.tscn", "New Game opens the intro")
	var intro: Node = current_scene
	_check(intro._hum.playing, "space hum playing at the start")
	intro._t = 10.0
	await create_timer(1.5).timeout
	_check(intro._music.playing, "intro music started at the flyby")
	_check(intro._thrust_started, "thruster sound triggered")
	intro._t = 30.8
	await create_timer(4.0).timeout
	_check(current_scene.scene_file_path == "res://main.tscn", "intro ends in the ship")
	var player: Node3D = current_scene.get_node("Player")
	_check(player.global_position.distance_to(Vector3(4.0, 1.1, -9.3)) < 0.6, "player starts in the cockpit (%s)" % player.global_position)
	var hum: AudioStreamPlayer = current_scene.get_node("ShipHum")
	_check(hum.playing, "ship hum playing in the cockpit")
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(OUT + "i8_cockpit.png")
	print("FAILS: ", fails)
	quit()
