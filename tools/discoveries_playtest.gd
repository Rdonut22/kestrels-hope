extends SceneTree

## Discoveries (ui/discoveries, discoveries/, GameState objectives):
## the opening's "Make something to eat" task from start to finish, the
## HUD notification and badge, the hunger highlight, compass markers, the
## Discoveries panel by keys and mouse, required vs optional tracking, the
## HUD focus, section locks, and save/load. Saves screenshots.
##
## Two optional objectives are registered for the test only (they aren't
## game content).
##   godot --path . -s tools/discoveries_playtest.gd [-- <out_dir>]

const EAT := "make_something_to_eat"
const TEST_TASK := "test_optional_task"
const TEST_MISSION := "test_optional_mission"

var fails := 0
var out := "user://discoveries_shots"
var hud: Node
var view: WristTerminalView
var panel: DiscoveriesPanel
var ohud: Control
var compass: Node
var gs: Node


func _check(c: bool, w: String) -> void:
	print(("PASS " if c else "FAIL ") + w)
	if not c:
		fails += 1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_register_test_objectives()
	change_scene_to_file("res://main.tscn")
	_run.call_deferred()


func _register_test_objectives() -> void:
	var t := ObjectiveDef.new()
	t.id = TEST_TASK
	t.category = "task"
	t.title = "Check the water filter"
	t.summary = "An optional test task with a waypoint."
	t.description = "Test-only optional task. It has a destination (the quarters' window), so it shows on the compass while tracked."
	t.waypoint_node = NodePath("ShipInterior/QuartersWindow")
	Objectives.register(t)
	var m := ObjectiveDef.new()
	m.id = TEST_MISSION
	m.category = "mission"
	m.title = "Trace the signal"
	m.summary = "An optional test mission without a known destination."
	m.description = "Test-only optional mission. Its destination isn't known, so it never gets a compass marker."
	Objectives.register(m)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _key(k: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _wait(2)


## Click at a point in window pixels.
func _click_at(at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	Input.parse_input_event(m)
	await _wait(2)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = at
		ev.global_position = at
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _wait(2)


## Click a panel hit target (in its 1080p layout units).
func _click_panel(action: String, arg: Variant = null) -> void:
	var r := panel.hit_rect(action, arg)
	_check(r.size != Vector2.ZERO, "found %s %s on the panel" % [action, arg])
	var local := panel.from_ref(r.get_center())
	await _click_at(root.get_final_transform() * (panel.get_global_transform_with_canvas() * local))


func _shot(name: String) -> void:
	await _wait(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")


## Face the camera towards a point (ship frame) from where Gana stands.
func _face(player: Node3D, target: Vector3) -> void:
	var d := target - player.global_position
	(player.get("pivot") as Node3D).rotation.y = atan2(-d.x, -d.z)
	await _wait(4)


func _run() -> void:
	await _wait(30)
	gs = Game.state()
	gs.reset()
	hud = current_scene.get_node("HUD")
	view = hud.get_node("WristTerminalView") as WristTerminalView
	panel = view.get("_panel")
	ohud = hud.get_node("ObjectiveHUD")
	compass = hud.get_node("NavCompass")
	var player: Node3D = current_scene.get_node("Player")
	var ship: Node3D = current_scene.get_node("ShipInterior")
	# The opening has started (as after the intro), but the terminal is
	# available from the beginning.
	gs.set_flag("opening_started")
	_check(gs.opening_locked(), "the opening gate is on")
	await _key(KEY_TAB)
	await create_timer(WristTerminalView.RAISE_SECS + 0.4).timeout
	_check(view.visible, "the wrist terminal opens during the opening")
	for i in view.ui.SECTIONS.size():
		_check_once_unlocked(i)
	await _key(KEY_TAB)
	_check(not view.visible, "Tab closes it")
	await _wait(10)

	# ---- The hunger beat: the eat task arrives.
	player.global_position = ship.to_global(Vector3(-0.15, 1.0, -4.4))
	await _face(player, ship.to_global(Vector3(5.86, 1.0, -5.1)))
	gs.add_objective(EAT)
	_check(not gs.add_objective(EAT), "the same objective can't be added twice")
	_check(gs.objective_ids("task") == [EAT], "the task is in Discoveries' Tasks")
	_check(gs.objective_tracked(EAT), "required: tracked automatically")
	await _wait(20)
	_check(ohud.is_notifying(), "a new-objective notification shows")
	await _shot("1_new_task_notification")
	var vitals: Node = hud.get_node("VitalsPanel")
	_check(vitals.highlights.has("hunger"), "the hunger vital is highlighted")
	var t := 0.0
	while ohud.is_notifying() and t < 8.0:
		await create_timer(0.1).timeout
		t += 0.1
	await _wait(5)
	_check(ohud.badge_id() == EAT, "then the persistent badge shows the task")
	_check(EAT in compass.objective_markers_shown, "the stove is marked on the compass (amber)")
	await _shot("2_badge_and_compass")
	_check(not gs.set_objective_tracked(EAT, false), "a required objective can't be untracked")
	_check(gs.objective_tracked(EAT), "...and stays tracked")

	# ---- Optional objectives: tracked on discovery, can be untracked.
	gs.add_objective(TEST_TASK)
	gs.add_objective(TEST_MISSION)
	await _wait(5)
	_check(gs.objective_tracked(TEST_TASK) and gs.objective_tracked(TEST_MISSION), "optional objectives start tracked")
	_check(gs.focused_objective() == EAT, "the required task keeps the HUD's emphasis")
	_check(gs.set_objective_focus(TEST_TASK) and gs.focused_objective() == EAT, "choosing another focus waits while the required task takes precedence")

	# ---- J opens Discoveries on the emphasised objective.
	t = 0.0
	while ohud.is_notifying() and t < 20.0:
		await create_timer(0.1).timeout
		t += 0.1
	await _key(KEY_J)
	await create_timer(WristTerminalView.RAISE_SECS + 0.5).timeout
	_check(view.discoveries_open(), "J opens Discoveries")
	_check(panel.category == "task" and panel.selected == EAT, "...on the focused objective")
	_check(not hud.hides_chrome(), "the HUD (vitals, compass, badge) stays up over Discoveries")
	await _shot("3_discoveries_tasks")
	# E on the required task: nothing changes.
	await _key(KEY_E)
	_check(gs.objective_tracked(EAT), "E on a required task doesn't untrack it")
	# W/S select; E toggles an optional one.
	await _key(KEY_S)
	_check(panel.selected == TEST_TASK, "S selects the next row")
	await _key(KEY_E)
	_check(not gs.objective_tracked(TEST_TASK), "E untracks an optional task")
	await _wait(5)
	_check(not TEST_TASK in compass.objective_markers_shown, "an untracked objective has no compass marker")
	await _shot("4_untracked_optional")
	await _key(KEY_E)
	_check(gs.objective_tracked(TEST_TASK), "E tracks it again")
	# Mouse: the row's badge toggles too.
	await _click_panel("track", TEST_TASK)
	_check(not gs.objective_tracked(TEST_TASK), "clicking TRACKED untracks it")
	await _click_panel("track", TEST_TASK)
	_check(gs.objective_tracked(TEST_TASK), "clicking TRACK tracks it")
	_check(panel.hit_rect("track", EAT) == Rect2(), "a required row has no track control")
	# Missions.
	await _key(KEY_A)
	_check(panel.category == "mission" and panel.selected == TEST_MISSION, "A switches to Missions")
	await _shot("5_discoveries_missions")
	await _key(KEY_E)
	_check(not gs.objective_tracked(TEST_MISSION), "an optional mission can be untracked")
	await _key(KEY_E)
	await _click_panel("category", "task")
	_check(panel.category == "task", "clicking TASKS switches back")
	await _key(KEY_ESCAPE)
	_check(view.visible and not view.discoveries_open() and view.ui.section == -1, "Esc goes back to the terminal's home screen")
	view.open_discoveries()
	await _wait(5)
	await _key(KEY_BACKSPACE)
	_check(view.visible and not view.discoveries_open() and view.ui.section == -1, "Backspace goes back too")
	view.open_discoveries()
	await _wait(5)
	await _click_panel("back")
	_check(view.visible and not view.discoveries_open() and view.ui.section == -1, "clicking ESC Back goes back too")
	view.open_discoveries()
	await _wait(5)
	await _key(KEY_TAB)
	_check(not view.visible, "Tab closes the terminal")
	await _wait(10)
	await _wait(10)

	# ---- Clicking the badge (when the cursor is free).
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var br: Rect2 = ohud.badge_rect()
	await _click_at(root.get_final_transform() * br.get_center())
	await create_timer(WristTerminalView.RAISE_SECS + 0.5).timeout
	_check(view.discoveries_open() and panel.selected == EAT, "clicking the badge opens Discoveries on its objective")
	await _key(KEY_TAB)
	await _wait(10)

	# ---- Save and load keep it all.
	gs.set_objective_tracked(TEST_MISSION, false)
	_check(gs.save_game(), "saved")
	var saved: Dictionary = gs.objectives.duplicate(true)
	var focus: String = gs.objective_focus
	_check(gs.load_game(), "loaded")
	await _wait(40)
	gs = Game.state()
	_check(gs.objectives.has(EAT) and gs.objective_tracked(EAT) and not gs.objective_done(EAT), "the eat task survives save/load")
	_check(gs.objective_tracked(TEST_TASK) and not gs.objective_tracked(TEST_MISSION), "tracked/untracked survive save/load")
	_check(gs.objective_focus == focus and gs.objectives.size() == saved.size(), "the chosen focus survives save/load")
	hud = current_scene.get_node("HUD")
	ohud = hud.get_node("ObjectiveHUD")
	view = hud.get_node("WristTerminalView") as WristTerminalView
	await _wait(20)
	_check(ohud.badge_id() == EAT, "the badge is back after loading (no repeat notification)")
	_check(not ohud.is_notifying(), "...and no notifications replay")
	_check(gs.opening_locked(), "the gate is still on")

	# ---- The meal: the cooking hook completes the task.
	gs.complete_objective(gs.EAT_TASK)
	_check(gs.objective_done(EAT) and not gs.objective_tracked(EAT), "the task is complete")
	_check(not gs.opening_locked(), "the gate opens (cockpit door, Meki's repairs)")
	await _wait(20)
	_check(ohud.is_notifying(), "a TASK COMPLETE notification shows")
	await _shot("6_task_complete")
	t = 0.0
	while ohud.is_notifying() and t < 8.0:
		await create_timer(0.1).timeout
		t += 0.1
	await _wait(5)
	_check(ohud.badge_id() == TEST_TASK, "the badge moves to the player's chosen focus")
	_check(not hud.get_node("VitalsPanel").highlights.has("hunger"), "the hunger highlight goes")
	gs.complete_objective(TEST_TASK)
	gs.complete_objective(TEST_MISSION)
	t = 0.0
	while (ohud.is_notifying() or not gs.tracked_objectives().is_empty()) and t < 20.0:
		await create_timer(0.1).timeout
		t += 0.1
	await _wait(5)
	_check(ohud.badge_id() == "", "with nothing tracked, no badge")
	view.open_discoveries(EAT)
	await create_timer(WristTerminalView.RAISE_SECS + 0.5).timeout
	await _shot("7_completed_in_discoveries")
	_check(panel_of(view).selected == EAT, "completed objectives stay in Discoveries")
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)


func panel_of(v: WristTerminalView) -> DiscoveriesPanel:
	return v.get("_panel")


func _check_once_unlocked(i: int) -> void:
	if view.ui.is_locked(i):
		_check(false, "section %s is unlocked (none are gated yet)" % view.ui.SECTIONS[i][0])
