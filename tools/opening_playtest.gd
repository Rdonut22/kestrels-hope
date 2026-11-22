extends SceneTree

## Plays the opening in the ship (ship/opening_cinematic.gd) from a fresh
## start, pressing to advance like a player would: the montage, Scene 1 in
## the quarters, free control and "Look outside" at the window, the window
## scene, then leaving the quarters until the "Make something to eat"
## objective comes up. Checks every line and speaker in order, the
## dialogue box's press rules, the locks (cockpit door, wrist terminal,
## Meki's repairs, saving), and that the window move has no cuts.
##   godot --path . --script tools/opening_playtest.gd [-- <screenshot dir>]

const SCENE1 := [
	["ganna", "Forty-three days..."],
	["ganna", "Can't believe it's been that long since you disappeared."],
	["ganna", "Better do my rounds."],
	["ship_computer", "Good morning, Gana. Would you like a status report?"],
	["ganna", "Yeah. Go ahead."],
	["ship_computer", "Main turbine remains critically damaged. Fuel reserves are at six percent."],
	["ship_computer", "The Kestrel has been drifting off course for forty-three days since the attack."],
	["ship_computer", "I was forced to establish orbit around a nearby moon to conserve our remaining fuel."],
	["ship_computer", "I'm also detecting an unidentified signal."],
	["ganna", "Wait... a moon? What moon?"],
	["ship_computer", "You were in deep sleep during our approach."],
	["ship_computer", "See for yourself."],
]
const WINDOW := [
	["ganna", "What...? Where the hell are we?"],
	["ship_computer", "This moon is not present in our navigation database."],
	["ship_computer", "We are approximately two thousand tenets from our assigned mining route."],
	["ship_computer", "Atmospheric analysis indicates a potentially habitable ecosystem."],
	["ship_computer", "I recommend an emergency landing. Our oxygen and fuel reserves are nearly depleted."],
	["ganna", "What are the chances we'd survive a landing?"],
	["ship_computer", "...Twenty-three percent."],
]

var fails := 0
var shots := ""
var _once := {}
var _tested_typing := false
var _tested_hold := false


func _check(c: bool, what: String) -> void:
	print(("PASS " if c else "FAIL ") + what)
	if not c:
		fails += 1


func _check_once(what: String, c: bool) -> void:
	if not c and _once.get(what, true):
		_check(false, what)
	_once[what] = _once.get(what, true) and c


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	shots = args[0] if args.size() > 0 else ""
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	root.set_meta("opening_cinematic", true)
	change_scene_to_file("res://main.tscn")
	_run.call_deferred()


func _press() -> void:
	var down := InputEventAction.new()
	down.action = "interact"
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventAction.new()
	up.action = "interact"
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name + ".png"))


## Press through `want` ([speaker, text] each) as a player would; returns
## the lines seen. `on_line` is called with the index of each new line.
func _play(cine: Node, want: Array, on_line: Callable, watch_cam := false) -> Array:
	var box: DialogueBox = cine.get("_box")
	var seen := []
	var timeout := 0.0
	while seen.size() < want.size() or box.is_open():
		await process_frame
		timeout += 1.0 / 60.0
		if timeout > 400.0:
			_check(false, "dialogue timed out after %d lines" % seen.size())
			break
		if watch_cam:
			on_line.call(-1)
		if not box.is_open() or not box.is_waiting():
			continue
		var text: String = box.current_text()
		if seen.is_empty() or seen[-1][1] != text:
			var i := seen.size()
			var id := ""
			for s in ["ganna", "ship_computer"]:
				if box.current_portrait() == DialogueSpeakers.portrait(s):
					id = s
			seen.append([id, text])
			_check_once("every opening line fits one box (no pages)", box.pages_left() == 0)
			_check_once("no choices in the opening", not (box.get("_choices") as Control).visible)
			await on_line.call(i)
		if box.is_typing():
			if not _tested_typing:
				await _press()
				_tested_typing = true
				_check(not box.is_typing() and box.is_open() and box.is_waiting(),
					"a press while typing completes the line instead of dismissing it")
			continue
		if not _tested_hold and float(box.get("_hold")) > 0.3:
			await _press()
			_tested_hold = true
			_check(box.is_open() and box.is_waiting() and box.current_text() == text,
				"a press inside the minimum hold doesn't dismiss the line")
			continue
		if not box.can_advance():
			continue
		await process_frame
		await _press()
		if seen.size() == want.size():
			break
	return seen


func _run() -> void:
	for i in 10:
		await process_frame
	var scene := current_scene
	var cine := scene.get_node_or_null("OpeningCinematic")
	_check(cine != null, "the opening cinematic starts in the ship")
	if cine == null:
		quit(1)
		return
	var player: Node3D = scene.get_node("Player")
	var hud: CanvasLayer = scene.get_node("HUD")
	var ship: Node3D = scene.get_node("ShipInterior")
	var gs: Node = Game.state()
	# Montage: three 2-second shots (cockpit, lounge, kitchen), before the
	# quarters.
	_check(player.process_mode == Node.PROCESS_MODE_DISABLED, "player control off")
	_check(not hud.visible, "gameplay HUD hidden")
	_check(not gs.can_save(), "no saving during the cutscene")
	_check(gs.opening_locked(), "opening locks on")
	var mcam: Camera3D = cine.get("_cam")
	var fade: ColorRect = cine.get("_fade")
	var names := ["1_montage_cockpit", "2_montage_lounge", "3_montage_kitchen"]
	var montage: Array = cine.get("MONTAGE")
	for k in 3:
		var a: Vector3 = montage[k][0]
		var b: Vector3 = montage[k][1]
		var t0 := 0.0
		while t0 < 10.0 and not (mcam.position.distance_to(a.lerp(b, 0.5)) < 0.1 and fade.color.a < 0.05):
			await process_frame
			t0 += 1.0 / 60.0
		_check(t0 < 10.0, "montage shot %d shown" % (k + 1))
		await _shot(names[k])
	# Scene 1.
	var s1 := await _play(cine, SCENE1, func(i: int) -> void:
		if i == 0:
			await _shot("4_quarters_first_line")
		if i == 5:
			await _shot("5_status_report"))
	_check(s1 == SCENE1, "Scene 1: every line, speaker and order (%d of %d)" % [s1.size(), SCENE1.size()])
	if s1 != SCENE1:
		print("  saw: ", s1)
	# Free control in the quarters.
	await create_timer(2.5).timeout
	_check(player.process_mode != Node.PROCESS_MODE_DISABLED, "control enabled after Scene 1")
	_check(hud.visible, "HUD back for free roam")
	var local := ship.to_local(player.global_position)
	_check(local.z < -6.0 and local.z > -9.6, "Gana is in the quarters (z %.2f)" % local.z)
	await _shot("6_free_in_quarters")
	var hook: Node = ship.get_node_or_null("LookOutside")
	_check(hook != null and hook.get("prompt") == "Look outside", "\"Look outside\" at the window")
	var door: Node = null
	for d in ship.find_children("*", "", true, false):
		if d.get("opening_lock") == true:
			door = d
	_check(door != null and door.name.contains("Cockpit"), "the cockpit door is locked for the opening")
	_check(gs.opening_locked(), "wrist terminal and Meki's repairs stay locked (opening_locked)")
	# The window.
	player.global_position = ship.to_global(Vector3(-0.4, 1.0, -8.7))
	await create_timer(0.3).timeout
	hook.interact(player)
	var cam: Camera3D = cine.get("_cam")
	# (Lambdas copy captured locals: the last camera transform lives in
	# the shared dictionary.)
	var stats := {"jump": 0.0, "turn": 0.0, "last": cam.global_transform, "t": Time.get_ticks_usec()}
	var watch := func(i: int) -> void:
		if i == -1:
			if is_instance_valid(cam):
				# Speeds, so a slow frame under xvfb doesn't read as a cut.
				var last: Transform3D = stats.last
				var now := Time.get_ticks_usec()
				var dt := maxf((now - int(stats.t)) / 1e6, 1.0 / 60.0)
				stats.jump = maxf(stats.jump, cam.global_position.distance_to(last.origin) / dt)
				stats.turn = maxf(stats.turn, rad_to_deg((-cam.global_basis.z).angle_to(-last.basis.z)) / dt)
				stats.last = cam.global_transform
				stats.t = now
			return
		if i == 0:
			await _shot("7_window_moon")
		if i == 6:
			await _shot("8_twenty_three")
	for f in 4:
		await process_frame
	stats.last = cam.global_transform
	stats.t = Time.get_ticks_usec()
	_check(player.process_mode == Node.PROCESS_MODE_DISABLED, "control off at the window")
	var w := await _play(cine, WINDOW, watch, true)
	_check(w == WINDOW, "window scene: every line, speaker and order (%d of %d)" % [w.size(), WINDOW.size()])
	if w != WINDOW:
		print("  saw: ", w)
	_check(stats.jump < 3.0 and stats.turn < 90.0, "the camera moves to the glass with no cuts (fastest %.2f m/s, %.1f deg/s)" % [stats.jump, stats.turn])
	await create_timer(4.0).timeout
	_check(player.process_mode != Node.PROCESS_MODE_DISABLED, "control restored after the window")
	_check(gs.has_flag("opening_window_done"), "window scene recorded (opening_window_done)")
	_check(gs.can_save(), "saving allowed again")
	_check(gs.objective() == "", "no objective yet (still in the quarters)")
	# Leaving the quarters: the hunger beat and the objective.
	player.global_position = ship.to_global(Vector3(-0.15, 1.0, -4.6))
	var t := 0.0
	while not gs.has_flag("objective_eat") and t < 30.0:
		await create_timer(0.25).timeout
		t += 0.25
		if t > 1.5 and t < 1.8:
			await _shot("9_hunger_thought")
	_check(gs.objective() == "Make something to eat", "objective \"Make something to eat\" after leaving the quarters")
	await create_timer(1.0).timeout
	await _shot("10_objective_banner")
	var tracker: Node = hud.find_children("*", "Control", true, false).filter(func(n: Node) -> bool: return n.get_script() and (n.get_script() as Script).resource_path.ends_with("objective_tracker.gd")).front()
	_check(tracker != null and (tracker.get("_banner") as Control).visible, "NEW OBJECTIVE banner on screen")
	await create_timer(7.0).timeout
	_check(tracker != null and (tracker.get("_corner") as Control).visible and not (tracker.get("_banner") as Control).visible, "then a small objective line stays in the corner")
	await _shot("11_objective_corner")
	_check(not is_instance_valid(cine), "the opening cinematic ends")
	_check(gs.opening_locked(), "locks stay on until Gana eats")
	for what in _once:
		if _once[what]:
			_check(true, what)
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)
