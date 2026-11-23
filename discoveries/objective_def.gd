class_name ObjectiveDef
extends Resource

## One Mission or Task for Discoveries (the wrist terminal's objectives).
## Each lives in its own .tres in discoveries/objectives/; Objectives
## (objectives.gd) loads them all. What the player has discovered, tracked
## and finished is kept in GameState (and the save), by `id`.
##
## Unlock one from gameplay with Game.state().add_objective(id) and finish
## it with Game.state().complete_objective(id).

## Stable id: saves refer to objectives by it, so never rename one.
@export var id := ""
## "mission" (a larger main objective) or "task" (smaller: side jobs,
## survival actions, other activities).
@export_enum("task", "mission") var category := "task"
@export var title := ""
## One line under the title in the Discoveries list.
@export var summary := ""
@export_multiline var description := ""
## Required objectives stay tracked until they're done; the player can't
## untrack them.
@export var required := false
## A required progression objective that takes the HUD's emphasis over
## the player's own choice while it's active.
@export var takes_precedence := false
## Optional objectives: tracked as soon as they're discovered.
@export var track_on_discovery := true
## Optional picture in the Discoveries detail pane.
@export var image: Texture2D
## A vitals row (ui/vitals) highlighted while this is active, e.g. "hunger".
@export var highlight_vital := ""

@export_group("Waypoint")
## Where the compass points while this is tracked. Leave `waypoint_node`
## empty when the destination isn't known: no marker is shown then.
## Node path from the scene root; the marker sits at its origin plus the
## offset (in that node's frame).
@export var waypoint_node: NodePath
@export var waypoint_offset := Vector3.ZERO
## Only in this scene ("" = whichever scene has that node).
@export_file("*.tscn") var waypoint_scene := ""


func is_mission() -> bool:
	return category == "mission"
