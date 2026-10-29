extends CharacterBody3D

## Meki: the ship's drone and Gana's link to the ship's computer. Starts
## dead on the engineering workbench; once repaired he boots up, brings the
## power back (Game.state().meki_online) and floats along after Gana, bobbing
## and keeping an eye on him. E talks to him (see meki_talk.gd).

const MODEL := "res://characters/meki/meki.glb"
const PAINT := "res://characters/meki/meki_paint.gdshader"
const SCALE := 0.7

var dead := true
var _model: Node3D
var _glow_mats: Array[StandardMaterial3D] = []
var _lens_mats: Array[StandardMaterial3D] = []
var _hover := 0.0
var _sfx: AudioStreamPlayer3D
var _player: Node3D
var _spark_light: OmniLight3D
## While set, Meki hovers here (e.g. jacked into a computer) instead of
## following Gana; `_hold_look` is what he faces.
var _hold := Vector3.INF
var _hold_look := Vector3.ZERO
## Docked exactly in place (plugged in), no drifting or bobbing.
var _docked := false
var _arm: Node3D
## Where Gana has been walking (open floor, newest last); when a wall cuts
## Meki off he pops back onto this trail instead of grinding into it.
var _trail: Array[Vector3] = []
var _trail_timer := 0.0
var _blocked := 0.0


func _enter_tree() -> void:
	add_to_group("meki")


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	# His own layer: the player walks through him, doors still notice him.
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.18
	shape.shape = ball
	add_child(shape)
	_build_model()
	_arm = Node3D.new()
	_arm.name = "JackArm"
	_arm.set_script(load("res://characters/meki/jack_arm.gd"))
	_arm.set("reach", 0.5)
	add_child(_arm)
	_sfx = AudioStreamPlayer3D.new()
	_sfx.unit_size = 4.0
	add_child(_sfx)
	if Game.state().meki_online:
		dead = false
		_set_glow(1.0)
		_add_talk()
		Game.state().set_flag("meki_waiting")
	else:
		# Slumped on the bench, lights out.
		_model.rotation = Vector3(0.35, 0.4, 0.75)
		_set_glow(0.0)


func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	var scene: Node3D = (load(MODEL) as PackedScene).instantiate()
	_model.add_child(scene)
	scene.scale = Vector3.ONE * SCALE
	# Centre the model on this node.
	var box := AABB()
	var first := true
	var to_model := _model.global_transform.affine_inverse()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = to_model * mi.global_transform * mi.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	scene.position = -box.get_center()
	var paint: Shader = load(PAINT)
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if not m:
				continue
			if m.albedo_texture:
				# Beige paint, rust and grime over the original metal.
				var pm := ShaderMaterial.new()
				pm.shader = paint
				pm.set_shader_parameter("detail", m.albedo_texture)
				if m.normal_texture:
					pm.set_shader_parameter("normal_tex", m.normal_texture)
					pm.set_shader_parameter("has_normal", true)
				mi.set_surface_override_material(i, pm)
			elif m.resource_name.begins_with("light") or m.resource_name == "Verre":
				var own := m.duplicate() as StandardMaterial3D
				own.emission_enabled = true
				mi.set_surface_override_material(i, own)
				if m.resource_name == "Verre":
					own.emission = Color(0.3, 0.8, 1.0)
					_lens_mats.append(own)
				else:
					own.emission = Color(1.0, 0.75, 0.25)
					_glow_mats.append(own)


func _set_glow(amount: float) -> void:
	for m in _glow_mats:
		m.emission_energy_multiplier = 2.5 * amount
	for m in _lens_mats:
		m.emission_energy_multiplier = 3.0 * amount


## Little sparks and sounds while he's being repaired on the bench.
func repair_fx(kind: String) -> void:
	_play("res://audio/sfx/%s.ogg" % ("weld" if kind == "weld" else "click"))
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.amount = 40 if kind == "weld" else 18
	sparks.lifetime = 0.6
	sparks.explosiveness = 0.2 if kind == "weld" else 0.9
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.initial_velocity_min = 1.0
	sparks.initial_velocity_max = 2.5
	sparks.gravity = Vector3(0, -6, 0)
	sparks.scale_amount_min = 0.01
	sparks.scale_amount_max = 0.025
	var dot := SphereMesh.new()
	dot.radius = 0.5
	dot.height = 1.0
	dot.radial_segments = 4
	dot.rings = 2
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(1.0, 0.75, 0.35)
	dot.material = hot
	sparks.mesh = dot
	sparks.position = Vector3(0, 0.12, 0)
	add_child(sparks)
	sparks.emitting = true
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.6, 0.8, 1.0) if kind == "weld" else Color(1.0, 0.8, 0.5)
	flash.omni_range = 2.0
	flash.position = Vector3(0, 0.25, 0)
	add_child(flash)
	var t := 1.8 if kind == "weld" else 0.25
	var end := Time.get_ticks_msec() + int(t * 1000)
	while Time.get_ticks_msec() < end:
		flash.light_energy = randf_range(0.5, 2.5)
		await get_tree().process_frame
	flash.queue_free()
	await get_tree().create_timer(1.0).timeout
	sparks.queue_free()


## Wakes up after the repair: lights flicker on, he rights himself and
## rises off the bench, then the ship's power comes back.
func boot() -> void:
	_play("res://audio/sfx/boot.ogg")
	for k in 6:
		_set_glow(randf_range(0.2, 1.0) if k < 5 else 1.0)
		await get_tree().create_timer(0.14).timeout
	var tw := create_tween().set_parallel()
	tw.tween_property(_model, "rotation", Vector3.ZERO, 1.0).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "global_position", global_position + Vector3(0, 0.55, 0), 1.2).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_play("res://audio/sfx/beep.ogg")
	dead = false
	_add_talk()
	Game.state().meki_online = true
	diagnose()


## Meki's first words and his ship diagnosis, right after he wakes.
func diagnose() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	await hud.think([
		["MEKI", "...Gana? How long was I out?"],
		"Forty-three days, buddy. Welcome back.",
		["MEKI", "Forty-three... Running diagnostics. Please hold."],
	])
	_play("res://audio/sfx/beep.ogg")
	await hud.think([
		["MEKI", "Main power cell is cracked. We've been running on scraps this whole time."],
		["MEKI", "Port thrusters aren't getting any power at all. Nav array and comms are damaged too."],
		["MEKI", "One more thing. There's a private file in my memory marked HALE. It's corrupted. I'll... keep working on it."],
		"...Hale's?",
		["MEKI", "First things first. I can jack into the power junction and route the backup cell around the damage."],
		["MEKI", "Meet me in engineering, at the junction next to the power panel."],
	])
	# Float over to the jack socket and wait there (see jack_socket.gd).
	Game.state().set_flag("meki_waiting")


## Park at a spot (plugged into a computer) looking at `look`.
func hold_at(pos: Vector3, look: Vector3) -> void:
	_hold = pos
	_hold_look = look


func release() -> void:
	_hold = Vector3.INF
	_docked = false


## Glide to exactly `pos` facing `look` and stay put there (to plug in).
func dock(pos: Vector3, look: Vector3) -> void:
	hold_at(pos, look)
	_docked = true
	velocity = Vector3.ZERO
	var face := look - pos
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "global_position", pos, 0.9).set_trans(Tween.TRANS_SINE)
	var yaw := _model.rotation.y + wrapf(atan2(face.x, face.z) - _model.rotation.y, -PI, PI)
	tw.tween_property(_model, "rotation", Vector3(0, yaw, 0), 0.6)
	tw.tween_property(_model, "position:y", 0.0, 0.6)
	await tw.finished


## Model yaw that points his lens (on the model's +X side) along `dir`.
static func _yaw_to(dir: Vector3) -> float:
	return atan2(-dir.z, dir.x)


## His telescoping jack arm (characters/meki/jack_arm.gd).
func jack_arm() -> Node3D:
	return _arm


func play_sfx(path: String) -> void:
	_play(path)


func _add_talk() -> void:
	var talk := Node3D.new()
	talk.set_script(load("res://interactables/meki_talk.gd"))
	talk.set("interact_range", 1.8)
	add_child(talk)


func _physics_process(delta: float) -> void:
	if dead or _docked:
		return
	if not _player:
		_player = get_tree().current_scene.get_node_or_null("Player")
		if not _player:
			return
	var t := Time.get_ticks_msec() * 0.001
	# Hover off Gana's right shoulder, drifting a little.
	var pivot: Node3D = _player.get_node("CameraPivot")
	var right := pivot.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	var target := _player.global_position + right * 0.75 + Vector3(0, 0.75 + sin(t * 0.7) * 0.08, 0) \
		+ Vector3(sin(t * 0.31), 0, cos(t * 0.23)) * 0.25
	var seat: Node3D = _player.get("_seat")
	if _hold != Vector3.INF:
		target = _hold
	elif seat and seat.has_method("stand_position"):
		# Out of the way while he's sitting: hover behind the seat.
		var stand: Transform3D = seat.stand_position()
		target = stand.origin + Vector3(0, 0.6 + sin(t * 0.7) * 0.06, 0.3)
	_record_trail(delta)
	var following := _hold == Vector3.INF and not seat
	if _cut_off(target, following, delta):
		return
	var to := target - global_position
	velocity = velocity.lerp(to * 2.2, minf(1.0, delta * 4.0)).limit_length(4.0)
	move_and_slide()
	# Bob, tilt into the motion and keep the lens on Gana.
	_hover += delta
	_model.position.y = sin(_hover * 2.1) * 0.04
	var look := (_player.global_position + Vector3(0, 0.6, 0) if _hold == Vector3.INF else _hold_look) - global_position
	_model.rotation.y = lerp_angle(_model.rotation.y, _yaw_to(look), minf(1.0, delta * 3.0))
	_model.rotation.z = lerpf(_model.rotation.z, -clampf(velocity.length() * 0.08, 0.0, 0.3), minf(1.0, delta * 3.0))


func _record_trail(delta: float) -> void:
	_trail_timer -= delta
	if _trail_timer > 0.0 or not _player.is_on_floor():
		return
	_trail_timer = 0.2
	var p := _player.global_position + Vector3(0, 0.8, 0)
	if _trail.is_empty() or _trail[-1].distance_to(p) > 0.3:
		_trail.append(p)
		if _trail.size() > 40:
			_trail.pop_front()


func _clear_line(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1, [get_rid(), _player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Walls between Meki and where he's going for over a second: jump to the
## closest open spot instead (his hold spot, or back along Gana's trail).
## True if he moved.
func _cut_off(target: Vector3, following: bool, delta: float) -> bool:
	var head := _player.global_position + Vector3(0, 0.8, 0)
	# Following, it's Gana he needs to see (his shoulder spot can be in a wall).
	var goal := head if following else target
	var far := global_position.distance_to(target) > 7.0
	if _clear_line(global_position, goal) and not far:
		_blocked = 0.0
		return false
	_blocked += delta
	if _blocked < 1.0 and not far:
		return false
	_blocked = 0.0
	var spot := target
	if following:
		# The most recent trail point that can see Gana and is a little
		# behind him (so he appears from where Gana just came).
		spot = head + _player.get_node("CameraPivot").global_transform.basis.z * 0.6
		for i in range(_trail.size() - 1, -1, -1):
			if _trail[i].distance_to(head) > 0.9 and _clear_line(_trail[i], head):
				spot = _trail[i]
				break
	global_position = spot
	velocity = Vector3.ZERO
	return true


func _play(path: String) -> void:
	_sfx.stream = load(path)
	_sfx.play()
