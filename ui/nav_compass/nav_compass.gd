class_name NavCompass
extends Control

## Navigation compass strip at the top of the gameplay screen.
##
## The player marker stays at the centre; the line, ticks and cardinal
## letters scroll with the camera's heading; the tracked waypoint slides
## along the line by its bearing and hides beyond the visible range.
##
## Layout is in "reference units": the pixels of the approved design
## (2000 px wide; its strip runs from x 45 to 1967, line at y 306.5). The
## whole control is scaled to the screen, so every number below can be
## checked against that image. Every glyph is its own TextureRect with an
## exported texture, so any of them can be replaced on its own.
##
## Headings: degrees clockwise from north (-Z) towards east (+X), the same
## convention as the sky and moons (world/sky_moons.gd).
##
## The waypoint is set with set_waypoint() (a Node3D or a Vector3); with
## none set, the first active NavWaypoint in the scene is tracked (one
## with hide_within only once the camera is that far from it).

const GLYPHS := "res://ui/nav_compass/glyphs/"

@export_group("Glyphs")
@export var marker_texture: Texture2D = preload(GLYPHS + "player_marker.png")
@export var waypoint_texture: Texture2D = preload(GLYPHS + "waypoint.png")
@export var cap_left_texture: Texture2D = preload(GLYPHS + "cap_left.png")
@export var cap_right_texture: Texture2D = preload(GLYPHS + "cap_right.png")
@export var letter_n: Texture2D = preload(GLYPHS + "letter_n.png")
@export var letter_e: Texture2D = preload(GLYPHS + "letter_e.png")
@export var letter_s: Texture2D = preload(GLYPHS + "letter_s.png")
@export var letter_w: Texture2D = preload(GLYPHS + "letter_w.png")

@export_group("Layout")
## Width of the whole strip as a fraction of the screen height (keeps the
## same look on any aspect ratio). 0.82 is about 880 px at 1080p.
@export_range(0.3, 1.5) var width_of_height := 0.82
## Gap above the strip, as a fraction of the screen height.
@export_range(0.0, 0.2) var top_margin := 0.012
## Reference pixels per degree of heading (W to N is ~760 px in the design).
@export var px_per_degree := 8.45
## Overall opacity (the bar is meant to stay subtle).
@export_range(0.0, 1.0) var opacity := 0.88

@export_group("Colours")
@export var line_color := Color(0.965, 0.906, 0.816)
@export var glow_color := Color(0.86, 0.6, 0.27)
@export var shadow_color := Color(0.0, 0.0, 0.0, 0.22)

# Reference-unit layout (origin = the design's x 45, y 230).
const REF_SIZE := Vector2(1922, 140)
const CENTER_X := 961.0
const LINE_Y := 76.5
const LINE_X0 := 178.0  # where the left cap hands over to the drawn line
const LINE_X1 := 1770.0  # where the right cap takes over
const CAP_LEFT_POS := Vector2(0, 50)
const CAP_RIGHT_POS := Vector2(1769, 50)
## Things further than this from the centre are hidden; they fade out over
## FADE_PX before that.
const VISIBLE_PX := 770.0
const FADE_PX := 110.0
const MARKER_GAP := 56.0  # the line stops at the marker's ring
const WAYPOINT_GAP := 31.0  # and at the waypoint's diamond
## Each letter: heading, glyph property, top edge (ref units).
const CARDINALS := [[0.0, "letter_n", -1.0], [90.0, "letter_e", 8.0], [180.0, "letter_s", 8.0], [270.0, "letter_w", 11.0]]
## Amber glow along the line: towards the centre, and beyond the waypoint.
const GLOW_INNER := 362.0
const GLOW_OUTER := 168.0
## How far a letter rises when it passes over the marker.
const LETTER_LIFT := 22.0

var heading := 0.0  # degrees, updated every frame from the camera
var waypoint_bearing := NAN  # degrees, NAN when there's no waypoint

var _waypoint_target: Variant = null  # Node3D or Vector3
var _track: Control
var _marker: TextureRect
var _waypoint: TextureRect
var _letters := {}  # heading -> TextureRect
var _letter_top := {}  # heading -> resting top edge


func _ready() -> void:
	name = "NavCompass"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = REF_SIZE
	pivot_offset = Vector2(CENTER_X, 0)
	_track = Control.new()
	_track.name = "Track"
	_track.size = REF_SIZE
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.draw.connect(_draw_track)
	add_child(_track)
	_glyph("CapLeft", cap_left_texture).position = CAP_LEFT_POS
	_glyph("CapRight", cap_right_texture).position = CAP_RIGHT_POS
	var letters := Control.new()
	letters.name = "Cardinals"
	letters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(letters)
	for c in CARDINALS:
		var tr := _glyph(String(c[1]).trim_prefix("letter_").to_upper(), get(c[1]), letters)
		tr.position.y = c[2]
		_letters[c[0]] = tr
		_letter_top[c[0]] = c[2]
	_waypoint = _glyph("Waypoint", waypoint_texture)
	_waypoint.position.y = LINE_Y - waypoint_texture.get_height() * 0.5 - 0.5
	_marker = _glyph("PlayerMarker", marker_texture)
	_marker.position = Vector2(CENTER_X, LINE_Y - 2.5) - marker_texture.get_size() * 0.5
	get_viewport().size_changed.connect(_fit)
	_fit()


func _glyph(n: String, tex: Texture2D, parent: Node = self) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = n
	tr.texture = tex
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.size = tex.get_size()
	parent.add_child(tr)
	return tr


## Scale and centre the strip at the top of the screen.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := vp.y * width_of_height / REF_SIZE.x
	scale = Vector2(s, s)
	position = Vector2(vp.x * 0.5 - CENTER_X, vp.y * top_margin)


# ------------------------------------------------------------------ waypoint

## Track a Node3D (follows it) or a fixed Vector3 position.
func set_waypoint(target: Variant) -> void:
	_waypoint_target = target


func clear_waypoint() -> void:
	_waypoint_target = null


func _waypoint_position(from: Vector3) -> Variant:
	var t: Variant = _waypoint_target
	if t is Node3D and not is_instance_valid(t):
		t = null
		_waypoint_target = null
	if t == null:
		for n in get_tree().get_nodes_in_group(NavWaypoint.GROUP):
			var w := n as NavWaypoint
			if w and w.wanted_from(from):
				t = w
				break
	if t is Node3D:
		return (t as Node3D).global_position
	if t is Vector3:
		return t
	return null


# ------------------------------------------------------------------ update

## Heading of a forward vector in degrees (0 = north/-Z, 90 = east/+X).
static func heading_of(v: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(v.x, -v.z)), 360.0)


## Screen x (reference units) of a heading, relative to the current one.
func x_of(deg: float) -> float:
	return CENTER_X + wrapf(deg - heading, -180.0, 180.0) * px_per_degree


func _edge_alpha(x: float) -> float:
	var d := absf(x - CENTER_X)
	return clampf((VISIBLE_PX - d) / FADE_PX, 0.0, 1.0)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var hud := get_parent()
	var busy: bool = hud != null and hud.has_method("is_busy") and hud.is_busy()
	visible = cam != null and not busy
	if not visible:
		return
	modulate.a = opacity
	var b := cam.global_basis
	var fwd := -b.z
	if Vector2(fwd.x, fwd.z).length() < 0.05:
		fwd = b.y * signf(-fwd.y)  # looking straight up/down: use the top of the view
	heading = heading_of(fwd)
	for h in _letters:
		var tr: TextureRect = _letters[h]
		var x := x_of(h)
		tr.position.x = x - tr.size.x * 0.5
		# Near the centre a letter rises over the marker's ring.
		var near := clampf(1.0 - (absf(x - CENTER_X) - 34.0) / 46.0, 0.0, 1.0)
		tr.position.y = float(_letter_top[h]) - LETTER_LIFT * near * near * (3.0 - 2.0 * near)
		tr.modulate.a = _edge_alpha(x)
		tr.visible = tr.modulate.a > 0.0
	var wp: Variant = _waypoint_position(cam.global_position)
	waypoint_bearing = NAN
	if wp != null:
		var d: Vector3 = (wp as Vector3) - cam.global_position
		if Vector2(d.x, d.z).length() > 0.5:
			waypoint_bearing = heading_of(d)
	if is_nan(waypoint_bearing):
		_waypoint.visible = false
	else:
		var x := x_of(waypoint_bearing)
		_waypoint.position.x = x - _waypoint.size.x * 0.5
		_waypoint.modulate.a = _edge_alpha(x)
		_waypoint.visible = _waypoint.modulate.a > 0.0
	_track.queue_redraw()


## True when the waypoint is shown on the strip.
func is_waypoint_visible() -> bool:
	return _waypoint != null and _waypoint.visible and visible


# ------------------------------------------------------------------ drawing

## Cheap repeatable hash for the line's distressing (stuck to the world, so
## the wear scrolls with the heading).
static func _hash(i: int) -> float:
	var h := (i * 374761393) ^ 668265263
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


func _gaps() -> Array:
	var g := [[CENTER_X - MARKER_GAP, CENTER_X + MARKER_GAP]]
	if _waypoint.visible:
		var wx := _waypoint.position.x + _waypoint.size.x * 0.5
		g.append([wx - WAYPOINT_GAP, wx + WAYPOINT_GAP])
	return g


func _in_gap(x: float, gaps: Array) -> bool:
	for g in gaps:
		if x > g[0] and x < g[1]:
			return true
	return false


func _draw_track() -> void:
	var gaps := _gaps()
	var t := _track
	# The line, in short pieces whose brightness is hashed by world position
	# (worn, slightly broken); a faint shadow keeps it legible on bright sky.
	var step := 6.0
	var shift := fposmod(heading * px_per_degree, step)
	var x := LINE_X0 - shift
	while x < LINE_X1:
		var x0 := maxf(x, LINE_X0)
		var x1 := minf(x + step, LINE_X1)
		var mid := (x0 + x1) * 0.5
		if not _in_gap(mid, gaps):
			var world := int(round((heading * px_per_degree + x - CENTER_X) / step))
			var h := _hash(world)
			var a := 0.78 + 0.22 * _hash(world + 7919)
			if h < 0.035:
				a *= 0.25  # a nick in the line
			var y := LINE_Y + (_hash(world + 104729) - 0.5) * 0.7
			t.draw_line(Vector2(x0, y + 1.5), Vector2(x1, y + 1.5), shadow_color, 6.0, true)
			t.draw_line(Vector2(x0, y), Vector2(x1, y), Color(line_color, a), 2.8, true)
		x += step
	_draw_glow(gaps)
	# Ticks every 22.5 degrees: cardinal ticks cross the line, 45s are tall
	# spindles, the rest short ones.
	var first := ceilf((heading - 120.0) / 22.5) * 22.5
	var deg := first
	while deg <= heading + 120.0:
		var tx := x_of(deg)
		var a := _edge_alpha(tx)
		if a > 0.0 and not _in_gap(tx, gaps):
			var k := int(round(fposmod(deg, 360.0) / 22.5)) % 16
			var c := Color(line_color, a)
			if k == 0:
				# North: a broken tick above the line, under the N.
				t.draw_line(Vector2(tx, LINE_Y - 37), Vector2(tx, LINE_Y - 25), c, 2.0, true)
				t.draw_line(Vector2(tx, LINE_Y - 20), Vector2(tx, LINE_Y - 8), c, 2.0, true)
				_spindle(t, tx, LINE_Y - 6, LINE_Y + 5, 3.0, c)
			elif k % 4 == 0:
				_spindle(t, tx, LINE_Y - 21, LINE_Y + 7, 2.6, c)
			elif k % 2 == 0:
				_spindle(t, tx, LINE_Y - 18, LINE_Y + 19, 4.6, c)
			else:
				_spindle(t, tx, LINE_Y - 10, LINE_Y + 12, 3.4, c)
		deg += 22.5


## A thin vertical tick, widest in the middle (like the hand-drawn ones).
func _spindle(t: Control, x: float, y0: float, y1: float, w: float, c: Color) -> void:
	var m := (y0 + y1) * 0.5
	var pts := PackedVector2Array([Vector2(x, y0), Vector2(x + w * 0.5, m), Vector2(x, y1), Vector2(x - w * 0.5, m)])
	t.draw_colored_polygon(pts, c)


## Warm glow along the line from the waypoint back towards the centre (and
## a shorter tail beyond it), brightest at the waypoint.
func _draw_glow(gaps: Array) -> void:
	if not _waypoint.visible:
		return
	var wx := _waypoint.position.x + _waypoint.size.x * 0.5
	var dir := -signf(wx - CENTER_X)
	if dir == 0.0:
		return
	var fade := _waypoint.modulate.a
	var t := _track
	var step := 5.0
	for side in [[dir, GLOW_INNER], [-dir, GLOW_OUTER]]:
		var sgn: float = side[0]
		var length: float = side[1]
		var d := 0.0
		while d < length:
			var xa := wx + sgn * d
			var xb := wx + sgn * minf(d + step, length)
			var mid := (xa + xb) * 0.5
			if mid > LINE_X0 and mid < LINE_X1 and not _in_gap(mid, gaps):
				var k := 1.0 - (d + step * 0.5) / length
				var a := k * k * fade * _edge_alpha(mid)
				t.draw_line(Vector2(xa, LINE_Y), Vector2(xb, LINE_Y), Color(glow_color, 0.22 * a), 11.0, true)
				t.draw_line(Vector2(xa, LINE_Y), Vector2(xb, LINE_Y), Color(glow_color.lerp(line_color, 0.4), 0.75 * a), 3.4, true)
			d += step
