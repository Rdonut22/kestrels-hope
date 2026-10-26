extends Node3D

## Start menu: the pilot sits on top of the Great Ring at dusk, looking out
## over the forest toward his crashed ship. Title and buttons are drawn at
## low resolution and scaled up with nearest filtering for a pixel look.

const MUSIC_PATHS := ["res://audio/menu_theme.ogg", "res://audio/menu_theme.mp3", "res://audio/menu_theme.wav"]
# Front edge of the lookout deck on top of the ring (ring-local space).
const RING_TOP_LOCAL := Vector3(0, 46.62, 6.15)

@onready var world: Node3D = $World

var _cam: Camera3D
var _cam_base: Transform3D
var _fade: ColorRect
var _music: AudioStreamPlayer
var _t := 0.0
var _starting := false


func _ready() -> void:
	_quiet_world()
	_set_dusk()
	_extend_forest()
	var seat := _place_pilot()
	_setup_camera(seat)
	_build_ui()
	_start_music()


func _quiet_world() -> void:
	var player := world.get_node("Player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	world.get_node("HUD").visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _set_dusk() -> void:
	var clock := world.get_node("DayNight")
	clock.skip_to(17.95)
	clock.set_process(false)
	clock.set_process_unhandled_input(false)
	var env: Environment = world.get_node("WorldEnvironment").environment
	env.fog_depth_begin = 70.0
	env.fog_depth_end = 260.0
	var sky: ShaderMaterial = env.sky.sky_material
	sky.set_shader_parameter("moon_a_dir", Vector3(-0.92, 0.3, 0.32))
	sky.set_shader_parameter("moon_b_dir", Vector3(-0.95, 0.24, -0.1))
	sky.set_shader_parameter("moon_scale", 1.35)
	sky.set_shader_parameter("prism", 1.0)


# The crash-site forest only covers the play area; tile its tree layers
# around it so the view from the ring is forest to the horizon.
func _extend_forest() -> void:
	var site := world.get_node("CrashSite")
	var offsets := [Vector3(184, 0, 0), Vector3(0, 0, 184), Vector3(0, 0, -184),
		Vector3(184, 0, 184), Vector3(184, 0, -184), Vector3(-184, 0, 0),
		Vector3(-184, 0, 184), Vector3(-184, 0, -184)]
	for layer in ["Trunks", "Pines", "Canopies"]:
		var src: MultiMeshInstance3D = site.get_node(layer)
		for off in offsets:
			var copy := MultiMeshInstance3D.new()
			copy.multimesh = src.multimesh
			copy.material_override = src.material_override
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			copy.position = off
			site.add_child(copy)


func _place_pilot() -> Transform3D:
	var ring: Node3D = world.get_node("CrashSite/Ruins/GreatRing")
	var top: Vector3 = ring.global_transform * RING_TOP_LOCAL
	var ship: Node3D = world.get_node("Ship")
	var look: Vector3 = ship.global_position - top
	look.y = 0.0
	var basis := Basis.looking_at(look.normalized(), Vector3.UP)
	var seat := Transform3D(basis, top)
	var pilot: Node3D = (load("res://character/character.tscn") as PackedScene).instantiate()
	add_child(pilot)
	pilot.set_process(false)
	# Hips sit on the edge; the model's origin is at its feet when standing.
	pilot.global_transform = Transform3D(basis, top + Vector3(0, -0.82, 0) - basis.z * 0.12)
	_pose_sitting(pilot)
	return seat


func _pose_sitting(pilot: Node3D) -> void:
	var anim: AnimationPlayer = pilot.get_node("Adventurer/AnimationPlayer")
	anim.play("CharacterArmature|Idle")
	anim.seek(0.4, true)
	anim.pause()
	var skel: Skeleton3D = pilot.find_children("*", "Skeleton3D", true, false)[0]
	# Work in skeleton space: thighs swing forward 90 degrees, shins hang down.
	var to_skel := skel.global_transform.affine_inverse().basis
	var forward := (to_skel * -pilot.global_basis.z).normalized()
	var right := (to_skel * pilot.global_basis.x).normalized()
	for side in ["L", "R"]:
		var thigh := skel.find_bone("UpperLeg." + side)
		var shin := skel.find_bone("LowerLeg." + side)
		var hip := skel.get_bone_global_pose(thigh)
		var knee := skel.get_bone_global_pose(shin)
		var down := (knee.origin - hip.origin).normalized()
		var swing := Basis(right, down.signed_angle_to(forward, right))
		hip.basis = swing * hip.basis
		skel.set_bone_global_pose(thigh, hip)
		var knee2 := skel.get_bone_global_pose(shin)
		knee2.basis = swing.inverse() * Basis(right, -0.15) * knee2.basis
		skel.set_bone_global_pose(shin, knee2)
	# Lean back a touch on straight arms.
	var spine := skel.find_bone("Abdomen")
	var sp := skel.get_bone_global_pose(spine)
	sp.basis = Basis(right, 0.12) * sp.basis
	skel.set_bone_global_pose(spine, sp)


func _setup_camera(seat: Transform3D) -> void:
	_cam = Camera3D.new()
	_cam.fov = 58
	_cam.far = 800
	add_child(_cam)
	var b := seat.basis
	# Behind and off to the side of the deck, looking out slightly below the
	# horizon so the moons, the forest and the ship far below all fit.
	var eye := seat.origin + b.z * 6.5 - b.x * 3.2 + Vector3(0, 2.2, 0)
	var target := eye + (-b.z) * 100.0 + b.x * 14.0 + Vector3(0, -12.0, 0)
	_cam.global_position = eye
	_cam.look_at(target)
	_cam_base = _cam.global_transform
	_cam.make_current()


func _process(delta: float) -> void:
	_t += delta
	# Slow, breathing drift.
	var sway := Vector3(sin(_t * 0.13) * 0.25, sin(_t * 0.09) * 0.12, 0.0)
	_cam.global_transform = _cam_base.translated_local(sway).rotated_local(Vector3.UP, sin(_t * 0.07) * 0.012)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.stretch_shrink = 3
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(container)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.handle_input_locally = true
	container.add_child(vp)

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Menlo", "Monaco", "DejaVu Sans Mono", "monospace"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE

	var box := VBoxContainer.new()
	box.position = Vector2(22, 22)
	box.add_theme_constant_override("separation", 0)
	vp.add_child(box)
	var title := Label.new()
	title.text = "KESTREL'S HOPE"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.78))
	title.add_theme_color_override("font_outline_color", Color(0.18, 0.08, 0.14))
	title.add_theme_constant_override("outline_size", 4)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "stranded on an uncharted world"
	sub.add_theme_font_override("font", font)
	sub.add_theme_font_size_override("font_size", 8)
	sub.add_theme_color_override("font_color", Color(0.95, 0.75, 0.85, 0.85))
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 70)
	box.add_child(gap)
	for item in [["New Game", _on_new_game, true], ["Continue", Callable(), false],
			["Crash Site (preview)", _on_crash_site, true], ["Quit", _on_quit, true]]:
		var b := Button.new()
		b.text = item[0]
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not item[2]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", 10)
		b.add_theme_color_override("font_color", Color(1.0, 0.92, 0.85))
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.62, 0.8))
		b.add_theme_color_override("font_pressed_color", Color(0.75, 0.55, 1.0))
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
		b.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.1))
		b.add_theme_constant_override("outline_size", 3)
		if item[2]:
			b.pressed.connect(item[1])
		box.add_child(b)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 2.5)


func _start_music() -> void:
	for path in MUSIC_PATHS:
		if ResourceLoader.exists(path):
			_music = AudioStreamPlayer.new()
			_music.stream = load(path)
			if "loop" in _music.stream:
				_music.stream.loop = true
			_music.volume_db = -40.0
			add_child(_music)
			_music.play()
			create_tween().tween_property(_music, "volume_db", -6.0, 4.0)
			return


func _go(scene: String) -> void:
	if _starting:
		return
	_starting = true
	var tw := create_tween().set_parallel()
	tw.tween_property(_fade, "color:a", 1.0, 1.5)
	if _music:
		tw.tween_property(_music, "volume_db", -40.0, 1.5)
	await tw.finished
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_file(scene)


func _on_new_game() -> void:
	_go("res://main.tscn")


func _on_crash_site() -> void:
	_go("res://crash_site.tscn")


func _on_quit() -> void:
	get_tree().quit()
