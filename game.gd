class_name Game

## Shortcut to the GameState autoload that also works when the autoload
## isn't loaded (the scene builder and test scripts run without autoloads).


static func state() -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node_or_null("GameState")
	if gs:
		return gs
	# Not in the tree yet: make one (once) and add it when the root is free.
	if not root.has_meta("game_state"):
		gs = (load("res://game_state.gd") as GDScript).new()
		gs.name = "GameState"
		root.set_meta("game_state", gs)
		root.add_child.call_deferred(gs)
	return root.get_meta("game_state")
