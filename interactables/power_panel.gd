extends Interactable

## Engineering power panel. Once Meki is awake he jacks into it and Gana
## reroutes the backup cell around the cracked main cell (the reroute
## puzzle), which brings the ship's power back.

var _puzzle: Control


func get_prompt() -> String:
	var gs := Game.state()
	if gs.meki_online and not gs.power_restored:
		return "Reroute power"
	return "Power panel"


func interact(_player: Node) -> void:
	var gs := Game.state()
	if not gs.meki_online:
		hud().think(["Main cell's cracked. The backup's fine, but I can't reach the routing without the ship's brain.", "And the ship's brain is lying on my workbench."])
		return
	if gs.power_restored:
		hud().think(["Backup cell holding at forty-one percent. Not pretty, but she's breathing."])
		return
	var meki: Node = get_tree().get_first_node_in_group("meki")
	if meki:
		meki.hold_at(global_position + global_transform.basis.z * 0.35 + Vector3(0.45, 0.1, 0), global_position)
	if not _puzzle:
		_puzzle = (load("res://ui/reroute_puzzle.gd") as GDScript).new()
		hud().add_overlay(_puzzle)
		_puzzle.solved.connect(_on_solved)
		_puzzle.closed.connect(_on_closed)
	_puzzle.open()


func _on_closed() -> void:
	var meki: Node = get_tree().get_first_node_in_group("meki")
	if meki:
		meki.release()


func _on_solved() -> void:
	Game.state().power_restored = true
	await get_tree().create_timer(0.6).timeout
	await hud().think([
		["MEKI", "Route's holding. Lights, life support, galley... and the cockpit."],
		"So she'll listen now.",
		["MEKI", "Go try the switches. I'll keep an eye on this."],
	])
	_on_closed()
