extends Interactable

## Barrel of salvaged parts in engineering. Each rummage turns up a couple
## of items for the inventory until only scrap is left.

## Found in this order, a few per rummage.
@export var contents: Array[String] = ["cap_square", "wrench", "fuse", "cap_round", "tape", "coil", "welder"]
@export var per_rummage := 2


func get_prompt() -> String:
	return "Rummage through parts" if not contents.is_empty() else "Parts barrel"


func interact(_player: Node) -> void:
	if contents.is_empty():
		hud().show_message("Nothing but scrap left in there.")
		return
	var found := PackedStringArray()
	for i in mini(per_rummage, contents.size()):
		var id: String = contents.pop_front()
		Game.state().add_item(id)
		found.append(Game.state().item(id).name)
	hud().show_message("Found: " + ", ".join(found))
