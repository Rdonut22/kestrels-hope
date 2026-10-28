extends Interactable

## Engineering workbench. While Meki lies dead on it, E opens the repair
## screen: the camera drops to a view over the bench, the inventory comes
## up on the right, and Gana's muttering hints at what each step needs.
## Leaving keeps your progress.

## Meki's repair: each step needs one item; wrong ones get a line back.
const MEKI_REPAIR := {
	"title": "MEKI  //  REPAIR",
	"intro": "Meki's dead. I can smell the burnt capacitor from here, right by his core. I'll need something round to replace it... then the shell has to be sealed back up.",
	"empty": "Got nothing to work with. That parts barrel by the bench might have something useful.",
	"steps": [
		{"label": "Replace the blown capacitor", "need": "cap_round", "consume": true, "fx": "click",
			"done": "Round cap, right size... *click*. Seated. Now to close him up.",
			"hints": ["The socket's round. Something round, thumb-sized.", "Round hole, round capacitor. Come on, Gana."],
			"wrong": {
				"cap_square": "Square peg, round hole. Literally.",
				"fuse": "A fuse? Close, but he needs a capacitor.",
				"coil": "Copper coil. Nice, but that's not what blew.",
				"tape": "Taping over a dead cap won't make it any less dead.",
				"wrench": "Nothing to tighten. The cap's blown; it needs replacing.",
				"welder": "Seal him up with a dead cap inside? Replace it first."}},
		{"label": "Seal the shell", "need": "welder", "fx": "weld",
			"done": "Steady... steady... *hiss*. Clean bead. That'll hold.",
			"hints": ["He'll be flying around. This needs a real seal, something hot.", "Weld it. The torch is what I need."],
			"wrong": {
				"wrench": "It's not loose, it's open. Needs a proper seal.",
				"tape": "Tape won't hold once he's flying around.",
				"cap_square": "He's got his capacitor. Now close him up.",
				"fuse": "Not the time for spare parts. Seal it.",
				"coil": "Not the time for spare parts. Seal it."}},
	],
	"finish": "That's everything. Come on, buddy...",
}

## Shown once Meki is fixed (or on the crashed ship).
@export var message := "Tools, scraps and a half-built nav sensor. Meki's old cradle."

var _step := 0
var _misses := 0
var _screen: Control
var _cam: Camera3D
var _prev_cam: Camera3D


func _meki() -> Node:
	return get_tree().get_first_node_in_group("meki")


func _repairing() -> bool:
	var meki := _meki()
	return meki != null and not Game.state().meki_online and meki.get("dead")


func get_prompt() -> String:
	return "Repair Meki" if _repairing() else "Workbench"


func interact(_player: Node) -> void:
	if not _repairing():
		hud().show_message(message)
		return
	_open()


func _open() -> void:
	if not _screen:
		_screen = (load("res://ui/repair_bench.gd") as GDScript).new()
		hud().add_overlay(_screen)
		_screen.tried.connect(_on_tried)
		_screen.closed.connect(_close_view)
	hud().message_label.modulate.a = 0.0
	hud().set_prompt("")
	_prev_cam = get_viewport().get_camera_3d()
	if not _cam:
		_cam = Camera3D.new()
		_cam.fov = 55
		get_tree().current_scene.add_child(_cam)
	# Over the bench, Meki on the left of the screen (inventory on the right).
	var meki: Node3D = _meki()
	_cam.global_position = meki.global_position + Vector3(1.05, 0.62, -0.32)
	_cam.look_at(meki.global_position + Vector3(0, 0.02, -0.3))
	_cam.make_current()
	_screen.open(MEKI_REPAIR, _step)
	var line: String = MEKI_REPAIR.intro if Game.state().items.size() > 0 else MEKI_REPAIR.empty
	_screen.say(line if _step == 0 else "Where was I... right. " + MEKI_REPAIR.steps[_step].label.to_lower() + ".")


func _close_view() -> void:
	if _prev_cam:
		_prev_cam.make_current()


func _on_tried(id: String) -> void:
	var step: Dictionary = MEKI_REPAIR.steps[_step]
	if id != step.need:
		_misses += 1
		var line: String = step.wrong.get(id, "That's not it.")
		if _misses >= 2:
			line += "  " + step.hints[mini(_misses - 2, step.hints.size() - 1)]
		_screen.reject(line)
		return
	_misses = 0
	if step.get("consume", false):
		Game.state().remove_item(id)
	_screen.accept(_step, step.done)
	_meki().call("repair_fx", step.fx)
	_step += 1
	if _step >= MEKI_REPAIR.steps.size():
		_finish()


func _finish() -> void:
	await get_tree().create_timer(2.2).timeout
	_screen.say(MEKI_REPAIR.finish)
	await get_tree().create_timer(1.4).timeout
	_screen.close(false)
	await _meki().boot()
	_close_view()
