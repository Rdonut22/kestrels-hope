extends SceneTree

## Drives ui/dialogue/dialogue_test.tscn like a player (keyboard and
## controller-style actions) and checks the dialogue box: the right
## portrait per speaker, no portrait frame without one, the text fitting
## its area at this window size, the name fitting its label, choices only
## when asked for, navigation with ui_down/ui_up and a fresh press to pick.
##   godot --path . --resolution 1280x720 --script tools/dialogue_playtest.gd [-- <screenshot dir>]

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
	change_scene_to_file("res://ui/dialogue/dialogue_test.tscn")
	_run.call_deferred()


func _action(name: String) -> void:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	e = InputEventAction.new()
	e.action = name
	e.pressed = false
	Input.parse_input_event(e)
	await process_frame


func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var sz := root.get_visible_rect().size
	root.get_texture().get_image().save_png(shots.path_join("%s_%dx%d.png" % [name, sz.x, sz.y]))


func _until_shown(box: DialogueBox) -> void:
	while not (box.is_open() and box.is_waiting()):
		await process_frame
	# Finish the typing with a press (ui_accept: Enter / pad A).
	await _action("ui_accept")
	await process_frame


func _layout_ok(box: DialogueBox, tag: String) -> void:
	var panel: Control = box.get("_panel")
	var text: Label = box.get("_text")
	var name: Label = box.get("_name")
	var vp := root.get_visible_rect()
	_check(vp.encloses(panel.get_global_rect()), "%s: panel inside the window" % tag)
	_check(panel.get_global_rect().grow(-2).encloses(text.get_global_rect()), "%s: text inside the panel" % tag)
	_check(text.get_theme_font_size("font_size") >= 14, "%s: text at a readable size (%d px)" % [tag, text.get_theme_font_size("font_size")])
	var f: Font = name.get_theme_font("font")
	var fs := name.get_theme_font_size("font_size")
	_check(f.get_string_size(name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= name.size.x + 0.5, "%s: name '%s' fits its label" % [tag, name.text])
	var frame: Control = box.get("_frame")
	if frame.visible:
		_check(not frame.get_global_rect().intersects(text.get_global_rect()), "%s: portrait and text don't overlap" % tag)


func _run() -> void:
	for i in 5:
		await process_frame
	var scene := current_scene
	var box: DialogueBox = scene.get("box")
	var picked := [-1]
	scene.done.connect(func(i: int) -> void: picked[0] = i)
	var expect := {"meki": "portrait_meki.png", "farm_droid": "portrait_farm_droid.png", "ship_computer": "portrait_ship_computer.png"}
	var tags := ["meki", "farm_droid", "ship_computer", "radio"]
	for tag in tags:
		await _until_shown(box)
		var tex := box.current_portrait() as AtlasTexture
		if expect.has(tag):
			_check(tex != null and String(tex.atlas.resource_path).ends_with(expect[tag]), "%s shows %s" % [tag, expect[tag]])
			_check((box.get("_frame") as Control).visible, "%s: portrait frame shown" % tag)
		else:
			_check(tex == null and not (box.get("_frame") as Control).visible, "no-portrait speaker: frame collapsed")
			var t: Label = box.get("_text")
			var p: Control = box.get("_panel")
			_check(t.position.x < p.size.x * 0.1, "no-portrait speaker: text takes the panel's width")
		_check(not (box.get("_choices") as Control).visible, "%s: no choices shown" % tag)
		_layout_ok(box, tag)
		await _shot(tag)
		# Long lines page: each page is advanced like a line.
		var pages := 1
		while box.pages_left() > 0:
			while not box.can_advance():
				await process_frame
			await _action("interact")
			pages += 1
			_layout_ok(box, "%s page %d" % [tag, pages])
			await _shot("%s_page%d" % [tag, pages])
		if tag == "ship_computer":
			print("  long line shown on %d page(s)" % pages)
		while not box.can_advance():
			await process_frame
		# A held key's repeat never advances: send an echo first.
		var echo := InputEventKey.new()
		echo.keycode = KEY_ENTER
		echo.physical_keycode = KEY_ENTER
		echo.pressed = true
		echo.echo = true
		Input.parse_input_event(echo)
		await process_frame
		var up := InputEventKey.new()
		up.keycode = KEY_ENTER
		up.physical_keycode = KEY_ENTER
		up.pressed = false
		Input.parse_input_event(up)
		await process_frame
		_check(box.is_waiting() and box.current_text() != "", "%s: a held key's repeat doesn't advance" % tag)
		await _action("interact")
	# The question with choices.
	await _until_shown(box)
	while box.get("_hold") > 0.0:
		await process_frame
	var ch: Control = box.get("_choices")
	_check(ch.visible and ch.get_child_count() == 3, "choices shown for a question")
	_check(not (box.get("_indicator") as Control).visible, "no continue arrow while choosing")
	_layout_ok(box, "question")
	_check(root.get_visible_rect().encloses(ch.get_global_rect()), "choices inside the window")
	await _action("ui_down")
	await _action("ui_down")
	await _action("ui_up")
	await _action("ui_down")
	await _shot("choices")
	await _action("ui_accept")
	for i in 10:
		await process_frame
	_check(picked[0] == 2, "ui_down/ui_up then a press picks the third choice (got %d)" % picked[0])
	_check(not ch.visible, "choices hidden after picking")
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)
