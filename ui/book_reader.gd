extends Control

## Cozy book reader over the HUD, in two modes: picking a book off the shelf
## (cover cards), and reading one as an open two-page spread. Each page is a
## RichTextLabel holding the whole book, scrolled to its own run of lines, so
## the book is laid out once and page turns are instant. Your page in each
## book is remembered (see Library.set_bookmark).

signal book_taken(id: String)

const PAPER := Color(0.95, 0.91, 0.82)
const INK := Color(0.2, 0.15, 0.1)
const PAGE := Vector2(470, 570)
const MARGIN := Vector2(44, 52)
const FONT_SIZE := 18
const LINE_GAP := 5

var _mode := ""
var _book := {}
var _loaded_id := ""
var _spread := 0  # index of the left-hand page
var _lines_per_page := 1
var _page_count := 1
var _choice := 0
var _regular: Font = load("res://ui/fonts/LiberationSerif-Regular.ttf")
var _italic: Font = load("res://ui/fonts/LiberationSerif-Italic.ttf")
var _bold: Font = load("res://ui/fonts/LiberationSerif-Bold.ttf")
var _shelf: Control
var _cards: Array[Button] = []
var _book_view: Control
var _pages: Array[RichTextLabel] = []
var _numbers: Array[Label] = []
var _heads: Array[Label] = []
var _turn: AudioStreamPlayer


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.02, 0.62)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	_turn = AudioStreamPlayer.new()
	_turn.stream = load("res://audio/page_turn.ogg")
	_turn.volume_db = -6.0
	add_child(_turn)
	_build_shelf()
	_build_book()


# ---------- shelf ----------

func open_shelf() -> void:
	_mode = "shelf"
	_shelf.show()
	_book_view.hide()
	for i in _cards.size():
		_cards[i].get_node("Note").text = _note(Library.BOOKS[i])
	_select(_choice)
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_shelf() -> void:
	_shelf = Control.new()
	_shelf.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(_shelf)
	var title := _text(_shelf, "The Bookshelf", _italic, 34, Color(0.96, 0.9, 0.78))
	_pin(title, Vector2(0.5, 0.0), Rect2(-200, 60, 400, 50))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 48)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pin(row, Vector2(0.5, 0.5), Rect2(-300, -170, 600, 330))
	_shelf.add_child(row)
	for i in Library.BOOKS.size():
		var book: Dictionary = Library.BOOKS[i]
		var card := Button.new()
		card.custom_minimum_size = Vector2(220, 320)
		card.focus_mode = FOCUS_NONE
		for state in ["normal", "hover", "pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = book.color if state != "hover" else book.color.lightened(0.08)
			box.set_corner_radius_all(6)
			box.border_color = Color(0.85, 0.7, 0.4)
			box.set_border_width_all(2)
			box.shadow_color = Color(0, 0, 0, 0.5)
			box.shadow_size = 10
			card.add_theme_stylebox_override(state, box)
		card.pressed.connect(_take.bind(i))
		card.mouse_entered.connect(_select.bind(i))
		row.add_child(card)
		_cards.append(card)
		var gold := Color(0.92, 0.8, 0.5)
		# Covers break long titles onto two lines: "The Time / Machine".
		var words := String(book.title).split(" ")
		var cover_title: String = " ".join(words.slice(0, words.size() - 1)) + "\n" + words[-1] if words.size() > 2 else book.title
		var t := _text(card, cover_title, _bold, 27, gold)
		t.position = Vector2(16, 60)
		t.size = Vector2(188, 120)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var a := _text(card, book.author, _italic, 17, gold.darkened(0.15))
		a.autowrap_mode = TextServer.AUTOWRAP_WORD
		a.position = Vector2(16, 190)
		a.size = Vector2(188, 50)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var note := _text(card, "", _italic, 14, gold.darkened(0.3))
		note.name = "Note"
		note.position = Vector2(16, 270)
		note.size = Vector2(188, 30)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _text(_shelf, "A / D  choose      E  take it      Esc  close", _italic, 17, Color(0.85, 0.8, 0.7))
	_pin(hint, Vector2(0.5, 1.0), Rect2(-300, -80, 600, 30))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _note(book: Dictionary) -> String:
	if not Library.has_pages(book):
		return "(pages missing)"
	var page := Library.bookmark(book.id)
	return "bookmark at page %d" % (page + 1) if page > 0 else book.year


func _select(i: int) -> void:
	_choice = clampi(i, 0, _cards.size() - 1)
	for k in _cards.size():
		_cards[k].modulate = Color.WHITE if k == _choice else Color(0.72, 0.72, 0.72)
		_cards[k].pivot_offset = _cards[k].size / 2.0
		_cards[k].scale = Vector2.ONE * (1.05 if k == _choice else 1.0)


func _take(i: int) -> void:
	close()
	book_taken.emit(Library.BOOKS[i].id)


# ---------- reading ----------

func open_book(id: String) -> void:
	_book = Library.find(id)
	_mode = "read"
	_shelf.hide()
	_book_view.show()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_heads[0].text = _book.author
	_heads[1].text = _book.title
	if not Library.has_pages(_book):
		_show_missing()
		return
	if _loaded_id != id:
		_loaded_id = id
		var code := Library.load_bbcode(_book)
		for p in _pages:
			p.text = code
	_paginate()
	_spread = clampi(Library.bookmark(id), 0, _page_count - 1) & ~1
	_show_spread()


func _build_book() -> void:
	_book_view = Control.new()
	_book_view.set_anchors_and_offsets_preset(PRESET_CENTER)
	add_child(_book_view)
	for side in 2:
		var paper := Panel.new()
		var box := StyleBoxFlat.new()
		box.bg_color = PAPER
		box.corner_radius_top_left = 8 if side == 0 else 2
		box.corner_radius_bottom_left = box.corner_radius_top_left
		box.corner_radius_top_right = 2 if side == 0 else 8
		box.corner_radius_bottom_right = box.corner_radius_top_right
		box.shadow_color = Color(0, 0, 0, 0.45)
		box.shadow_size = 14
		paper.add_theme_stylebox_override("panel", box)
		paper.position = Vector2(-PAGE.x if side == 0 else 0.0, -PAGE.y / 2.0)
		paper.size = PAGE
		paper.mouse_filter = MOUSE_FILTER_IGNORE
		_book_view.add_child(paper)
		# Shading into the spine.
		var gutter := TextureRect.new()
		var grad := Gradient.new()
		grad.set_color(0, Color(0.35, 0.25, 0.15, 0.0 if side == 0 else 0.35))
		grad.set_color(1, Color(0.35, 0.25, 0.15, 0.35 if side == 0 else 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = grad
		gt.width = 64
		gt.height = 4
		gutter.texture = gt
		gutter.stretch_mode = TextureRect.STRETCH_SCALE
		gutter.position = Vector2(PAGE.x - 40 if side == 0 else 0.0, 0)
		gutter.size = Vector2(40, PAGE.y)
		gutter.mouse_filter = MOUSE_FILTER_IGNORE
		paper.add_child(gutter)
		var head := _text(paper, "", _italic, 14, INK.lightened(0.35))
		head.position = Vector2(MARGIN.x, 18)
		head.size = Vector2(PAGE.x - MARGIN.x * 2, 20)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_heads.append(head)
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.scroll_active = false
		rt.mouse_filter = MOUSE_FILTER_IGNORE
		rt.add_theme_font_override("normal_font", _regular)
		rt.add_theme_font_override("italics_font", _italic)
		rt.add_theme_font_override("bold_font", _bold)
		for f in ["normal_font_size", "italics_font_size", "bold_font_size"]:
			rt.add_theme_font_size_override(f, FONT_SIZE)
		rt.add_theme_color_override("default_color", INK)
		rt.add_theme_constant_override("line_separation", LINE_GAP)
		rt.position = MARGIN
		paper.add_child(rt)
		_pages.append(rt)
		var num := _text(paper, "", _italic, 14, INK.lightened(0.35))
		num.position = Vector2(MARGIN.x, PAGE.y - 34)
		num.size = Vector2(PAGE.x - MARGIN.x * 2, 20)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		_numbers.append(num)
	var hint := _text(_book_view, "A / D  turn the page      Esc  close the book", _italic, 16, Color(0.85, 0.8, 0.7))
	hint.position = Vector2(-300, PAGE.y / 2.0 + 18)
	hint.size = Vector2(600, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# Fit a whole number of lines on a page and count the pages.
func _paginate() -> void:
	var line_h := _regular.get_height(FONT_SIZE) + LINE_GAP
	var text_h := PAGE.y - MARGIN.y * 2.0 - 8.0
	_lines_per_page = maxi(1, int(text_h / line_h))
	for p in _pages:
		p.size = Vector2(PAGE.x - MARGIN.x * 2.0, _lines_per_page * line_h)
	var lines := _pages[0].get_line_count()
	_page_count = maxi(1, ceili(float(lines) / _lines_per_page))


func _show_spread() -> void:
	for side in 2:
		var page := _spread + side
		var rt := _pages[side]
		rt.visible = page < _page_count
		if rt.visible:
			# Line offsets are exact, so pages never show half a line.
			var top := rt.get_line_offset(page * _lines_per_page)
			var bottom := rt.get_line_offset(mini((page + 1) * _lines_per_page, rt.get_line_count() - 1))
			if (page + 1) * _lines_per_page >= rt.get_line_count():
				bottom = top + rt.size.y
			rt.size.y = bottom - top
			rt.get_v_scroll_bar().value = top
		_numbers[side].text = str(page + 1) if page < _page_count else ""
	Library.set_bookmark(_book.id, _spread)


func _show_missing() -> void:
	for side in 2:
		_pages[side].visible = side == 0
		_numbers[side].text = ""
	_loaded_id = ""
	_pages[0].size = Vector2(PAGE.x - MARGIN.x * 2.0, 300)
	_pages[0].text = "\n\n[center][i]This copy's pages are missing.\n\nAdd the Project Gutenberg text file as\n%s[/i][/center]" % _book.file


func _turn_page(dir: int) -> void:
	var next := clampi(_spread + dir * 2, 0, (_page_count - 1) & ~1)
	if next != _spread:
		_spread = next
		_turn.pitch_scale = randf_range(0.9, 1.1)
		_turn.play()
		_show_spread()


# ---------- shared ----------

func close() -> void:
	_mode = ""
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var handled := true
	if event.is_action_pressed("ui_cancel") or (_mode == "read" and event.is_action_pressed("read")):
		close()
	elif _mode == "shelf":
		if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
			_select(_choice - 1)
		elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
			_select(_choice + 1)
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_take(_choice)
		else:
			handled = false
	elif _mode == "read":
		var next := event.is_action_pressed("move_right") or event.is_action_pressed("ui_right")
		var prev := event.is_action_pressed("move_left") or event.is_action_pressed("ui_left")
		var click := event as InputEventMouseButton
		if click and click.pressed:
			# Wheel flips pages; clicking the right/left half turns forward/back.
			match click.button_index:
				MOUSE_BUTTON_WHEEL_DOWN:
					next = true
				MOUSE_BUTTON_WHEEL_UP:
					prev = true
				MOUSE_BUTTON_LEFT:
					next = click.position.x > get_viewport_rect().size.x / 2.0
					prev = not next
		if next or prev:
			_turn_page(1 if next else -1)
		else:
			handled = false
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


# Anchor a control to one point of its parent (0..1 on each axis) with its
# rect given relative to that point, so it stays put when the window resizes.
func _pin(c: Control, anchor: Vector2, rect: Rect2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = rect.position.x
	c.offset_top = rect.position.y
	c.offset_right = rect.end.x
	c.offset_bottom = rect.end.y


func _text(parent: Node, text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
