extends Interactable

## The hover bike's switch panel glowing while it waits to be used (the
## rider flips its toggles with Space, not E: hoverbike.gd flip_switch). It
## only borrows Interactable's outline, so it doesn't join the
## "interactables" group the player picks targets from.

var targets: Array[Node] = []


func _enter_tree() -> void:
	pass


func _targets() -> Array[Node]:
	return targets
