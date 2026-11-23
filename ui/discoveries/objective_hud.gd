extends Control

## The HUD side of Discoveries (GameState objectives):
##
##   - When an objective is discovered (or finished), a notification slides
##     in at the top centre: "NEW TASK" / "NEW MISSION" (or "... COMPLETE")
##     over the objective's title.
##   - A new one then shrinks into the persistent badge in the top-right
##     corner: the same text, in its category's colour and diamond.
##   - The badge only ever shows ONE objective: GameState.focused_objective()
##     (the player's choice, unless a required progression objective takes
##     precedence). Clicking it, or J, opens Discoveries on it.
##   - Active objectives with a `highlight_vital` light up that vitals row.
##
## Both use the design's objective badge (ui/discoveries/art/hud_badge_*,
## cut from the mockup): the notification is the same badge, larger, near
## the top centre, so it shrinks straight into the corner. Sizes are in
## the mockup's pixels (978 high), scaled with the screen height.

const S := preload("res://ui/discoveries/discoveries_style.gd")
const MOCKUP_H := 978.0
const PLATE_H := 59.0
const BADGE_MIN_W := 345.0
const BADGE_TOP := 80.0
const BADGE_RIGHT := 23.0
const NOTE_TOP := 92.0
const NOTE_SCALE := 1.3
const TEXT_X := 76.0
const HOLD := 3.5
## Loaded up front: the badge only redraws when it changes, so a texture
## first loaded inside a draw would stay blank until the next change.
const BADGE_TASK := preload("res://ui/discoveries/art/hud_badge_task.png")
const BADGE_MISSION := preload("res://ui/discoveries/art/hud_badge_mission.png")
const DIAMOND := preload("res://ui/discoveries/art/glyph_badge_diamond.png")

var _note: Control      # the temporary notification
var _badge: Control     # the persistent reminder
var _queue: Array = []  # [kind ("new" / "done"), id]
var _showing := false
var _note_kind := ""
var _note_id := ""
var _badge_id := ""
var _badge_hover := false
var _scale := 1.0


func _ready() -> void:
	name = "ObjectiveHUD"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_note = Control.new()
	_note.name = "Notification"
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.draw.connect(_draw_note)
	_note.visible = false
	add_child(_note)
	_badge = Control.new()
	_badge.name = "Badge"
	_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	_badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_badge.tooltip_text = "Open in Discoveries (J)"
	_badge.draw.connect(_draw_badge)
	_badge.gui_input.connect(_badge_input)
	_badge.mouse_entered.connect(func() -> void: _badge_hover = true; _badge.queue_redraw())
	_badge.mouse_exited.connect(func() -> void: _badge_hover = false; _badge.queue_redraw())
	_badge.visible = false
	add_child(_badge)
	var gs := Game.state()
	gs.objective_added.connect(func(id: String) -> void: _queue.append(["new", id]))
	gs.objective_completed.connect(func(id: String) -> void:
		_queue = _queue.filter(func(q: Array) -> bool: return q[1] != id)
		_queue.append(["done", id]))
	gs.objective_changed.connect(func(_id: String) -> void: _refresh_badge())
	get_viewport().size_changed.connect(_fit)
	_fit()
	_refresh_badge()


func _fit() -> void:
	_scale = get_viewport().get_visible_rect().size.y / MOCKUP_H
	_note.scale = Vector2(_scale, _scale) * NOTE_SCALE
	_badge.scale = Vector2(_scale, _scale)
	_place_badge()


func _hud() -> Node:
	return get_parent()


func _chrome_hidden() -> bool:
	var hud := _hud()
	if hud and hud.has_method("hides_chrome"):
		return hud.hides_chrome()
	return hud != null and hud.has_method("is_busy") and hud.is_busy()


func _process(_delta: float) -> void:
	var hidden := _chrome_hidden()
	_badge.visible = _badge_id != "" and not hidden and not (_showing and _note_id == _badge_id and _note_kind == "new")
	_highlight_vitals()
	if not _showing and not _queue.is_empty() and not hidden:
		var q: Array = _queue.pop_front()
		_show(q[0], q[1])


# ------------------------------------------------------------ notification

func _show(kind: String, id: String) -> void:
	var def := Objectives.get_def(id)
	if def == null:
		return
	_showing = true
	_note_kind = kind
	_note_id = id
	_note.size = _plate_size(id, kind)
	var vp := get_viewport().get_visible_rect().size
	var k := _scale * NOTE_SCALE
	var home := Vector2(vp.x * 0.5 - _note.size.x * 0.5 * k, NOTE_TOP * _scale)
	_note.position = home - Vector2(0, 14 * _scale)
	_note.scale = Vector2(k, k)
	_note.modulate.a = 0.0
	_note.visible = true
	_note.queue_redraw()
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_note, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(_note, "position", home, 0.35)
	tw.tween_interval(HOLD)
	var into_badge: bool = kind == "new" and Game.state().focused_objective() == id
	if into_badge:
		# Shrink into the badge's place (same plate, same text), then hand
		# over to it.
		_refresh_badge()
		tw.tween_callback(func() -> void:
			_note_kind = "badge"
			_note.size = _badge.size
			_note.queue_redraw())
		tw.tween_property(_note, "position", _badge.position, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(_note, "scale", _badge.scale, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	else:
		tw.tween_property(_note, "modulate:a", 0.0, 0.6)
	await tw.finished
	_note.visible = false
	_showing = false
	_refresh_badge()


func is_notifying() -> bool:
	return _showing


## Width of the badge plate for an objective's text (mockup px).
func _plate_size(id: String, kind := "badge") -> Vector2:
	var def := Objectives.get_def(id)
	if def == null:
		return Vector2(BADGE_MIN_W, PLATE_H)
	var w := S.ui_font(500, 2).get_string_size(def.title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	if kind != "badge":
		w = maxf(w, S.ui_font(600, 2).get_string_size(_kicker(def, kind), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)
	return Vector2(clampf(TEXT_X + w + 62.0, BADGE_MIN_W, 760.0), PLATE_H)


func _kicker(def: ObjectiveDef, kind: String) -> String:
	return ("NEW " + S.noun(def.category)) if kind == "new" else (S.noun(def.category) + " COMPLETE")


## The design's badge with an objective on it. `kind`: "badge" (title
## only), "new" or "done" (a small line above the title).
func _draw_plate(ci: Control, id: String, kind: String, hover := false) -> void:
	var def := Objectives.get_def(id)
	if def == null:
		return
	var tex: Texture2D = BADGE_MISSION if def.is_mission() else BADGE_TASK
	var r := Rect2(Vector2.ZERO, ci.size)
	ci.draw_style_box(S.plate(tex, 40, 52), r)
	if hover:
		var hl := S.plate(tex, 40, 52).duplicate() as StyleBoxTexture
		hl.modulate_color = Color(1.4, 1.3, 1.1, 0.35)
		ci.draw_style_box(hl, r)
	var done := kind == "done"
	ci.draw_texture(DIAMOND, Vector2(31, 12), Color(1, 1, 1, 0.55) if done else S.color(def.category) if kind == "new" else Color.WHITE)
	var title := S.fit(def.title.to_upper(), S.ui_font(500, 2), 24, ci.size.x - TEXT_X - 58)
	if kind == "badge":
		ci.draw_string(S.ui_font(500, 2), Vector2(TEXT_X, 38), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, S.IVORY)
	else:
		ci.draw_string(S.ui_font(600, 2), Vector2(TEXT_X, 23), _kicker(def, kind), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, S.color(def.category))
		ci.draw_string(S.ui_font(500, 2), Vector2(TEXT_X, 46), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color(S.IVORY, 0.7) if done else S.IVORY)


func _draw_note() -> void:
	if _note_id != "":
		_draw_plate(_note, _note_id, _note_kind)


# ------------------------------------------------------------------ badge

func _refresh_badge() -> void:
	_badge_id = Game.state().focused_objective()
	_place_badge()
	_badge.queue_redraw()


func _place_badge() -> void:
	var vp := get_viewport().get_visible_rect().size
	_badge.size = _plate_size(_badge_id)
	_badge.position = Vector2(vp.x - (BADGE_RIGHT + _badge.size.x) * _scale, BADGE_TOP * _scale)


func _draw_badge() -> void:
	if _badge_id != "":
		_draw_plate(_badge, _badge_id, "badge", _badge_hover)


func badge_id() -> String:
	return _badge_id if _badge.visible else ""


func badge_rect() -> Rect2:
	return _badge.get_global_rect()


func _badge_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		open_badge()
		_badge.accept_event()


## Open Discoveries on the badge's objective.
func open_badge() -> void:
	var w := get_tree().get_first_node_in_group("wrist_terminal_view")
	if w and _badge_id != "":
		w.open_discoveries(_badge_id)


# ------------------------------------------------------------------ vitals

func _highlight_vitals() -> void:
	var vitals := _hud().get_node_or_null("VitalsPanel") if _hud() else null
	if vitals == null or not vitals.has_method("set_highlights"):
		return
	var want := {}
	var gs := Game.state()
	for id in gs.objective_ids():
		var def := Objectives.get_def(id)
		if def.highlight_vital != "":
			want[def.highlight_vital] = S.color(def.category)
	vitals.set_highlights(want)
