extends Interactable


func interact(_player: Node) -> void:
	hud().fade_through_black("You sleep. No dreams, which is a mercy.")
