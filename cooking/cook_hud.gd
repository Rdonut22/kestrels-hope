class_name CookHud
extends CanvasLayer

## The cooking view's HUD (cooking/cook_session.gd): a slim panel down the
## left with what Gana brought from the cupboard, each in its own slot
## with its model turning slowly in it, and the prompt shown by a drop
## target ("Release to add coffee grounds"). No recipes, checklists, timers
## or buttons: the window stays clear.
##
## Slots: coffee grounds (no indicator: there's always enough), water (its
## level is the water in the flask; a quiet note when low or empty), meal
## packs (how many).

const AMBER := Color(1.0, 0.62, 0.2)
const FONT := "res://ui/fonts/barlow-condensed-latin-600-normal.woff2"
const ORDER := ["coffee_grounds", "water", "meal_pack"]
const SLOT := Vector2(188, 132)

var _font: Font
var _panel: PanelContainer
var _slots := {}       # ingredient id -> {"box": PanelContainer, "model": Node3D, "count": Label, "note": Label}
var _prompt: PanelContainer
var _prompt_label: Label
var _hint: Label
var _empty: Label
var _hover := ""
var _t := 0.0


func _ready() -> void:
	layer = 60
	_font = load(FONT) if ResourceLoader.exists(FONT) else null
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.045, 0.04, 0.78)
	sb.border_color = Color(AMBER, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.position = Vector2(22, 22)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	box.add_child(_label("COOKING", 24, AMBER))
	for id in ORDER:
		_slots[id] = _make_slot(box, id)
	_empty = _label("Nothing brought from\nthe cupboard yet.", 16, Color(0.75, 0.72, 0.66))
	box.add_child(_empty)
	# The prompt by a drop target.
	_prompt = PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.06, 0.05, 0.04, 0.85)
	psb.border_color = AMBER
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(10)
	psb.content_margin_left = 14
	psb.content_margin_right = 14
	psb.content_margin_top = 6
	psb.content_margin_bottom = 6
	_prompt.add_theme_stylebox_override("panel", psb)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label = _label("", 19, Color(1.0, 0.95, 0.88))
	_prompt.add_child(_prompt_label)
	_prompt.visible = false
	add_child(_prompt)
	_hint = _label("[E] Step back", 17, Color(0.85, 0.82, 0.75, 0.75))
	add_child(_hint)
	Game.state().pantry_changed.connect(refresh)
	refresh()


func _exit_tree() -> void:
	if Game.state().pantry_changed.is_connected(refresh):
		Game.state().pantry_changed.disconnect(refresh)


func _process(delta: float) -> void:
	_t += delta
	var vp := get_viewport().get_visible_rect().size
	_hint.position = Vector2(vp.x * 0.5 - _hint.size.x * 0.5, vp.y - 46)
	for id in _slots:
		var m: Node3D = _slots[id]["model"]
		if m:
			# Each floats, turning slowly; the one under the cursor faster.
			m.rotation.y += delta * (1.2 if id == _hover else 0.35)
			m.position.y = sin(_t * 1.6 + float(ORDER.find(id))) * 0.006


func _make_slot(parent: Control, id: String) -> Dictionary:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = SLOT
	box.add_theme_stylebox_override("panel", _slot_style(false))
	parent.add_child(box)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(SLOT)
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	svc.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 30
	cam.position = Vector3(0, 0.12, 0.62)
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
	var model := model_for(id)
	vp.add_child(model)
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(overlay)
	var count := _label("", 22, Color(1.0, 0.95, 0.88))
	count.position = Vector2(SLOT.x - 56, SLOT.y - 40)
	overlay.add_child(count)
	var note := _label("", 15, AMBER)
	note.position = Vector2(10, SLOT.y - 30)
	overlay.add_child(note)
	return {"box": box, "model": model, "count": count, "note": note}


## A model of an ingredient, as shown in its slot and held under the cursor.
static func model_for(id: String) -> Node3D:
	match id:
		"coffee_grounds":
			return CookProps.coffee_sack()
		"water":
			return CookProps.water_flask(Game.state().counter_amount("water"))
		"meal_pack":
			return CookProps.meal_pack()
	return Node3D.new()


func _slot_style(lit: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.085, 0.07, 0.85)
	sb.border_color = AMBER if lit else Color(1, 1, 1, 0.12)
	sb.set_border_width_all(2 if lit else 1)
	sb.set_corner_radius_all(14)
	if lit:
		sb.shadow_color = Color(AMBER, 0.35)
		sb.shadow_size = 8
	return sb


func refresh() -> void:
	var gs := Game.state()
	var any := false
	for id in ORDER:
		var s: Dictionary = _slots[id]
		var box: PanelContainer = s["box"]
		var have: bool = gs.at_counter.has(id)
		box.visible = have
		any = any or have
		var count: Label = s["count"]
		var note: Label = s["note"]
		count.text = ""
		note.text = ""
		var ing := Cookbook.ingredient(id)
		if ing and have:
			match ing.supply:
				"count":
					count.text = "×%d" % int(gs.counter_amount(id))
				"volume":
					var level: float = gs.counter_amount(id)
					CookProps.set_flask(s["model"], level)
					if level <= 0.001:
						note.text = "Empty: refill at the cupboard"
					elif level <= ing.low_at:
						note.text = "Running low"
	_empty.visible = not any


## Which ingredient's slot is under a screen point ("" if none, or empty).
func slot_at(p: Vector2) -> String:
	for id in ORDER:
		var box: PanelContainer = _slots[id]["box"]
		if box.visible and box.get_global_rect().has_point(p):
			return id
	return ""


## Usable now: there's some of it.
func slot_ready(id: String) -> bool:
	var ing := Cookbook.ingredient(id)
	if ing == null or not Game.state().at_counter.has(id):
		return false
	if ing.supply == "unlimited":
		return true
	if ing.supply == "volume":
		return Game.state().counter_amount(id) >= ing.use_amount - 0.001
	return Game.state().counter_amount(id) >= 1.0


func set_hover(id: String) -> void:
	if id == _hover:
		return
	if _hover != "" and _slots.has(_hover):
		(_slots[_hover]["box"] as PanelContainer).add_theme_stylebox_override("panel", _slot_style(false))
	_hover = id
	if id != "" and _slots.has(id):
		(_slots[id]["box"] as PanelContainer).add_theme_stylebox_override("panel", _slot_style(true))


## The prompt near a screen point; `strong` false shows it quieter (a hint
## for something not possible yet).
func show_prompt(text: String, at: Vector2, strong := true) -> void:
	if text == "":
		_prompt.visible = false
		return
	_prompt_label.text = text
	_prompt.modulate = Color(1, 1, 1, 1.0 if strong else 0.7)
	(_prompt.get_theme_stylebox("panel") as StyleBoxFlat).border_color = AMBER if strong else Color(1, 1, 1, 0.3)
	_prompt.reset_size()
	_prompt.position = at + Vector2(24, -_prompt.size.y - 18)
	_prompt.visible = true


func set_hint(text: String) -> void:
	_hint.text = text


func _label(t: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font:
		l.add_theme_font_override("font", _font)
	return l
