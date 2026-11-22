extends SceneTree
## The opening's first shot (intro.gd): New Game opens the exterior drift,
## which hands over to the ship (main.tscn) and the opening cinematic.
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
	await create_timer(1.0).timeout
	_check(current_scene.scene_file_path == "res://intro.tscn", "New Game opens the intro")
	var intro: Node = current_scene
	var ship: Node3D = intro.get("_ship")
	var r0 := ship.rotation
	await create_timer(1.5).timeout
	_check(ship.rotation.distance_to(r0) > 0.001, "the Kestrel drifts and turns")
	_check(root.get_node_or_null("OpeningMusic") != null, "the opening music player is on the root (carries into the ship)")
	root.get_texture().get_image().save_png(OUT + "i1_drift.png")
	await create_timer(4.5).timeout
	_check(current_scene.scene_file_path == "res://main.tscn", "after five seconds the intro ends in the ship")
	for i in 5: await process_frame
	_check(current_scene.get_node_or_null("OpeningCinematic") != null, "the opening cinematic continues in the ship")
	var hum: AudioStreamPlayer = current_scene.get_node("ShipHum")
	_check(hum.playing, "ship hum playing aboard")
	print("FAILS: ", fails)
	quit()
