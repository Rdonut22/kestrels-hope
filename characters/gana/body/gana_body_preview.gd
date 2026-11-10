extends Node3D

## Preview of the stylized Gana body (run with F6): the generated mesh
## (gana_body.glb) with the mechanical right hand (robot_arm.gd, hand
## only) and the glowing eyes (gana_eyes.gd), playing its animations.
##   Left drag: orbit    Right/middle drag: pan    Wheel: zoom
##   1-7: views    I/W/Q/R/J/P: idle/walk/quick walk/run/jump/pick up
##   Space: pause    T: turntable
## Not used by the game yet.

const PRESETS := [
	# name, target, yaw (deg, 0 = in front of him), pitch, distance
	["Three-quarter", Vector3(0, 0.88, 0), 28.0, 4.0, 3.7],
	["Front", Vector3(0, 0.88, 0), 0.0, 3.0, 3.7],
	["Side (his right)", Vector3(0, 0.88, 0), 90.0, 3.0, 3.7],
	["Back", Vector3(0, 0.88, 0), 180.0, 3.0, 3.7],
	["Face", Vector3(0, 1.55, 0), 15.0, 2.0, 0.9],
	["Mechanical hand", Vector3(0.3, 0.85, 0.0), 55.0, 8.0, 0.75],
	["Left hand", Vector3(-0.3, 0.85, 0.0), -55.0, 8.0, 0.75],
]

var target := Vector3(0, 0.88, 0)
var yaw := 28.0
var pitch := 4.0
var distance := 3.7
var turntable := false
var anim: AnimationPlayer
var _cam: Camera3D
var _help: Label
var _drag := 0
var _current := "Idle"


func _ready() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.93, 0.91, 0.87)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.84, 0.8)
	env.ambient_light_energy = 0.7
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.0
	key.light_color = Color(1.0, 0.97, 0.92)
	key.shadow_enabled = true
	key.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(-155.0), 0.0)
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.35
	fill.rotation = Vector3(deg_to_rad(-15.0), deg_to_rad(40.0), 0.0)
	add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.8
	disc.bottom_radius = 0.8
	disc.height = 0.02
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.82, 0.8, 0.76)
	disc.material = fm
	floor_mesh.mesh = disc
	floor_mesh.position.y = -0.01
	add_child(floor_mesh)

	var body := build_gana()
	add_child(body)
	_cam = Camera3D.new()
	_cam.fov = 32.0
	_cam.near = 0.02
	add_child(_cam)
	_cam.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	_help = Label.new()
	_help.position = Vector2(14, 10)
	_help.add_theme_color_override("font_color", Color(0.25, 0.2, 0.16))
	layer.add_child(_help)
	play("Idle")
	apply_preset(0)


## The body with its runtime parts, facing -Z like the player.
static func build_gana() -> Node3D:
	var root := Node3D.new()
	root.name = "Gana"
	var g: Node3D = (load("res://characters/gana/body/gana_body.glb") as PackedScene).instantiate()
	g.rotation.y = PI
	root.add_child(g)
	var skel: Skeleton3D = g.find_children("*", "Skeleton3D", true, false)[0]
	var arm := RobotArm.new()
	arm.name = "RobotHand"
	arm.build_forearm = false
	arm.show_terminal = false
	arm.frame_color = Color(0.3, 0.29, 0.29)
	arm.plate_color = Color(0.88, 0.85, 0.78)
	arm.wear = 0.4
	arm.light_hand = true
	arm.palm_glow = Color(0.98, 0.67, 0.22)
	root.add_child(arm)
	var eyes := GanaEyes.new()
	root.add_child(eyes)
	# Attach once everything is in the tree (needs global transforms).
	(func():
		arm.attach(skel)
		eyes.attach(skel)).call_deferred()
	return root


func play(n: String) -> void:
	if anim == null:
		anim = find_children("*", "AnimationPlayer", true, false)[0]
	if anim.has_animation(n):
		_current = n
		anim.play(n, 0.2)
	_update_help()


func apply_preset(i: int) -> void:
	var p: Array = PRESETS[clampi(i, 0, PRESETS.size() - 1)]
	target = p[1]
	yaw = p[2]
	pitch = p[3]
	distance = p[4]
	_update_camera()
	_update_help(p[0])


func _update_help(view := "") -> void:
	if _help:
		if view != "":
			_help.set_meta("view", view)
		_help.text = "GANA - stylized body   view: %s   animation: %s\n1-7 views | I idle  W walk  Q quick walk  R run  J jump  P pick up  Space pause | drag orbit, wheel zoom | T turntable" % [
			_help.get_meta("view", ""), _current]


func _update_camera() -> void:
	if not _cam:
		return
	var b := Basis(Vector3.UP, deg_to_rad(-yaw)) * Basis(Vector3.RIGHT, deg_to_rad(pitch))
	_cam.position = target + b * Vector3(0, 0, -distance)
	_cam.look_at(target, Vector3.UP)


func _process(delta: float) -> void:
	if turntable:
		yaw += 25.0 * delta
		_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			distance = maxf(distance * 0.9, 0.3)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			distance = minf(distance * 1.1, 10.0)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_drag = mb.button_index if mb.pressed else 0
		_update_camera()
	elif event is InputEventMouseMotion and _drag != 0:
		var mm := event as InputEventMouseMotion
		if _drag == MOUSE_BUTTON_LEFT:
			yaw += mm.relative.x * 0.35
			pitch = clampf(pitch + mm.relative.y * 0.35, -80.0, 80.0)
		else:
			var s := distance * 0.0015
			target += _cam.global_basis * Vector3(-mm.relative.x * s, mm.relative.y * s, 0)
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_7:
			apply_preset(k - KEY_1)
		match k:
			KEY_I: play("Idle")
			KEY_W: play("Walk")
			KEY_R: play("Run")
			KEY_J: play("Jump")
			KEY_Q: play("QuickWalk")
			KEY_P: play("PickUp")
			KEY_T: turntable = not turntable
			KEY_SPACE:
				if anim:
					if anim.is_playing():
						anim.pause()
					else:
						anim.play()
