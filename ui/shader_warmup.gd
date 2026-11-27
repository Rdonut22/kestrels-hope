extends CanvasLayer

## Shader warm-up (autoload "ShaderWarmup"). The first time a material is
## drawn, the graphics driver compiles its shader, and on a Mac (Apple's
## OpenGL keeps nothing between runs) that freezes the game for seconds:
## right at the start of a scene, mid-animation (a door half open).
##
## So when one of SCENES starts, the game is paused behind a dark screen
## while the camera looks all round once from where it stands, drawing
## (and so compiling) everything near, then it unpauses and fades in. A
## scene already warmed up this session starts as before. Not in the
## playtests (their own SceneTree), so their timing is unchanged.

const SCENES := ["res://menu.tscn", "res://main.tscn", "res://crash_site.tscn"]
## Directions looked in: every 45 degrees round, a little up and down.
const YAWS := 8
const PITCHES := [-0.35, 0.3]
const FRAMES_EACH := 1
const FADE := 0.5

var _warmed := {}
var _busy := false
var _cover: ColorRect


func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree().get_script() != null or DisplayServer.get_name() == "headless":
		return
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null or _busy:
		return
	var path := scene.scene_file_path
	if not path in SCENES or _warmed.has(path):
		return
	_warmed[path] = true
	_warm_up(scene)


func _warm_up(scene: Node) -> void:
	_busy = true
	var t0 := Time.get_ticks_msec()
	var was_paused := get_tree().paused
	get_tree().paused = true
	_cover = ColorRect.new()
	_cover.color = Color.BLACK
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_cover)
	var note := Label.new()
	note.text = "Loading..."
	note.add_theme_color_override("font_color", Color(0.75, 0.72, 0.66))
	note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	note.position -= Vector2(140, 60)
	_cover.add_child(note)
	# Let the scene finish setting up (and its camera become current).
	for i in 3:
		await get_tree().process_frame
	var vp := get_viewport()
	var cam := vp.get_camera_3d()
	if cam and is_instance_valid(scene) and scene.is_inside_tree():
		var look := Camera3D.new()
		look.fov = maxf(cam.fov, 90.0)
		look.near = cam.near
		look.far = cam.far
		look.cull_mask = cam.cull_mask
		look.environment = cam.environment
		scene.add_child(look)
		look.global_position = cam.global_position
		look.make_current()
		for pitch: float in PITCHES:
			for k in YAWS:
				look.rotation = Vector3(pitch, TAU * k / YAWS, 0.0)
				for f in FRAMES_EACH:
					await get_tree().process_frame
		if is_instance_valid(cam):
			cam.make_current()
		look.queue_free()
		await get_tree().process_frame
	get_tree().paused = was_paused
	print("ShaderWarmup: %s ready in %d ms" % [scene.scene_file_path if is_instance_valid(scene) else "?", Time.get_ticks_msec() - t0])
	var tw := create_tween()
	tw.tween_property(_cover, "modulate:a", 0.0, FADE)
	tw.tween_callback(_cover.queue_free)
	_busy = false
