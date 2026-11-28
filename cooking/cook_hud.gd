class_name CookHud
extends CanvasLayer

## The cooking view's HUD (cooking/cook_session.gd), in frosted glass
## (cooking/glass_panel.gd): a panel at the left with a "COOKING //"
## header and a 2 x 2 grid of slots holding what Gana brought from the
## cupboard, each with its model turning slowly in it; and the prompt shown
## by a drop target ("Release to add coffee grounds"), a glass pill with a
## mouse icon. No recipes, checklists, timers or buttons: the window stays
## clear.
##
## Slots: coffee grounds (no indicator: there's always enough), water (its
## level is the water in the flask; a quiet note when low or empty), meal
## packs (how many, in the corner). A slot glows white under the cursor,
## amber while its ingredient is held, and is hatched when there's none
## left. Unused slots stay empty.

const AMBER := Color(1.0, 0.62, 0.2)
const RIM := Color(1.0, 1.0, 1.0, 0.2)
const RIM_HOVER := Color(1.0, 1.0, 1.0, 0.85)
const FONT := "res://ui/fonts/barlow-condensed-latin-500-normal.woff2"
const ORDER := ["coffee_grounds", "water", "meal_pack"]
const SLOTS := 4
const SLOT := Vector2(128, 128)

var _font: Font
var _panel: GlassPanel
var _grid: GridContainer
var _slots := {}       # ingredient id -> {"box": GlassPanel, "model": Node3D, "count": Label, "note": Label}
var _spare: Array[GlassPanel] = []
var _prompt: GlassPanel
var _prompt_label: Label
var _hint: Label
var _empty: Label
var _hover := ""
var _held := ""
var _t := 0.0


func _ready() -> void:
	layer = 60
	_font = load(FONT) if ResourceLoader.exists(FONT) else null
	_panel = GlassPanel.new()
	_panel.radius = 22.0
	_panel.padding = 18.0
	_panel.position = Vector2(30, 30)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	box.add_child(_header())
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.22)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_grid)
	for id in ORDER:
		_slots[id] = _make_slot(id)
	for i in SLOTS - ORDER.size():
		var spare := _glass_slot()
		_grid.add_child(spare)
		_spare.append(spare)
	_empty = _label("Nothing brought from the\ncupboard yet.", 17, Color(0.85, 0.82, 0.76))
	box.add_child(_empty)
	# The prompt by a drop target: a glass pill with a mouse icon.
	_prompt = GlassPanel.new()
	_prompt.radius = 20.0
	_prompt.padding = 10.0
	_prompt.visible = false
	add_child(_prompt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_child(row)
	var mouse := _MouseIcon.new()
	mouse.custom_minimum_size = Vector2(22, 30)
	row.add_child(mouse)
	_prompt_label = _label("", 21, Color(1.0, 0.97, 0.92))
	row.add_child(_prompt_label)
	_hint = _label("[E] Step back", 17, Color(0.9, 0.88, 0.82, 0.7))
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
	# On the left, centred top to bottom.
	_panel.position = Vector2(30, maxf(24.0, (vp.y - _panel.size.y) * 0.5))
	for id in _slots:
		var m: Node3D = _slots[id]["model"]
		if m:
			# Each floats, turning slowly; the one under the cursor faster.
			m.rotation.y += delta * (1.2 if id == _hover else 0.35)
			m.position.y = sin(_t * 1.6 + float(ORDER.find(id))) * 0.006


# ------------------------------------------------------------ building

## "COOKING //" with a pot icon, letter-spaced.
func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pot := _PotIcon.new()
	pot.custom_minimum_size = Vector2(34, 30)
	row.add_child(pot)
	var title := _label("COOKING", 28, Color(0.97, 0.95, 0.9))
	if _font:
		var fv := FontVariation.new()
		fv.base_font = _font
		fv.spacing_glyph = 7
		title.add_theme_font_override("font", fv)
	row.add_child(title)
	var slash := _label("//", 28, AMBER)
	row.add_child(slash)
	return row


func _glass_slot() -> GlassPanel:
	var g := GlassPanel.new()
	g.radius = 16.0
	g.padding = 0.0
	g.custom_minimum_size = SLOT
	g.set_rim(RIM)
	return g


func _make_slot(id: String) -> Dictionary:
	var box := _glass_slot()
	_grid.add_child(box)
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
	cam.position = Vector3(0, 0.125, 0.62)
	cam.rotation.x = -0.03
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
	var count := _label("", 34, Color(1.0, 0.98, 0.94))
	count.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	count.add_theme_constant_override("outline_size", 4)
	count.position = Vector2(SLOT.x - 34, SLOT.y - 48)
	overlay.add_child(count)
	var note := _label("", 15, AMBER)
	note.position = Vector2(10, SLOT.y - 26)
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


# ------------------------------------------------------------ state

func refresh() -> void:
	var gs := Game.state()
	var shown := 0
	for id in ORDER:
		var s: Dictionary = _slots[id]
		var box: GlassPanel = s["box"]
		var have: bool = gs.at_counter.has(id)
		box.visible = have
		if have:
			shown += 1
		var count: Label = s["count"]
		var note: Label = s["note"]
		count.text = ""
		note.text = ""
		var ing := Cookbook.ingredient(id)
		if ing and have:
			match ing.supply:
				"count":
					count.text = str(int(gs.counter_amount(id)))
				"volume":
					var level: float = gs.counter_amount(id)
					CookProps.set_flask(s["model"], level)
					if level <= 0.001:
						note.text = "Empty"
					elif level <= ing.low_at:
						note.text = "Running low"
		_style(id)
	# Fill the grid's last row with empty slots; none at all if nothing's here.
	for i in _spare.size():
		_spare[i].visible = shown > 0 and shown + i < SLOTS and (shown + i) % 2 == 1
	_empty.visible = shown == 0
	_grid.visible = shown > 0


func _style(id: String) -> void:
	if not _slots.has(id):
		return
	var box: GlassPanel = _slots[id]["box"]
	var usable := slot_ready(id)
	box.set_hatch(not usable)
	if id == _held:
		box.set_glow(Color(AMBER, 0.9))
		box.set_rim(Color(AMBER, 0.95))
	elif id == _hover:
		box.set_glow(Color(1, 1, 1, 0.25))
		box.set_rim(RIM_HOVER)
	else:
		box.set_glow(Color(0, 0, 0, 0))
		box.set_rim(RIM)


## Which ingredient's slot is under a screen point ("" if none, or empty).
func slot_at(p: Vector2) -> String:
	for id in ORDER:
		var box: Control = _slots[id]["box"]
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
	var was := _hover
	_hover = id
	_style(was)
	_style(id)


## The ingredient being held (its slot glows amber), or "".
func set_held(id: String) -> void:
	var was := _held
	_held = id
	_style(was)
	_style(id)


## The prompt near a screen point; `strong` false shows it quieter (a hint
## for something not possible yet).
func show_prompt(text: String, at: Vector2, strong := true) -> void:
	if text == "":
		_prompt.visible = false
		return
	_prompt_label.text = text
	_prompt.set_rim(Color(AMBER, 0.95) if strong else Color(1, 1, 1, 0.3))
	_prompt.set_glow(Color(AMBER, 0.45) if strong else Color(0, 0, 0, 0))
	_prompt.modulate = Color(1, 1, 1, 1.0 if strong else 0.8)
	_prompt.reset_size()
	# Beside the target, kept on screen (flipped to its left near the edge).
	var vp := get_viewport().get_visible_rect().size
	var p := at + Vector2(28, -_prompt.size.y - 22)
	if p.x + _prompt.size.x > vp.x - 16:
		p.x = at.x - 28 - _prompt.size.x
	_prompt.position = Vector2(clampf(p.x, 16, vp.x - _prompt.size.x - 16), clampf(p.y, 16, vp.y - _prompt.size.y - 16))
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


# ------------------------------------------------------------ icons

## A cooking pot, in thin light lines.
class _PotIcon extends Control:
	func _draw() -> void:
		var c := Color(0.95, 0.93, 0.88)
		var w := 2.0
		var s := size
		var body := Rect2(s.x * 0.14, s.y * 0.38, s.x * 0.72, s.y * 0.56)
		draw_line(Vector2(body.position.x, body.position.y), Vector2(body.end.x, body.position.y), c, w, true)
		draw_line(Vector2(body.position.x + 1, body.position.y), Vector2(body.position.x + 3, body.end.y - 3), c, w, true)
		draw_line(Vector2(body.end.x - 1, body.position.y), Vector2(body.end.x - 3, body.end.y - 3), c, w, true)
		draw_line(Vector2(body.position.x + 3, body.end.y - 3), Vector2(body.end.x - 3, body.end.y - 3), c, w, true)
		draw_line(Vector2(0, body.position.y + 4), Vector2(body.position.x, body.position.y + 4), c, w, true)
		draw_line(Vector2(body.end.x, body.position.y + 4), Vector2(s.x, body.position.y + 4), c, w, true)
		# Lid and knob.
		draw_line(Vector2(s.x * 0.2, s.y * 0.28), Vector2(s.x * 0.8, s.y * 0.28), c, w, true)
		draw_arc(Vector2(s.x * 0.5, s.y * 0.24), s.x * 0.08, PI, TAU, 10, c, w, true)


## A computer mouse (left button), in thin light lines.
class _MouseIcon extends Control:
	func _draw() -> void:
		var c := Color(0.95, 0.93, 0.88)
		var r := Rect2(Vector2(2, 1), size - Vector2(4, 2))
		var rad := r.size.x * 0.5
		var top := r.position.y + rad
		var bottom := r.end.y - rad
		var cx := r.get_center().x
		draw_arc(Vector2(cx, top), rad, PI, TAU, 14, c, 2.0, true)
		draw_arc(Vector2(cx, bottom), rad, 0.0, PI, 14, c, 2.0, true)
		draw_line(Vector2(r.position.x, top), Vector2(r.position.x, bottom), c, 2.0, true)
		draw_line(Vector2(r.end.x, top), Vector2(r.end.x, bottom), c, 2.0, true)
		draw_line(Vector2(cx, r.position.y), Vector2(cx, top + 2), c, 2.0, true)
		draw_line(Vector2(r.position.x, top + 2), Vector2(r.end.x, top + 2), c, 2.0, true)
