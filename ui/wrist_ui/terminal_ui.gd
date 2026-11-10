class_name TerminalUI
extends Control

## The G-07 wrist terminal's screen: a 1280 x 800 phosphor-green UI drawn
## into its own viewport and shown on the terminal model's display
## (ui/wrist_ui/wrist_terminal_view.gd). Home screen of six sections (2 x 3),
## and a page for each section (filled in section by section).
##
## Drawn in code: the grid texture, borders and selection are lines and
## polygons; the icons are textures in ui/wrist_ui/icons (replaceable one by
## one via SECTIONS); text is JetBrains Mono.

signal section_opened(index: int)
signal home_shown

const SIZE := Vector2(1280, 800)
const ICONS := "res://ui/wrist_ui/icons/"
## id, title, subtitle, icon file.
const SECTIONS := [
	["map", "MAP", "NAVIGATION & TERRAIN", "icon_map.png"],
	["discoveries", "DISCOVERIES", "OBJECTIVES & LEADS", "icon_discoveries.png"],
	["comms", "COMMS", "FREQUENCY SCANNING", "icon_comms.png"],
	["inventory", "INVENTORY", "COLLECTED ITEMS", "icon_inventory.png"],
	["arm", "ARM SYSTEMS", "MODULES & UPGRADES", "icon_arm.png"],
	["scan", "SCAN ARCHIVE", "LOGGED DISCOVERIES", "icon_scan.png"],
]

# Phosphor palette.
const BG := Color(0.024, 0.063, 0.035)
const GRID := Color(0.35, 0.85, 0.4, 0.055)
const DIM := Color(0.3, 0.62, 0.32)
const TEXT := Color(0.58, 0.93, 0.52)
const BRIGHT := Color(0.72, 1.0, 0.64)
const GLOW := Color(0.45, 1.0, 0.4, 0.22)

# Layout.
const MARGIN := 60.0
const HEADER_Y := 132.0
const GRID_TOP := 158.0
const TILE_H := 162.0
const TILE_GAP := 20.0
const FOOTER_Y := 712.0
const CHAMFER := 14.0

## Selected tile on the home screen.
var selected := 0
## Open section, or -1 on the home screen.
var section := -1

var _font: Font = preload("res://ui/fonts/JetBrainsMono-Bold.ttf")
var _font_light: Font = preload("res://ui/fonts/JetBrainsMono-Regular.ttf")
var _icons: Array[Texture2D] = []
var _logo: Texture2D = preload(ICONS + "icon_ushida_logo.png")
var _unread := {}
var _blink := 0.0


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in SECTIONS:
		_icons.append(load(ICONS + s[3]) as Texture2D)


func _process(delta: float) -> void:
	_blink = fmod(_blink + delta, 1.2)
	queue_redraw()


# ------------------------------------------------------------- navigation

## Move the home-screen selection: dir is (-1/1, 0) or (0, -1/1).
func move(dir: Vector2i) -> bool:
	if section >= 0:
		return false
	var col := selected % 2
	var row := selected / 2
	col = clampi(col + dir.x, 0, 1)
	row = clampi(row + dir.y, 0, 2)
	var n := row * 2 + col
	if n == selected:
		return false
	selected = n
	return true


func activate() -> void:
	if section < 0:
		open_section(selected)


func open_section(i: int) -> void:
	section = clampi(i, 0, SECTIONS.size() - 1)
	selected = section
	_unread.erase(SECTIONS[section][0])
	section_opened.emit(section)


## Back one level; false when already on the home screen.
func back() -> bool:
	if section < 0:
		return false
	home()
	return true


func home() -> void:
	section = -1
	home_shown.emit()


## Small marker beside a section's tile until it's opened.
func set_unread(id: String, on := true) -> void:
	if on:
		_unread[id] = true
	else:
		_unread.erase(id)


func is_unread(id: String) -> bool:
	return _unread.has(id)


## Tile under a point (screen pixels), or -1.
func tile_at(p: Vector2) -> int:
	if section >= 0:
		return -1
	for i in SECTIONS.size():
		if _tile_rect(i).has_point(p):
			return i
	return -1


## Mouse over the screen: hover selects; returns true if it changed.
func hover(p: Vector2) -> bool:
	var t := tile_at(p)
	if t >= 0 and t != selected:
		selected = t
		return true
	return false


## Click on the screen: opens a tile, or the footer's BACK on a page.
func click(p: Vector2) -> void:
	if section >= 0:
		if _back_rect().has_point(p):
			back()
		return
	var t := tile_at(p)
	if t >= 0:
		open_section(t)


# ---------------------------------------------------------------- drawing

func _tile_rect(i: int) -> Rect2:
	var w := (SIZE.x - MARGIN * 2.0 - TILE_GAP) * 0.5
	return Rect2(MARGIN + (i % 2) * (w + TILE_GAP), GRID_TOP + (i / 2) * (TILE_H + TILE_GAP), w, TILE_H)


func _back_rect() -> Rect2:
	return Rect2(MARGIN, FOOTER_Y + 8, 300, 50)


static func _chamfer(r: Rect2, c: float) -> PackedVector2Array:
	var a := r.position
	var b := r.end
	return PackedVector2Array([Vector2(a.x + c, a.y), Vector2(b.x - c, a.y), Vector2(b.x, a.y + c), Vector2(b.x, b.y - c),
		Vector2(b.x - c, b.y), Vector2(a.x + c, b.y), Vector2(a.x, b.y - c), Vector2(a.x, a.y + c), Vector2(a.x + c, a.y)])


func _text(t: String, p: Vector2, size: int, c: Color, light := false, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := _font_light if light else _font
	if align == HORIZONTAL_ALIGNMENT_RIGHT and width <= 0.0:
		p.x -= f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		align = HORIZONTAL_ALIGNMENT_LEFT
		width = -1.0
	# Restrained phosphor bloom: a soft halo under bright text.
	if c.v > 0.8:
		for o in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5)]:
			draw_string(f, p + o, t, align, width, size, Color(c, 0.18))
	draw_string(f, p, t, align, width, size, c)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), BG)
	_draw_grid()
	_draw_header()
	if section < 0:
		for i in SECTIONS.size():
			_draw_tile(i)
	else:
		_draw_section()
	_draw_footer()
	_draw_scanlines()


func _draw_grid() -> void:
	var step := 20.0
	var x := 0.0
	while x <= SIZE.x:
		draw_line(Vector2(x, 0), Vector2(x, SIZE.y), GRID, 1.0)
		x += step
	var y := 0.0
	while y <= SIZE.y:
		draw_line(Vector2(0, y), Vector2(SIZE.x, y), GRID, 1.0)
		y += step


func _draw_scanlines() -> void:
	var y := 0.0
	while y < SIZE.y:
		draw_line(Vector2(0, y), Vector2(SIZE.x, y), Color(0, 0, 0, 0.09), 1.0)
		y += 3.0
	# Darker corners (the tube's falloff).
	for i in 6:
		var inset := i * 6.0
		draw_rect(Rect2(Vector2(inset, inset), SIZE - Vector2(inset, inset) * 2.0), Color(0, 0, 0, 0.05), false, 6.0)


func _slashes(p: Vector2, h: float, c: Color) -> void:
	for i in 3:
		var x := p.x + i * h * 0.42
		draw_colored_polygon(PackedVector2Array([Vector2(x + h * 0.38, p.y - h), Vector2(x + h * 0.6, p.y - h),
			Vector2(x + h * 0.22, p.y), Vector2(x, p.y)]), c)


func _draw_header() -> void:
	draw_texture_rect(_logo, Rect2(MARGIN + 6, 34, 72, 66), false, TEXT)
	_text("USHIDA", Vector2(MARGIN + 96, 66), 30, TEXT)
	_text("INDUSTRIES", Vector2(MARGIN + 96, 100), 22, DIM, true)
	draw_line(Vector2(MARGIN + 300, 40), Vector2(MARGIN + 300, 104), DIM, 2.0)
	var title := "FIELD TERMINAL  G-07"
	_text(title, Vector2(MARGIN + 330, 86), 38, TEXT)
	_slashes(Vector2(MARGIN + 330 + _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x + 26, 84), 30.0, DIM)
	# Power and link.
	var rx := SIZE.x - MARGIN
	_text("PWR 82%", Vector2(rx - 280, 66), 24, TEXT, true)
	var bat := Rect2(rx - 120, 44, 92, 30)
	draw_rect(bat, TEXT, false, 2.0)
	draw_rect(Rect2(bat.end.x, bat.position.y + 9, 6, 12), TEXT)
	for i in 4:
		draw_rect(Rect2(bat.position.x + 6 + i * 21.0, bat.position.y + 6, 16, 18), TEXT)
	_text("LOCAL MODE", Vector2(rx - 280, 104), 24, TEXT, true)
	for i in 4:
		var h := 8.0 + i * 7.0
		draw_rect(Rect2(rx - 60 + i * 13.0, 106 - h, 8, h), TEXT)
	draw_line(Vector2(MARGIN, HEADER_Y), Vector2(SIZE.x - MARGIN, HEADER_Y), DIM, 2.0)
	draw_line(Vector2(MARGIN, HEADER_Y), Vector2(MARGIN + 160, HEADER_Y), TEXT, 3.0)


func _draw_tile(i: int) -> void:
	var r := _tile_rect(i)
	var sel := i == selected
	var poly := _chamfer(r, CHAMFER)
	if sel:
		draw_colored_polygon(poly.slice(0, 8), Color(0.4, 1.0, 0.4, 0.07))
		draw_polyline(poly, GLOW, 9.0)
		draw_polyline(poly, BRIGHT, 3.0)
	else:
		draw_polyline(poly, DIM, 2.0)
	var c := BRIGHT if sel else TEXT
	# Icon, centred in the left block.
	var icon := _icons[i]
	var box := Rect2(r.position + Vector2(18, 22), Vector2(150, r.size.y - 44))
	var s := minf(box.size.x / icon.get_width(), box.size.y / icon.get_height())
	var isz := icon.get_size() * s
	draw_texture_rect(icon, Rect2(box.get_center() - isz * 0.5, isz), false, c)
	draw_line(r.position + Vector2(190, 26), r.position + Vector2(190, r.size.y - 26), DIM, 2.0)
	var s_data: Array = SECTIONS[i]
	_text("%02d" % (i + 1), r.position + Vector2(214, 72), 32, c, true)
	_text(s_data[1], r.position + Vector2(268, 72), 38, c)
	_text(s_data[2], r.position + Vector2(214, 122), 22, TEXT if sel else DIM, true)
	if _unread.has(s_data[0]):
		# Unread: a small lit diamond in the tile's top-right corner.
		var d := r.position + Vector2(r.size.x - 30, 30)
		var on := _blink < 0.9
		draw_colored_polygon(PackedVector2Array([d + Vector2(0, -8), d + Vector2(8, 0), d + Vector2(0, 8), d + Vector2(-8, 0)]),
			BRIGHT if on else DIM)


func _draw_section() -> void:
	var s_data: Array = SECTIONS[section]
	var top := GRID_TOP
	var r := Rect2(MARGIN, top, SIZE.x - MARGIN * 2.0, FOOTER_Y - top - 20)
	draw_polyline(_chamfer(r, CHAMFER), DIM, 2.0)
	var icon := _icons[section]
	var isz := icon.get_size() * (64.0 / icon.get_height())
	draw_texture_rect(icon, Rect2(r.position + Vector2(24, 18), isz), false, BRIGHT)
	_text("%02d" % (section + 1), r.position + Vector2(48 + isz.x, 62), 30, TEXT, true)
	_text(s_data[1], r.position + Vector2(100 + isz.x, 62), 40, BRIGHT)
	_text(s_data[2], r.position + Vector2(r.size.x - 24, 60), 22, DIM, true, HORIZONTAL_ALIGNMENT_RIGHT, 0.0)
	draw_line(r.position + Vector2(20, 100), r.position + Vector2(r.size.x - 20, 100), DIM, 2.0)
	# Section content comes next; until then the module reports standby.
	var mid := r.get_center() + Vector2(0, 30)
	_text("[ MODULE STANDBY ]", Vector2(r.position.x, mid.y), 34, TEXT, false, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_text("NO DATA LINKED", Vector2(r.position.x, mid.y + 46), 24, DIM, true, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_footer() -> void:
	draw_line(Vector2(MARGIN, FOOTER_Y), Vector2(SIZE.x - MARGIN, FOOTER_Y), DIM, 2.0)
	draw_line(Vector2(MARGIN, FOOTER_Y), Vector2(MARGIN + 60, FOOTER_Y), TEXT, 3.0)
	draw_line(Vector2(SIZE.x - MARGIN - 60, FOOTER_Y), Vector2(SIZE.x - MARGIN, FOOTER_Y), TEXT, 3.0)
	var y := FOOTER_Y + 46
	if section < 0:
		_text("SYSTEM READY", Vector2(MARGIN + 12, y), 24, TEXT, true)
		_slashes(Vector2(MARGIN + 24 + _font_light.get_string_size("SYSTEM READY", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x, y), 22.0, TEXT)
		_text("[ARROWS] SELECT  [E] OPEN  [TAB] CLOSE", Vector2(MARGIN + 290, y), 20, DIM, true)
	else:
		_text("< BACK", Vector2(MARGIN + 12, y), 26, BRIGHT)
		_text("[ESC] BACK  [H] HOME  [TAB] CLOSE", Vector2(MARGIN + 170, y), 20, DIM, true)
	_text("USER: GANA  //  G-07", Vector2(SIZE.x - MARGIN - 12, y), 24, TEXT, true, HORIZONTAL_ALIGNMENT_RIGHT, 0.0)
