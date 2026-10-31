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
	_set_midday()
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


func _set_midday() -> void:
	var clock := world.get_node("DayNight")
	clock.skip_to(11.0)
	clock.set_process(false)
	clock.set_process_unhandled_input(false)
	var env: Environment = world.get_node("WorldEnvironment").environment
	env.fog_depth_begin = 100.0
	env.fog_depth_end = 360.0
	_boost_smoke()


# Thicker, wind-blown smoke column so the wreck reads from the ring.
func _boost_smoke() -> void:
	var smoke: CPUParticles3D = world.get_node("CrashSite/Smoke")
	smoke.amount = 90
	smoke.lifetime = 16.0
	smoke.preprocess = 16.0
	smoke.emission_sphere_radius = 1.6
	smoke.initial_velocity_min = 2.4
	smoke.initial_velocity_max = 3.4
	smoke.spread = 8.0
	smoke.gravity = Vector3(0.18, 0.5, 0.1)
	smoke.scale_amount_min = 6.0
	smoke.scale_amount_max = 10.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.2, 0.18, 0.18, 1.0))
	ramp.add_point(0.35, Color(0.38, 0.34, 0.34, 0.85))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.62, 0.56, 0.58, 0.0))
	smoke.color_ramp = ramp
	# Keep the dusk haze from turning the column red.
	var mat: StandardMaterial3D = smoke.mesh.material.duplicate()
	mat.disable_fog = true
	mat.billboard_keep_scale = true
	mat.albedo_color = Color(1, 1, 1, 1)
	var quad: QuadMesh = smoke.mesh.duplicate()
	quad.material = mat
	smoke.mesh = quad
	smoke.restart()


## The redwoods' size on the title screen (they're 20-70 m tall in the
## game): lower, and spread wider so the crowns close up.
const MENU_TREE_SCALE := Vector3(0.85, 0.48, 0.85)
## Extra trees fill the gaps between the game's (deliberately airy) redwoods
## on this shot only: one per cell of this size, where there's room.
const MENU_FILL_SPACING := 10.0


# The crash-site forest only covers the play area; thicken it for the title
# shot and tile it around so the view from the ring is forest to the horizon.
func _extend_forest() -> void:
	var site := world.get_node("CrashSite")
	var offsets := [Vector3(184, 0, 0), Vector3(0, 0, 184), Vector3(0, 0, -184),
		Vector3(184, 0, 184), Vector3(184, 0, -184), Vector3(-184, 0, 0),
		Vector3(-184, 0, 184), Vector3(-184, 0, -184)]
	# One multimesh per distant redwood mesh (kind and part), gathered from
	# every tree, then copied round.
	var merged := {}  # mesh -> [material, transforms]
	for tree: Node3D in site.get_node("Redwoods").get_children():
		# Shrunk for this shot, so from the ring Gana looks out over the
		# treetops to the wreck instead of into a wall of giant trunks.
		tree.scale *= MENU_TREE_SCALE
		for part: MeshInstance3D in [tree.get_node("BarkFar"), tree.get_node("Foliage")]:
			# The far foliage: same kind, saved next to the full one.
			var mesh: Mesh = part.mesh if part.name == "BarkFar" else load(part.mesh.resource_path.replace("_lod0_", "_lod1_"))
			if not merged.has(mesh):
				merged[mesh] = [part.material_override, []]
			(merged[mesh][1] as Array).append(tree.transform)
	var fill := _fill_trees(site, merged)
	for mesh: Mesh in fill:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var xfs: Array = fill[mesh][1]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = fill[mesh][0]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		site.add_child(mmi)
	for mesh: Mesh in merged:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		var xfs: Array = merged[mesh][1]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		for off in offsets:
			var copy := MultiMeshInstance3D.new()
			copy.multimesh = mm
			copy.material_override = merged[mesh][0]
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			copy.position = off
			site.add_child(copy)


## Distant-version redwoods (smaller kinds) in the gaps of the play area,
## kept off the clearing, the wreck and its trail. Returns them as
## mesh -> [material, transforms], and adds them to `merged` for the tiling.
func _fill_trees(site: Node3D, merged: Dictionary) -> Dictionary:
	var taken: Array[Vector2] = []
	for tree: Node3D in site.get_node("Redwoods").get_children():
		taken.append(Vector2(tree.position.x, tree.position.z))
	var bark: Material = load("res://world/materials/redwood_bark.tres")
	var leaf: Material = load("res://world/materials/redwood_foliage.tres")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var fill := {}
	var x := -90.0
	while x <= 90.0:
		var z := -90.0
		while z <= 90.0:
			var p := Vector2(x, z) + Vector2(rng.randf_range(-3.5, 3.5), rng.randf_range(-3.5, 3.5))
			var kind: int = [2, 3, 4, 4, 5][rng.randi() % 5]
			var sc := rng.randf_range(0.8, 1.2)
			var yaw := rng.randf() * TAU
			z += MENU_FILL_SPACING
			var clearing := Vector2((p.x - 4.0) / 31.0, p.y / 26.0).length() < 1.0
			var trail := absf(p.x + 0.8) < 8.0 and p.y > 6.0 and p.y < 88.0
			if clearing or trail or taken.any(func(q: Vector2) -> bool: return q.distance_to(p) < 7.0):
				continue
			var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(MENU_TREE_SCALE * sc), Vector3(p.x, -0.5, p.y))
			for part in 2:
				var mesh: Mesh = load("res://world/redwoods/kind%d_lod1_%s.res" % [kind, ["bark", "foliage"][part]])
				for d in [fill, merged]:
					if not d.has(mesh):
						d[mesh] = [[bark, leaf][part], []]
					(d[mesh][1] as Array).append(xf)
		x += MENU_FILL_SPACING
	return fill


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
	_cam.fov = 68
	_cam.far = 900
	add_child(_cam)
	# From the side of the deck: the pilot in profile on the left third, the
	# wreck and its smoke far below in the valley he is looking at.
	var ring: Node3D = world.get_node("CrashSite/Ruins/GreatRing")
	var side := ring.global_basis.x.normalized()
	side.y = 0.0
	side = side.normalized()
	var facing := -seat.basis.z
	if facing.dot(side) > 0.0:
		side = -side
	var eye := seat.origin + side * 4.4 + facing * -0.6 + Vector3(0, 0.9, 0)
	# Turn from looking at the pilot toward where he's looking, tilt down a bit.
	var yaw_dir := (-side * cos(deg_to_rad(52.0)) + facing * sin(deg_to_rad(52.0))).normalized()
	var fwd := (yaw_dir * cos(deg_to_rad(10.0)) + Vector3.DOWN * sin(deg_to_rad(10.0))).normalized()
	_cam.global_position = eye
	_cam.look_at(eye + fwd)
	_cam_base = _cam.global_transform
	_cam.make_current()
	# One gigantic and one small moon in the sky of this shot.
	var b := _cam_base.basis
	var moons := world.get_node("SkyMoons")
	moons.point_at("giant", (-b.z + b.y * 0.47 - b.x * 0.12).normalized())
	moons.point_at("small", (-b.z + b.y * 0.56 + b.x * 1.0).normalized())


func _process(delta: float) -> void:
	_t += delta
	# Slow, breathing drift.
	var sway := Vector3(sin(_t * 0.13) * 0.25, sin(_t * 0.09) * 0.12, 0.0)
	_cam.global_transform = _cam_base.translated_local(sway).rotated_local(Vector3.UP, sin(_t * 0.07) * 0.012)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var font: FontFile = load("res://ui/fonts/Dena.otf")
	var shadow := Color(0.12, 0.04, 0.1, 0.85)

	var box := VBoxContainer.new()
	box.position = Vector2(72, 64)
	box.add_theme_constant_override("separation", 6)
	layer.add_child(box)
	var title := Label.new()
	title.text = "KESTREL'S HOPE"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.82))
	title.add_theme_color_override("font_shadow_color", shadow)
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "stranded on an uncharted world"
	sub.add_theme_font_override("font", font)
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.98, 0.78, 0.88, 0.9))
	sub.add_theme_color_override("font_shadow_color", shadow)
	sub.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 34)
	box.add_child(gap)
	for item in [["Continue", _on_continue, Game.state().has_save()], ["New Game", _on_new_game, true],
			["Crash Site (preview)", _on_crash_site, true], ["Quit", _on_quit, true]]:
		var b := Button.new()
		b.text = item[0]
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not item[2]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", 30)
		b.add_theme_color_override("font_color", Color(1.0, 0.93, 0.86))
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.62, 0.82))
		b.add_theme_color_override("font_pressed_color", Color(0.78, 0.58, 1.0))
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.32))
		b.add_theme_color_override("font_outline_color", shadow)
		b.add_theme_constant_override("outline_size", 6)
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


func _go(scene: String, load_save := false) -> void:
	if _starting:
		return
	_starting = true
	var tw := create_tween().set_parallel()
	tw.tween_property(_fade, "color:a", 1.0, 1.5)
	if _music:
		tw.tween_property(_music, "volume_db", -40.0, 1.5)
	await tw.finished
	if load_save and Game.state().load_game():
		return
	if load_save:
		Game.state().reset()
	get_tree().change_scene_to_file(scene)


func _on_new_game() -> void:
	get_tree().root.remove_meta("preview")
	Game.state().reset()
	_go("res://intro.tscn")


func _on_continue() -> void:
	get_tree().root.remove_meta("preview")
	_go("res://intro.tscn", true)


func _on_crash_site() -> void:
	# Just a look around: don't let it overwrite the saved game.
	get_tree().root.set_meta("preview", true)
	_go("res://crash_site.tscn")


func _on_quit() -> void:
	get_tree().quit()
