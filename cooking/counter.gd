extends Interactable

## The cooking counter (cooking/kitchen.gd): E steps up to it and into the
## cooking view (cooking/cook_session.gd). The stove outlines while Gana
## looks at it.

var kitchen: Node3D


func _enter_tree() -> void:
	super()
	interact_range = 1.7


func get_prompt() -> String:
	return "Cook"


func can_interact(player: Node) -> bool:
	return player.has_method("start_cooking") and kitchen != null and not kitchen.get("busy")


func interact(player: Node) -> void:
	var session := CookSession.new()
	session.name = "CookSession"
	kitchen.add_child(session)
	session.start(kitchen, player)


func _targets() -> Array[Node]:
	var t: Array[Node] = []
	if kitchen and kitchen.get("stove"):
		t.append(kitchen.get("stove"))
	return t
