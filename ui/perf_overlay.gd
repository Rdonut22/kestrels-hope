extends CanvasLayer

## Performance readout for tracking down lag (autoload "PerfOverlay").
##
##   ` (backtick, left of 1) or F3: show / hide the readout
##   While it's showing, these switch things off for a moment to see what the
##   lag comes from (nothing is saved; hiding the readout or a restart puts
##   them back). On a Mac the F keys need fn held, so each has a plain key too:
##   1 / F4  sun shadows    2 / F5  grass     3 / F6  3D at half resolution
##   4 / F7  trees          5 / F8  the wreck
##   C / F9  copy the readout to the clipboard
##
## "Freezes" counts frames that took over 50 ms in the last 10 seconds.

const FREEZE_MS := 50.0

var _label: Label
var _times := []          # [ticks_usec, frame_ms] for the last 10 s
var _last := 0
var _t := 0.0
var _off := {}            # toggle name -> true while switched off
var _hidden: Array[Node3D] = []
var _shadow_lights: Array[Light3D] = []
var _report := ""
var _copied := 0.0        # seconds left showing "copied"


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.72)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(12, 12)
	add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	panel.add_child(_label)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_last = Time.get_ticks_usec()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var key := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	if key == KEY_F3 or key == KEY_QUOTELEFT:
		visible = not visible
		if not visible:
			_restore()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	match key:
		KEY_F4, KEY_1:
			_toggle("shadows")
		KEY_F5, KEY_2:
			_toggle("grass")
		KEY_F6, KEY_3:
			_toggle("half_res")
		KEY_F7, KEY_4:
			_toggle("trees")
		KEY_F8, KEY_5:
			_toggle("wreck")
		KEY_F9, KEY_C:
			DisplayServer.clipboard_set(_report)
			_copied = 2.0
		_:
			return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	_times.append([now, (now - _last) / 1000.0])
	_last = now
	while not _times.is_empty() and now - int(_times[0][0]) > 10_000_000:
		_times.pop_front()
	_t += _delta
	_copied = maxf(_copied - _delta, 0.0)
	if not visible or _t < 0.5:
		return
	_t = 0.0
	_report = _make_report(now)
	_label.text = _report + ("\n\nCOPIED - paste it to Claude" if _copied > 0.0 else "")


func _make_report(now: int) -> String:
	var recent := []
	var freezes := 0
	var worst_10 := 0.0
	for e in _times:
		var ms: float = e[1]
		if now - int(e[0]) < 2_000_000:
			recent.append(ms)
		if ms > FREEZE_MS:
			freezes += 1
		worst_10 = maxf(worst_10, ms)
	var avg := 0.0
	var worst := 0.0
	for ms in recent:
		avg += ms
		worst = maxf(worst, ms)
	avg /= maxf(recent.size(), 1)
	var vp := get_viewport().get_viewport_rid()
	var rs := RenderingServer
	var lines := PackedStringArray()
	lines.append("FPS %d   frame %.1f ms avg, %.1f ms worst (2 s)" % [Engine.get_frames_per_second(), avg, worst])
	lines.append("freezes >%d ms in last 10 s: %d   (worst %.0f ms)" % [FREEZE_MS, freezes, worst_10])
	lines.append("scripts %.1f ms   physics %.1f ms" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	lines.append("render: CPU %.1f ms   GPU %.1f ms" % [rs.viewport_get_measured_render_time_cpu(vp) + rs.get_frame_setup_time_cpu(),
		rs.viewport_get_measured_render_time_gpu(vp)])
	lines.append("draw calls %d   objects %d   triangles %.2f M" % [
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1.0e6])
	lines.append("video memory %d MB   nodes %d" % [rs.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	var win := DisplayServer.window_get_size()
	lines.append("window %dx%d   screen scale %.1f   3D scale %.2f   vsync %d" % [win.x, win.y,
		DisplayServer.screen_get_scale(), get_viewport().scaling_3d_scale, DisplayServer.window_get_vsync_mode()])
	lines.append("%s / %s   %s" % [rs.get_video_adapter_vendor(), rs.get_video_adapter_name(), rs.get_current_rendering_driver_name()])
	lines.append("%s, %d cores" % [OS.get_processor_name(), OS.get_processor_count()])
	var cam := get_viewport().get_camera_3d()
	if cam:
		var p := cam.global_position
		lines.append("camera at (%.0f, %.0f, %.0f)" % [p.x, p.y, p.z])
	lines.append("")
	var names := {"shadows": "1 shadows", "grass": "2 grass", "half_res": "3 half-res 3D", "trees": "4 trees", "wreck": "5 wreck"}
	var state := PackedStringArray()
	for k in names:
		state.append("%s %s" % [names[k], "OFF" if _off.get(k, false) else "on"])
	lines.append("   ".join(state.slice(0, 3)))
	lines.append("   ".join(state.slice(3)) + "   C copy")
	return "\n".join(lines)


func _toggle(what: String) -> void:
	var off: bool = not _off.get(what, false)
	_off[what] = off
	var scene := get_tree().current_scene
	match what:
		"shadows":
			if off:
				_shadow_lights.clear()
				for l in scene.find_children("*", "Light3D", true, false):
					if (l as Light3D).shadow_enabled:
						(l as Light3D).shadow_enabled = false
						_shadow_lights.append(l)
			else:
				for l in _shadow_lights:
					if is_instance_valid(l):
						l.shadow_enabled = true
				_shadow_lights.clear()
		"half_res":
			get_viewport().scaling_3d_scale = 0.5 if off else 1.0
		"grass":
			_show(scene, ["CrashSite/Grass", "CrashSite/GrassEast"], not off)
		"trees":
			_show(scene, ["CrashSite/EastForest", "CrashSite/Redwoods", "CrashSite/FarForest", "RenderBudget"], not off)
		"wreck":
			_show(scene, ["Ship"], not off)


func _show(scene: Node, paths: Array, on: bool) -> void:
	for p in paths:
		var n := scene.get_node_or_null(p)
		if n is Node3D:
			(n as Node3D).visible = on
		elif n:
			for c in n.find_children("*", "Node3D", false, false):
				(c as Node3D).visible = on


func _restore() -> void:
	for k in _off.keys():
		if _off[k]:
			_toggle(k)
