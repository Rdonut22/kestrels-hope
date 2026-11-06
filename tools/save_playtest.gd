extends SceneTree

## Save/load round trip through GameState's own API (no gameplay changes):
## in the ship, sets a distinctive state (a flag, an item, the day), saves,
## wipes the state, loads, and checks everything came back, including the
## player's position. Then the same at the crash site, plus the time of day.
## Deletes the save it made at the end (tools/check.sh also backs up and
## restores any real save around the whole suite).
##   godot --path . --script tools/save_playtest.gd

var fails := 0


func _check(c: bool, what: String) -> void:
	print(("PASS " if c else "FAIL ") + what)
	if not c:
		fails += 1


func _initialize() -> void:
	change_scene_to_file("res://main.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _round_trip(label: String, scene_path: String, hour := -1.0) -> void:
	var gs: Node = Game.state()
	var scene := current_scene
	_check(scene != null and scene.scene_file_path == scene_path, "%s: scene loaded" % label)
	_check(gs.can_save(), "%s: can save here" % label)
	var player: Node3D = scene.get_node("Player")
	var pos := player.global_position
	var flag := "save_test_" + label
	gs.set_flag(flag)
	gs.add_item("fuse")
	gs.day = 4
	var clock := get_first_node_in_group("day_night")
	if hour >= 0.0 and clock:
		clock.call("set_hour", hour)
	await _frames(2)
	var saved_hour: float = clock.get("hour") if clock else -1.0
	var t_saved := Time.get_ticks_msec()
	_check(gs.save_game(), "%s: save_game() wrote the file" % label)
	_check(gs.has_save(), "%s: save file exists" % label)
	_check(not gs.save_info().is_empty(), "%s: save_info() reads it back" % label)

	gs.reset()
	_check(not gs.has_flag(flag) and not gs.has_item("fuse") and gs.day == 1, "%s: state cleared" % label)
	_check(gs.load_game(), "%s: load_game() started" % label)
	await _frames(60)
	var loaded := current_scene
	_check(loaded != null and loaded.scene_file_path == scene_path, "%s: saved scene reloaded" % label)
	_check(gs.has_flag(flag), "%s: flag restored" % label)
	_check(gs.has_item("fuse"), "%s: item restored" % label)
	_check(gs.day == 4, "%s: day restored (%d)" % [label, gs.day])
	if loaded:
		var p2: Vector3 = (loaded.get_node("Player") as Node3D).global_position
		_check(p2.distance_to(pos) < 0.5, "%s: player position restored (off by %.2f m)" % [label, p2.distance_to(pos)])
	if hour >= 0.0:
		var c2 := get_first_node_in_group("day_night")
		var h: float = c2.get("hour") if c2 else -1.0
		# The clock keeps running while the scene reloads (24 h per
		# day_length seconds), so allow for the time that passed.
		var day_len: float = c2.get("day_length") if c2 else 1440.0
		var drift := (Time.get_ticks_msec() - t_saved) / 1000.0 / day_len * 24.0
		_check(c2 != null and absf(h - saved_hour) <= drift + 0.1,
			"%s: time of day restored (saved %.2f, now %.2f, allowed drift %.2f)" % [label, saved_hour, h, drift])


func _run() -> void:
	await _frames(30)
	var gs: Node = Game.state()
	gs.reset()
	await _round_trip("ship", "res://main.tscn")

	change_scene_to_file("res://crash_site.tscn")
	await _frames(40)
	gs.reset()
	await _round_trip("crash", "res://crash_site.tscn", 15.5)

	# Leave no save behind (check.sh restores any real one).
	var path := ProjectSettings.globalize_path(gs.SAVE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	gs.reset()
	print("FAILS: ", fails)
	quit()
