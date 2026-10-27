extends Node3D

## Opening cinematic for New Game. Stars and the space hum; the camera tilts
## down until the forest moon fills the bottom of the frame; thrusters swell
## and the Kestrel bursts past overhead as the intro music and title come in;
## the ship shrinks toward the horizon; fade to black and cut to the cockpit.
## Hold Space / Enter to skip.

const NEXT_SCENE := "res://main.tscn"
const BURST := 10.5          # seconds: ship passes the camera, music starts
const END := 31.0            # seconds: fade to black
const PLANET_RADIUS := 6000.0
# Planet seen as a bright dome low in the frame: ~35 degrees across its
# radius, top edge about 18 degrees below the horizon line.
const PLANET_CENTER := Vector3(0.0, -8350.0, -6290.0)
const THRUST_PEAK := 4.2     # seconds into thruster_flyby.ogg at its loudest

var _t := 0.0
var _cam: Camera3D
var _ship: Node3D
var _title: Label
var _fade: ColorRect
var _skip_hint: Label
var _skip_held := 0.0
var _hum: AudioStreamPlayer
var _thrust: AudioStreamPlayer
var _music: AudioStreamPlayer
var _thrust_started := false
var _music_started := false
var _leaving := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_build_space()
	_build_planet()
	_build_ship()
	_build_ui()
	_hum = _audio("res://audio/space_hum.ogg", -9.0, true)
	_hum.play()
	_thrust = _audio("res://audio/thruster_flyby.ogg", 0.0, false)
	_music = _audio("res://audio/intro_music.ogg", -2.0, false)


func _audio(path: String, db: float, loop: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	if "loop" in p.stream:
		p.stream.loop = loop
	p.volume_db = db
	add_child(p)
	return p


func _build_space() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ship/space_sky.gdshader")
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.3, 0.45)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 2.8
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.basis = Basis.looking_at(-Vector3(0.3, 0.5, 0.81).normalized(), Vector3.UP)
	add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 60
	_cam.far = 9000
	_cam.rotation.x = deg_to_rad(55)
	add_child(_cam)
	_cam.make_current()


func _build_planet() -> void:
	var center := PLANET_CENTER
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = PLANET_RADIUS
	sphere.height = PLANET_RADIUS * 2.0
	sphere.radial_segments = 160
	sphere.rings = 80
	planet.mesh = sphere
	var pm := ShaderMaterial.new()
	pm.shader = load("res://world/planet.gdshader")
	planet.material_override = pm
	planet.position = center
	planet.rotation = Vector3(0.4, 1.2, 0.0)
	add_child(planet)
	var atmo := MeshInstance3D.new()
	var shell := SphereMesh.new()
	shell.radius = PLANET_RADIUS * 1.012
	shell.height = shell.radius * 2.0
	shell.radial_segments = 160
	shell.rings = 80
	atmo.mesh = shell
	var am := ShaderMaterial.new()
	am.shader = load("res://world/atmosphere.gdshader")
	atmo.material_override = am
	atmo.position = center
	add_child(atmo)


func _build_ship() -> void:
	_ship = (load("res://ship/ship_interior.tscn") as PackedScene).instantiate()
	add_child(_ship)
	# Interior lights don't matter out here; hide them to save work.
	for l in _ship.get_node("Lights").get_children():
		l.visible = false
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.4, 0.7, 1.0)
	glow.light_energy = 3.0
	glow.omni_range = 9.0
	glow.position = Vector3(-1.0, 1.6, 12.0)
	_ship.add_child(glow)
	# Bright engine flares so the ship stays a glowing speck in the distance.
	var flare_mat := StandardMaterial3D.new()
	flare_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flare_mat.albedo_color = Color(0.6, 0.85, 1.0)
	flare_mat.emission_enabled = true
	flare_mat.emission = Color(0.5, 0.8, 1.0)
	flare_mat.emission_energy_multiplier = 6.0
	for x in [-5.2, 3.85]:
		var flare := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 1.3
		ball.height = 2.6
		flare.mesh = ball
		flare.material_override = flare_mat
		flare.position = Vector3(x, 1.6, 11.4)
		_ship.add_child(flare)
	_ship.visible = false


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var font: FontFile = load("res://ui/fonts/Dena.otf")
	_title = Label.new()
	_title.text = "KESTREL'S HOPE"
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", font)
	_title.add_theme_font_size_override("font_size", 84)
	_title.add_theme_color_override("font_color", Color(1.0, 0.94, 0.86))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_title.add_theme_constant_override("shadow_offset_y", 4)
	_title.modulate.a = 0.0
	_title.offset_top = -200
	layer.add_child(_title)
	_skip_hint = Label.new()
	_skip_hint.text = "hold SPACE to skip"
	_skip_hint.add_theme_font_override("font", font)
	_skip_hint.add_theme_font_size_override("font_size", 16)
	_skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_hint.offset_left = -240
	_skip_hint.offset_top = -48
	_skip_hint.modulate.a = 0.0
	layer.add_child(_skip_hint)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 3.0)


func _process(delta: float) -> void:
	_t += delta
	_update_camera()
	_update_ship()
	_update_audio_and_title()
	_update_skip(delta)
	if _t >= END and not _leaving:
		_leave(2.0)


func _update_camera() -> void:
	# Slow tilt from the stars down to just above the horizon.
	var k := smoothstep(0.5, 9.5, _t)
	_cam.rotation.x = deg_to_rad(lerpf(55.0, 0.0, k))
	_cam.position = Vector3.ZERO
	# A short rumble as the ship roars over.
	var shake := clampf(1.0 - absf(_t - BURST) / 1.2, 0.0, 1.0)
	if shake > 0.0:
		_cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.08 * shake


func _update_ship() -> void:
	var start := BURST - 1.6
	if _t < start:
		return
	_ship.visible = true
	var pass_pos := Vector3(1.5, 2.0, -16.0)
	if _t < BURST:
		# From behind and above the camera to just past it, very fast.
		var a := (_t - start) / (BURST - start)
		_ship.position = Vector3(2.0, 12.0, 55.0).lerp(pass_pos, a)
		_ship.rotation = Vector3(-0.04, 0.0, 0.0)
	else:
		# Away toward the horizon, appearing to slow as it shrinks.
		var a := clampf((_t - BURST) / (END + 2.0 - BURST), 0.0, 1.0)
		# Accelerates away so it lingers large, then dwindles to a speck.
		var e := pow(a, 1.5)
		_ship.position = pass_pos.lerp(Vector3(-20.0, -560.0, -1750.0), e)
		_ship.rotation = Vector3(-0.1 - 0.25 * e, 0.012 * e, 0.05 * sin(_t * 0.6) * (1.0 - e))


func _update_audio_and_title() -> void:
	if not _thrust_started and _t >= BURST - THRUST_PEAK:
		_thrust_started = true
		_thrust.play()
		# Let the roar ring briefly after the pass, then fall away fast.
		var tw := create_tween()
		tw.tween_interval(THRUST_PEAK + 0.8)
		tw.tween_property(_thrust, "volume_db", -40.0, 3.0)
	if not _music_started and _t >= BURST:
		_music_started = true
		_music.play()
		var tw := create_tween()
		tw.tween_interval(0.3)
		tw.tween_property(_title, "modulate:a", 1.0, 2.5)
		tw.tween_interval(11.0)
		tw.tween_property(_title, "modulate:a", 0.0, 3.0)
		create_tween().tween_property(_hum, "volume_db", -18.0, 4.0)


func _update_skip(delta: float) -> void:
	var held := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER)
	if held:
		_skip_hint.modulate.a = 0.8
		_skip_held += delta
		if _skip_held > 0.9 and not _leaving:
			_leave(0.8)
	else:
		_skip_held = 0.0
		_skip_hint.modulate.a = move_toward(_skip_hint.modulate.a, 0.0, delta * 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_skip_hint.modulate.a = 0.8


func _leave(duration: float) -> void:
	_leaving = true
	var tw := create_tween().set_parallel()
	tw.tween_property(_fade, "color:a", 1.0, duration)
	for p in [_hum, _thrust, _music]:
		tw.tween_property(p, "volume_db", -50.0, duration)
	await tw.finished
	# The cockpit scene reads this to start the player at the pilot seat.
	get_tree().root.set_meta("spawn_cockpit", true)
	get_tree().change_scene_to_file(NEXT_SCENE)
