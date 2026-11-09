@tool
extends Node3D

## Inspection scene for the wrist terminal prop (run it with F6).
##   Left drag: orbit    Right/middle drag: pan    Wheel: zoom
##   1-8: preset views (hero, top, outer side, handle side, underside/strap,
##        elbow end/port, controls close-up, wearer's view)
##   A: stand-in forearm on/off   P: port cover   K: turn knob
##   L: status lamp   B: press buttons   T: turntable   F: reset view
## Lights, environment and the stand-in arm are built at runtime (also in
## the editor, so the scene looks right there too).

const PRESETS := [
	# name, target, yaw (deg), pitch (deg), distance (m)
	["Hero (reference angle)", Vector3(0.0, 0.06, 0.0), 8.0, 50.0, 0.40],
	["Top", Vector3(0.0, 0.06, 0.0), 0.0, 89.0, 0.40],
	["Outer side (+Z)", Vector3(0.0, 0.045, 0.0), 0.0, 10.0, 0.42],
	["Handle side (-Z)", Vector3(0.0, 0.05, 0.0), 180.0, 16.0, 0.42],
	["Underside / strap", Vector3(0.0, 0.0, 0.0), 20.0, -58.0, 0.40],
	["Elbow end / data port", Vector3(-0.086, 0.054, -0.055), -158.0, 12.0, 0.13],
	["Controls close-up", Vector3(0.078, 0.073, -0.012), 25.0, 58.0, 0.15],
	["Wearer's view", Vector3(0.0, 0.065, 0.0), -62.0, 58.0, 0.34],
]

@export var show_arm := true:
	set(v):
		show_arm = v
		if _arm:
			_arm.visible = v

var target := Vector3(0, 0.06, 0)
var yaw := 8.0
var pitch := 50.0
var distance := 0.40
var turntable := false

var _cam: Camera3D
var _arm: Node3D
var _help: Label
var _terminal: WristTerminal
var _drag := 0


func _ready() -> void:
	_terminal = get_node_or_null("WristTerminal") as WristTerminal
	_build_environment()
	_build_lights()
	_build_arm()
	_cam = Camera3D.new()
	_cam.name = "OrbitCamera"
	_cam.near = 0.004
	_cam.far = 20.0
	_cam.fov = 40.0
	add_child(_cam)
	_cam.current = true
	if not Engine.is_editor_hint():
		_build_help()
	apply_preset(0)


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "Environment"
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	# Dim, warm-over-green surroundings, like late light in the forest.
	sm.sky_top_color = Color(0.16, 0.18, 0.17)
	sm.sky_horizon_color = Color(0.32, 0.29, 0.22)
	sm.ground_horizon_color = Color(0.2, 0.2, 0.15)
	sm.ground_bottom_color = Color(0.06, 0.07, 0.05)
	sm.sun_angle_max = 10.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.06, 0.055)
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	we.environment = env
	add_child(we)


func _build_lights() -> void:
	# Warm key from high on the elbow / handle side, like the reference.
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color(1.0, 0.91, 0.79)
	key.light_energy = 1.55
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 1.2
	key.shadow_bias = 0.03
	key.shadow_normal_bias = 1.6
	key.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-140.0), 0.0)
	add_child(key)
	# Cool fill from the opposite side.
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.62, 0.74, 0.86)
	fill.light_energy = 0.45
	fill.rotation = Vector3(deg_to_rad(-25.0), deg_to_rad(40.0), 0.0)
	add_child(fill)
	# Rim light behind the hand end to pick out the silhouette.
	var rim := OmniLight3D.new()
	rim.name = "RimLight"
	rim.light_color = Color(1.0, 0.8, 0.55)
	rim.light_energy = 1.4
	rim.omni_range = 0.8
	rim.position = Vector3(0.3, 0.18, -0.25)
	add_child(rim)
	# Weak bounce from below so the strap side can be inspected.
	var bounce := DirectionalLight3D.new()
	bounce.name = "BounceLight"
	bounce.light_color = Color(0.7, 0.62, 0.5)
	bounce.light_energy = 0.35
	bounce.rotation = Vector3(deg_to_rad(70.0), deg_to_rad(20.0), 0.0)
	add_child(bounce)


## Stand-in forearm (a skin-toned cylinder) with a sleeve past the elbow end.
func _build_arm() -> void:
	_arm = Node3D.new()
	_arm.name = "ArmStandIn"
	add_child(_arm)
	var r := _terminal.arm_radius if _terminal else 0.04
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.4, 0.25, 0.18)
	skin.roughness = 0.7
	var forearm := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r - 0.0004
	cm.bottom_radius = r - 0.0012
	cm.height = 0.34
	cm.radial_segments = 48
	cm.material = skin
	forearm.mesh = cm
	forearm.rotation.z = PI / 2
	forearm.position.x = 0.03
	_arm.add_child(forearm)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.14, 0.14, 0.12)
	cloth.roughness = 0.95
	var sleeve := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = r + 0.012
	sm.bottom_radius = r + 0.016
	sm.height = 0.14
	sm.radial_segments = 48
	sm.material = cloth
	sleeve.mesh = sm
	sleeve.rotation.z = -PI / 2
	sleeve.position.x = -0.205
	_arm.add_child(sleeve)
	_arm.visible = show_arm


func _build_help() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_help = Label.new()
	_help.position = Vector2(14, 10)
	_help.add_theme_color_override("font_color", Color(0.85, 0.82, 0.74))
	_help.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_help.add_theme_font_size_override("font_size", 14)
	layer.add_child(_help)
	_update_help("")


func _update_help(view: String) -> void:
	if _help:
		_help.text = ("USHIDA G-07 wrist terminal - preview   %s\n" % view) + \
			"Left drag orbit | right/middle drag pan | wheel zoom | 1-8 views | F reset\n" + \
			"A arm  P port cover  K knob  L lamp  B buttons  T turntable"


func apply_preset(i: int) -> void:
	var p: Array = PRESETS[clampi(i, 0, PRESETS.size() - 1)]
	target = p[1]
	yaw = p[2]
	pitch = p[3]
	distance = p[4]
	_update_camera()
	_update_help("[%d] %s" % [i + 1, p[0]])


func _update_camera() -> void:
	if not _cam:
		return
	var b := Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(-pitch))
	_cam.position = target + b * Vector3(0, 0, distance)
	var up := Vector3.UP if absf(pitch) < 88.0 else b * Vector3.UP
	_cam.look_at(target, up)


func _process(delta: float) -> void:
	if turntable and not Engine.is_editor_hint():
		yaw += 20.0 * delta
		_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			distance = maxf(distance * 0.9, 0.05)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			distance = minf(distance * 1.1, 2.0)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_drag = mb.button_index if mb.pressed else 0
		_update_camera()
	elif event is InputEventMouseMotion and _drag != 0:
		var mm := event as InputEventMouseMotion
		if _drag == MOUSE_BUTTON_LEFT:
			yaw -= mm.relative.x * 0.35
			pitch = clampf(pitch + mm.relative.y * 0.35, -89.0, 89.0)
		else:
			var s := distance * 0.0015
			target += _cam.global_basis * Vector3(-mm.relative.x * s, mm.relative.y * s, 0)
		_update_camera()
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_8:
			apply_preset(k - KEY_1)
		elif k == KEY_F:
			apply_preset(0)
		elif k == KEY_A:
			show_arm = not show_arm
		elif k == KEY_T:
			turntable = not turntable
		elif _terminal:
			match k:
				KEY_P:
					_terminal.port_cover_open = 0.0 if _terminal.port_cover_open > 0.5 else 1.0
				KEY_K:
					_terminal.knob_angle = wrapf(_terminal.knob_angle + 30.0, -180.0, 180.0)
				KEY_L:
					_terminal.indicator_on = not _terminal.indicator_on
				KEY_B:
					var down := _terminal.button_a_pressed < 0.5
					_terminal.button_a_pressed = 1.0 if down else 0.0
					_terminal.button_b_pressed = 1.0 if down else 0.0
