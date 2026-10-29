extends Control

## A close look at a photo: the picture fills the middle of the screen in
## its wooden frame, tilted a little as if held, over a dimmed background.
## E or Esc puts it down.

signal closed

var _frame: Panel
var _pic: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.01, 0.82)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	_frame = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.28, 0.16, 0.09)
	sb.border_color = Color(0.42, 0.26, 0.15)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 24
	_frame.add_theme_stylebox_override("panel", sb)
	add_child(_frame)
	_pic = TextureRect.new()
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_frame.add_child(_pic)
	var hint := Label.new()
	hint.text = "[E] put it down"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75, 0.7))
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -80
	hint.offset_right = 80
	hint.offset_top = -50
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)


func open(tex: Texture2D) -> void:
	_pic.texture = tex
	var vs := get_viewport_rect().size
	var aspect := tex.get_width() / float(tex.get_height())
	var h := vs.y * 0.72
	var w := h * aspect
	if w > vs.x * 0.7:
		w = vs.x * 0.7
		h = w / aspect
	var border := 22.0
	_frame.size = Vector2(w, h) + Vector2.ONE * border * 2.0
	_frame.position = (vs - _frame.size) / 2.0 - Vector2(0, 30)
	_frame.pivot_offset = _frame.size / 2.0
	_pic.position = Vector2.ONE * border
	_pic.size = Vector2(w, h)
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Lift it up into view.
	_frame.rotation = -0.12
	_frame.scale = Vector2.ONE * 0.85
	modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tw.tween_property(_frame, "rotation", -0.035, 0.35)
	tw.tween_property(_frame, "scale", Vector2.ONE, 0.35)
	tw.tween_property(self, "modulate:a", 1.0, 0.25)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		closed.emit()
