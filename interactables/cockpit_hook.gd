class_name CockpitHook
extends Interactable

## An interaction point in the cockpit with no behaviour of its own
## (ship/cockpit_fitout.gd places them: co-pilot seat, the three central
## levers, the pilot's instruments, the co-pilot's navigation display).
## Off by default: it isn't offered to the player (no outline, no [E])
## until `enabled` is set. When used it only emits `used`; connect that
## to whatever system should respond.

signal used(hook_id: String, player: Node)

## Which point this is, e.g. "copilot_seat", "lever_1", "pilot_instruments".
@export var hook_id := ""
@export var enabled := false:
	set(v):
		enabled = v
		if is_inside_tree():
			if v:
				add_to_group("interactables")
			elif is_in_group("interactables"):
				remove_from_group("interactables")


func _enter_tree() -> void:
	if enabled:
		super()


func can_interact(_player: Node) -> bool:
	return enabled


func interact(player: Node) -> void:
	used.emit(hook_id, player)
