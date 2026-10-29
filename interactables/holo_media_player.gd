extends Interactable

## Holo-pad media player floating at an angle over the lounge table. The
## hologram shows the looping video beside a little track list and a live
## visualizer; E cycles Sad Jazz -> Vaporwave -> off.

const TRACKS := [
	{"genre": "SAD JAZZ", "title": "Misty", "path": "res://audio/music/misty.mp3"},
	{"genre": "VAPORWAVE", "title": "Sun", "path": "res://audio/music/sun.mp3"},
]
const VIDEO := "res://ship/media/holo_idol.ogv"
const SCREEN := Vector2i(900, 560)
const PAD_WIDTH := 1.1
const BARS := 18
const CYAN := Color(0.45, 0.85, 1.0)

const IDLE_YAW := -PI / 2  # faces the lounge entrance
const IDLE_TILT := -0.32  # leaning back for people standing

var _track := -1  # -1 = music off
var _rig: Node3D  # turns to face the viewer
var _pad: Node3D
var _yaw := IDLE_YAW
var _tilt := IDLE_TILT
var _rows: Array[Label] = []
var _now: Label
var _bars: Array[ColorRect] = []
var _levels := PackedFloat32Array()
var _progress: ColorRect
var _music: AudioStreamPlayer3D
var _spectrum: AudioEffectSpectrumAnalyzerInstance
var _glow: OmniLight3D


func _ready() -> void:
	needs_power = true
	_levels.resize(BARS)
	var viewport := _build_screen()
	_build_pad(viewport)
	_music = AudioStreamPlayer3D.new()
	_music.unit_size = 5.0
	_music.volume_db = -4.0
	_music.position = Vector3(0, 1.2, 0)
	_music.bus = _analyzer_bus()
	add_child(_music)
	_spectrum = AudioServer.get_bus_effect_instance(AudioServer.get_bus_index(_music.bus), 0)
	_refresh()
	# The hologram only appears once the power is back on.
	visible = Game.state().power_restored
	Game.state().power_restored_changed.connect(func(on: bool) -> void: visible = on)


func get_prompt() -> String:
	if _track + 1 < TRACKS.size():
		return "Play " + String(TRACKS[_track + 1].genre).capitalize()
	return "Stop music"


func interact(_player: Node) -> void:
	_track = _track + 1 if _track + 1 < TRACKS.size() else -1
	if _track == -1:
		_music.stop()
	else:
		var stream: AudioStream = load(TRACKS[_track].path)
		if "loop" in stream:
			stream.loop = true
		_music.stream = stream
		_music.play()
	_refresh()


# Music goes through its own bus with a spectrum analyzer for the bars.
func _analyzer_bus() -> StringName:
	var name := &"HoloMusic"
	if AudioServer.get_bus_index(name) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, &"Master")
		AudioServer.add_bus_effect(idx, AudioEffectSpectrumAnalyzer.new())
	return name


# The 2D screen the hologram shows, drawn into a SubViewport.
func _build_screen() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = SCREEN
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var font: FontFile = load("res://ui/fonts/Dena.otf")

	var frame := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = CYAN
	box.set_border_width_all(3)
	box.set_corner_radius_all(22)
	frame.add_theme_stylebox_override("panel", box)
	frame.position = Vector2(4, 4)
	frame.size = Vector2(SCREEN) - Vector2(8, 8)
	vp.add_child(frame)

	var video := VideoStreamPlayer.new()
	video.stream = load(VIDEO)
	video.expand = true
	video.loop = true
	video.volume_db = -80.0
	video.position = Vector2(24, 24)
	video.size = Vector2(560, 490)
	vp.add_child(video)
	video.play()

	var x := 610.0
	_label(vp, "HOLO // AUDIO", font, 21, Vector2(x, 28), CYAN * 0.8)
	for i in TRACKS.size():
		_rows.append(_label(vp, "", font, 25, Vector2(x, 92 + i * 74), CYAN))
		_label(vp, String(TRACKS[i].title).to_upper(), font, 16, Vector2(x + 26, 126 + i * 74), CYAN * 0.6)
	_now = _label(vp, "", font, 15, Vector2(x, 262), CYAN * 0.8)
	for i in BARS:
		var bar := ColorRect.new()
		bar.color = CYAN
		bar.position = Vector2(x + i * 14.5, 470)
		bar.size = Vector2(9, 4)
		vp.add_child(bar)
		_bars.append(bar)
	var track := ColorRect.new()
	track.color = CYAN * 0.35
	track.position = Vector2(x, 500)
	track.size = Vector2(258, 3)
	vp.add_child(track)
	_progress = ColorRect.new()
	_progress.color = CYAN
	_progress.position = Vector2(x, 498)
	_progress.size = Vector2(0, 7)
	vp.add_child(_progress)
	return vp


func _label(parent: Node, text: String, font: Font, size: int, pos: Vector2, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


# The floating pad: the screen on a tilted quad, a faint projector beam
# up from the table and a cool glow.
func _build_pad(vp: SubViewport) -> void:
	_rig = Node3D.new()
	_rig.rotation.y = IDLE_YAW
	add_child(_rig)
	_pad = Node3D.new()
	_pad.position = Vector3(0, 1.45, 0)
	_pad.rotation.x = IDLE_TILT
	_rig.add_child(_pad)
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(PAD_WIDTH, PAD_WIDTH * SCREEN.y / SCREEN.x)
	quad.mesh = qm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ship/holo_screen.gdshader")
	mat.set_shader_parameter("screen", vp.get_texture())
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pad.add_child(quad)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var apex := Vector3(0, 0.8, 0)
	var corners: Array[Vector3] = []
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		corners.append(_pad.transform * Vector3(c.x * qm.size.x / 2.0, c.y * qm.size.y / 2.0, 0))
	for i in 4:
		for p in [apex, corners[i], corners[(i + 1) % 4]]:
			st.set_uv(Vector2(0, 0.0 if p == apex else 1.0))
			st.add_vertex(p)
	var beam := MeshInstance3D.new()
	beam.mesh = st.commit()
	var bm := ShaderMaterial.new()
	bm.shader = load("res://ship/holo_beam.gdshader")
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rig.add_child(beam)

	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.5, 0.8, 1.0)
	_glow.light_energy = 0.6
	_glow.omni_range = 2.8
	_glow.position = Vector3(0, 1.3, 0)
	add_child(_glow)


## Turn the hologram to face a viewer at `eye` (e.g. someone sitting on the
## couch), tipped slightly toward them since they're below it.
func face(eye: Vector3) -> void:
	var d := to_local(eye)
	_yaw = atan2(d.x, d.z)
	_tilt = 0.12


## Back to facing the entrance for people walking in.
func unface() -> void:
	_yaw = IDLE_YAW
	_tilt = IDLE_TILT


func _refresh() -> void:
	for i in _rows.size():
		var on := i == _track
		_rows[i].text = ("> " if on else "   ") + TRACKS[i].genre
		_rows[i].modulate = Color(1, 1, 1, 1.0 if on else 0.45)
	_now.text = "NOW PLAYING" if _track >= 0 else "STANDBY  -  [E] TO PLAY"


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	_pad.position.y = 1.45 + sin(t * 1.1) * 0.012
	_rig.rotation.y = lerp_angle(_rig.rotation.y, _yaw, minf(1.0, delta * 3.0))
	_pad.rotation.x = lerpf(_pad.rotation.x, _tilt, minf(1.0, delta * 3.0))
	var energy := 0.0
	for i in BARS:
		var level := 0.0
		if _track >= 0 and _spectrum:
			var lo := 60.0 * pow(10000.0 / 60.0, float(i) / BARS)
			var hi := 60.0 * pow(10000.0 / 60.0, float(i + 1) / BARS)
			var mag := _spectrum.get_magnitude_for_frequency_range(lo, hi).length()
			level = clampf((linear_to_db(mag) + 62.0) / 50.0, 0.0, 1.0)
		_levels[i] = maxf(level, _levels[i] - delta * 1.8)
		energy += _levels[i] / BARS
		var h := 4.0 + _levels[i] * 150.0
		_bars[i].size.y = h
		_bars[i].position.y = 474.0 - h
	if _track >= 0 and _music.stream:
		_progress.size.x = 258.0 * _music.get_playback_position() / maxf(_music.stream.get_length(), 0.01)
	else:
		_progress.size.x = 0.0
	_glow.light_energy = 0.5 + energy * 0.8
