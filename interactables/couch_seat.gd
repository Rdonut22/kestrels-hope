extends Interactable

## A spot on the lounge couch. Sitting switches to a first-person view of
## the holo-table, and the media player's hologram turns to face you.

## The lounge's holo media player (optional).
@export var media_path: NodePath
## Eye height when sitting.
@export var eye_height := 1.12


func get_prompt() -> String:
	return "Sit"


func can_interact(player: Node) -> bool:
	return player.has_method("sit")


func interact(player: Node) -> void:
	player.sit(self)


func media() -> Node:
	return get_node_or_null(media_path) if media_path else null


func eye_position() -> Vector3:
	return global_position + Vector3(0, eye_height, 0)


## Where the viewer looks: the hologram if there is one, else straight ahead.
func look_target() -> Vector3:
	var m := media()
	if m:
		return m.global_position + Vector3(0, 1.4, 0)
	return eye_position() - global_transform.basis.z
