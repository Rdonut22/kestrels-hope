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
@export_range(0.08, 0.4) var height_of_screen := 0.175
@export var margin := Vector2(14, 34)
@export var color := Color(0.93, 0.87, 0.76)
@export_range(0.0, 1.0) var opacity := 0.9

var values := {"health": 100.0, "hunger": 80.0, "hydration": 75.0, "temp": 36.6}
var _labels := {}


func _ready() -> void:
	name = "VitalsPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = PANEL_SIZE
	var art := TextureRect.new()
	art.name = "Art"
	art.texture = ART
	art.size = ART_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(art)
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
		add_child(l)
		_labels[r[0]] = l
	_refresh()
	draw.connect(_draw_lines)
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
		draw_line(Vector2(LINE_END - 2.0, y), Vector2(VALUE_RIGHT, y), Color(color, 0.95), 2.4, true)
		draw_line(Vector2(VALUE_RIGHT - 1.0, y - 3.0), Vector2(VALUE_RIGHT - 1.0, y + 3.0), Color(color, 0.95), 2.0, true)


func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := vp.y * height_of_screen / PANEL_SIZE.y
	scale = Vector2(s, s)
	position = margin * (vp.y / 1080.0)


func _process(_delta: float) -> void:
	var hud := get_parent()
	visible = not (hud != null and hud.has_method("is_busy") and hud.is_busy())
	modulate.a = opacity
