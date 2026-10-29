extends Interactable

## Talking to Meki (a child of the drone, so it floats along with him).
## Opens the ship-link screen with things you can ask; the status answer is
## read live from the ship computer.


func get_prompt() -> String:
	return "Talk to Meki"


func interact(_player: Node) -> void:
	get_parent().call("_play", "res://audio/sfx/beep.ogg")
	hud().open_screen("MEKI  //  SHIP LINK", [
		{"title": "How are you feeling?", "body": "New capacitor, warm seams. I feel... [i]welded[/i].\n\nThank you, Gana. I didn't think anyone was coming."},
		{"title": "Ship status", "body": _status()},
		{"title": "What happened to us?", "body": "Pirates, near Aphelion. Forty-three days ago now.\n\nThey hit the reactor and a surge went straight through my core. I've been dark ever since.\n\nYou've been out here alone this whole time?"},
		{"title": "Where are we?", "body": "Drifting in high orbit over a world that isn't on any chart I have.\n\nThere's something on the surface, too. A faint signal, very regular. I'm keeping an ear on it."},
		{"title": "What should I do now?", "body": _next_step()},
		{"title": "Hale's file", "body": _hale_file()},
		{"title": "Tell me about yourself", "body": "Meki. Maintenance, Engineering and Kinetic Interface. Hale said it stood for something sillier.\n\nI'm the ship's hands and its voice. If the Kestrel needs telling something, I'm the one who tells it."},
	])


func _status() -> String:
	var pc := get_tree().current_scene.find_child("ShipComputer", true, false)
	var power: int = pc.get("power") if pc else 31
	var hull: int = pc.get("hull") if pc else 87
	var oxygen: int = pc.get("oxygen") if pc else 96
	var fuel: int = pc.get("fuel") if pc else 34
	return ("[b]Power[/b]   %d%%   reactor's limping; I've routed it to life support, lights and the galley.\n" +
		"[b]Hull[/b]    %d%%   some scarring aft, nothing venting.\n" +
		"[b]Oxygen[/b]  %d%%   scrubbers are happy.\n" +
		"[b]Fuel[/b]    %d%%   enough to steer, not enough to go home.\n\n" +
		"Days adrift: 43.") % [power, hull, oxygen, fuel]


func _next_step() -> String:
	var gs := Game.state()
	if not gs.power_restored:
		return "The power junction in engineering, next to the power panel. I'll jack in and we'll route the backup cell around the damage.\n\nYou do the routing. I'll do the worrying."
	if not gs.has_flag("hud_all_seen"):
		return "The cockpit's awake now. Flip the switches and check every screen on the glass.\n\nThen get some coffee. You look like a man who's been drinking reactor coolant."
	return "Everything that can be fixed from up here is fixed.\n\nThere's the landing option on nav, when you're ready. No rush. I'll be right here."


func _hale_file() -> String:
	var pct := int(Game.state().hale_file)
	return "HALE_PRIVATE.LOG\n\nStill rebuilding it, block by block. %d%% so far.\n\nI don't know what's in it, Gana. He locked it to both of us." % pct
