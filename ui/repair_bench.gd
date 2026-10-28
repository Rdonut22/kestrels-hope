extends Control

## Repair screen over the bench view: a checklist of steps on the left, the
## inventory on the right (A/D to browse, E to try the selected item) and
## Gana thinking out loud along the bottom. The workbench decides whether a
## try was right and calls accept() or reject().

signal tried(id: String)
signal closed

const PANEL := Color(0.06, 0.07, 0.08, 0.86)
const EDGE := Color(0.85, 0.66, 0.36)
const TEXT := Color(0.93, 0.89, 0.8)

var _steps: Array[Label] = []
var _index := 0
var _busy := false
var _title: Label
var _icon: Control
var _name: Label
var _desc: Label
var _count: Label
var _chips: HBoxContainer
var _line: Label
var _right: Panel
var _sfx: AudioStreamPlayer
var _font: Font = load("res://ui/fonts/Dena.otf")


## Draws a little picture of an item from its "shape".
class ItemIcon extends Control:
	var id := ""

	func _draw() -> void:
		var info: Dictionary = Game.state().item(id)
		if info.is_empty():
			return
		var c: Color = info.color
		var s := size
		var m := s / 2.0
		var r := minf(s.x, s.y) * 0.32
		match info.shape:
			"round":
				draw_rect(Rect2(m.x - r * 0.6, m.y - r, r * 1.2, r * 2.0), c)
				draw_circle(Vector2(m.x, m.y - r), r * 0.6, c.lightened(0.25))
				draw_rect(Rect2(m.x - r * 0.6, m.y - r * 0.2, r * 0.25, r * 1.1), Color(0.95, 0.95, 0.9))
				draw_line(Vector2(m.x - r * 0.3, m.y + r), Vector2(m.x - r * 0.3, m.y + r * 1.5), Color.SILVER, 3)
				draw_line(Vector2(m.x + r * 0.3, m.y + r), Vector2(m.x + r * 0.3, m.y + r * 1.5), Color.SILVER, 3)
			"square":
				draw_rect(Rect2(m.x - r, m.y - r * 0.8, r * 2.0, r * 1.6), c)
				draw_rect(Rect2(m.x - r, m.y - r * 0.8, r * 2.0, r * 0.35), c.darkened(0.3))
				for k in 3:
					draw_line(Vector2(m.x - r * 0.6 + k * r * 0.6, m.y + r * 0.8), Vector2(m.x - r * 0.6 + k * r * 0.6, m.y + r * 1.3), Color.SILVER, 3)
			"fuse":
				draw_rect(Rect2(m.x - r * 1.2, m.y - r * 0.35, r * 2.4, r * 0.7), c, false, 3)
				draw_rect(Rect2(m.x - r * 1.5, m.y - r * 0.4, r * 0.4, r * 0.8), Color.SILVER)
				draw_rect(Rect2(m.x + r * 1.1, m.y - r * 0.4, r * 0.4, r * 0.8), Color.SILVER)
				draw_line(Vector2(m.x - r * 1.1, m.y), Vector2(m.x + r * 1.1, m.y), Color(0.6, 0.6, 0.6), 2)
			"coil":
				for k in 5:
					draw_arc(Vector2(m.x - r + k * r * 0.5, m.y), r * 0.55, 0, TAU, 24, c, 4)
			"tape":
				draw_arc(m, r, 0, TAU, 32, c, r * 0.55)
				draw_arc(m, r * 0.45, 0, TAU, 32, c.darkened(0.4), 3)
			"wrench":
				draw_line(m + Vector2(-r, r), m + Vector2(r * 0.6, -r * 0.6), c, r * 0.45)
				draw_arc(m + Vector2(r * 0.8, -r * 0.8), r * 0.45, -2.4, 2.0, 16, c, r * 0.3)
			"torch":
				draw_rect(Rect2(m.x - r * 1.2, m.y - r * 0.3, r * 1.5, r * 0.6), Color(0.35, 0.36, 0.38))
				draw_rect(Rect2(m.x + r * 0.3, m.y - r * 0.15, r * 0.6, r * 0.3), Color.SILVER)
				draw_circle(m + Vector2(r * 1.15, 0), r * 0.22, c)
				draw_circle(m + Vector2(r * 1.15, 0), r * 0.1, Color(1, 0.95, 0.7))
				draw_rect(Rect2(m.x - r * 1.0, m.y - r * 0.3, r * 0.3, r * 0.6), c.darkened(0.2))


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	hide()
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -4.0
	add_child(_sfx)

	var left := _panel(Vector2(0, 0), Rect2(24, 24, 340, 150))
	_title = _label(left, "", 22, EDGE, Vector2(18, 14), 300)
	_title.add_theme_font_override("font", _font)

	_right = _panel(Vector2(1, 0), Rect2(-384, 24, 360, 0))
	_right.anchor_bottom = 1.0
	_right.offset_bottom = -24
	var head := _label(_right, "INVENTORY", 22, EDGE, Vector2(20, 16), 320)
	head.add_theme_font_override("font", _font)
	_icon = ItemIcon.new()
	_icon.position = Vector2(100, 60)
	_icon.size = Vector2(160, 150)
	_right.add_child(_icon)
	_name = _label(_right, "", 24, TEXT, Vector2(20, 220), 320)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc = _label(_right, "", 16, TEXT.darkened(0.25), Vector2(28, 258), 304)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.size.y = 60
	_count = _label(_right, "", 18, EDGE, Vector2(20, 330), 320)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chips = HBoxContainer.new()
	_chips.position = Vector2(20, 370)
	_chips.size = Vector2(320, 44)
	_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_right.add_child(_chips)
	var keys := _label(_right, "A / D  browse     E  try it     Esc  step away", 15, TEXT.darkened(0.35), Vector2(20, 430), 320)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var bottom := _panel(Vector2(0, 1), Rect2(24, -130, 0, 106))
	bottom.anchor_right = 1.0
	bottom.offset_right = -408
	var who := _label(bottom, "GANA", 18, EDGE, Vector2(18, 12), 200)
	who.add_theme_font_override("font", _font)
	_line = _label(bottom, "", 19, TEXT, Vector2(18, 40), 0)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD
	_line.anchor_right = 1.0
	_line.offset_right = -18
	_line.size.y = 60
	Game.state().inventory_changed.connect(_refresh)


func open(recipe: Dictionary, step: int) -> void:
	_title.text = recipe.title
	for l in _steps:
		l.queue_free()
	_steps.clear()
	var left: Control = _title.get_parent()
	for i in recipe.steps.size():
		var l := _label(left, "", 18, TEXT, Vector2(18, 54 + i * 34), 310)
		l.set_meta("label", recipe.steps[i].label)
		_steps.append(l)
		_mark(i, i < step)
	_index = clampi(_index, 0, maxi(0, Game.state().items.size() - 1))
	_busy = false
	_refresh()
	show()


func say(text: String) -> void:
	_line.text = text
	_line.visible_ratio = 0.0
	var tw := create_tween()
	tw.tween_property(_line, "visible_ratio", 1.0, clampf(text.length() * 0.018, 0.3, 2.0))


func reject(text: String) -> void:
	_play("res://audio/sfx/thunk.ogg")
	say(text)
	var tw := create_tween()
	var x := _right.position.x
	for k in 4:
		tw.tween_property(_right, "position:x", x + (8.0 if k % 2 == 0 else -8.0), 0.04)
	tw.tween_property(_right, "position:x", x, 0.04)


func accept(step: int, text: String) -> void:
	_mark(step, true)
	say(text)
	_busy = true
	await get_tree().create_timer(1.6).timeout
	_busy = false


func close(signal_closed := true) -> void:
	hide()
	if signal_closed:
		closed.emit()


func _mark(i: int, done: bool) -> void:
	_steps[i].text = ("(x)  " if done else "( )  ") + String(_steps[i].get_meta("label"))
	_steps[i].modulate = Color(0.6, 1.0, 0.6) if done else Color.WHITE


func _refresh() -> void:
	var items: Array[String] = Game.state().items
	_index = clampi(_index, 0, maxi(0, items.size() - 1))
	for c in _chips.get_children():
		c.queue_free()
	if items.is_empty():
		_icon.id = ""
		_name.text = "Empty"
		_desc.text = "Nothing in your pockets yet."
		_count.text = ""
	else:
		var id: String = items[_index]
		var info: Dictionary = Game.state().item(id)
		_icon.id = id
		_name.text = info.name
		_desc.text = info.desc + ("   (tool)" if info.get("tool", false) else "")
		_count.text = "<   %d / %d   >" % [_index + 1, items.size()]
		for i in items.size():
			var chip := ItemIcon.new()
			chip.id = items[i]
			chip.custom_minimum_size = Vector2(36, 36)
			chip.modulate = Color.WHITE if i == _index else Color(1, 1, 1, 0.35)
			_chips.add_child(chip)
	_icon.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var items: Array[String] = Game.state().items
	if event.is_action_pressed("ui_cancel"):
		close()
	elif _busy:
		pass
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_index = wrapi(_index - 1, 0, maxi(1, items.size()))
		_refresh()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_index = wrapi(_index + 1, 0, maxi(1, items.size()))
		_refresh()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if items.is_empty():
			say("Got nothing to work with. That parts barrel might have something useful.")
		else:
			tried.emit(items[_index])
	else:
		return
	get_viewport().set_input_as_handled()


func _play(path: String) -> void:
	_sfx.stream = load(path)
	_sfx.play()


# A dark panel anchored at one corner/edge of the screen.
func _panel(anchor: Vector2, rect: Rect2) -> Panel:
	var p := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL
	box.border_color = EDGE.darkened(0.3)
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	p.add_theme_stylebox_override("panel", box)
	p.anchor_left = anchor.x
	p.anchor_right = anchor.x
	p.anchor_top = anchor.y
	p.anchor_bottom = anchor.y
	p.offset_left = rect.position.x
	p.offset_top = rect.position.y
	p.offset_right = rect.end.x
	p.offset_bottom = rect.end.y
	p.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(p)
	return p


func _label(parent: Node, text: String, size: int, color: Color, pos: Vector2, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.position = pos
	if width > 0:
		l.size.x = width
	parent.add_child(l)
	return l
