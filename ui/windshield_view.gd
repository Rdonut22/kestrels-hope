extends Control

## What the windshield HUD draws (inside a SubViewport, projected onto the
## cockpit glass by cockpit_panel.gd). Retro vector style: thin phosphor
## green lines, amber warnings, red damage. One main view and a row of tabs
## along the bottom, each with an unread badge until it's been looked at.

signal tab_shown(tab: String)

const TABS := ["ALTITUDE", "DIAGNOSTICS", "COMMS", "NAV"]
const GREEN := Color(0.45, 1.0, 0.55)
const DIM := Color(0.22, 0.5, 0.28)
const AMBER := Color(1.0, 0.72, 0.25)
const RED := Color(1.0, 0.3, 0.25)

## Ship systems for the diagnostics screen: name, status, colour, notes,
## and which wireframe parts light up.
const SYSTEMS := [
	{"name": "REACTOR", "status": "DEGRADED", "col": "amber", "parts": ["reactor"],
		"rows": [["CELL A", "CRACKED"], ["CELL B", "ONLINE 41%"], ["ROUTING", "MEKI / MANUAL"], ["CORE TEMP", "412 K"]]},
	{"name": "MAIN DRIVE", "status": "FAULT", "col": "red", "parts": ["engines_port", "engines_stbd"],
		"rows": [["STBD ARRAY", "POWERED"], ["PORT ARRAY", "NO POWER"], ["CONDUIT P-3", "SEVERED"], ["THRUST", "ASYMMETRIC"]]},
	{"name": "NAV ARRAY", "status": "08%", "col": "red", "parts": ["dish"],
		"rows": [["DISH", "MISALIGNED"], ["STAR FIX", "43 DAYS OLD"], ["SURFACE SCAN", "PARTIAL"], ["GUIDANCE", "DEGRADED"]]},
	{"name": "COMMS", "status": "DEGRADED", "col": "amber", "parts": ["antenna"],
		"rows": [["LONG RANGE", "NO CARRIER"], ["BEACON", "TRANSMITTING"], ["REPLIES", "NONE"], ["", ""]]},
	{"name": "LIFE SUPPORT", "status": "OK", "col": "green", "parts": ["hull_mid"],
		"rows": [["O2 RESERVE", "ADEQUATE"], ["SCRUBBERS", "NOMINAL"], ["CABIN", "21 C"], ["", ""]]},
	{"name": "HULL", "status": "87%", "col": "amber", "parts": ["hull"],
		"rows": [["BREACHES", "NONE"], ["SCORING", "AFT / PORT"], ["AIRLOCK", "SEALED"], ["", ""]]},
	{"name": "MEKI LINK", "status": "ONLINE", "col": "green", "parts": ["reactor"],
		"rows": [["DRONE", "ONLINE"], ["SHIP LINK", "STABLE"], ["MEMORY", "REBUILDING"], ["HALE_PRIVATE.LOG", "%FILE%"]]},
]

var tab := 0
var system := 0
var on := false
## While true the main view shows the landing warnings.
var confirm_landing := false
var _boot := 0.0  # 0..1 while booting
var _flicker := 0.0  # brief "insufficient power" flash
var _font: Font = load("res://ui/fonts/JetBrainsMono-Regular.ttf")
var _bold: Font = load("res://ui/fonts/JetBrainsMono-Bold.ttf")
var _ship_edges := []  # [a, b, part]
var _globe_dots := []


func _ready() -> void:
	_build_ship()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# Land masses as clusters of dots on the globe.
	for k in 9:
		var c := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 0.7), rng.randf_range(-1, 1)).normalized()
		for i in 70:
			var p := (c + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.32).normalized()
			_globe_dots.append(p)


func boot() -> void:
	on = true
	var tw := create_tween()
	tw.tween_property(self, "_boot", 1.0, 2.6)


func flash_no_power() -> void:
	_flicker = 1.2


func select_tab(i: int) -> void:
	tab = wrapi(i, 0, TABS.size())
	confirm_landing = false
	tab_shown.emit(TABS[tab])


func current_tab() -> String:
	return TABS[tab]


func _process(delta: float) -> void:
	_flicker = maxf(0.0, _flicker - delta)
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var s := size
	if not on:
		if _flicker > 0.0 and fmod(t, 0.2) < 0.13:
			_text(Vector2(s.x / 2.0, s.y / 2.0), "INSUFFICIENT POWER", 40, AMBER, true, true)
			_text(Vector2(s.x / 2.0, s.y / 2.0 + 44), "REACTOR 12%  //  REQUIRED 40%", 20, AMBER, false, true)
		return
	var a := clampf(_boot * 1.4, 0.0, 1.0)
	modulate.a = 0.35 + 0.65 * a if _boot < 1.0 else 1.0
	# Frame and header.
	var m := 18.0
	var frame := Rect2(m, m, s.x - m * 2.0, s.y - m * 2.0)
	_corners(frame, 26.0, GREEN)
	_text(Vector2(40, 52), "KESTREL B26 // FLIGHT SYSTEMS", 22, GREEN, true)
	_text(Vector2(s.x - 40, 52), "PWR 41%%   D+43   %s" % _clock(t), 20, GREEN, false, false, true)
	draw_line(Vector2(40, 66), Vector2(s.x - 40, 66), DIM, 1.0)
	if _boot < 1.0:
		var lines := ["KESTREL OS 4.02 ............ OK", "BACKUP CELL ROUTE .......... OK", "FLIGHT DATA ................ OK",
			"NAV ARRAY .................. DEGRADED", "COMMS ...................... DEGRADED", "MEKI LINK .................. ONLINE"]
		for i in int(_boot * (lines.size() + 1)):
			if i < lines.size():
				_text(Vector2(70, 120 + i * 34), lines[i], 20, AMBER if "DEGRADED" in lines[i] else GREEN)
		return
	# Main view.
	var view := Rect2(40, 82, s.x - 80, s.y - 82 - 130)
	if confirm_landing:
		_draw_landing(view, t)
	else:
		match TABS[tab]:
			"ALTITUDE":
				_draw_altitude(view, t)
			"DIAGNOSTICS":
				_draw_diagnostics(view, t)
			"COMMS":
				_draw_comms(view, t)
			"NAV":
				_draw_nav(view, t)
	_draw_tabs(Rect2(40, s.y - 120, s.x - 80, 86), t)


# ---------- tabs ----------

func _draw_tabs(r: Rect2, t: float) -> void:
	var w := r.size.x / TABS.size()
	var gs := Game.state()
	for i in TABS.size():
		var cell := Rect2(r.position + Vector2(i * w + 4, 0), Vector2(w - 8, r.size.y))
		var sel := i == tab
		draw_rect(cell, Color(GREEN, 0.1) if sel else Color(0, 0, 0, 0))
		draw_rect(cell, GREEN if sel else DIM, false, 2.0 if sel else 1.0)
		_text(cell.position + Vector2(14, 30), TABS[i], 20, GREEN if sel else DIM.lightened(0.3), true)
		var sub := ""
		match TABS[i]:
			"ALTITUDE":
				sub = "ALT 412 KM"
			"DIAGNOSTICS":
				sub = "3 FAULTS"
			"COMMS":
				sub = "NO CARRIER"
			"NAV":
				sub = "SIGNAL" if not gs.has_flag("hud_all_seen") else "LANDING READY"
		_text(cell.position + Vector2(14, 62), sub, 16, AMBER if TABS[i] in ["DIAGNOSTICS", "NAV"] else DIM.lightened(0.2))
		if _unread(TABS[i]) and fmod(t, 1.0) < 0.65:
			draw_circle(cell.position + Vector2(cell.size.x - 18, 18), 7.0, AMBER)


func _unread(tab_name: String) -> bool:
	var gs := Game.state()
	if not gs.has_flag("seen_tab_" + tab_name.to_lower()):
		return true
	return tab_name == "NAV" and gs.has_flag("hud_all_seen") and not gs.has_flag("seen_landing_ready")


# ---------- altitude ----------

func _draw_altitude(v: Rect2, t: float) -> void:
	var c := v.position + Vector2(v.size.x * 0.36, v.size.y * 0.5)
	var rad := v.size.y * 0.42
	draw_arc(c, rad, 0, TAU, 64, DIM, 1.5)
	# Drifting horizon line and pitch ladder.
	var roll := sin(t * 0.21) * 0.18
	var pitch := sin(t * 0.13) * 18.0
	var dir := Vector2(cos(roll), sin(roll))
	var nrm := Vector2(-dir.y, dir.x)
	var h0 := c + nrm * pitch
	draw_line(h0 - dir * rad * 0.95, h0 + dir * rad * 0.95, GREEN, 2.5)
	for k in [-2, -1, 1, 2]:
		var p: Vector2 = h0 - nrm * (k * 34.0)
		var half := rad * (0.22 if k % 2 else 0.36)
		_dashed(p - dir * half, p + dir * half, DIM, 1.5, 8.0)
		_text(p + dir * (half + 8), str(k * 10), 14, DIM.lightened(0.2))
	draw_line(c - Vector2(46, 0), c - Vector2(14, 0), AMBER, 3.0)
	draw_line(c + Vector2(14, 0), c + Vector2(46, 0), AMBER, 3.0)
	draw_circle(c, 4.0, AMBER)
	# Readouts.
	var x := v.position.x + v.size.x * 0.6
	var rows := [["ALTITUDE", "%.1f KM" % (412.0 + sin(t * 0.05) * 0.4)], ["ORBITAL V", "7.62 KM/S"], ["PERIOD", "93 MIN"],
		["INCLINATION", "21.4 DEG"], ["ORBIT", "STABLE (DEGRADING)"]]
	for i in rows.size():
		_text(Vector2(x, v.position.y + 40 + i * 44), rows[i][0], 16, DIM.lightened(0.25))
		_text(Vector2(x + 160, v.position.y + 40 + i * 44), rows[i][1], 17, AMBER if "DEGRADING" in rows[i][1] else GREEN)
	var fy := v.position.y + 40 + rows.size() * 44 + 10
	_text(Vector2(x, fy), "FUEL", 16, DIM.lightened(0.25))
	_bar(Rect2(x + 160, fy - 16, 200, 18), 0.34, AMBER)


# ---------- diagnostics ----------

func _build_ship() -> void:
	# A stylised Kestrel: hull box, cockpit block, wings, engines, dish.
	var box := func(a: Vector3, b: Vector3, part: String) -> void:
		var p := []
		for i in 8:
			p.append(Vector3(a.x if i & 1 == 0 else b.x, a.y if i & 2 == 0 else b.y, a.z if i & 4 == 0 else b.z))
		for e in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
			_ship_edges.append([p[e[0]], p[e[1]], part])
	box.call(Vector3(-0.9, -0.25, -1.2), Vector3(0.7, 0.3, 1.2), "hull")
	box.call(Vector3(0.25, -0.15, -1.7), Vector3(0.7, 0.25, -1.2), "hull")
	box.call(Vector3(-0.2, -0.1, -0.2), Vector3(0.2, 0.25, 0.2), "hull_mid")
	box.call(Vector3(0.3, -0.2, -0.75), Vector3(0.45, 0.2, -0.6), "reactor")
	for side in [-1.0, 1.0]:
		var root: float = 0.7 if side > 0 else -0.9
		var tip: float = root + side * 1.1
		_ship_edges.append([Vector3(root, 0.0, -0.9), Vector3(tip, -0.15, -0.2), "hull"])
		_ship_edges.append([Vector3(tip, -0.15, -0.2), Vector3(tip, -0.15, 0.6), "hull"])
		_ship_edges.append([Vector3(tip, -0.15, 0.6), Vector3(root, 0.0, 0.9), "hull"])
	for i in 3:
		box.call(Vector3(-0.75 + i * 0.22, -0.18, 1.2), Vector3(-0.6 + i * 0.22, 0.02, 1.45), "engines_port")
		box.call(Vector3(0.05 + i * 0.22, -0.18, 1.2), Vector3(0.2 + i * 0.22, 0.02, 1.45), "engines_stbd")
	_ship_edges.append([Vector3(-0.2, 0.3, 0.4), Vector3(-0.2, 0.55, 0.4), "dish"])
	box.call(Vector3(-0.38, 0.55, 0.3), Vector3(-0.02, 0.6, 0.5), "dish")
	_ship_edges.append([Vector3(0.4, 0.3, 0.8), Vector3(0.4, 0.8, 0.8), "antenna"])
	_ship_edges.append([Vector3(0.4, 0.8, 0.8), Vector3(0.5, 0.72, 0.8), "antenna"])


func _draw_diagnostics(v: Rect2, t: float) -> void:
	var sys: Dictionary = SYSTEMS[system]
	var c := v.position + Vector2(v.size.x * 0.3, v.size.y * 0.52)
	var sc := v.size.y * 0.42
	var basis := Basis(Vector3.RIGHT, 0.45) * Basis(Vector3.UP, t * 0.35)
	for e in _ship_edges:
		var a: Vector3 = basis * e[0]
		var b: Vector3 = basis * e[1]
		var part: String = e[2]
		var hot: bool = part in sys.parts
		var col := DIM
		if part == "engines_port":
			col = Color(RED, 0.5 + 0.5 * sin(t * 6.0)) if hot or fmod(t, 1.2) < 0.6 else Color(RED, 0.35)
		elif hot:
			col = _col(sys.col)
		draw_line(c + Vector2(a.x, -a.y) * sc, c + Vector2(b.x, -b.y) * sc, col, 2.5 if hot else 1.2)
	# File card on the right.
	var x := v.position.x + v.size.x * 0.6
	var y := v.position.y + 10
	var card := Rect2(x, y, v.size.x * 0.4, v.size.y - 20)
	draw_rect(card, DIM, false, 1.0)
	_text(card.position + Vector2(16, 34), "< %s >" % sys.name, 22, GREEN, true)
	_text(card.position + Vector2(card.size.x - 16, 34), "%d/%d" % [system + 1, SYSTEMS.size()], 16, DIM.lightened(0.2), false, false, true)
	_text(card.position + Vector2(16, 66), "STATUS  " + sys.status, 18, _col(sys.col))
	draw_line(card.position + Vector2(10, 80), card.position + Vector2(card.size.x - 10, 80), DIM, 1.0)
	for i in sys.rows.size():
		var row: Array = sys.rows[i]
		var val: String = row[1].replace("%FILE%", "%d%%" % int(Game.state().hale_file))
		_text(card.position + Vector2(16, 110 + i * 32), row[0], 15, DIM.lightened(0.25))
		_text(card.position + Vector2(card.size.x - 16, 110 + i * 32), val, 15, GREEN, false, false, true)
	# Live trace along the bottom of the card.
	var gy := card.end.y - 40
	var prev := Vector2.ZERO
	for i in 60:
		var px := card.position.x + 16 + i * (card.size.x - 32) / 59.0
		var p := Vector2(px, gy + sin(i * 0.35 + t * 4.0 + system) * 14.0 * (0.4 if sys.col == "red" and fmod(t, 1.5) < 0.3 else 1.0))
		if i > 0:
			draw_line(prev, p, _col(sys.col), 1.5)
		prev = p
	_text(Vector2(v.position.x + 10, v.end.y - 6), "W / S  CYCLE SYSTEMS", 14, DIM.lightened(0.2))


# ---------- comms ----------

func _draw_comms(v: Rect2, t: float) -> void:
	var rows := [["ANGEL (HOME)", "NO CARRIER", RED], ["USHIDA DISPATCH", "NO RESPONSE", AMBER],
		["EMERGENCY BEACON", "TRANSMITTING  -  NO REPLY", AMBER]]
	_text(v.position + Vector2(10, 34), "LONG RANGE // CHANNELS", 20, GREEN, true)
	for i in rows.size():
		var y := v.position.y + 80 + i * 70
		draw_rect(Rect2(v.position.x + 10, y, v.size.x * 0.55, 54), DIM, false, 1.0)
		_text(Vector2(v.position.x + 26, y + 34), rows[i][0], 20, GREEN)
		var col: Color = rows[i][2]
		if fmod(t + i * 0.3, 1.4) < 1.0:
			_text(Vector2(v.position.x + v.size.x * 0.55 - 6, y + 34), rows[i][1], 16, col, false, false, true)
	# Static on the scope.
	var scope := Rect2(v.position.x + v.size.x * 0.62, v.position.y + 80, v.size.x * 0.36, 194)
	draw_rect(scope, DIM, false, 1.0)
	var prev := Vector2.ZERO
	for i in 80:
		var p := Vector2(scope.position.x + i * scope.size.x / 79.0,
			scope.get_center().y + (randf() - 0.5) * 40.0 * (1.0 if fmod(t, 3.0) > 0.4 else 3.0))
		if i > 0:
			draw_line(prev, p, DIM.lightened(0.2), 1.0)
		prev = p
	_text(scope.position + Vector2(10, scope.size.y + 26), "BEACON PULSE  1 / 30 S", 14, DIM.lightened(0.2))


# ---------- nav ----------

func _draw_nav(v: Rect2, t: float) -> void:
	var c := v.position + Vector2(v.size.x * 0.3, v.size.y * 0.5)
	var rad := v.size.y * 0.44
	var spin := t * 0.12
	draw_arc(c, rad, 0, TAU, 72, GREEN, 2.0)
	var rot := Basis(Vector3.RIGHT, 0.35) * Basis(Vector3.UP, spin)
	# Latitude and longitude lines (front half only).
	for lat in [-60, -30, 0, 30, 60]:
		_globe_line(c, rad, rot, func(k: float) -> Vector3:
			var la := deg_to_rad(lat)
			return Vector3(cos(la) * cos(k), sin(la), cos(la) * sin(k)), DIM)
	for lon in range(0, 180, 30):
		_globe_line(c, rad, rot, func(k: float) -> Vector3:
			var lo := deg_to_rad(lon)
			return Vector3(cos(k) * cos(lo), sin(k), cos(k) * sin(lo)), DIM)
	for d in _globe_dots:
		var p: Vector3 = rot * d
		if p.z > 0:
			draw_circle(c + Vector2(p.x, -p.y) * rad, 1.6, Color(GREEN, 0.75))
	# The signal.
	var sig: Vector3 = rot * Vector3(0.45, 0.3, 0.84).normalized()
	if sig.z > 0:
		var sp := c + Vector2(sig.x, -sig.y) * rad
		var pulse := fmod(t, 1.4) / 1.4
		draw_arc(sp, 6.0 + pulse * 30.0, 0, TAU, 24, Color(RED, 1.0 - pulse), 2.0)
		draw_circle(sp, 5.0, RED)
		draw_line(sp, sp + Vector2(40, -40), RED, 1.0)
		_text(sp + Vector2(44, -44), "UNKNOWN SIGNAL", 14, RED)
	# Orbit and the Kestrel.
	var orbit := Rect2(c - Vector2(rad * 1.25, rad * 0.32), Vector2(rad * 2.5, rad * 0.64))
	var prev := Vector2.ZERO
	for i in 73:
		var k := TAU * i / 72.0
		var p := orbit.get_center() + Vector2(cos(k) * orbit.size.x / 2.0, sin(k) * orbit.size.y / 2.0)
		if i > 0 and i % 2 == 0:
			draw_line(prev, p, AMBER, 1.0)
		prev = p
	var ka := t * 0.25
	var kp := orbit.get_center() + Vector2(cos(ka) * orbit.size.x / 2.0, sin(ka) * orbit.size.y / 2.0)
	draw_rect(Rect2(kp - Vector2(6, 6), Vector2(12, 12)), AMBER, false, 2.0)
	_text(kp + Vector2(10, -10), "KESTREL", 13, AMBER)
	# Readouts.
	var x := v.position.x + v.size.x * 0.58
	var y := v.position.y + 26
	var gs := Game.state()
	var rows := [["SOURCE", "UNKNOWN // OUTPUT OFF-SCALE", RED], ["BEARING", "032.6  /  RANGE 418 KM", GREEN],
		["", "", GREEN], ["ATMOSPHERE", "O2 21.3%   N2 77%", GREEN], ["PRESSURE", "0.94 ATM", GREEN],
		["SURFACE", "14 C   //   0.94 G", GREEN], ["TERRAIN", "TEMPERATE FOREST", GREEN], ["", "MOUNTAIN RANGES, FRESH WATER", GREEN],
		["", "RING STRUCTURE NEAR SOURCE", AMBER]]
	for i in rows.size():
		_text(Vector2(x, y + i * 30), rows[i][0], 14, DIM.lightened(0.25))
		_text(Vector2(x + 118, y + i * 30), rows[i][1], 14, rows[i][2])
	var by := y + rows.size() * 30 + 16
	if gs.has_flag("landing_confirmed"):
		_text(Vector2(x, by), "DESCENT PROGRAM ARMED", 18, AMBER, true)
		_text(Vector2(x, by + 26), "AWAITING BURN WINDOW", 14, AMBER)
	elif gs.has_flag("hud_all_seen"):
		var box := Rect2(x, by - 24, 330, 40)
		draw_rect(box, Color(AMBER, 0.12 + 0.08 * sin(t * 4.0)))
		draw_rect(box, AMBER, false, 2.0)
		_text(box.position + Vector2(14, 28), "[E]  INITIATE LANDING", 18, AMBER, true)
	else:
		_text(Vector2(x, by), "LANDING CALCULATION PENDING", 15, DIM.lightened(0.3))
		_text(Vector2(x, by + 22), "SYSTEM CHECK INCOMPLETE", 15, DIM.lightened(0.3))


func _draw_landing(v: Rect2, t: float) -> void:
	var box := Rect2(v.position + Vector2(v.size.x * 0.18, 10), Vector2(v.size.x * 0.64, v.size.y - 20))
	draw_rect(box, Color(0, 0, 0, 0.4))
	draw_rect(box, AMBER, false, 2.0)
	_text(box.position + Vector2(box.size.x / 2.0, 44), "INITIATE LANDING", 26, AMBER, true, true)
	var rows := [["PORT THRUSTER ARRAY", "NO POWER", RED], ["NAV ARRAY", "08%  GUIDANCE DEGRADED", RED],
		["HULL INTEGRITY", "87%", AMBER], ["ESTIMATED SUCCESS", "23%", RED]]
	for i in rows.size():
		var y := box.position.y + 100 + i * 40
		if fmod(t + i * 0.2, 1.2) < 0.9:
			_text(Vector2(box.position.x + 30, y), "!", 20, rows[i][2], true)
		_text(Vector2(box.position.x + 60, y), rows[i][0], 17, GREEN)
		_text(Vector2(box.end.x - 30, y), rows[i][1], 17, rows[i][2], false, false, true)
	_text(box.position + Vector2(box.size.x / 2.0, box.size.y - 30), "[E] CONFIRM          [ESC] ABORT", 20, AMBER, true, true)


# ---------- helpers ----------

func _globe_line(c: Vector2, rad: float, rot: Basis, f: Callable, col: Color) -> void:
	var prev := Vector3.ZERO
	for i in 49:
		var p: Vector3 = rot * (f.call(TAU * i / 48.0) as Vector3)
		if i > 0 and p.z > 0 and prev.z > 0:
			draw_line(c + Vector2(prev.x, -prev.y) * rad, c + Vector2(p.x, -p.y) * rad, col, 1.0)
		prev = p


func _corners(r: Rect2, l: float, col: Color) -> void:
	for p in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if p.x < r.get_center().x else -1.0
		var sy := 1.0 if p.y < r.get_center().y else -1.0
		draw_line(p, p + Vector2(l * sx, 0), col, 2.0)
		draw_line(p, p + Vector2(0, l * sy), col, 2.0)


func _dashed(a: Vector2, b: Vector2, col: Color, w: float, dash: float) -> void:
	var n := int(a.distance_to(b) / dash)
	for i in range(0, n, 2):
		draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), col, w)


func _bar(r: Rect2, f: float, col: Color) -> void:
	draw_rect(r, DIM, false, 1.0)
	draw_rect(Rect2(r.position + Vector2(3, 3), Vector2((r.size.x - 6) * f, r.size.y - 6)), col)


func _col(name: String) -> Color:
	return {"green": GREEN, "amber": AMBER, "red": RED}.get(name, GREEN)


func _clock(t: float) -> String:
	return "%02d:%02d" % [int(t / 60.0) % 24, int(t) % 60]


func _text(pos: Vector2, text: String, size: int, col: Color, bold := false, center := false, right := false) -> void:
	var f := _bold if bold else _font
	var p := pos
	if center or right:
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		p.x -= w / 2.0 if center else w
	draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
