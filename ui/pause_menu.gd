extends CanvasLayer

## Global pause menu (autoload). Esc pauses the game and shows Resume /
## Save Game / Quit to Menu / Quit Game (quitting to the menu saves first). Ignored on the title screen. Open terminal
## screens consume Esc first (see hud.gd), so Esc closes those instead.

const MENU_SCENE := "res://menu.tscn"
const NO_PAUSE := ["res://menu.tscn", "res://intro.tscn"]

var _root: Control
var _backdrop: TextureRect
var _resume: Button
var _save: Button
var _hint: Label


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path in NO_PAUSE:
		return
	get_viewport().set_input_as_handled()
	if _root.visible:
		resume()
	else:
		pause()


func pause() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Freeze the last frame as a still backdrop and stop rendering the 3D
	# world while paused, so the menu stays responsive.
	await RenderingServer.frame_post_draw
	_backdrop.texture = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	get_viewport().disable_3d = true
	_save.disabled = not Game.state().can_save()
	_hint.text = "Esc to resume"
	_root.show()


func resume() -> void:
	get_viewport().disable_3d = false
	_backdrop.texture = null
	_root.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _save_game() -> void:
	_hint.text = "Game saved" if Game.state().save_game() else "Can't save right now"


func _quit_to_menu() -> void:
	Game.state().save_game()
	get_viewport().disable_3d = false
	_backdrop.texture = null
	_root.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)


func _build() -> void:
	var font: FontFile = load("res://ui/fonts/Dena.otf")
	var shadow := Color(0.12, 0.04, 0.1, 0.85)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_backdrop = TextureRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(_backdrop)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.03, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.82))
	title.add_theme_color_override("font_shadow_color", shadow)
	title.add_theme_constant_override("shadow_offset_y", 3)
	box.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	box.add_child(gap)
	for item in [["Resume", resume], ["Save Game", _save_game], ["Quit to Menu", _quit_to_menu], ["Quit Game", get_tree().quit]]:
		var b := Button.new()
		b.text = item[0]
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", 30)
		b.add_theme_color_override("font_color", Color(1.0, 0.93, 0.86))
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.62, 0.82))
		b.add_theme_color_override("font_pressed_color", Color(0.78, 0.58, 1.0))
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.32))
		b.add_theme_color_override("font_outline_color", shadow)
		b.add_theme_constant_override("outline_size", 6)
		b.pressed.connect(item[1])
		box.add_child(b)
		if _resume == null:
			_resume = b
		if item[0] == "Save Game":
			_save = b
	var hint := Label.new()
	_hint = hint
	hint.text = "Esc to resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", font)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	box.add_child(hint)
