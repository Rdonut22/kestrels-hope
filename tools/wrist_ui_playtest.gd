extends SceneTree

## Wrist terminal UI (ui/wrist_ui): Tab opens it on the G-07 model, home
## screen navigation by keys and mouse, sections, Back/Home, reopening the
## last section, unread markers, and the player frozen while it's open.
## Saves screenshots.
##   godot --path . -s tools/wrist_ui_playtest.gd [-- <out_dir>]

var fails := 0
var out := "user://wrist_ui_shots"
var hud: Node
var view: WristTerminalView


func _check(c: bool, w: String) -> void:
	print(("PASS " if c else "FAIL ") + w)
	if not c:
		fails += 1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://main.tscn")
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _key(k: Key) -> void:
	var opening := k == KEY_TAB and view != null and not view.visible
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _wait(2)
	if opening:
		# Gana raises his arm first; the screen opens after.
		await create_timer(WristTerminalView.RAISE_SECS + 0.3).timeout
		await _wait(2)


## Click at a point in the view's coordinates (converted to window pixels:
## the game's canvas is scaled to the window).
func _click(local: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var at := view.get_global_transform_with_canvas() * local
	at = root.get_final_transform() * at
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	Input.parse_input_event(m)
	await _wait(2)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.position = at
		ev.global_position = at
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _wait(2)


func _shot(name: String) -> void:
	await _wait(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")


func _run() -> void:
	await _wait(30)
	hud = current_scene.get_node("HUD")
	view = hud.get_node_or_null("WristTerminalView") as WristTerminalView
	_check(view != null, "wrist terminal is part of the HUD")
	if view == null:
		print("FAILS: ", fails)
		quit()
		return
	_check(not view.visible, "closed at the start")
	var player: Node = current_scene.get_node("Player")

	await _key(KEY_TAB)
	_check(view.visible, "Tab opens the terminal (after Gana raises his arm)")
	var model = current_scene.get_node("Player").mesh
	_check(model._raise != null and model._raise.amount > 0.5, "Gana's arm is raised")
	_check(hud.is_busy(), "the player is frozen while it's open")
	_check(view.ui.section == -1 and view.ui.selected == 0, "opens on the home screen with MAP selected")
	_check(view.terminal.get_display().material_override != null, "the UI is on the G-07 model's display")
	await _shot("01_home")

	var knob := view.terminal.knob_angle
	await _key(KEY_RIGHT)
	_check(view.ui.selected == 1, "Right selects DISCOVERIES")
	_check(view.terminal.knob_angle != knob, "the knob turns with the selection")
	await _key(KEY_DOWN)
	_check(view.ui.selected == 3, "Down selects INVENTORY")
	await _key(KEY_LEFT)
	_check(view.ui.selected == 2, "Left selects COMMS")
	await _key(KEY_S)
	_check(view.ui.selected == 4, "S (WASD) selects ARM SYSTEMS")
	await _key(KEY_DOWN)
	_check(view.ui.selected == 4, "selection stops at the edge")
	var pos: Vector3 = player.global_position
	await _key(KEY_W)
	_check(view.ui.selected == 2, "W (WASD) moves the selection up to COMMS")
	_check(player.global_position.distance_to(pos) < 0.01, "movement keys don't move Gana while it's open")
	await _key(KEY_S)
	await _shot("02_arm_selected")

	await _key(KEY_ENTER)
	_check(view.ui.section == 4, "Enter opens ARM SYSTEMS")
	await _shot("03_section")
	await _key(KEY_ESCAPE)
	_check(view.ui.section == -1 and view.visible, "Esc goes back to the home screen")
	_check(not get_root().get_tree().paused, "Esc doesn't open the pause menu")
	await _key(KEY_E)
	_check(view.ui.section == 4, "E opens the selected section")
	await _key(KEY_H)
	_check(view.ui.section == -1, "H goes home")
	await _key(KEY_ESCAPE)
	_check(not view.visible and not hud.is_busy(), "Esc on the home screen closes it")

	# Reopens the last-used section.
	await _key(KEY_TAB)
	await _key(KEY_ENTER)  # ARM SYSTEMS (still selected)
	await _key(KEY_TAB)
	_check(not view.visible, "Tab closes it from a section")
	await _key(KEY_TAB)
	_check(view.visible and view.ui.section == 4, "reopens on the last-used section")
	await _key(KEY_H)

	# Mouse on the 3D screen.
	var tile := view.ui._tile_rect(1).get_center()
	var at := view.control_point(tile)
	var back: Variant = view.screen_point(at)
	_check(back != null and (back as Vector2).distance_to(tile) < 4.0, "mouse maps onto the screen (%s -> %s)" % [tile, back])
	await _click(at)
	_check(view.ui.section == 1, "clicking a tile opens it (DISCOVERIES)")
	await _click(view.control_point(view.ui._back_rect().get_center()))
	_check(view.ui.section == -1, "clicking BACK returns home")
	await _click(view.control_point(view.ui._tile_rect(5).get_center()), MOUSE_BUTTON_RIGHT)
	_check(not view.visible, "right-click on the home screen closes it")

	# Unread markers.
	await _key(KEY_TAB)
	view.set_unread("comms")
	_check(view.ui.is_unread("comms"), "a section can be marked unread")
	await _shot("04_unread")
	view.ui.open_section(2)
	_check(not view.ui.is_unread("comms"), "opening it clears the marker")
	view.ui.home()
	await _key(KEY_TAB)
	print("FAILS: ", fails)
	quit()
