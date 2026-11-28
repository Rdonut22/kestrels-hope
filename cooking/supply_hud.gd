class_name SupplyHud
extends Control

## The galley cupboard's supplies (cooking/cupboard.gd), full screen in the
## cooking HUD's frosted glass (cooking/glass_panel.gd): a card for each
## supply, its model turning, with what's on the counter and what to do.
## What's taken goes into game_state.gd at_counter and shows in the cooking
## view's panel; meal packs come out of the cupboard's stores. The coffee
## sack and the water flask are taken whole; the flask is refilled here from
## the ship's tap. E, Esc or Done closes it.

const AMBER := Color(1.0, 0.62, 0.2)
const FONT := "res://ui/fonts/barlow-condensed-latin-500-normal.woff2"
const CARD := Vector2(300, 370)

var _font: Font
var _cards := {}     # id -> {"detail": Label, "actions": HBoxContainer, "model": Node3D}
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load(FONT) if ResourceLoader.exists(FONT) else null
	# The galley behind, blurred and darkened: the whole screen is glass.
	var back := GlassPanel.new()
	back.radius = 0.0
	back.set_param("blur", 4.5)
	back.set_param("tint", Color(0.04, 0.035, 0.03, 0.55))
	back.set_rim(Color(0, 0, 0, 0))
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 22)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	page.add_child(_title())
	var sub := _label("Take what you need to the cooking counter.", 22, Color(0.85, 0.82, 0.76))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 34)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(row)
	for id in ["coffee_grounds", "water", "meal_pack"]:
		row.add_child(_card(id))
	var done := _button("Done", true)
	done.pressed.connect(close)
	var done_row := HBoxContainer.new()
	done_row.alignment = BoxContainer.ALIGNMENT_CENTER
	done_row.add_child(done)
	page.add_child(done_row)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.state().pantry_changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	for id in _cards:
		var m: Node3D = _cards[id]["model"]
		m.rotation.y += delta * 0.45
		m.position.y = sin(_t * 1.4 + id.length()) * 0.006


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if Game.state().pantry_changed.is_connected(_refresh):
		Game.state().pantry_changed.disconnect(_refresh)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()


# ------------------------------------------------------------ building

func _title() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := _label("GALLEY CUPBOARD", 40, Color(0.97, 0.95, 0.9))
	if _font:
		var fv := FontVariation.new()
		fv.base_font = _font
		fv.spacing_glyph = 9
		t.add_theme_font_override("font", fv)
	row.add_child(t)
	row.add_child(_label("//", 40, AMBER))
	return row


func _card(id: String) -> Control:
	var card := GlassPanel.new()
	card.radius = 22.0
	card.padding = 20.0
	card.custom_minimum_size = CARD
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	# The model, turning in its own little window.
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(CARD.x - 40, 170)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	svc.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 28
	cam.position = Vector3(0, 0.13, 0.62)
	cam.rotation.x = -0.12
	vp.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.7, 0.6, 0)
	key.light_energy = 0.9
	vp.add_child(key)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.85, 0.7)
	e.ambient_light_energy = 0.4
	env.environment = e
	vp.add_child(env)
	var model := CookHud.model_for(id)
	vp.add_child(model)
	var ing := Cookbook.ingredient(id)
	var name_l := _label(ing.display_name.to_upper() if ing else id, 26, Color(0.97, 0.95, 0.9))
	if _font:
		var fv := FontVariation.new()
		fv.base_font = _font
		fv.spacing_glyph = 3
		name_l.add_theme_font_override("font", fv)
	box.add_child(name_l)
	var detail := _label("", 19, Color(0.8, 0.77, 0.7))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(CARD.x - 40, 52)
	box.add_child(detail)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	_cards[id] = {"detail": detail, "actions": actions, "model": model}
	return card


# ------------------------------------------------------------ state

func _refresh() -> void:
	var gs := Game.state()
	# Coffee: the sack, taken or put back.
	var has_coffee: bool = gs.counter_amount("coffee_grounds") > 0.0
	_set_card("coffee_grounds", "On the counter." if has_coffee else "A sack of ship's ration coffee.",
		[["Put back", func() -> void: gs.set_counter_amount("coffee_grounds", 0.0)]] if has_coffee
		else [["Take", func() -> void: gs.set_counter_amount("coffee_grounds", 1.0)]])
	# Water: the flask; refilled from the tap.
	var flask: bool = gs.at_counter.has("water")
	var level: float = gs.counter_amount("water")
	CookProps.set_flask(_cards["water"]["model"], level if flask else 1.0)
	var how := "full" if level >= 0.99 else ("empty" if level <= 0.001 else ("running low" if level <= 0.25 else "partly full"))
	var water_actions := []
	if not flask:
		water_actions.append(["Take", func() -> void: gs.set_counter_amount("water", 1.0)])
	elif level < 0.99:
		water_actions.append(["Refill", func() -> void: gs.set_counter_amount("water", 1.0)])
	_set_card("water", ("On the counter, %s." % how) if flask else "Filled from the ship's tap.", water_actions)
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
	_set_card("meal_pack", "%d in the cupboard, %d on the counter." % [stock, here], meal_actions)


func _set_card(id: String, detail: String, actions: Array) -> void:
	var c: Dictionary = _cards[id]
	(c["detail"] as Label).text = detail
	var row: HBoxContainer = c["actions"]
	for b in row.get_children():
		b.queue_free()
	for a: Array in actions:
		var b := _button(a[0], false)
		b.pressed.connect(a[1])
		row.add_child(b)


func _label(t: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font:
		l.add_theme_font_override("font", _font)
	return l


## A glass-look button: dark, thin light border, amber when hovered.
func _button(t: String, wide: bool) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(200 if wide else 120, 46)
	if _font:
		b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 20)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.06) if state == "normal" else Color(1.0, 0.62, 0.2, 0.14)
		sb.border_color = Color(1, 1, 1, 0.3) if state == "normal" else AMBER
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(8)
		if state != "normal":
			sb.shadow_color = Color(AMBER, 0.3)
			sb.shadow_size = 6
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.6))
	return b
