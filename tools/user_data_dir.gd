extends SceneTree

## Prints the game's user data folder (where savegame.json lives), so
## tools/check.sh can back up and restore a real save around the tests.
##   godot --headless --path . --script tools/user_data_dir.gd


func _initialize() -> void:
	print("USER_DATA_DIR=" + OS.get_user_data_dir())
	quit()
