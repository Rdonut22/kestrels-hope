extends Node3D

## Opening, shot 1 (00:00-00:05): the Kestrel drifting silently through
## space, engines dark, turning slowly as the camera eases along beside it.
## Soft piano begins (OpeningMusic, kept playing into the ship: see
## ship/opening_cinematic.gd). No dialogue, no HUD. Then the interior
## montage and the quarters scene play in the ship (main.tscn).
## Hold Space / Enter to skip to the ship.

const NEXT_SCENE := "res://main.tscn"
const LENGTH := 5.0
## Music slot: soft, melancholic piano (no suitable track in the project
## yet; the scene plays without it until a file is put here).
const PIANO := "res://audio/music/opening_piano.ogg"
const PIANO_DB := -8.0

var _t := 0.0
var _cam: Camera3D
var _ship: Node3D
var _fade: ColorRect
var _leaving := false
var _skip_held := 0.0
var _music: AudioStreamPlayer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_build_space()
	_build_ship()
	_build_ui()
	_start_music()


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
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 2.4
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.basis = Basis.looking_at(-Vector3(0.6, 0.5, 0.3).normalized(), Vector3.UP)
	add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 50
	_cam.far = 9000
	add_child(_cam)
	_cam.make_current()


func _build_ship() -> void:
	_ship = (load("res://ship/ship_interior.tscn") as PackedScene).instantiate()
	add_child(_ship)
	for l in _ship.get_node("Lights").get_children():
		l.visible = false
	# Engines cold: adrift.
	var cold := StandardMaterial3D.new()
	cold.albedo_color = Color(0.08, 0.09, 0.1)
	for core in _ship.find_children("ThrusterCore*", "", true, false):
		(core as MeshInstance3D).material_override = cold


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 1.5)


## The piano lives on the root, so it carries on into the ship.
func _start_music() -> void:
	var old := get_tree().root.get_node_or_null("OpeningMusic")
	if old:
		old.queue_free()
	_music = AudioStreamPlayer.new()
	_music.name = "OpeningMusic"
	if ResourceLoader.exists(PIANO):
		_music.stream = load(PIANO)
		_music.volume_db = PIANO_DB
	else:
		push_warning("Opening: no music at %s (slot left empty)" % PIANO)
	get_tree().root.add_child.call_deferred(_music)
	if _music.stream:
		_music.ready.connect(_music.play, CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	_t += delta
	# The ship turns slowly as it drifts; the camera eases along beside it.
	var k := _t / LENGTH
	_ship.rotation = Vector3(0.06 + 0.01 * k, 0.6 + 0.08 * k, 0.1 - 0.02 * k)
	_ship.position = Vector3(0, 0, -0.8 * k)
	_cam.position = Vector3(26.0 - 2.0 * k, 7.0 - 0.6 * k, 30.0 - 3.0 * k)
	_cam.look_at(Vector3(0, 0, -2.0))
	var held := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER)
	_skip_held = _skip_held + delta if held else 0.0
	if (_t >= LENGTH or _skip_held > 0.9) and not _leaving:
		_leave(0.8)


func _leave(duration: float) -> void:
	_leaving = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, duration)
	await tw.finished
	# The ship scene reads this and plays the montage and the quarters
	# scene (ship/opening_cinematic.gd).
	get_tree().root.set_meta("opening_cinematic", true)
	get_tree().change_scene_to_file(NEXT_SCENE)
