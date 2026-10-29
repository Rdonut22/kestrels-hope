extends Control

## Power reroute puzzle on the engineering computer: a phosphor-green
## schematic of conduit tiles. Rotate tiles (click, or arrows + E) so power
## from backup cell B reaches all three outputs, around the cracked main
## cell. Emits solved once every output is lit.

signal solved
signal closed

const COLS := 6
const ROWS := 4
const N := 1
const E := 2
const S := 4
const W := 8
const GREEN := Color(0.45, 1.0, 0.55)
const DIM := Color(0.2, 0.45, 0.25)
const AMBER := Color(1.0, 0.7, 0.25)
const RED := Color(1.0, 0.3, 0.25)

## Where cell B feeds in (row, from the left edge) and the outputs (row,
## off the right edge).
const SOURCE_ROW := 1
const OUTPUTS := [[0, "LIGHTS + LIFE SUPPORT"], [2, "GALLEY + LOUNGE"], [3, "COCKPIT SYSTEMS"]]
## The solved layout, row by row (bit masks); -1 marks dead tiles over the
## cracked main cell.
const SOLUTION := [
	[E | W, S | E, W | E, W | E, W | E, W | E],
	[W | E, W | N | S, -1, -1, -1, S | W],
	[N | E, N | E, W | E, W | S | E, W | E, W | E],
	[E | S, N | W, N | S, N | E, W | E, W | E],
]

var _tiles := []  # current masks, [row][col]
var _powered := {}
var _cursor := Vector2i(0, SOURCE_ROW)
var _done := false
var _cell := 72.0
var _origin := Vector2.ZERO
var _sfx: AudioStreamPlayer
var _font: Font = load("res://ui/fonts/JetBrainsMono-Bold.ttf")
var _mono: Font = load("res://ui/fonts/JetBrainsMono-Regular.ttf")


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -6.0
	add_child(_sfx)
	hide()


func open() -> void:
	_done = false
	if _tiles.is_empty():
		_scramble()
	_flow()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


# Turn every live tile away from its solved position (fixed seed, so the
# puzzle is the same every time).
func _scramble() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4023
	for r in ROWS:
		var row := []
		for c in COLS:
			var m: int = SOLUTION[r][c]
			if m > 0:
				for k in rng.randi_range(1, 3):
					m = _rot(m)
			row.append(m)
		_tiles.append(row)


static func _rot(m: int) -> int:
	return ((m << 1) | (m >> 3)) & 15


func _flow() -> void:
	_powered.clear()
	var start := Vector2i(0, SOURCE_ROW)
	if _tiles[SOURCE_ROW][0] > 0 and _tiles[SOURCE_ROW][0] & W:
		var todo := [start]
		_powered[start] = true
		while not todo.is_empty():
			var p: Vector2i = todo.pop_back()
			var m: int = _tiles[p.y][p.x]
			for d in [[N, Vector2i(0, -1), S], [E, Vector2i(1, 0), W], [S, Vector2i(0, 1), N], [W, Vector2i(-1, 0), E]]:
				if not (m & d[0]):
					continue
				var q: Vector2i = p + d[1]
				if q.x < 0 or q.y < 0 or q.x >= COLS or q.y >= ROWS or _powered.has(q):
					continue
				var mq: int = _tiles[q.y][q.x]
				if mq > 0 and mq & d[2]:
					_powered[q] = true
					todo.append(q)
	queue_redraw()


func _output_lit(row: int) -> bool:
	var p := Vector2i(COLS - 1, row)
	return _powered.has(p) and _tiles[row][COLS - 1] & E


func _all_lit() -> bool:
	for o in OUTPUTS:
		if not _output_lit(o[0]):
			return false
	return true


func _turn(p: Vector2i) -> void:
	if _done or _tiles[p.y][p.x] <= 0:
		return
	_tiles[p.y][p.x] = _rot(_tiles[p.y][p.x])
	_sfx.stream = load("res://audio/sfx/click.ogg")
	_sfx.pitch_scale = randf_range(0.9, 1.1)
	_sfx.play()
	_flow()
	if _all_lit():
		_finish()


func _finish() -> void:
	_done = true
	_sfx.stream = load("res://audio/sfx/power_on.ogg")
	_sfx.pitch_scale = 1.0
	_sfx.play()
	queue_redraw()
	await get_tree().create_timer(1.8).timeout
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	solved.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := Vector2i(((event.position - _origin) / _cell).floor())
		if p.x >= 0 and p.y >= 0 and p.x < COLS and p.y < ROWS:
			_cursor = p
			_turn(p)
		accept_event()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var handled := true
	if event.is_action_pressed("ui_cancel"):
		if not _done:
			close()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_cursor.x = maxi(0, _cursor.x - 1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_cursor.x = mini(COLS - 1, _cursor.x + 1)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_forward"):
		_cursor.y = maxi(0, _cursor.y - 1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_back"):
		_cursor.y = mini(ROWS - 1, _cursor.y + 1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_turn(_cursor)
	else:
		handled = false
	if handled:
		queue_redraw()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var vs := size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.01, 0.03, 0.02, 0.94))
	_cell = minf(vs.x * 0.09, vs.y * 0.13)
	var grid := Vector2(COLS, ROWS) * _cell
	_origin = (vs - grid) / 2.0 + Vector2(-_cell * 0.6, _cell * 0.3)
	var t := Time.get_ticks_msec() * 0.001
	# Frame and title.
	var frame := Rect2(_origin - Vector2(_cell * 2.6, _cell * 1.6), grid + Vector2(_cell * 7.0, _cell * 2.6))
	draw_rect(frame, DIM, false, 2.0)
	draw_string(_font, frame.position + Vector2(18, 34), "KESTREL B26 // POWER ROUTING", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, GREEN)
	draw_string(_mono, frame.position + Vector2(18, 58), "MEKI LINK ACTIVE   -   ROTATE CONDUITS TO FEED ALL OUTPUTS FROM CELL B", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, DIM.lightened(0.3))
	# Source.
	var src := _origin + Vector2(0, (SOURCE_ROW + 0.5) * _cell)
	draw_rect(Rect2(src - Vector2(_cell * 2.1, _cell * 0.35), Vector2(_cell * 1.5, _cell * 0.7)), GREEN, false, 2.0)
	draw_string(_font, src - Vector2(_cell * 2.0, -6), "CELL B", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, GREEN)
	draw_line(src - Vector2(_cell * 0.6, 0), src, GREEN, 4.0)
	# Cracked main cell over the dead tiles.
	var dead := Rect2(_origin + Vector2(2, 1) * _cell, Vector2(3, 1) * _cell)
	draw_rect(dead, Color(RED, 0.08 + 0.05 * sin(t * 4.0)))
	draw_rect(dead, RED, false, 2.0)
	draw_string(_mono, dead.position + Vector2(10, _cell * 0.58), "CELL A  -  CRACKED  -  NO ROUTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, RED)
	# Tiles.
	for r in ROWS:
		for c in COLS:
			var m: int = _tiles[r][c]
			if m <= 0:
				continue
			var p := Vector2i(c, r)
			var center := _origin + (Vector2(c, r) + Vector2(0.5, 0.5)) * _cell
			var lit := _powered.has(p)
			var col := (GREEN if not _done else GREEN.lightened(0.4 + 0.3 * sin(t * 10.0))) if lit else DIM
			draw_rect(Rect2(center - Vector2.ONE * _cell * 0.46, Vector2.ONE * _cell * 0.92), Color(col, 0.08), true)
			for d in [[N, Vector2(0, -1)], [E, Vector2(1, 0)], [S, Vector2(0, 1)], [W, Vector2(-1, 0)]]:
				if m & d[0]:
					draw_line(center, center + d[1] * _cell * 0.5, col, 6.0 if lit else 4.0)
			draw_circle(center, _cell * 0.09, col)
	# Cursor.
	draw_rect(Rect2(_origin + Vector2(_cursor) * _cell + Vector2.ONE * 3, Vector2.ONE * (_cell - 6)), AMBER, false, 2.0)
	# Outputs.
	for o in OUTPUTS:
		var row: int = o[0]
		var p := _origin + Vector2(COLS * _cell, (row + 0.5) * _cell)
		var on := _output_lit(row)
		var col := GREEN if on else AMBER
		draw_line(p, p + Vector2(_cell * 0.5, 0), col, 4.0)
		draw_circle(p + Vector2(_cell * 0.62, 0), 7.0, col if on else Color(col, 0.4 + 0.4 * sin(t * 5.0)))
		draw_string(_mono, p + Vector2(_cell * 0.85, 6), ("[OK] " if on else "[--] ") + String(o[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
	var foot := frame.position + Vector2(18, frame.size.y - 18)
	var msg := "ROUTE COMPLETE  -  BACKUP CELL ONLINE" if _done else "CLICK / E  ROTATE      ARROWS  MOVE      ESC  STEP AWAY"
	draw_string(_mono, foot, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GREEN if _done else DIM.lightened(0.3))
