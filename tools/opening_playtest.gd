extends SceneTree

## Plays the quarters half of the opening cinematic (ship/opening_cinematic.gd)
## from a fresh start, pressing to advance like a player would, and checks:
## every line in order; a press while a line types completes it rather than
## dismissing it; a press inside the minimum hold is ignored; the camera
## never cuts from the planet reveal to the end; the player and HUD are off
## during it and back, in the pilot seat, after.
##   godot --path . --script tools/opening_playtest.gd [-- <screenshot dir>]

const LINES := ["It's been 43 days already.", "Not sure what I'm hoping for at this point.",
	"It's… beautiful.", "But how?", "Good morning, Gana.",
	"Forty-three days since the attack. No sign of Hale.",
	"The drive sustained extensive damage. Fuel reserves are low.",
	"I've established a stable orbit.", "This planet isn't on our system map.",
	"But… there's a signal."]

var fails := 0
var shots := ""


func _check(c: bool, what: String) -> void:
	print(("PASS " if c else "FAIL ") + what)
	if not c:
		fails += 1


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


func _run() -> void:
	for i in 10:
		await process_frame
	var scene := current_scene
	var cine := scene.get_node_or_null("OpeningCinematic")
	_check(cine != null, "the opening cinematic starts in the ship")
	if cine == null:
		quit(1)
		return
	var player: Node = scene.get_node("Player")
	var hud: CanvasLayer = scene.get_node("HUD")
	await create_timer(3.0).timeout
	_check(player.process_mode == Node.PROCESS_MODE_DISABLED, "player control off")
	_check(not hud.visible, "gameplay HUD hidden")
	await _shot("1_bed")
	var box: Control = cine.get("_box")
	var cam: Camera3D = cine.get("_cam")
	var seen := []
	var tested_typing := false
	var tested_hold := false
	var reveal_from := -1
	var last := Transform3D()
	var max_jump := 0.0
	var max_turn := 0.0
	var frames := 0
	while is_instance_valid(cine) and not (seen.size() == LINES.size() and not box.get("_waiting")):
		await process_frame
		frames += 1
		if is_instance_valid(cam):
			# From the planet reveal (the third line) on: no cuts.
			if reveal_from >= 0:
				max_jump = maxf(max_jump, cam.global_position.distance_to(last.origin))
				max_turn = maxf(max_turn, rad_to_deg((-cam.global_basis.z).angle_to(-last.basis.z)))
			last = cam.global_transform
		var panel: Control = box.get("_box")
		if not panel.visible or not box.get("_waiting"):
			continue
		var text: String = (box.get("_line") as Label).text
		if seen.is_empty() or seen[-1] != text:
			seen.append(text)
			if seen.size() == 3 and reveal_from < 0:
				reveal_from = frames
				await _shot("4_reveal_first_line")
			if seen.size() == 1:
				await _shot("2_thought_on_bed")
			if seen.size() == 6:
				await _shot("5_computer_hale")
			if seen.size() == 10:
				await _shot("6_signal")
		if box.get("_typing"):
			if not tested_typing:
				await _press()
				tested_typing = true
				_check(not box.get("_typing") and panel.visible and box.get("_waiting"),
					"a press while typing completes the line instead of dismissing it")
			continue
		if not tested_hold and float(box.get("_hold")) > 0.3:
			await _press()
			tested_hold = true
			_check(panel.visible and box.get("_waiting") and (box.get("_line") as Label).text == text,
				"a press inside the minimum hold doesn't dismiss the line")
			continue
		if float(box.get("_hold")) > 0.0:
			continue
		if seen.size() == 2:
			await _press()
			await create_timer(4.0).timeout
			await _shot("3_walk")
			continue
		await _press()
	_check(seen == LINES, "all lines in order (%d of %d)" % [seen.size(), LINES.size()])
	if seen != LINES:
		print("  saw: ", seen)
	_check(max_jump < 0.05 and max_turn < 1.5, "camera stays on the planet, no cuts (largest step %.3f m, %.2f deg)" % [max_jump, max_turn])
	# The final hold, then the existing next sequence.
	await create_timer(12.0).timeout
	_check(not is_instance_valid(cine), "the cinematic ends")
	_check(player.process_mode != Node.PROCESS_MODE_DISABLED, "player control back")
	_check(hud.visible, "HUD back")
	var seat: Node3D = get_first_node_in_group("pilot_seat")
	_check(seat != null and player.get("_seat") == seat, "player continues in the pilot seat (the existing opening)")
	await create_timer(2.0).timeout
	await _shot("7_after")
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)
