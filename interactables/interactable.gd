class_name Interactable
extends Node3D

## Base for anything the player can use with the interact key (E).
## Make a script that extends this and override interact().

@export var prompt := "Use"
## How close (in meters, ignoring height) the player must be.
@export var interact_range := 2.0
## Dead until Meki brings the ship's power back (see GameState).
@export var needs_power := false


func _enter_tree() -> void:
	add_to_group("interactables")


func get_prompt() -> String:
	return prompt


func can_interact(_player: Node) -> bool:
	return true


func interact(_player: Node) -> void:
	pass


func hud() -> Node:
	return get_tree().get_first_node_in_group("hud")
