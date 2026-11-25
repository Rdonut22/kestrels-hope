extends Interactable

## Getting on the hover bike (world/vehicles/hoverbike.gd): its "Seat".
## Gana gets on from either side; the bike outlines while he looks at it.


func _enter_tree() -> void:
	super()
	interact_range = 2.6


func bike() -> Node:
	return get_parent()


func get_prompt() -> String:
	return "Ride the hover bike"


func can_interact(player: Node) -> bool:
	return player.has_method("mount") and bike().get("rider") == null


func interact(player: Node) -> void:
	player.mount(bike())


func _targets() -> Array[Node]:
	return bike().outline_targets()
