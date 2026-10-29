extends Area3D

## An area that makes Gana think out loud the first time he walks into it
## (e.g. entering the quarters, leaving the cockpit). Built by the scene
## builder with a box shape.

## The lines ("|" separated); "MEKI: " at the start of a line makes it his.
@export_multiline var lines := ""
## Flag that marks it played; also used to skip it.
@export var flag := ""
## Only play while Meki is still dead (or only once he's awake).
@export_enum("any", "meki_dead", "meki_online") var when := "any"


func _ready() -> void:
	collision_mask = 1
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D or body.is_in_group("meki"):
		return
	var gs := Game.state()
	if gs.has_flag(flag):
		return
	if (when == "meki_dead" and gs.meki_online) or (when == "meki_online" and not gs.meki_online):
		return
	var out := []
	for l in lines.split("|"):
		out.append(["MEKI", l.substr(6)] if l.begins_with("MEKI: ") else l)
	get_tree().get_first_node_in_group("hud").think(out, flag)
