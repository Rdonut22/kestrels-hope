class_name DialogueBox
extends Control

## The game's dialogue box (ui/dialogue/dialogue_box.tscn): the supplied
## green CRT panel with a speaker label, an optional portrait in its frame,
## typewriter text, a continue indicator, and optional response choices.
## All text is live; the art is the user's PNGs (ui/dialogue/assets),
## never stretched: the panel scales as a whole, keeping its aspect.
##
##   await box.show_line("ship_computer", "Good morning.", {"hold": 1.2})
##   var pick: int = await box.ask("ganna", "Well?", ["Yes", "No"])
##
## Speakers (name, colour, portrait) come from DialogueSpeakers. With no
## portrait the frame is gone and the text takes its width.
##
## Input (existing actions): advance = interact / ui_accept / left click;
## choices = ui_up / ui_down (keyboard, d-pad, stick), confirm with
## advance. A press while the text types completes it; a separate, fresh
## press (never a held key's repeat) advances. The continue indicator only
## shows when advancing is possible (typed, and the line's minimum hold
## has passed). Nothing advances on its own.

signal dismissed
signal chosen(index: int)

const ART := "res://ui/dialogue/assets/"
## The panel artwork, and the parts of it (in its own pixels) things go in.
const PANEL_SIZE := Vector2(1741, 429)
const FRAME_RECT := Rect2(42, 34, 324, 350)          # portrait frame
const FRAME_ART := Vector2(367, 396)
const FRAME_INNER := 18.0                            # the frame's border, in its pixels
const LABEL_SIZE := Vector2(302, 95) * 1.35         # the label art, kept in proportion
const LABEL_AT := Vector2(392, 64)                   # with a portrait
const LABEL_AT_BARE := Vector2(52, 30)               # without
const TEXT_RECT := Rect2(398, 200, 1284, 188)        # with a portrait
const TEXT_RECT_BARE := Rect2(64, 182, 1618, 206)    # without
const INDICATOR_AT := Vector2(1442, 330)
const INDICATOR_SIZE := Vector2(51, 59)
const CHOICE_ART := Vector2(1294, 119)

## Width of the panel on screen: a share of the window, within limits.
@export var width_share := 0.52
@export var min_width := 560.0
@export var max_width := 900.0
@export var bottom_margin := 14.0
@export var read_speed := 30.0                       # characters a second

var _panel: TextureRect
var _frame: TextureRect
var _portrait: TextureRect
var _label: TextureRect
var _name: Label
var _text: Label
var _indicator: TextureRect
var _choices: VBoxContainer
var _blip: AudioStreamPlayer
var _type_tween: Tween
var _bob: Tween
var _fade: Tween
var _typing := false
var _waiting := false
var _hold := 0.0
var _min_hold := 0.0
var _has_portrait := false
var _options: Array = []
var _selected := 0
var _choice_nodes: Array[TextureRect] = []
## Long lines: the text shrinks to fit, down to MIN_TEXT_SIZE; past that
## it shows as pages of _page_lines lines, advanced like lines.
const MIN_TEXT_SIZE := 14
const LINE_GAP := 3
var _page := 0
var _pages := 1
var _page_lines := 1


func _ready() -> void:
	# "interact" (E) is added by player.gd at run time, not in the project
	# settings: make sure it exists in scenes without the player too.
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var e := InputEventKey.new()
		e.physical_keycode = KEY_E
		InputMap.action_add_event("interact", e)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_panel = _tex("dialogue_panel.png")
	add_child(_panel)
	_frame = _tex("portrait_frame.png")
	_panel.add_child(_frame)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = MOUSE_FILTER_IGNORE
	_frame.add_child(_portrait)
	_label = _tex("speaker_label.png")
	_panel.add_child(_label)
	_name = Label.new()
	_name.add_theme_font_override("font", load("res://ui/fonts/JetBrainsMono-Bold.ttf"))
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.clip_text = true
	_label.add_child(_name)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_override("font", load("res://ui/fonts/JetBrainsMono-Regular.ttf"))
	_text.add_theme_color_override("font_color", Color(0.86, 1.0, 0.87))
	_text.add_theme_color_override("font_shadow_color", Color(0.25, 0.9, 0.35, 0.35))
	_text.add_theme_constant_override("shadow_offset_x", 0)
	_text.add_theme_constant_override("shadow_offset_y", 0)
	_text.add_theme_constant_override("shadow_outline_size", 4)
	_panel.add_child(_text)
	_indicator = _tex("continue_indicator.png")
	_panel.add_child(_indicator)
	_choices = VBoxContainer.new()
	_choices.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_choices)
	_blip = AudioStreamPlayer.new()
	_blip.stream = load("res://audio/type_blip.ogg")
	_blip.volume_db = -22.0
	add_child(_blip)
	_panel.hide()
	_choices.hide()
	_indicator.hide()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _tex(file: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(ART + file)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = MOUSE_FILTER_IGNORE
	return t


# ---------- public ----------

## Show one line and wait until the player dismisses it. opts:
## hold (least seconds it stays once fully shown, default 0.6).
func show_line(speaker: String, text: String, opts := {}) -> void:
	_open(speaker, text, float(opts.get("hold", 0.6)), [])
	await dismissed


## Show a line with response choices; returns the chosen index.
func ask(speaker: String, text: String, options: Array, opts := {}) -> int:
	_open(speaker, text, float(opts.get("hold", 0.4)), options)
	var i: int = await chosen
	return i


func close() -> void:
	_waiting = false
	_panel.hide()
	_choices.hide()


func is_open() -> bool:
	return _panel.visible


func is_waiting() -> bool:
	return _waiting


func is_typing() -> bool:
	return _typing


func can_advance() -> bool:
	return _waiting and not _typing and _hold <= 0.0


func current_text() -> String:
	return _text.text


func current_portrait() -> Texture2D:
	return _portrait.texture if _has_portrait else null


func current_speaker_name() -> String:
	return _name.text


# ---------- showing ----------

func _open(speaker: String, text: String, hold: float, options: Array) -> void:
	var s := DialogueSpeakers.lookup(speaker)
	_name.text = String(s["name"]).to_upper()
	_name.add_theme_color_override("font_color", s["color"])
	_portrait.texture = s["portrait"]
	_has_portrait = s["portrait"] != null
	_text.text = text
	_text.visible_characters = 0
	_page = 0
	_options = options
	_selected = 0
	_build_choices()
	_choices.hide()
	_indicator.hide()
	_layout()
	if _fade:
		_fade.kill()
	if not _panel.visible or _panel.modulate.a < 1.0:
		_panel.show()
		_fade = create_tween()
		_fade.tween_property(_panel, "modulate:a", 1.0, 0.2)
	_typing = true
	_waiting = true
	_min_hold = hold
	_hold = hold
	if _type_tween:
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(_text, "visible_characters", text.length(), text.length() / read_speed)
	_type_tween.tween_callback(_typed)


func _typed() -> void:
	_typing = false
	_text.visible_characters = -1
	_hold = _min_hold


func _build_choices() -> void:
	for c in _choice_nodes:
		c.queue_free()
	_choice_nodes.clear()
	for i in _options.size():
		var c := _tex("choice_normal.png")
		var l := Label.new()
		l.text = str(_options[i])
		l.add_theme_font_override("font", load("res://ui/fonts/JetBrainsMono-Regular.ttf"))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.clip_text = true
		c.add_child(l)
		c.mouse_filter = MOUSE_FILTER_STOP
		c.gui_input.connect(_on_choice_input.bind(i))
		c.mouse_entered.connect(func() -> void:
			_selected = i
			_refresh_choices())
		_choices.add_child(c)
		_choice_nodes.append(c)


func _refresh_choices() -> void:
	for i in _choice_nodes.size():
		var on := i == _selected
		var c := _choice_nodes[i]
		c.texture = load(ART + ("choice_selected.png" if on else "choice_normal.png"))
		var l := c.get_child(0) as Label
		l.add_theme_color_override("font_color", Color(0.04, 0.16, 0.06) if on else Color(0.86, 1.0, 0.87))
		l.text = ("›  " if on else "   ") + str(_options[i])


# ---------- layout ----------

## Fit everything to the window: the panel scales as one piece (its
## aspect kept), everything inside is placed in its pixels times the scale.
func _layout() -> void:
	if _panel == null:
		return
	var vw := get_viewport_rect().size
	var w := clampf(vw.x * width_share, min_width, minf(max_width, vw.x - 32.0))
	var k := w / PANEL_SIZE.x
	var size := PANEL_SIZE * k
	_panel.size = size
	_panel.position = Vector2((vw.x - size.x) / 2.0, vw.y - size.y - bottom_margin)
	_frame.visible = _has_portrait
	_frame.position = FRAME_RECT.position * k
	_frame.size = FRAME_RECT.size * k
	var fk := _frame.size.x / FRAME_ART.x
	_portrait.position = Vector2.ONE * FRAME_INNER * fk
	_portrait.size = _frame.size - Vector2.ONE * 2.0 * FRAME_INNER * fk
	_label.position = (LABEL_AT if _has_portrait else LABEL_AT_BARE) * k
	_label.size = LABEL_SIZE * k
	_name.position = Vector2(26, 0) * k
	_name.size = (LABEL_SIZE - Vector2(52, 0)) * k
	# The name fits the label: its size, shrunk for long names.
	var font: Font = _name.get_theme_font("font")
	var fs := maxi(12, roundi(40.0 * k))
	while fs > 10 and font.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > _name.size.x:
		fs -= 1
	_name.add_theme_font_size_override("font_size", fs)
	var tr := TEXT_RECT if _has_portrait else TEXT_RECT_BARE
	_fit_text(tr.position * k, tr.size * k, maxi(15, roundi(44.0 * k)))
	_indicator.position = INDICATOR_AT * k
	_indicator.size = INDICATOR_SIZE * k
	# Choices: stacked above the panel, right-aligned with it.
	var cw := size.x * 0.62
	var ch := cw * CHOICE_ART.y / CHOICE_ART.x
	_choices.add_theme_constant_override("separation", roundi(6.0 * k / 0.37))
	for c in _choice_nodes:
		c.custom_minimum_size = Vector2(cw, ch)
		var l := c.get_child(0) as Label
		l.position = Vector2(ch * 0.55, 0)
		l.size = Vector2(cw - ch * 1.1, ch)
		l.add_theme_font_size_override("font_size", maxi(14, roundi(ch * 0.42)))
	var n := _choice_nodes.size()
	var total := n * ch + maxi(n - 1, 0) * _choices.get_theme_constant("separation")
	_choices.size = Vector2(cw, total)
	_choices.position = Vector2(_panel.position.x + size.x - cw, _panel.position.y - total - 8.0 * k / 0.37)


## Size the text to its area: the largest font (up to `start`) that fits
## the whole line, else the smallest readable one in pages.
func _fit_text(pos: Vector2, area: Vector2, start: int) -> void:
	var font: Font = _text.get_theme_font("font")
	var fs := start
	var lines := 1
	var fit := 1
	while true:
		var lh := font.get_height(fs) + LINE_GAP
		fit = maxi(1, floori((area.y + LINE_GAP) / lh))
		var h := font.get_multiline_string_size(_text.text, HORIZONTAL_ALIGNMENT_LEFT, area.x, fs).y
		lines = maxi(1, ceili(h / font.get_height(fs) - 0.01))
		if lines <= fit or fs <= MIN_TEXT_SIZE:
			break
		fs -= 1
	_text.add_theme_font_size_override("font_size", fs)
	_text.add_theme_constant_override("line_spacing", LINE_GAP)
	_page_lines = fit
	_pages = maxi(1, ceili(float(lines) / fit))
	_page = mini(_page, _pages - 1)
	_text.max_lines_visible = fit
	_text.lines_skipped = _page * fit
	_text.position = pos
	_text.size = Vector2(area.x, 0)
	_text.size = Vector2(area.x, minf(_text.get_combined_minimum_size().y, area.y))


func pages_left() -> int:
	return _pages - 1 - _page


# ---------- input ----------

func _process(delta: float) -> void:
	if not _panel.visible:
		return
	if _typing:
		if Engine.get_process_frames() % 4 == 0 and _text.visible_characters < _text.text.length():
			_blip.pitch_scale = randf_range(0.9, 1.15)
			_blip.play()
		return
	_hold = maxf(_hold - delta, 0.0)
	var show := can_advance() and (_options.is_empty() or _page < _pages - 1)
	if _waiting and not _options.is_empty() and not _typing and _page == _pages - 1 and not _choices.visible:
		_choices.show()
		_refresh_choices()
	if show != _indicator.visible:
		_indicator.visible = show
		if _bob:
			_bob.kill()
		if show:
			var base := _indicator.position
			_bob = create_tween().set_loops()
			_bob.tween_property(_indicator, "position:x", base.x + 6.0, 0.45).set_trans(Tween.TRANS_SINE)
			_bob.tween_property(_indicator, "position:x", base.x, 0.45).set_trans(Tween.TRANS_SINE)


func _advance_pressed(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _choices.visible
	if event.is_echo():
		return false
	return event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")


func _input(event: InputEvent) -> void:
	if not _panel.visible or not _waiting:
		return
	if not _options.is_empty() and not _typing and _choices.visible:
		if event.is_action_pressed("ui_down", false):
			_selected = (_selected + 1) % _options.size()
			_refresh_choices()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_up", false):
			_selected = (_selected - 1 + _options.size()) % _options.size()
			_refresh_choices()
			get_viewport().set_input_as_handled()
			return
	if not _advance_pressed(event):
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_type_tween.kill()
		_typed()
		return
	if _hold > 0.0:
		return
	if _page < _pages - 1:
		# The next page of a long line.
		_page += 1
		_text.lines_skipped = _page * _page_lines
		_hold = minf(_min_hold, 0.4)
		_indicator.hide()
		return
	_finish()


func _on_choice_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _typing and _hold <= 0.0:
		_selected = i
		_finish()


func _finish() -> void:
	_waiting = false
	_indicator.hide()
	var options := _options
	var pick := _selected
	_choices.hide()
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_panel, "modulate:a", 0.0, 0.18)
	_fade.tween_callback(_panel.hide)
	if options.is_empty():
		dismissed.emit()
	else:
		chosen.emit(pick)
