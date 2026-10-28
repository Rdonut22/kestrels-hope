extends Node

## Story flags and the player's inventory, kept across scenes (autoload).

signal meki_online_changed(online: bool)
signal inventory_changed

## Everything that can be carried. Tools aren't used up by repairs.
const ITEMS := {
	"cap_round": {"name": "Round capacitor", "desc": "Thumb-sized barrel cap. 220 microfarad, looks unused.",
		"shape": "round", "color": Color(0.3, 0.5, 0.85)},
	"cap_square": {"name": "Square capacitor", "desc": "A boxy cap pulled out of some old console.",
		"shape": "square", "color": Color(0.85, 0.62, 0.22)},
	"fuse": {"name": "Glass fuse", "desc": "Ten amp. Still good.", "shape": "fuse", "color": Color(0.75, 0.85, 0.9)},
	"coil": {"name": "Copper coil", "desc": "A tidy spool of copper winding.", "shape": "coil", "color": Color(0.8, 0.45, 0.2)},
	"tape": {"name": "Duct tape", "desc": "Half a roll. Fixes everything, allegedly.", "shape": "tape", "color": Color(0.6, 0.62, 0.6)},
	"wrench": {"name": "Wrench", "desc": "Heavy, reliable, slightly bent.", "shape": "wrench", "color": Color(0.55, 0.58, 0.62), "tool": true},
	"welder": {"name": "Welding torch", "desc": "Pocket arc welder. Half a charge left.", "shape": "torch", "color": Color(0.95, 0.55, 0.15), "tool": true},
}

## Meki is the ship's drone and its link to the ship's computer; until he's
## repaired the ship runs on emergency power.
var meki_online := false:
	set(value):
		if value != meki_online:
			meki_online = value
			meki_online_changed.emit(value)
var items: Array[String] = []


func add_item(id: String) -> void:
	items.append(id)
	inventory_changed.emit()


func has_item(id: String) -> bool:
	return id in items


func remove_item(id: String) -> void:
	items.erase(id)
	inventory_changed.emit()


func item(id: String) -> Dictionary:
	return ITEMS.get(id, {})
