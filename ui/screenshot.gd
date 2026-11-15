extends Node

## P takes a screenshot (anywhere in the game, also while paused), saved
## as PNG in the computer's Pictures folder under "Kestrel's Hope" (or the
## game's user folder if there's no Pictures folder). Autoload.

const ACTION := "screenshot"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_P
		InputMap.action_add_event(ACTION, ev)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION) and not event.is_echo():
		take()


## Where screenshots go: Pictures/Kestrel's Hope (or the game's own data
## folder if there's no Pictures folder).
static func folder() -> String:
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	return dir.path_join("Kestrel's Hope") if dir != "" else ProjectSettings.globalize_path("user://screenshots")


## Opens the screenshots folder in Finder / Explorer (the pause menu's
## "Screenshots" button).
static func open_folder() -> void:
	DirAccess.make_dir_recursive_absolute(folder())
	OS.shell_open(folder())


## Saves the current frame; returns the file path ("" on failure).
func take() -> String:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := folder()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("kestrels_hope_%s.png" % Time.get_datetime_string_from_system().replace(":", "-"))
	if img.save_png(path) != OK:
		push_warning("Screenshot failed: " + path)
		return ""
	print("Screenshot saved: ", path)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		hud.show_message("Screenshot saved (Pause > Screenshots to open)", 2.0)
	return path
