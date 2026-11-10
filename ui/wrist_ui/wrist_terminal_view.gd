class_name WristTerminalView
extends Control

## Gana's wrist computer, opened with Tab: a close-up of the G-07 terminal
## (the existing model, characters/gana/wrist_terminal) over the dimmed
## game, with the terminal UI (terminal_ui.gd) on its display.
##
## Registered with the HUD as an overlay, so the player is frozen and the
## compass hides while it's open. Keys: arrows/WASD select, E/Enter open,
## Esc/Backspace back (closes from the home screen), H home, Tab close.
## The mouse works on the screen itself (hover selects, click opens).
## Reopening shows the section that was open last.

const ACTION := "wrist_terminal"
const UI_SIZE := Vector2i(1280, 800)

var ui: TerminalUI
var terminal: WristTerminal
## Section to reopen next time (-1 = home).
var last_section := -1

var _ui_vp: SubViewport
var _view_vp: SubViewport
var _cam: Camera3D
var _hud: Node


func _ready() -> void:
	name = "WristTerminalView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_TAB
		InputMap.action_add_event(ACTION, ev)
	_build_ui_viewport()
	_build_view()


func _build_ui_viewport() -> void:
	_ui_vp = SubViewport.new()
	_ui_vp.name = "ScreenUI"
	_ui_vp.size = UI_SIZE
	_ui_vp.disable_3d = true
	_ui_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_ui_vp)
	ui = TerminalUI.new()
	_ui_vp.add_child(ui)
	ui.section_opened.connect(func(_i): _press_button())


## The 3D close-up: the terminal, a camera square to its screen, lights.
func _build_view() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var box := SubViewportContainer.new()
	box.name = "View"
	box.stretch = true
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_view_vp = SubViewport.new()
	_view_vp.own_world_3d = true
	_view_vp.transparent_bg = true
	_view_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	box.add_child(_view_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.52, 0.46)
	env.environment.ambient_light_energy = 0.5
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_view_vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.9, 0.76)
	key.light_energy = 1.3
	key.rotation = Vector3(deg_to_rad(-62.0), deg_to_rad(-150.0), 0.0)
	_view_vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.6, 0.72, 0.85)
	fill.light_energy = 0.35
	fill.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(40.0), 0.0)
	_view_vp.add_child(fill)
	terminal = WristTerminal.new()
	terminal.name = "WristTerminal"
	_view_vp.add_child(terminal)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_cam.near = 0.01
	_cam.far = 5.0
	_view_vp.add_child(_cam)
	_frame_camera.call_deferred()


## Look straight down at the display from just in front, screen "up"
## (-Z on the terminal) at the top of the view.
func _frame_camera() -> void:
	var disp := terminal.get_display()
	if disp == null:
		return
	var aabb := disp.mesh.get_aabb()
	var c := disp.global_transform * aabb.get_center()
	var up := terminal.global_basis.y.normalized()
	var top := -terminal.global_basis.z.normalized()
	var dist := 0.215
	_cam.global_position = c + up * dist - top * dist * 0.16
	_cam.look_at(c, top)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _ui_vp.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	disp.material_override = mat


# ----------------------------------------------------------------- open/close

func open() -> void:
	if visible:
		return
	visible = true
	_ui_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if last_section >= 0:
		ui.open_section(last_section)
	else:
		ui.home()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not visible:
		return
	last_section = ui.section
	visible = false
	_ui_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Mark a section as having something new (until it's opened).
func set_unread(id: String, on := true) -> void:
	ui.set_unread(id, on)


func _hud_node() -> Node:
	if _hud == null:
		_hud = get_tree().get_first_node_in_group("hud")
	return _hud


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed(ACTION) and not event.is_echo():
			var hud := _hud_node()
			if hud == null or not hud.is_busy():
				open()
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse:
		return  # handled in _gui_input
	if not (event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton):
		return
	if not event.is_pressed():
		return
	if event.is_action(ACTION) and not event.is_echo():
		close()
	elif event.is_action("ui_cancel") or _key(event, KEY_BACKSPACE):
		if not ui.back():
			close()
	elif _key(event, KEY_H):
		ui.home()
	elif event.is_action("ui_accept") or event.is_action("interact"):
		ui.activate()
	elif event.is_action("ui_left") or event.is_action("move_left"):
		_move(Vector2i(-1, 0))
	elif event.is_action("ui_right") or event.is_action("move_right"):
		_move(Vector2i(1, 0))
	elif event.is_action("ui_up") or event.is_action("move_forward"):
		_move(Vector2i(0, -1))
	elif event.is_action("ui_down") or event.is_action("move_back"):
		_move(Vector2i(0, 1))
	# Every key is swallowed while open so nothing reaches the game.
	get_viewport().set_input_as_handled()


static func _key(event: InputEvent, k: Key) -> bool:
	return event is InputEventKey and ((event as InputEventKey).physical_keycode == k or (event as InputEventKey).keycode == k)


func _move(dir: Vector2i) -> void:
	if ui.move(dir):
		# The knob clicks round with the selection.
		terminal.knob_angle = wrapf(terminal.knob_angle + 30.0 * (dir.x + dir.y * 2), -180.0, 180.0)


func _press_button() -> void:
	var t := create_tween()
	t.tween_property(terminal, "button_b_pressed", 1.0, 0.06)
	t.tween_property(terminal, "button_b_pressed", 0.0, 0.12)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var p: Variant = screen_point(event.position)
		if p != null:
			ui.hover(p)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var p: Variant = screen_point(event.position)
			if p != null:
				ui.hover(p)
				ui.click(p)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if not ui.back():
				close()
	accept_event()


## A point on this control -> pixel on the terminal's screen UI, or null if
## it's off the display. (A ray from the close-up camera onto the display.)
func screen_point(pos: Vector2) -> Variant:
	var disp := terminal.get_display()
	if disp == null or size.x <= 0.0:
		return null
	var p := pos * Vector2(_view_vp.size) / size
	var o := _cam.project_ray_origin(p)
	var n := _cam.project_ray_normal(p)
	var inv := disp.global_transform.affine_inverse()
	var lo := inv * o
	var ln := inv.basis * n
	var aabb := disp.mesh.get_aabb()
	if absf(ln.y) < 1e-5:
		return null
	var t := (aabb.position.y - lo.y) / ln.y
	var hit := lo + ln * t
	var uv := Vector2((hit.x - aabb.position.x) / aabb.size.x, (hit.z - aabb.position.z) / aabb.size.z)
	if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
		return null
	return uv * Vector2(UI_SIZE)


## The opposite of screen_point (for tests): screen UI pixel -> this
## control's coordinates.
func control_point(ui_px: Vector2) -> Vector2:
	var disp := terminal.get_display()
	var aabb := disp.mesh.get_aabb()
	var uv := ui_px / Vector2(UI_SIZE)
	var local := Vector3(aabb.position.x + uv.x * aabb.size.x, aabb.position.y, aabb.position.z + uv.y * aabb.size.z)
	var vp := _cam.unproject_position(disp.global_transform * local)
	return vp * size / Vector2(_view_vp.size)
