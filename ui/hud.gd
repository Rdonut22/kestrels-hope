extends CanvasLayer

var _entries: Array = []
var _message_tween: Tween
var _sleeping := false
var _reader: Control
var _overlays: Array[Control] = []  # full-screen panels that pause the player
var _thoughts: Control

@onready var prompt_label: Label = %PromptLabel
@onready var message_label: Label = %MessageLabel
@onready var held_label: Label = %HeldLabel
@onready var fade: ColorRect = %Fade
@onready var screen: Control = %Screen
@onready var screen_title: Label = %ScreenTitle
@onready var entry_list: ItemList = %EntryList
@onready var entry_body: RichTextLabel = %EntryBody


func _enter_tree() -> void:
	add_to_group("hud")


func _ready() -> void:
	screen.hide()
	set_prompt("")
	set_held("")
	message_label.modulate.a = 0.0
	fade.color.a = 0.0
	entry_list.item_selected.connect(_on_entry_selected)
	%CloseButton.pressed.connect(close_screen)
	_thoughts = (load("res://ui/thought_box.gd") as GDScript).new()
	add_child(_thoughts)


func _input(event: InputEvent) -> void:
	# F11, or Alt/Option+Enter, toggles fullscreen.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()
			return
	if screen.visible and event.is_action_pressed("ui_cancel"):
		close_screen()
		get_viewport().set_input_as_handled()


## True while a menu, a book or the sleep fade is up, so the player can't move.
func is_busy() -> bool:
	for o in _overlays:
		if is_instance_valid(o) and o.visible:
			return true
	return screen.visible or _sleeping or (_reader != null and _reader.visible)


## Add a full-screen panel; the player is frozen while it's visible.
func add_overlay(panel: Control) -> void:
	_overlays.append(panel)
	add_child(panel)
	# Gana's thoughts stay readable on top of any panel.
	move_child(_thoughts, -1)


## Gana (or Meki) thinking out loud. Lines are Strings (Gana) or
## [who, text]. With a `once` key the lines only ever play the first time.
## Await the result to wait until they've all been shown.
func think(lines: Array, once := "", interrupt := false) -> void:
	if once != "":
		if Game.state().has_flag(once):
			return
		Game.state().set_flag(once)
	_thoughts.say(lines, interrupt)
	await _thoughts.finished


func is_thinking() -> bool:
	return _thoughts.is_talking()


## Show the lounge bookshelf; `on_take` gets the id of the book picked.
func open_shelf(on_take: Callable) -> void:
	var reader := _book_reader()
	for c in reader.book_taken.get_connections():
		reader.book_taken.disconnect(c.callable)
	reader.book_taken.connect(on_take, CONNECT_ONE_SHOT)
	reader.open_shelf()


func open_book(id: String) -> void:
	_book_reader().open_book(id)


func _book_reader() -> Control:
	if not _reader:
		_reader = (load("res://ui/book_reader.gd") as GDScript).new()
		add_child(_reader)
	return _reader


func set_prompt(text: String) -> void:
	prompt_label.text = text


func set_held(text: String) -> void:
	held_label.text = text


func show_message(text: String, duration := 3.0) -> void:
	message_label.text = text
	if _message_tween:
		_message_tween.kill()
	message_label.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(duration)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.6)


## entries: Array of {"title": String, "body": String (BBCode)}
func open_screen(title: String, entries: Array) -> void:
	_entries = entries
	screen_title.text = title
	entry_list.clear()
	for entry in entries:
		entry_list.add_item(entry.title)
	screen.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not entries.is_empty():
		entry_list.select(0)
		_on_entry_selected(0)
	entry_list.grab_focus()


func close_screen() -> void:
	screen.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func fade_through_black(message: String) -> void:
	_sleeping = true
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 1.0)
	tween.tween_callback(show_message.bind(message, 3.0))
	tween.tween_interval(3.0)
	tween.tween_property(fade, "color:a", 0.0, 1.5)
	await tween.finished
	_sleeping = false


func _on_entry_selected(index: int) -> void:
	entry_body.text = _entries[index].body
