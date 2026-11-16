extends "res://ui/thought_box.gd"

## The thought box (ui/thought_box.gd: same panel, fonts and colours) for
## cinematics: one line at a time, in the lower letterbox band, centred,
## and only ever advanced by the player.
##
## - Text types out at READ_SPEED characters a second.
## - A press (interact / ui_accept / left click; a fresh press, never a
##   held key's repeat) while it types completes the line.
## - Once complete the line can't be dismissed for its `hold` seconds.
## - Nothing dismisses itself.
##
## Await show_line(); it returns once the player dismisses the line.

signal dismissed

const READ_SPEED := 30.0
const BOX_W := 680.0

var _min_hold := 0.0
var _waiting := false


func _ready() -> void:
	super()
	# Centred along the bottom, in the letterbox band, inside safe margins.
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.offset_left = -BOX_W / 2.0
	_box.offset_right = BOX_W / 2.0
	_box.offset_top = -112
	_box.offset_bottom = -22
	_line.size = Vector2(BOX_W - 36, 56)


## Show one line; `hold` = the least time it stays once fully shown.
func show_line(who: String, text: String, colour: Color, hold := 0.9) -> void:
	_who.text = who
	_who.add_theme_color_override("font_color", colour)
	_line.text = text
	_line.visible_characters = 0
	_box.modulate.a = 0.0
	_box.show()
	create_tween().tween_property(_box, "modulate:a", 1.0, 0.25)
	_typing = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_line, "visible_characters", text.length(), text.length() / READ_SPEED)
	_tween.tween_callback(_shown)
	_min_hold = hold
	_waiting = true
	await dismissed


func _shown() -> void:
	_typing = false
	_hold = _min_hold


func _process(delta: float) -> void:
	if not _box.visible:
		return
	if _typing:
		if Engine.get_process_frames() % 4 == 0 and _line.visible_characters < _line.text.length():
			_blip.pitch_scale = randf_range(0.9, 1.15)
			_blip.play()
		return
	_hold = maxf(_hold - delta, 0.0)


func _input(event: InputEvent) -> void:
	if not _box.visible or not _waiting:
		return
	var press: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (not event.is_echo() and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")))
	if not press:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_tween.kill()
		_line.visible_characters = -1
		_shown()
	elif _hold <= 0.0:
		_waiting = false
		var tw := create_tween()
		tw.tween_property(_box, "modulate:a", 0.0, 0.25)
		tw.tween_callback(_box.hide)
		dismissed.emit()
