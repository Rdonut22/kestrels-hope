class_name VitalsPanel
extends Control

## Gana's vitals in the top-left corner: the body ring and four rows
## (health, hunger, hydration, temperature) from the approved HUD design,
## with each row's value at the right end. The values are fixed for now;
## set them with set_value() once the survival systems exist.
##
## Layout numbers are in the art's pixels (vitals_panel.png, 660 x 270);
## the whole panel scales with the screen height.

const ART := preload("res://ui/vitals/vitals_panel.png")
const ART_SIZE := Vector2(660, 270)
## Each row: id, y of its line in the art, value format.
const ROWS := [["health", 84.0, "%d%%"], ["hunger", 143.0, "%d%%"], ["hydration", 201.0, "%d%%"], ["temp", 260.0, "%.1f°C"]]
## Where the value text ends (right edge) and how far above the line it sits.
const VALUE_RIGHT := 790.0
## The art's row lines end at LINE_END; they're drawn on to VALUE_RIGHT.
const LINE_END := 655.0
const PANEL_SIZE := Vector2(800, 270)
const VALUE_ABOVE := 10.0

## Panel height as a fraction of the screen height.
@export_range(0.08, 0.4) var height_of_screen := 0.12
## V folds the rows away, leaving just the ring with the body figure.
@export var collapsed := false
const ACTION := "toggle_vitals"
## Width of the ring alone (art pixels), and the fold time.
const RING_WIDTH := 363.0
## The ring with the figure is drawn at this size relative to the rows,
## centred on them; the rows follow right after it.
const RING_SCALE := 0.5
## The ring's centre in the art, and the size of the ring_*.png layers.
const RING_CENTER := Vector2(235, 162)
const RING_TEX := 312.0
## How far each disk is turned before it locks into place, in degrees,
## and in how many clicks it gets there.
const UNLOCK := {"inner": -72.0, "outer": 48.0, "ticks": -30.0}
const CLICKS := {"inner": 4, "outer": 3, "ticks": 2}
const FOLD_SECS := 0.25
@export var margin := Vector2(14, 34)
@export var color := Color(0.93, 0.87, 0.76)
@export_range(0.0, 1.0) var opacity := 0.72

var values := {"health": 100.0, "hunger": 80.0, "hydration": 75.0, "temp": 36.6}
var _labels := {}
var _clip: Control
var _rows: Control
var _disks := {}
var _spins: Array[Tween] = []


func _ring_w() -> float:
	return RING_WIDTH * RING_SCALE


func _open_w() -> float:
	return _ring_w() + VALUE_RIGHT + 4.0 - RING_WIDTH
var _tween: Tween


func _ready() -> void:
	name = "VitalsPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = PANEL_SIZE
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_V
		InputMap.action_add_event(ACTION, ev)
	# Everything sits in a clipping box; folding shrinks it to the ring.
	_clip = Control.new()
	_clip.name = "Clip"
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.size = Vector2(_ring_w() if collapsed else _open_w(), PANEL_SIZE.y)
	add_child(_clip)
	# The ring: separate disks (cut from the art, ring_*.png, 312 px square
	# around the ring's centre) so they can turn, and the figure in the
	# middle. Scaled down and centred on the rows.
	var ring := Control.new()
	ring.name = "Ring"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side := RING_TEX * RING_SCALE
	ring.size = Vector2(side, side)
	ring.position = Vector2(RING_CENTER.x * RING_SCALE, (ART_SIZE.y - ART_SIZE.y * RING_SCALE) * 0.5 + RING_CENTER.y * RING_SCALE) - ring.size * 0.5
	_clip.add_child(ring)
	for layer in ["ticks", "outer", "inner", "figure"]:
		var t := TextureRect.new()
		t.name = layer.capitalize()
		t.texture = load("res://ui/vitals/ring_%s.png" % layer)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.size = ring.size
		t.pivot_offset = ring.size * 0.5
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ring.add_child(t)
		if layer != "figure":
			_disks[layer] = t
	# The rows (bracket, icons, labels, lines, values) in art coordinates,
	# shifted left to sit right after the smaller ring.
	_rows = Control.new()
	_rows.name = "Rows"
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.size = PANEL_SIZE
	_rows.position.x = _ring_w() - RING_WIDTH
	_clip.add_child(_rows)
	var art := TextureRect.new()
	art.name = "Art"
	var rows_tex := AtlasTexture.new()
	rows_tex.atlas = ART
	rows_tex.region = Rect2(RING_WIDTH, 0, ART_SIZE.x - RING_WIDTH, ART_SIZE.y)
	art.texture = rows_tex
	art.position.x = RING_WIDTH
	art.size = Vector2(ART_SIZE.x - RING_WIDTH, ART_SIZE.y)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_rows.add_child(art)
	var font: Font = preload("res://ui/fonts/JetBrainsMono-Regular.ttf")
	for r in ROWS:
		var l := Label.new()
		l.name = String(r[0]).capitalize() + "Value"
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", 23)
		l.add_theme_color_override("font_color", color)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		l.size = Vector2(160, 34)
		l.position = Vector2(VALUE_RIGHT - 160, float(r[1]) - VALUE_ABOVE - 34)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.add_child(l)
		_labels[r[0]] = l
	_refresh()
	_rows.draw.connect(_draw_lines)
	get_viewport().size_changed.connect(_fit)
	_fit()


## health / hunger / hydration in percent, temp in °C.
func set_value(id: String, v: float) -> void:
	values[id] = v
	_refresh()


func _refresh() -> void:
	for r in ROWS:
		var l: Label = _labels.get(r[0])
		if l:
			var v: float = values.get(r[0], 0.0)
			l.text = String(r[2]) % (v if r[0] == "temp" else roundi(v))


## Continue each row's line past the end of the art, slightly worn.
func _draw_lines() -> void:
	for r in ROWS:
		var y: float = float(r[1]) + 0.5
		_rows.draw_line(Vector2(LINE_END - 2.0, y), Vector2(VALUE_RIGHT, y), Color(color, 0.95), 2.4, true)
		_rows.draw_line(Vector2(VALUE_RIGHT - 1.0, y - 3.0), Vector2(VALUE_RIGHT - 1.0, y + 3.0), Color(color, 0.95), 2.0, true)


func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := vp.y * height_of_screen / PANEL_SIZE.y
	scale = Vector2(s, s)
	position = margin * (vp.y / 1080.0)


## Fold the rows away (just the ring) or open them again.
func set_collapsed(on: bool) -> void:
	collapsed = on
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_clip, "size:x", _ring_w() if on else _open_w(), FOLD_SECS)
	_turn_disks(not on)


## The disks swing round and click back into place one notch at a time,
## each a little after the last. Opening locks them in fully; folding
## gives a quicker, shorter turn.
func _turn_disks(opening: bool) -> void:
	for t in _spins:
		if t.is_valid():
			t.kill()
	_spins.clear()
	var delay := 0.0
	for k in ["inner", "outer", "ticks"]:
		var d: TextureRect = _disks.get(k)
		if d == null:
			continue
		var start: float = deg_to_rad(UNLOCK[k]) * (1.0 if opening else 0.4)
		var clicks: int = CLICKS[k] if opening else 1
		var seq := create_tween()
		_spins.append(seq)
		seq.tween_interval(delay)
		seq.tween_property(d, "rotation", start, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		for c in clicks:
			var target := start * (1.0 - float(c + 1) / clicks)
			seq.tween_interval(0.035)
			seq.tween_property(d, "rotation", target, 0.075).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		delay += 0.05



func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION) and not event.is_echo() and visible:
		set_collapsed(not collapsed)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var hud := get_parent()
	visible = not (hud != null and hud.has_method("is_busy") and hud.is_busy())
	modulate.a = opacity
