extends Control

## Gana thinking out loud (and Meki answering): short typed-out lines in a
## box at the bottom left. Never blocks the player; lines advance on their
## own, a click skips ahead. Queue more with say().

signal finished

const COLORS := {"GANA": Color(0.85, 0.66, 0.36), "MEKI": Color(0.45, 0.85, 1.0)}

var _queue: Array = []
var _who: Label
var _line: Label
var _box: Panel
var _blip: AudioStreamPlayer
var _tween: Tween
var _hold := 0.0
var _typing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_box = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.06, 0.78)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	_box.add_theme_stylebox_override("panel", sb)
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = 28
	_box.offset_right = 28 + 600
	_box.offset_top = -210
	_box.offset_bottom = -120
	_box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_box)
	_who = Label.new()
	_who.position = Vector2(18, 10)
	_who.add_theme_font_override("font", load("res://ui/fonts/Dena.otf"))
	_who.add_theme_font_size_override("font_size", 16)
	_box.add_child(_who)
	_line = Label.new()
	_line.position = Vector2(18, 34)
	_line.size = Vector2(564, 50)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD
	_line.add_theme_font_override("font", load("res://ui/fonts/LiberationSerif-Italic.ttf"))
	_line.add_theme_font_size_override("font_size", 20)
	_line.add_theme_color_override("font_color", Color(0.94, 0.9, 0.82))
	_box.add_child(_line)
	_blip = AudioStreamPlayer.new()
	_blip.stream = load("res://audio/type_blip.ogg")
	_blip.volume_db = -20.0
	add_child(_blip)
	_box.hide()


## Queue lines: each is a String (Gana) or [who, text]. `interrupt` drops
## whatever was queued and cuts in straight away.
func say(lines: Array, interrupt := false) -> void:
	if interrupt:
		_queue.clear()
		if _box.visible:
			for l in lines:
				_queue.append(l if l is Array else ["GANA", l])
			_next()
			return
	for l in lines:
		_queue.append(l if l is Array else ["GANA", l])
	if not _box.visible:
		_next()


func is_talking() -> bool:
	return _box.visible


func _next() -> void:
	if _queue.is_empty():
		_box.hide()
		finished.emit()
		return
	var l: Array = _queue.pop_front()
	var who: String = l[0]
	var text: String = l[1]
	_who.text = who
	_who.add_theme_color_override("font_color", COLORS.get(who, Color.WHITE))
	_line.text = text
	_line.visible_characters = 0
	_box.show()
	_typing = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_line, "visible_characters", text.length(), text.length() / 38.0)
	_tween.tween_callback(func() -> void: _typing = false)
	_hold = 1.6 + text.length() * 0.035


func _process(delta: float) -> void:
	if not _box.visible:
		return
	if _typing:
		if Engine.get_process_frames() % 4 == 0 and _line.visible_characters < _line.text.length():
			_blip.pitch_scale = randf_range(0.9, 1.15)
			_blip.play()
		return
	_hold -= delta
	if _hold <= 0.0:
		_next()


func _input(event: InputEvent) -> void:
	if not _box.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _typing:
			_tween.kill()
			_line.visible_characters = -1
			_typing = false
		else:
			_next()
