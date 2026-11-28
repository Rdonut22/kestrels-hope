class_name SupplyHud
extends Control

## The galley cupboard's supplies (cooking/cupboard.gd): choose what to take
## to the cooking counter. What's taken goes into game_state.gd at_counter
## and shows in the cooking view's ingredient panel; meal packs come out of
## the cupboard's stores. The coffee sack and the water flask are taken
## whole; the flask is refilled here from the ship's tap.

const AMBER := Color(1.0, 0.62, 0.2)
const FONT := "res://ui/fonts/barlow-condensed-latin-600-normal.woff2"

var _rows: VBoxContainer
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load(FONT) if ResourceLoader.exists(FONT) else null
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.055, 0.05, 0.92)
	sb.border_color = Color(AMBER, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(460, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(_label("GALLEY CUPBOARD", 26, AMBER))
	box.add_child(_label("Take what you need to the cooking counter.", 17, Color(0.8, 0.77, 0.7)))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	box.add_child(_rows)
	var done := _button("Done")
	done.pressed.connect(close)
	box.add_child(done)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.state().pantry_changed.connect(_refresh)
	_refresh()
	# Keep it centred whatever the window.
	panel.resized.connect(func() -> void: panel.position = (size - panel.size) * 0.5)
	resized.connect(func() -> void: panel.position = (size - panel.size) * 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if Game.state().pantry_changed.is_connected(_refresh):
		Game.state().pantry_changed.disconnect(_refresh)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


func _refresh() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var gs := Game.state()
	# Coffee: the sack, taken or put back.
	var has_coffee: bool = gs.counter_amount("coffee_grounds") > 0.0
	_row("Coffee grounds", "On the counter" if has_coffee else "A sack of ship's ration coffee",
		[["Put back", func() -> void: gs.set_counter_amount("coffee_grounds", 0.0)]] if has_coffee
		else [["Take", func() -> void: gs.set_counter_amount("coffee_grounds", 1.0)]])
	# Water: the flask; refilled from the tap.
	var flask: bool = gs.at_counter.has("water")
	var level: float = gs.counter_amount("water")
	var how := "full" if level >= 0.99 else ("empty" if level <= 0.001 else ("running low" if level <= 0.25 else "partly full"))
	var water_actions := []
	if not flask:
		water_actions.append(["Take", func() -> void: gs.set_counter_amount("water", 1.0)])
	elif level < 0.99:
		water_actions.append(["Refill", func() -> void: gs.set_counter_amount("water", 1.0)])
	_row("Water flask", ("On the counter, %s" % how) if flask else "Filled from the ship's tap", water_actions)
	# Meal packs, one at a time.
	var stock := int(gs.stores.get("meal_pack", 0))
	var here := int(gs.counter_amount("meal_pack"))
	var meal_actions := []
	if stock > 0:
		meal_actions.append(["Take one", func() -> void:
			gs.set_store_amount("meal_pack", stock - 1)
			gs.set_counter_amount("meal_pack", here + 1)])
	if here > 0:
		meal_actions.append(["Put one back", func() -> void:
			gs.set_store_amount("meal_pack", stock + 1)
			gs.set_counter_amount("meal_pack", here - 1)])
	_row("Meal packs", "%d in the cupboard, %d on the counter" % [stock, here], meal_actions)


func _row(title: String, detail: String, actions: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(_label(title, 21, Color(0.95, 0.92, 0.85)))
	text.add_child(_label(detail, 16, Color(0.7, 0.67, 0.6)))
	row.add_child(text)
	for a: Array in actions:
		var b := _button(a[0])
		b.pressed.connect(a[1])
		row.add_child(b)
	_rows.add_child(row)


func _label(t: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	if _font:
		l.add_theme_font_override("font", _font)
	return l


func _button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(96, 36)
	if _font:
		b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.1, 0.08) if state == "normal" else Color(0.22, 0.15, 0.08)
		sb.border_color = Color(AMBER, 0.4 if state == "normal" else 0.9)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(6)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	b.add_theme_color_override("font_hover_color", AMBER)
	return b
