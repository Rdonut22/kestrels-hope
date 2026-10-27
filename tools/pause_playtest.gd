extends SceneTree
const OUT := "user://playtest_shots/"
var fails := 0
func _check(c: bool, w: String) -> void:
	print(("PASS " if c else "FAIL ") + w)
	if not c: fails += 1
func _esc() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 3: await process_frame
	ev = InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = false
	Input.parse_input_event(ev)
	for i in 3: await process_frame
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://menu.tscn")
	_run.call_deferred()
func _run() -> void:
	for i in 20: await process_frame
	await _esc()
	_check(not paused, "Esc ignored on title screen")
	change_scene_to_file("res://crash_site.tscn")
	for i in 30: await process_frame
	await _esc()
	_check(paused, "Esc pauses the game")
	root.get_texture().get_image().save_png(OUT + "pause.png")
	await _esc()
	_check(not paused, "Esc again resumes")
	var hud: Node = current_scene.get_node("HUD")
	var comp: Node = current_scene.get_node("Ship/ShipInterior/Interactables/ShipComputer")
	comp.interact(current_scene.get_node("Player"))
	for i in 3: await process_frame
	await _esc()
	_check(not hud.screen.visible and not paused, "Esc closes a terminal without pausing")
	await _esc()
	var pm: Node = root.get_node("PauseMenu")
	pm._quit_to_menu()
	for i in 10: await process_frame
	_check(not paused and current_scene.scene_file_path == "res://menu.tscn", "Quit to Menu returns to the title")
	print("FAILS: ", fails)
	quit()
