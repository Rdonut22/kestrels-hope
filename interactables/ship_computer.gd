extends Interactable

@export var ship_name := "KESTREL'S HOPE"
@export_range(0, 100) var hull := 87
@export_range(0, 100) var fuel := 34
@export_range(0, 100) var oxygen := 96
@export_range(0, 100) var power := 72


func interact(_player: Node) -> void:
	hud().open_screen(ship_name + " // SHIP COMPUTER", [
		{"title": "Status", "body": _status()},
		{"title": "Navigation", "body": "Position: [color=#ffb347]UNKNOWN[/color]\nVelocity: drifting\n\nNav array offline. Last good fix 41 days ago.\nRecommend manual star sighting."},
		{"title": "Comms", "body": "Inbox empty.\n\nLong-range transmitter: standby\nDistress beacon: [color=#888888]not armed[/color]"},
		{"title": "Diagnostics", "body": "Life support ....... [color=#7CFC00]OK[/color]\nReactor ............ [color=#7CFC00]OK[/color]\nArtificial gravity . [color=#7CFC00]OK[/color]\nNav array .......... [color=#ff5555]FAULT[/color]\nCoffee machine ..... [color=#7CFC00]EXCELLENT[/color]"},
	])


func _status() -> String:
	return "Hull integrity  %s\nFuel            %s\nOxygen          %s\nReactor output  %s" % [
		_bar(hull), _bar(fuel), _bar(oxygen), _bar(power)]


func _bar(value: int) -> String:
	var filled := int(round(value / 5.0))
	var color := "#7CFC00" if value > 60 else ("#ffb347" if value > 30 else "#ff5555")
	return "[color=%s]%s[/color][color=#333333]%s[/color] %3d%%" % [
		color, "█".repeat(filled), "█".repeat(20 - filled), value]
