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
	_check(intro._thrust_started, "engine sound triggered at the flyby")
	_check(intro._engine.playing, "uneven engine hum playing")
	_check(not intro._music.playing, "no music in the flyby (the piano starts in the quarters)")
	intro._t = 14.0
	await create_timer(5.0).timeout
	_check(intro._bars[0].anchor_bottom > 0.05, "letterbox bars slide in as the ship moves away")
	root.get_texture().get_image().save_png(OUT + "i5_flyby.png")
	intro._leave(0.5)
	await create_timer(2.0).timeout
	_check(current_scene.scene_file_path == "res://main.tscn", "intro ends in the ship")
	# The quarters half of the opening (tools/opening_playtest.gd plays it
	# through); it ends in the pilot seat.
	_check(current_scene.get_node_or_null("OpeningCinematic") != null, "the opening cinematic continues in the quarters")
	var hum: AudioStreamPlayer = current_scene.get_node("ShipHum")
	_check(hum.playing, "ship hum playing aboard")
	print("FAILS: ", fails)
	quit()
