extends Control

## The current objective (GameState.objective()): when one starts, a
## "NEW OBJECTIVE" banner slides in at the top of the screen for a few
## seconds; after that a small line stays in the top-right corner until
## it's done. Driven by flags, so it survives saving and loading.

const BAR := "res://ui/dialogue/assets/choice_normal.png"
const SHOW_SECS := 4.0

var _banner: Control
var _banner_title: Label
var _banner_text: Label
var _corner: Label
var _current := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	var mono: Font = load("res://ui/fonts/JetBrainsMono-Regular.ttf")
	var bold: Font = load("res://ui/fonts/JetBrainsMono-Bold.ttf")
	# Banner: the dialogue UI's green bar, centred near the top.
	_banner = TextureRect.new()
	(_banner as TextureRect).texture = load(BAR)
	(_banner as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	(_banner as TextureRect).stretch_mode = TextureRect.STRETCH_SCALE
	_banner.mouse_filter = MOUSE_FILTER_IGNORE
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_left = -260
	_banner.offset_right = 260
	_banner.offset_top = 70
	_banner.offset_bottom = 70 + 520.0 * 119.0 / 1294.0 + 30
	add_child(_banner)
	_banner_title = Label.new()
	_banner_title.text = "NEW OBJECTIVE"
	_banner_title.add_theme_font_override("font", bold)
	_banner_title.add_theme_font_size_override("font_size", 13)
	_banner_title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_banner_title.offset_top = 8
	_banner.add_child(_banner_title)
	_banner_text = Label.new()
	_banner_text.add_theme_font_override("font", mono)
	_banner_text.add_theme_font_size_override("font_size", 20)
	_banner_text.add_theme_color_override("font_color", Color(0.88, 1.0, 0.9))
	_banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_text.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_banner_text.offset_top = 30
	_banner.add_child(_banner_text)
	_banner.modulate.a = 0.0
	_banner.hide()
	# Corner line: small and faint, under the compass's level, top right.
	_corner = Label.new()
	_corner.add_theme_font_override("font", mono)
	_corner.add_theme_font_size_override("font_size", 14)
	_corner.add_theme_color_override("font_color", Color(0.85, 1.0, 0.87, 0.75))
	_corner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_corner.add_theme_constant_override("shadow_offset_y", 1)
	_corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_corner.anchor_left = 1.0
	_corner.anchor_right = 1.0
	_corner.offset_left = -420
	_corner.offset_right = -28
	_corner.offset_top = 24
	_corner.offset_bottom = 60
	add_child(_corner)
	_corner.hide()
	Game.state().flag_set.connect(func(_f: String) -> void: _refresh(true))
	_refresh(false)


## Show the current objective; `announce` plays the banner if it's new.
func _refresh(announce: bool) -> void:
	var o: String = Game.state().objective()
	if o == _current:
		return
	_current = o
	if o == "":
		_corner.hide()
		_banner.hide()
		return
	_corner.text = "◆  " + o
	if not announce:
		_corner.show()
		return
	_corner.hide()
	_banner_text.text = o
	_banner.show()
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.5)
	tw.tween_interval(SHOW_SECS)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.8)
	tw.tween_callback(_banner.hide)
	tw.tween_callback(func() -> void:
		_corner.modulate.a = 0.0
		_corner.show()
		create_tween().tween_property(_corner, "modulate:a", 1.0, 0.6))
