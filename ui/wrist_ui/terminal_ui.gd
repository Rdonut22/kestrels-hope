class_name TerminalUI
extends Control

## The G-07 wrist terminal's screen: a 1280 x 800 UI drawn into its own
## viewport and shown on the terminal model's display
## (ui/wrist_ui/wrist_terminal_view.gd). Home screen of six sections (2 x 3),
## and a page for each section (filled in section by section; DISCOVERIES
## opens its own panel, ui/discoveries).
##
## Built from the approved design's own art (ui/wrist_ui/art, cut from the
## design by tools/make_terminal_art.py): the screen with its amber frame
## and header, the module tiles (selected / not), the six icons and the home
## footer. Positions are the design's pixels (REF), scaled by K; the text
## on the tiles is live Barlow Condensed, the design's lettering.

signal section_opened(index: int)
signal home_shown
## A locked section was chosen (see SECTION_UNLOCKS).
signal section_locked(index: int)

const SIZE := Vector2(1280, 800)
## id, title, subtitle (icons: ui/wrist_ui/art/icon_<id>.png).
const SECTIONS := [
	["map", "MAP", "NAVIGATION & TERRAIN"],
	["discoveries", "DISCOVERIES", "OBJECTIVES & LEADS"],
	["comms", "COMMS", "FREQUENCY SCANNING"],
	["inventory", "INVENTORY", "COLLECTED ITEMS"],
	["arm", "ARM SYSTEMS", "MODULES & UPGRADES"],
	["scan", "SCAN ARCHIVE", "LOGGED DISCOVERIES"],
]

## Sections that stay locked until an objective (Discoveries) is done:
## section id -> objective id. The terminal itself is available from the
## start; e.g. {"map": "some_mission_id"}. None are locked yet.
const SECTION_UNLOCKS := {}

const ART := "res://ui/wrist_ui/art/"
## The design's screen region (reference pixels) -> this UI: x scale K,
## then TOP px down (see tools/make_terminal_art.py).
const REF_ORIGIN := Vector2(384, 196)
const K := 1280.0 / 905.0
const TOP := 16.0
## Tile outlines in the design (reference px): columns, rows, size.
const TILE_X := [416.0, 837.0]
const TILE_Y := [309.0, 429.0, 549.0]
const TILE_SIZE := Vector2(409, 103)
## The art's margin round a tile outline (its glow).
const SELECTED_PAD := Vector2(12, 12)
const NORMAL_PAD := Vector2(8, 8)
## Inside a tile (reference px from its outline's corner).
const ICON_CENTER := Vector2(65, 51)
const TEXT_X := 160.0
const TITLE_BASE := 43.0
const SUB_BASE := 77.0
## The section page's panel and the footer (reference px).
const PAGE := Rect2(416, 309, 830, 343)
const FOOTER_BASE := 708.0
const FOOTER_RECT := Rect2(402, 684, 860, 38)

const IVORY := Color("#EFE6D6")
const IVORY_DIM := Color("#CFC0A4")
const AMBER := Color("#F7A92B")
const INK := Color("#1d140b")
## The amber of a tile's outline in the design.
const TILE_EDGE := Color("#d18a3a")
const STYLE := preload("res://ui/discoveries/discoveries_style.gd")

## Selected tile on the home screen.
var selected := 0
## Open section, or -1 on the home screen.
var section := -1

var _font: Font = preload("res://ui/fonts/JetBrainsMono-Bold.ttf")
var _font_light: Font = preload("res://ui/fonts/JetBrainsMono-Regular.ttf")
var _icons: Array[Texture2D] = []
var _plate: Texture2D = preload(ART + "screen_plate.png")
var _footer_home: Texture2D = preload(ART + "footer_home.png")
var _tile: Texture2D = preload(ART + "tile.png")
var _tile_selected: Texture2D = preload(ART + "tile_selected.png")
var _unread := {}
var _blink := 0.0


func _ready() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in SECTIONS:
		_icons.append(load(ART + "icon_" + s[0] + ".png") as Texture2D)


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
	i = clampi(i, 0, SECTIONS.size() - 1)
	if is_locked(i):
		selected = i
		section_locked.emit(i)
		return
	section = i
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


## True while a section waits on its objective (SECTION_UNLOCKS).
func is_locked(i: int) -> bool:
	var o: String = SECTION_UNLOCKS.get(SECTIONS[i][0], "")
	return o != "" and not Game.state().objective_done(o)


func section_index(id: String) -> int:
	for i in SECTIONS.size():
		if SECTIONS[i][0] == id:
			return i
	return -1


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

## Reference px -> UI px.
static func ui(p: Vector2) -> Vector2:
	return (p - REF_ORIGIN) * K + Vector2(0, TOP)


static func ui_rect(r: Rect2) -> Rect2:
	return Rect2(ui(r.position), r.size * K)


## A tile's outline in UI px.
func _tile_rect(i: int) -> Rect2:
	return ui_rect(Rect2(Vector2(TILE_X[i % 2], TILE_Y[i / 2]), TILE_SIZE))


## The footer's "< BACK" on a section page (UI px).
func _back_rect() -> Rect2:
	return ui_rect(Rect2(FOOTER_RECT.position, Vector2(130, FOOTER_RECT.size.y)))


func _text(t: String, p: Vector2, size: int, c: Color, light := false, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, spacing := 0) -> void:
	var f: Font = _font_light if light else _font
	if spacing != 0:
		f = _spaced(f, spacing)
	if align == HORIZONTAL_ALIGNMENT_RIGHT and width <= 0.0:
		p.x -= f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		align = HORIZONTAL_ALIGNMENT_LEFT
		width = -1.0
	draw_string(f, p, t, align, width, size, c)


var _spaced_fonts := {}


func _spaced(f: Font, spacing: int) -> Font:
	var key := "%s/%d" % [f.resource_path, spacing]
	if not _spaced_fonts.has(key):
		var v := FontVariation.new()
		v.base_font = f
		v.spacing_glyph = spacing
		_spaced_fonts[key] = v
	return _spaced_fonts[key]


## Barlow Condensed (the design's lettering) at a weight.
func _ctext(t: String, p: Vector2, size: int, c: Color, weight := 500, spacing := 1) -> void:
	draw_string(STYLE.ui_font(weight, spacing), p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


func _cw(t: String, size: int, weight := 500, spacing := 1) -> float:
	return STYLE.ui_font(weight, spacing).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _w(t: String, size: int, light := false, spacing := 0) -> float:
	var f: Font = _font_light if light else _font
	if spacing != 0:
		f = _spaced(f, spacing)
	return f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _draw() -> void:
	draw_texture(_plate, Vector2.ZERO)
	if section < 0:
		for i in SECTIONS.size():
			_draw_tile(i)
		draw_texture_rect(_footer_home, ui_rect(Rect2(Vector2(400, 680), _footer_home.get_size() / K)), false)
	else:
		_draw_section()
		_draw_section_footer()


func _draw_tile(i: int) -> void:
	var r := _tile_rect(i)
	var sel := i == selected
	var locked := is_locked(i)
	var pad: Vector2 = (SELECTED_PAD if sel else NORMAL_PAD) * K
	var tex := _tile_selected if sel else _tile
	draw_texture_rect(tex, Rect2(r.position - pad, r.size + pad * 2.0), false)
	var fade := 0.45 if locked else 1.0
	# Icon, centred in the left block.
	var icon := _icons[i]
	draw_texture(icon, r.position + ICON_CENTER * K - icon.get_size() * 0.5, Color(1, 1, 1, fade))
	# "01 MAP" / subtitle, as in the design (number light, title bold).
	var s_data: Array = SECTIONS[i]
	var num := "%02d" % (i + 1)
	var base := r.position + Vector2(TEXT_X, TITLE_BASE) * K
	_ctext(num, base, 45, Color(IVORY, fade), 500, 2)
	_ctext(s_data[1], base + Vector2(_cw(num, 45, 500, 2) + 16, 0), 45, Color(IVORY, fade), 600, 3)
	var sub: String = "[ LOCKED ]" if locked else s_data[2]
	_ctext(sub, r.position + Vector2(TEXT_X, SUB_BASE) * K, 29, Color(IVORY_DIM, fade), 400, 2)
	if _unread.has(s_data[0]):
		# Unread: a small amber diamond in the tile's top-right corner.
		var d := r.position + Vector2(r.size.x - 26, 24)
		var on := _blink < 0.9
		draw_colored_polygon(PackedVector2Array([d + Vector2(0, -8), d + Vector2(8, 0), d + Vector2(0, 8), d + Vector2(-8, 0)]),
			AMBER if on else Color(AMBER, 0.35))


## A section without content yet: its tile, large, reporting standby.
func _draw_section() -> void:
	var r := ui_rect(PAGE)
	# The tiles' outline, drawn (stretching the tile art would stretch its
	# divider and corners too).
	var c := 18.0
	var a := r.position
	var b := r.end
	var pts := PackedVector2Array([Vector2(a.x + c, a.y), Vector2(b.x - c, a.y), Vector2(b.x, a.y + c), Vector2(b.x, b.y - c),
		Vector2(b.x - c, b.y), Vector2(a.x + c, b.y), Vector2(a.x, b.y - c), Vector2(a.x, a.y + c), Vector2(a.x + c, a.y)])
	draw_colored_polygon(pts.slice(0, 8), Color(0.02, 0.016, 0.012, 0.55))
	draw_polyline(pts, Color(TILE_EDGE, 0.25), 7.0, true)
	draw_polyline(pts, TILE_EDGE, 2.0, true)
	var s_data: Array = SECTIONS[section]
	var icon := _icons[section]
	draw_texture(icon, r.position + Vector2(40, 34))
	var num := "%02d" % (section + 1)
	var p := r.position + Vector2(40 + icon.get_width() + 34, 74)
	_ctext(num, p, 41, IVORY, 500, 2)
	_ctext(s_data[1], p + Vector2(_cw(num, 41, 500, 2) + 16, 0), 41, IVORY, 600, 3)
	_ctext(s_data[2], r.position + Vector2(r.size.x - 30 - _cw(s_data[2], 27, 400, 2), 74), 27, IVORY_DIM, 400, 2)
	draw_line(r.position + Vector2(30, 140), r.position + Vector2(r.size.x - 30, 140), Color(IVORY, 0.35), 1.5)
	var mid := r.get_center().y + 50
	var t1 := "[ MODULE STANDBY ]"
	_ctext(t1, Vector2(r.get_center().x - _cw(t1, 40, 600, 3) * 0.5, mid), 40, AMBER, 600, 3)
	var t2 := "NO DATA LINKED"
	_ctext(t2, Vector2(r.get_center().x - _cw(t2, 28, 400, 2) * 0.5, mid + 46), 28, IVORY_DIM, 400, 2)


## A key cap like the design's (light plate, dark letter).
func _key_cap(p: Vector2, k: String) -> float:
	var w := maxf(40.0, _cw(k, 27, 600, 1) + 22.0)
	var r := Rect2(p, Vector2(w, 40))
	draw_rect(r, Color("#e8dcc6"))
	_ctext(k, Vector2(r.get_center().x - _cw(k, 27, 600, 1) * 0.5, r.position.y + 30), 27, INK, 600, 1)
	return w


func _draw_section_footer() -> void:
	var y := ui(Vector2(0, FOOTER_BASE)).y
	var top := ui(Vector2(0, FOOTER_RECT.position.y)).y
	var x := ui(Vector2(FOOTER_RECT.position.x, 0)).x + 12
	_ctext("< BACK", Vector2(x, y), 30, IVORY, 600, 2)
	x += 250
	for k in [["ESC", "BACK"], ["H", "HOME"], ["TAB", "CLOSE"]]:
		x += _key_cap(Vector2(x, top + 6), k[0]) + 14
		_ctext(k[1], Vector2(x, y), 24, IVORY, 500, 1)
		x += _cw(k[1], 24, 500, 1) + 46
	var user := "USER: GANA  //  G-07"
	_ctext(user, Vector2(ui(Vector2(FOOTER_RECT.end.x, 0)).x - 12 - _cw(user, 28, 500, 2), y), 28, IVORY, 500, 2)
