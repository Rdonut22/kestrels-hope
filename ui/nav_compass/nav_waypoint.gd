class_name NavWaypoint
extends Marker3D

## A place the navigation compass (ui/nav_compass/nav_compass.gd) can
## track. Drop one into a scene; while `active`, the compass shows the
## first active one it finds, unless a script has called
## NavCompass.set_waypoint() with something else.

const GROUP := "nav_waypoint"

@export var active := true
## Not shown while the camera is closer than this (metres); 0 = always.
## Lets a waypoint for somewhere big, like the ship, appear only once
## you're away from it.
@export var hide_within := 0.0


## True when the compass should track this from `from`.
func wanted_from(from: Vector3) -> bool:
	return active and is_inside_tree() and (hide_within <= 0.0 or from.distance_to(global_position) >= hide_within)


func _enter_tree() -> void:
	add_to_group(GROUP)
