extends Interactable


func interact(_player: Node) -> void:
	var clock := get_tree().get_first_node_in_group("day_night")
	if clock:
		# Skip to morning while the screen is black.
		get_tree().create_timer(1.2).timeout.connect(clock.skip_to.bind(7.0))
		hud().fade_through_black("You sleep until morning.")
	else:
		hud().fade_through_black("You sleep. No dreams, which is a mercy.")
