class_name DiscoveriesPanel
extends Control

## DISCOVERIES: the wrist terminal's objectives section (opened from the
## G-07 home screen, or straight to an objective from the HUD badge / J).
## Built from the approved design's own art (ui/discoveries/art, cut from
## the mockup by tools/make_discoveries_art.py) and laid out at the
## mockup's pixel positions (MOCKUP, 1608 x 978), scaled to the screen:
##
##   left    MISSIONS / TASKS, each with a count of active ones
##   centre  the selected category's objectives: diamond (amber or green =
##           tracked, ivory = not), title, summary, TRACKED / TRACK /
##           REQUIRED / DONE
##   right   the selected objective: picture (if it has one), title, TASK
##           or MISSION tag, description, then "REQUIRED - COMPLETE TO
##           CONTINUE" for a required one, or TRACK / HUD FOCUS buttons
##
## Keys: W/S or Up/Down select, A/D or Left/Right switch category, E/Enter
## track or untrack, F make it the HUD's focus, Esc close, Backspace back
## to the terminal's home screen. The mouse works on everything.

signal back_requested
signal close_requested

const MOCKUP := Vector2(1608, 978)
const S := preload("res://ui/discoveries/discoveries_style.gd")
const ART := "res://ui/discoveries/art/"

# Positions in mockup pixels (see tools/make_discoveries_art.py).
const PLATE_AT := Vector2(56, 166)
const NAV_AT := [Vector2(80, 282), Vector2(80, 352)]   # missions, tasks
const NAV_SELECTED_OFFSET := Vector2(-3, 2)
const LIST_X := 356.0
const LIST_W := 526.0
const HEADER_BASE := 301.0
const HEADER_RULE_Y := 308.0
const ROW_CENTER0 := 386.0
const ROW_PITCH := 82.0
const ROWS_VISIBLE := 5
const ROW_BUTTON_X := 776.0
const TEXT_X := 437.0
const DETAIL_X := 916.0
const DETAIL_W := 614.0
const IMAGE_Y := 277.0
const IMAGE_H := 160.0
const BANNER_Y := 746.0
## The description wraps at about this width in the mockup.
const DESC_W := 520.0
const FOOT_F_LABEL := Vector2(338, 846)
const FOOT_F_RECT := Rect2(288, 822, 150, 32)
const FOOT_ESC_RECT := Rect2(1420, 822, 110, 32)

const INK := Color("#2a1a0c")

var category := "task"
## Selected objective id in the current category ("" for none).
var selected := ""

var _root: Control
var _hits: Array = []  # [Rect2 (mockup px), action, arg]; later ones on top
var _scroll := 0
var _time := 0.0
var _flash := {}
var _tex := {}


func _ready() -> void:
	name = "DiscoveriesPanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_root = Control.new()
	_root.name = "Layout"
	_root.size = MOCKUP
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_root.draw.connect(_draw_panel)
	add_child(_root)
	resized.connect(_fit)
	_fit()
	Game.state().objective_changed.connect(func(_id: String) -> void: _keep_selection())
	visible = false


func _t(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load(ART + n + ".png")
	return _tex[n]


func _fit() -> void:
	var s := minf(size.x / MOCKUP.x, size.y / MOCKUP.y)
	if s <= 0.0:
		return
	_root.scale = Vector2(s, s)
	_root.position = (size - MOCKUP * s) * 0.5
	queue_redraw()


func _process(delta: float) -> void:
	if visible:
		_time += delta
		_root.queue_redraw()


## A soft dim over the game behind the panel, leaving the HUD at the top
## (vitals, compass, objective badge) clear, as in the mockup.
func _draw() -> void:
	var top := _root.position.y + (PLATE_AT.y - 40.0) * _root.scale.y
	var fade := 80.0 * _root.scale.y
	var c0 := Color(0, 0, 0, 0.0)
	var c1 := Color(0, 0, 0, 0.45)
	draw_polygon(PackedVector2Array([Vector2(0, top - fade), Vector2(size.x, top - fade), Vector2(size.x, top), Vector2(0, top)]),
		PackedColorArray([c0, c0, c1, c1]))
	draw_rect(Rect2(0, top, size.x, size.y - top), c1)


# ------------------------------------------------------------------ opening

## Show Discoveries, on `id` if given (switching to its category).
func open_to(id := "") -> void:
	var def := Objectives.get_def(id) if id != "" else null
	if def and Game.state().has_objective(id):
		category = def.category
		selected = id
	_keep_selection()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


func ids() -> Array[String]:
	return Game.state().objective_ids(category, true)


func _keep_selection() -> void:
	var list := ids()
	if not selected in list:
		var active := list.filter(func(id: String) -> bool: return Game.state().objective_active(id))
		selected = active[0] if not active.is_empty() else (list[0] if not list.is_empty() else "")
	var i := list.find(selected)
	if i >= 0:
		_scroll = clampi(_scroll, i - ROWS_VISIBLE + 1, i)
	_scroll = clampi(_scroll, 0, maxi(0, list.size() - ROWS_VISIBLE))


# ------------------------------------------------------------------ actions

func set_category(c: String) -> void:
	if c == category:
		return
	category = c
	selected = ""
	_scroll = 0
	_keep_selection()


func select_step(d: int) -> void:
	var list := ids()
	if list.is_empty():
		return
	selected = list[clampi(list.find(selected) + d, 0, list.size() - 1)]
	_keep_selection()


## Track / untrack the selected objective (required ones can't be).
func toggle_track(id := "") -> bool:
	if id == "":
		id = selected
	var gs := Game.state()
	if not gs.objective_active(id):
		return false
	var ok: bool = gs.set_objective_tracked(id, not gs.objective_tracked(id))
	if ok:
		_flash[id] = _time
	return ok


func focus(id := "") -> bool:
	if id == "":
		id = selected
	var ok: bool = Game.state().set_objective_focus(id)
	if ok:
		_flash[id] = _time
	return ok


## Keys from the wrist terminal while this is up; true if used.
func key_input(event: InputEvent) -> bool:
	if not event.is_pressed():
		return false
	if event.is_action("ui_cancel"):
		close_requested.emit()
	elif _key(event, KEY_BACKSPACE):
		back_requested.emit()
	elif event.is_action("ui_up") or event.is_action("move_forward"):
		select_step(-1)
	elif event.is_action("ui_down") or event.is_action("move_back"):
		select_step(1)
	elif event.is_action("ui_left") or event.is_action("move_left"):
		set_category("mission")
	elif event.is_action("ui_right") or event.is_action("move_right"):
		set_category("task")
	elif event.is_action("ui_accept") or event.is_action("interact"):
		toggle_track()
	elif _key(event, KEY_F):
		focus()
	else:
		return false
	return true


static func _key(event: InputEvent, k: Key) -> bool:
	return event is InputEventKey and ((event as InputEventKey).physical_keycode == k or (event as InputEventKey).keycode == k)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			click(_to_mockup(event.position))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			back_requested.emit()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select_step(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select_step(1)
	accept_event()


func _to_mockup(p: Vector2) -> Vector2:
	return (p - _root.position) / _root.scale


## Where a mockup-pixel point is on this control (for tests).
func from_ref(p: Vector2) -> Vector2:
	return _root.position + p * _root.scale


## A click at a point in mockup pixels (the topmost target wins).
func click(p: Vector2) -> void:
	for i in range(_hits.size() - 1, -1, -1):
		var h: Array = _hits[i]
		if (h[0] as Rect2).has_point(p):
			match h[1]:
				"category": set_category(h[2])
				"row": selected = h[2]
				"track": selected = h[2]; toggle_track(h[2])
				"focus": focus(h[2])
				"close": close_requested.emit()
			return


## The mockup-pixel rect of a hit target, for tests: e.g. ("track", id).
func hit_rect(action: String, arg: Variant = null) -> Rect2:
	for h in _hits:
		if h[1] == action and (arg == null or h[2] == arg):
			return h[0]
	return Rect2()


# ------------------------------------------------------------------ drawing

func _hit(r: Rect2, action: String, arg: Variant = null) -> void:
	_hits.append([r, action, arg])


func _text(t: String, p: Vector2, size: int, c: Color, weight := 500, spacing := 0) -> void:
	_root.draw_string(S.ui_font(weight, spacing), p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _text_w(t: String, size: int, weight := 500, spacing := 0) -> float:
	return S.ui_font(weight, spacing).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Text centred in a rect (caps, so centred on the cap height).
func _centered(t: String, r: Rect2, size: int, c: Color, weight := 600, spacing := 1) -> void:
	var w := _text_w(t, size, weight, spacing)
	_text(t, Vector2(r.get_center().x - w * 0.5, r.get_center().y + size * 0.35), size, c, weight, spacing)


func _draw_panel() -> void:
	_hits.clear()
	_root.draw_texture(_t("panel_plate"), PLATE_AT)
	_draw_nav()
	_draw_list()
	_draw_detail()
	_draw_footer()


func _draw_nav() -> void:
	var gs := Game.state()
	for i in 2:
		var c: String = ["mission", "task"][i]
		var at: Vector2 = NAV_AT[i]
		if c == category:
			_root.draw_texture(_t("nav_button_selected"), at + NAV_SELECTED_OFFSET)
		else:
			_root.draw_texture(_t("nav_button"), at)
		var mission := c == "mission"
		_root.draw_texture(_t("glyph_mission_emblem" if mission else "glyph_task_diamond"), at + Vector2(17, 10 if mission else 8))
		_root.draw_texture(_t("glyph_label_missions" if mission else "glyph_label_tasks"), at + Vector2(70, 20))
		var plate := Rect2(at + Vector2(200, 23), Vector2(34, 29))
		_root.draw_texture(_t("count_plate"), plate.position)
		_centered(str(gs.objective_ids(c).size()), plate, 22, INK, 600, 0)
		_hit(Rect2(at, Vector2(251, 66)), "category", c)


func _draw_list() -> void:
	var gs := Game.state()
	var list := ids()
	# "◇ TASKS (2)": the design's small diamond, then live text.
	var d := _t("glyph_diamond_ivory")
	# Mockup: centred on (370, 291), about 22 px tall.
	_root.draw_texture_rect(d, Rect2(Vector2(356, 277), Vector2(29, 29)), false)
	var head := "MISSIONS" if category == "mission" else "TASKS"
	_text(head, Vector2(LIST_X + 38, HEADER_BASE), 29, S.IVORY, 600, 1)
	_text("(%d)" % gs.objective_ids(category).size(), Vector2(LIST_X + 38 + _text_w(head, 29, 600, 1) + 8, HEADER_BASE), 29, S.IVORY_DIM, 400, 1)
	_root.draw_texture(_t("header_rule"), Vector2(LIST_X, HEADER_RULE_Y))
	if list.is_empty():
		var none := "Nothing discovered yet."
		_text(none, Vector2(LIST_X + (LIST_W - _text_w(none, 21, 400)) * 0.5, ROW_CENTER0 + 6), 21, S.LINE, 400)
		return
	for k in range(_scroll, mini(list.size(), _scroll + ROWS_VISIBLE)):
		_draw_row(list[k], ROW_CENTER0 + (k - _scroll) * ROW_PITCH)
	if _scroll > 0:
		_text("▲", Vector2(LIST_X + LIST_W * 0.5 - 6, HEADER_RULE_Y + 24), 12, S.LINE, 400)
	if _scroll + ROWS_VISIBLE < list.size():
		_text("▼", Vector2(LIST_X + LIST_W * 0.5 - 6, ROW_CENTER0 + ROWS_VISIBLE * ROW_PITCH - 34), 12, S.LINE, 400)


func _draw_row(id: String, c: float) -> void:
	var gs := Game.state()
	var def := Objectives.get_def(id)
	var mission := def.is_mission()
	var done: bool = gs.objective_done(id)
	var tracked: bool = gs.objective_tracked(id)
	# The separator under the row; the selected row's glowing plate.
	_root.draw_texture(_t("row_rule"), Vector2(LIST_X, c + 38))
	if id == selected:
		var tint := Color(0.62, 1.0, 0.55) if mission else Color.WHITE
		_root.draw_texture(_t("row_selected"), Vector2(351, c - 44), Color(tint, 0.94 + 0.06 * sin(_time * 2.2)))
	# Diamond: the category colour when tracked, ivory when not.
	var glyph := "glyph_diamond_ivory"
	if tracked:
		glyph = "glyph_diamond_green" if mission else "glyph_diamond_amber"
	_root.draw_texture(_t(glyph), Vector2(371, c - 20), Color(1, 1, 1, 0.45 if done else 1.0))
	var fade := 0.5 if done else 1.0
	var text_w := ROW_BUTTON_X - TEXT_X - 14
	_text(S.fit(def.title, S.ui_font(500), 28, text_w), Vector2(TEXT_X, c - 3), 28, Color(S.IVORY, fade), 500)
	_text(S.fit(def.summary, S.ui_font(400), 19, text_w), Vector2(TEXT_X, c + 20), 19, Color(S.IVORY_DIM, fade), 400)
	_hit(Rect2(LIST_X, c - 40, LIST_W, 80), "row", id)
	# Status button (on top of the row for clicks).
	var b := Rect2(ROW_BUTTON_X, c - 17, 90, 34)
	if done:
		_button(b, "DONE", false, mission, 0.45)
	elif def.required:
		_button(b, "REQUIRED", true, mission)
	else:
		_button(b, "TRACKED" if tracked else "TRACK", tracked, mission, 1.0, _flash.get(id, -9.0))
		_hit(b, "track", id)


## One of the design's buttons, stretched to `r`, its label live: amber (or
## green) filled with dark text, or an outline with ivory text.
func _button(r: Rect2, label: String, filled: bool, mission: bool, alpha := 1.0, flashed_at := -9.0, size := 19) -> void:
	var tex := _t(("button_filled_mission" if mission else "button_filled_task") if filled else "button_outline")
	var sb := S.plate(tex, 10)
	if alpha < 1.0:
		sb = sb.duplicate()
		sb.modulate_color = Color(1, 1, 1, alpha)
	_root.draw_style_box(sb, r)
	var k := clampf(1.0 - (_time - flashed_at) / 0.5, 0.0, 1.0)
	if k > 0.0:
		_root.draw_rect(r.grow(3.0 * k), Color(S.color("mission" if mission else "task"), 0.35 * k), false, 2.0)
	_centered(label, r, size, Color(INK if filled else S.IVORY, alpha), 600, 1)


func _draw_detail() -> void:
	if selected == "":
		return
	var gs := Game.state()
	var def := Objectives.get_def(selected)
	var mission := def.is_mission()
	var done: bool = gs.objective_done(selected)
	var tracked: bool = gs.objective_tracked(selected)
	# Picture (mockup 916,277), then the title row at 442.
	var y := IMAGE_Y - 4
	if def.image:
		_root.draw_texture_rect(def.image, Rect2(DETAIL_X, IMAGE_Y, DETAIL_W, IMAGE_H), false)
		y = IMAGE_Y + IMAGE_H + 5
	var dg := "glyph_detail_diamond_ivory"
	if tracked:
		dg = "glyph_detail_diamond_green" if mission else "glyph_detail_diamond_amber"
	_root.draw_texture(_t(dg), Vector2(923, y), Color(1, 1, 1, 0.5 if done else 1.0))
	var tag := Rect2(1446, y + 8, 85, 36)
	_root.draw_texture(_t("tag_outline_mission" if mission else "tag_outline_task"), tag.position)
	_centered("MISSION" if mission else "TASK", tag, 19 if mission else 23, S.color(def.category), 600, 1)
	var title := S.fit(def.title.to_upper(), S.ui_font(600, 2), 38, tag.position.x - 997 - 12)
	_text(title, Vector2(997, y + 41), 38, S.IVORY, 600, 2)
	# Description (mockup x 939, lines 27 px apart), then the rule.
	var top := y + 56
	var font := S.ui_font(400, 1)
	_root.draw_multiline_string(font, Vector2(939, top + 20), def.description, HORIZONTAL_ALIGNMENT_LEFT, DESC_W, 23, -1, Color(S.IVORY, 0.92))
	var dh := font.get_multiline_string_size(def.description, HORIZONTAL_ALIGNMENT_LEFT, DESC_W, 23).y
	_root.draw_texture(_t("detail_rule"), Vector2(DETAIL_X, top + dh + 12))
	# Bottom: the required banner, or the tracking controls.
	if done:
		_centered("COMPLETED", Rect2(DETAIL_X, BANNER_Y, DETAIL_W, 50), 23, S.IVORY_DIM, 600, 2)
		return
	if def.required:
		_root.draw_texture(_t("required_banner_mission" if mission else "required_banner_task"), Vector2(DETAIL_X, BANNER_Y))
		return
	var tb := Rect2(DETAIL_X + 2, BANNER_Y + 2, 290, 46)
	_button(tb, "UNTRACK" if tracked else "TRACK", not tracked, mission, 1.0, _flash.get(selected, -9.0), 22)
	_hit(tb, "track", selected)
	if tracked:
		var is_focus: bool = gs.focused_objective() == selected
		var fb := Rect2(DETAIL_X + DETAIL_W - 292, BANNER_Y + 2, 290, 46)
		_button(fb, "HUD FOCUS" if is_focus else "SET HUD FOCUS", is_focus, mission, 1.0, -9.0, 22)
		if not is_focus:
			_hit(fb, "focus", selected)
			var first: String = gs.focused_objective()
			if first != "" and Objectives.get_def(first).takes_precedence:
				var note := "A required objective has the HUD for now."
				_text(note, Vector2(DETAIL_X + DETAIL_W - _text_w(note, 18, 400), BANNER_Y - 12), 18, S.LINE, 400)


func _draw_footer() -> void:
	# The F key cap is part of the plate (where the mockup had "View on
	# Map"); its label is live.
	_text("HUD Focus", FOOT_F_LABEL, 21, S.IVORY, 400)
	_hit(FOOT_F_RECT, "focus", selected)
	_hit(FOOT_ESC_RECT, "close")
