extends Node

## Story flags and the player's inventory, kept across scenes (autoload),
## and the save game: one slot in user://savegame.json holding all of this
## plus where Gana is (scene, position, facing, the pilot seat) and the time
## of day. Saved from the pause menu, automatically whenever the story moves
## on (a flag, an item, Meki or the power), and on Quit to Menu; loaded by
## Continue on the title screen.

signal meki_online_changed(online: bool)
signal power_restored_changed(on: bool)
signal flag_set(flag: String)
signal inventory_changed

## Everything that can be carried. Tools aren't used up by repairs.
const ITEMS := {
	"cap_round": {"name": "Round capacitor", "desc": "Thumb-sized barrel cap. 220 microfarad, looks unused.",
		"shape": "round", "color": Color(0.3, 0.5, 0.85)},
	"cap_square": {"name": "Square capacitor", "desc": "A boxy cap pulled out of some old console.",
		"shape": "square", "color": Color(0.85, 0.62, 0.22)},
	"fuse": {"name": "Glass fuse", "desc": "Ten amp. Still good.", "shape": "fuse", "color": Color(0.75, 0.85, 0.9)},
	"coil": {"name": "Copper coil", "desc": "A tidy spool of copper winding.", "shape": "coil", "color": Color(0.8, 0.45, 0.2)},
	"tape": {"name": "Duct tape", "desc": "Half a roll. Fixes everything, allegedly.", "shape": "tape", "color": Color(0.6, 0.62, 0.6)},
	"wrench": {"name": "Wrench", "desc": "Heavy, reliable, slightly bent.", "shape": "wrench", "color": Color(0.55, 0.58, 0.62), "tool": true},
	"welder": {"name": "Welding torch", "desc": "Pocket arc welder. Half a charge left.", "shape": "torch", "color": Color(0.95, 0.55, 0.15), "tool": true},
}

## Meki is the ship's drone and its link to the ship's computer; until he's
## repaired the ship runs on emergency power.
var meki_online := false:
	set(value):
		if value != meki_online:
			meki_online = value
			meki_online_changed.emit(value)
## Backup cell rerouted (Meki's puzzle at the engineering computer): the
## ship's lights, galley, lounge and cockpit switches have power again.
var power_restored := false:
	set(value):
		if value != power_restored:
			power_restored = value
			power_restored_changed.emit(value)
var items: Array[String] = []
## Meki rebuilds Hale's corrupted file in the background once the power is
## back. It sits just short of done until Gana tries to land; then Meki
## finishes it and shows him (see the windshield HUD).
var hale_file := 0.0
const HALE_FILE_CAP := 97.0
const HALE_FILE_RATE := 0.25  # percent per second
## One-off story flags ("seen_tab_nav", "thought_bunk", ...).
var flags := {}

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1
## Scenes you can save in (not the title screen or the intro).
const SAVE_SCENES := ["res://main.tscn", "res://crash_site.tscn"]
## Flags only meant for the next scene load, never saved.
const TRANSIENT_FLAGS := ["wake_after_crash"]

var _autosave_queued := false
var _loading := false


func _ready() -> void:
	for sig in [flag_set, inventory_changed, meki_online_changed, power_restored_changed]:
		sig.connect(func(_a = null) -> void: _queue_autosave())


## Back to the very start (New Game).
func reset() -> void:
	meki_online = false
	power_restored = false
	items.clear()
	flags.clear()
	hale_file = 0.0
	inventory_changed.emit()


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func set_flag(flag: String) -> void:
	if not has_flag(flag):
		flags[flag] = true
		flag_set.emit(flag)


func add_item(id: String) -> void:
	items.append(id)
	inventory_changed.emit()


func has_item(id: String) -> bool:
	return id in items


func remove_item(id: String) -> void:
	items.erase(id)
	inventory_changed.emit()


func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## True when the game can be saved right now: in a playable scene, Gana
## present, no cinematic (the landing) running, and not the title screen's
## crash-site preview.
func can_save() -> bool:
	var tree := get_tree()
	if tree == null or tree.root.has_meta("preview"):
		return false
	var scene := tree.current_scene
	if scene == null or not scene.scene_file_path in SAVE_SCENES or scene.get_node_or_null("Player") == null:
		return false
	var descent := scene.get_node_or_null("Descent")
	return not (descent and descent.get("running"))


## Writes the save file. Returns false if saving isn't possible right now.
func save_game() -> bool:
	if _loading or not can_save():
		return false
	var scene := get_tree().current_scene
	var player: Node3D = scene.get_node("Player")
	var pivot: Node3D = player.get_node("CameraPivot")
	var model: Node3D = player.get_node("Model")
	var seat: Node = player.get("_seat")
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"scene": scene.scene_file_path,
		"meki_online": meki_online,
		"power_restored": power_restored,
		"items": Array(items),
		"hale_file": hale_file,
		"flags": flags.keys().filter(func(f: String) -> bool: return not f in TRANSIENT_FLAGS),
		"player": {
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
			"yaw": pivot.rotation.y,
			"pitch": pivot.rotation.x,
			"model_yaw": model.rotation.y,
			"pilot_seat": seat != null and seat.is_in_group("pilot_seat"),
		},
	}
	var clock := get_tree().get_first_node_in_group("day_night")
	if clock:
		data["hour"] = clock.get("hour")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Couldn't write the save file: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


## When and where the save was made, for the title screen ({} if none).
func save_info() -> Dictionary:
	var data := _read_save()
	if data.is_empty():
		return {}
	return {"saved_at": data.get("saved_at", ""), "outside": data.get("scene", "") == "res://crash_site.tscn"}


## Restores the saved game and loads its scene. Returns false if there's no
## usable save.
func load_game() -> bool:
	var data := _read_save()
	if data.is_empty() or not ResourceLoader.exists(data.get("scene", "")):
		return false
	_loading = true
	reset()
	meki_online = data.get("meki_online", false)
	power_restored = data.get("power_restored", false)
	for id in data.get("items", []):
		items.append(String(id))
	hale_file = data.get("hale_file", 0.0)
	for f in data.get("flags", []):
		flags[String(f)] = true
	inventory_changed.emit()
	var spawn: Dictionary = data.get("player", {})
	if data.has("hour"):
		spawn["hour"] = data["hour"]
	get_tree().root.set_meta("load_spawn", spawn)
	get_tree().change_scene_to_file(data["scene"])
	_loading = false
	return true


func _read_save() -> Dictionary:
	if not has_save():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary or int((parsed as Dictionary).get("version", 0)) > SAVE_VERSION:
		return {}
	return parsed


## Saves at the end of the frame, once however many things changed at once.
func _queue_autosave() -> void:
	if _loading or _autosave_queued:
		return
	_autosave_queued = true
	(func() -> void:
		_autosave_queued = false
		save_game()).call_deferred()


func _process(delta: float) -> void:
	if power_restored and hale_file < HALE_FILE_CAP:
		hale_file = minf(HALE_FILE_CAP, hale_file + delta * HALE_FILE_RATE)
