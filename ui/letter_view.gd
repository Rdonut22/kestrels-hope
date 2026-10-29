extends Control

## Hale's recovered letter, shown in Meki's box: his message to Gana types
## out line by line. E or Esc finishes the typing, then closes.

signal closed

const CYAN := Color(0.45, 0.85, 1.0)
const LETTER := """Gana,

If you're reading this, I was right about them.

The ore we've been hauling isn't for reactors. Ushida's labs found it holds more energy than anything we've ever seen, and they're building weapons with it. I saw the specs.

I asked to be let go. They said my contract runs to the end of this run, and then they'd "discuss it." I know what that means.

It doesn't come from where they say it does, either. The richest deposits are in a system nobody's settled yet. That's why they sent us. A two-man crew, an old ship, nobody asking questions.

I think they know what I saw. If something happens out here, it isn't an accident.

I'm sorry I didn't tell you. I didn't want you anywhere near it.

Get home to Angel.

- Hale"""

var _body: Label
var _tween: Tween
var _blip: AudioStreamPlayer


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.02, 0.7)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(dim)
	var box := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.07, 0.94)
	sb.border_color = CYAN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	box.add_theme_stylebox_override("panel", sb)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -380
	box.offset_right = 380
	box.offset_top = -300
	box.offset_bottom = 300
	add_child(box)
	var head := Label.new()
	head.text = "MEKI  //  HALE_PRIVATE.LOG  //  RECOVERED 100%"
	head.position = Vector2(26, 18)
	head.add_theme_font_override("font", load("res://ui/fonts/JetBrainsMono-Bold.ttf"))
	head.add_theme_font_size_override("font_size", 17)
	head.add_theme_color_override("font_color", CYAN)
	box.add_child(head)
	_body = Label.new()
	_body.text = LETTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_body.custom_minimum_size = Vector2(708, 0)
	_body.add_theme_font_override("font", load("res://ui/fonts/JetBrainsMono-Regular.ttf"))
	_body.add_theme_font_size_override("font_size", 15)
	_body.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	box.add_child(_body)
	_body.position = Vector2(26, 58)
	_body.size = Vector2(708, 500)
	var keys := Label.new()
	keys.text = "[E] close"
	keys.position = Vector2(630, 566)
	keys.add_theme_font_size_override("font_size", 14)
	keys.add_theme_color_override("font_color", Color(CYAN, 0.6))
	box.add_child(keys)
	_blip = AudioStreamPlayer.new()
	_blip.stream = load("res://audio/type_blip.ogg")
	_blip.volume_db = -22.0
	add_child(_blip)


func open() -> void:
	show()
	_body.visible_characters = 0
	_tween = create_tween()
	_tween.tween_property(_body, "visible_characters", LETTER.length(), LETTER.length() / 45.0)


func _process(_delta: float) -> void:
	if visible and _tween and _tween.is_running() and Engine.get_process_frames() % 5 == 0:
		_blip.pitch_scale = randf_range(0.9, 1.1)
		_blip.play()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _tween and _tween.is_running():
			_tween.kill()
			_body.visible_characters = -1
		else:
			hide()
			closed.emit()
