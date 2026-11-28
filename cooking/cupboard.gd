extends Interactable

## The galley cupboard (the wall unit over the aft counter): E opens the
## supplies (cooking/supply_hud.gd) to choose what to take to the cooking
## counter.

var kitchen: Node3D


func _enter_tree() -> void:
	super()
	interact_range = 1.8


func get_prompt() -> String:
	return "Open the cupboard"


func interact(_player: Node) -> void:
	var panel := SupplyHud.new()
	hud().add_overlay(panel)


func _targets() -> Array[Node]:
	var t: Array[Node] = []
	if kitchen and kitchen.get("cabinet"):
		t.append(kitchen.get("cabinet"))
	return t
