extends Interactable

## The pilot's chair. Sitting gives a first-person view out of the canopy
## with three choices: the flight panel (switches and windshield HUD), the
## Kestrel drive (ship computer) or standing up.

@export var panel_path: NodePath
@export var computer_path: NodePath

var _panel_view := false
var _eye := Vector3.ZERO
var _target := Vector3.ZERO
var _player: Node


func _enter_tree() -> void:
	super()
	add_to_group("pilot_seat")


func get_prompt() -> String:
	return "Sit in the pilot seat"


func can_interact(player: Node) -> bool:
	return player.has_method("sit")


func interact(player: Node) -> void:
	player.sit(self)


func _panel() -> Node:
	return get_node_or_null(panel_path)


func _seat_eye() -> Vector3:
	return global_position + Vector3(0.0, 1.15, 0.05)


func _seat_target() -> Vector3:
	return global_position + Vector3(0.2, 1.35, -1.6)


func eye_position() -> Vector3:
	return _eye if _eye != Vector3.ZERO else _seat_eye()


func look_target() -> Vector3:
	return _target if _target != Vector3.ZERO else _seat_target()


func on_sit(player: Node) -> void:
	_player = player
	_panel_view = false
	_eye = _seat_eye()
	_target = _seat_target()


func on_stand(_player_node: Node) -> void:
	if _panel_view:
		_panel().set_active(false)
	_panel_view = false
	_eye = Vector3.ZERO
	_target = Vector3.ZERO


## The thoughts that open the game, once, sat here after the intro.
func opening() -> void:
	await get_tree().create_timer(1.2).timeout
	hud().think(["Forty-three days in this chair.",
		"I keep expecting Hale to tell me I'm doing it wrong.",
		"...Let's see if she'll listen today."], "opening")


func seated_prompt(_p: Node) -> String:
	if _panel_view:
		return _panel().prompt()
	return "[E] Panel      [Q] Kestrel drive      [Space] Stand up"


func seated_input(player: Node, event: InputEvent) -> bool:
	if _panel_view:
		if _panel().handle_input(event):
			get_viewport().set_input_as_handled()
			return true
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("jump") or event.is_action_pressed("move_back"):
			_set_panel_view(player, false)
			get_viewport().set_input_as_handled()
			return true
		# No looking around while working the panel.
		return event is InputEventMouseMotion
	if event.is_action_pressed("interact"):
		_set_panel_view(player, true)
		return true
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		var pc := get_node_or_null(computer_path)
		if pc:
			pc.interact(player)
		return true
	return false


func _set_panel_view(player: Node, on: bool) -> void:
	var panel := _panel()
	_panel_view = on
	panel.set_active(on)
	var eye: Vector3 = panel.view_eye() if on else _seat_eye()
	var target: Vector3 = panel.view_target() if on else _seat_target()
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_eye", eye, 0.6)
	tw.tween_property(self, "_target", target, 0.6)
	tw.tween_method(func(_v: float) -> void: player.reaim(), 0.0, 1.0, 0.6)
	if on and not Game.state().power_restored:
		hud().think(["Main drive, nav, diagnostics. Moment of truth."], "panel_first")
