extends CharacterBody3D

const SPEED = 5.0
const WALK_SPEED = 1.4
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003

var has_coffee := false:
	set(value):
		has_coffee = value
		_show_held()
## Id of the book we're carrying (see Library), or "".
var held_book := "":
	set(value):
		held_book = value
		_show_held()

var current_target: Interactable
var _target_usable := false
var _steps: AudioStreamPlayer
var _floor: Object
var _seat: Node3D  # couch seat we're sitting on, if any
var _sit_cam: Camera3D
var _sit_look := Vector2.ZERO  # yaw, pitch offsets while seated
var _bike: Node3D  # the hover bike we're riding, if any (world/vehicles/hoverbike.gd)
var _ride_pose: Node  # character/ride_pose.gd on the model's skeleton
var _ride_tween: Tween
var _look_idle := 0.0  # seconds since the mouse last turned the camera

@onready var pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var mesh: Node3D = $Model
@onready var hud: Node = get_tree().get_first_node_in_group("hud")

func _ready() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("jump", KEY_SPACE)
	_add_key("walk", KEY_SHIFT)
	_add_key("interact", KEY_E)
	_add_key("drink", KEY_F)
	_add_key("read", KEY_R)
	spring_arm.add_excluded_object(get_rid())
	spring_arm.collision_mask |= CAMERA_LAYER
	_camera_blockers.call_deferred()
	_setup_footsteps()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Coming from the intro's exterior shot: the montage, the quarters and
	# the window scene (ship/opening_cinematic.gd).
	if get_tree().root.has_meta("opening_cinematic"):
		get_tree().root.remove_meta("opening_cinematic")
		var cine := Node.new()
		cine.name = "OpeningCinematic"
		cine.set_script(load("res://ship/opening_cinematic.gd"))
		get_parent().add_child.call_deferred(cine)
	# Start sat in the pilot seat.
	elif get_tree().root.has_meta("spawn_cockpit"):
		get_tree().root.remove_meta("spawn_cockpit")
		_start_in_pilot_seat.call_deferred()
	# Continuing a saved game: back where we were (GameState.load_game).
	elif get_tree().root.has_meta("load_spawn"):
		var spawn: Dictionary = get_tree().root.get_meta("load_spawn")
		get_tree().root.remove_meta("load_spawn")
		_apply_save.call_deferred(spawn)
		# Saved after the window scene but before leaving the quarters: the
		# hunger beat is still to come.
		var gs := Game.state()
		if gs.has_flag("opening_window_done") and not gs.has_objective(gs.EAT_TASK):
			var cine := Node.new()
			cine.name = "OpeningCinematic"
			cine.set_script(load("res://ship/opening_cinematic.gd"))
			cine.set("start_at", "hunger")
			get_parent().add_child.call_deferred(cine)


## The camera sits SHOULDER m to Gana's side; where something's closer
## than that (narrow cockpit, passages), the side offset shrinks so the
## boom never starts on the far side of a wall.
const SHOULDER := 0.5
const SHOULDER_GAP := 0.22


func _fit_shoulder(delta: float) -> void:
	var from := pivot.global_position
	var to := pivot.to_global(Vector3(SHOULDER + SHOULDER_GAP, 0, 0))
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | CAMERA_LAYER, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var want := SHOULDER
	if hit:
		want = clampf(from.distance_to(hit.position) - SHOULDER_GAP, 0.0, SHOULDER)
	# Pull in at once, ease back out.
	var x := spring_arm.position.x
	spring_arm.position.x = want if want < x else move_toward(x, want, delta * 0.8)


## The camera's own collision layer: everything you can see inside the ship
## (models without physics too: the cockpit's wall sections, dashboard,
## the kitchen cabinet and stove, pipes, crates) stops the camera boom, so
## it pulls in toward Gana instead of passing through. Nothing walks on it.
const CAMERA_LAYER := 1 << 18


func _camera_blockers() -> void:
	# The ship's runtime-built parts (cockpit, galley) are added in their
	# own _ready; wait for them.
	for i in 3:
		await get_tree().process_frame
	var scene := get_tree().current_scene
	var ship: Node = null
	for n in ["ShipInterior", "Ship"]:
		ship = scene.get_node_or_null(n) if scene else null
		if ship:
			break
	if ship == null:
		return
	for mi: MeshInstance3D in ship.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.transparency > 0.0:
			continue
		# Glass, glows and tiny bits don't stop the camera.
		var nm := String(mi.name).to_lower()
		if "glass" in nm or "window" in nm or "windshield" in nm or "glow" in nm or "light" in nm:
			continue
		if mi.get_aabb().size.length() * absf(mi.global_basis.get_scale().x) < 0.25:
			continue
		var faces := mi.mesh.get_faces()
		if faces.is_empty():
			continue
		# In the ship's frame, unscaled (physics mishandles mirrored or
		# scaled concave shapes: the right cockpit wall is a mirror).
		var xf: Transform3D = (ship as Node3D).global_transform.affine_inverse() * mi.global_transform
		for i in faces.size():
			faces[i] = xf * faces[i]
		var body := StaticBody3D.new()
		body.name = "CameraBlocker"
		body.collision_layer = CAMERA_LAYER
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		cs.shape = shape
		body.add_child(cs)
		ship.add_child(body)


func _apply_save(spawn: Dictionary) -> void:
	if spawn.get("riding", false):
		var bike := get_tree().get_first_node_in_group("hoverbike")
		if bike:
			var clock0 := get_tree().get_first_node_in_group("day_night")
			if clock0 and spawn.has("hour"):
				clock0.set_hour(float(spawn["hour"]))
			pivot.rotation = Vector3(float(spawn.get("pitch", -0.15)), float(spawn.get("yaw", 0.0)), 0.0)
			mount(bike, true)
			return
	var clock := get_tree().get_first_node_in_group("day_night")
	if clock and spawn.has("hour"):
		clock.set_hour(float(spawn["hour"]))
	if spawn.get("pilot_seat", false):
		var seat := get_tree().get_first_node_in_group("pilot_seat")
		if seat:
			sit(seat)
			return
	var p: Array = spawn.get("position", [])
	if p.size() == 3:
		global_position = Vector3(p[0], p[1], p[2])
	velocity = Vector3.ZERO
	pivot.rotation = Vector3(float(spawn.get("pitch", pivot.rotation.x)), float(spawn.get("yaw", pivot.rotation.y)), 0.0)
	mesh.rotation.y = float(spawn.get("model_yaw", mesh.rotation.y))

func _start_in_pilot_seat() -> void:
	var seat := get_tree().get_first_node_in_group("pilot_seat")
	if seat:
		sit(seat)
		seat.opening()


func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)

func _unhandled_input(event: InputEvent) -> void:
	if hud.is_busy():
		return
	if _seat:
		_seated_input(event)
		return
	if _bike:
		_riding_input(event)
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		pivot.rotation.x = clamp(pivot.rotation.x - event.relative.y * MOUSE_SENSITIVITY, deg_to_rad(-60), deg_to_rad(30))
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("interact") and current_target and current_target.can_interact(self) and _has_power(current_target):
		current_target.interact(self)
		if mesh.has_method("play_action"):
			mesh.play_action("Interact")
	if event.is_action_pressed("drink") and has_coffee:
		has_coffee = false
		hud.show_message("Ahh. That's the stuff.")
	if event.is_action_pressed("read") and held_book != "":
		hud.open_book(held_book)

func _physics_process(delta: float) -> void:
	var busy: bool = hud.is_busy()
	if _seat:
		_update_seated_prompt()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if not busy and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		if mesh.has_method("play_jump"):
			mesh.play_jump(Vector2(velocity.x, velocity.z).length() > SPEED * 0.55)

	var input_dir := Vector2.ZERO if busy else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := pivot.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	direction.y = 0
	direction = direction.normalized()

	if direction:
		# Shift to walk instead of run.
		var speed := WALK_SPEED if Input.is_action_pressed("walk") else SPEED
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		mesh.rotation.y = lerp_angle(mesh.rotation.y, atan2(-direction.x, -direction.z), 10 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	# What Gana is standing on (for the footstep sounds), looked up every
	# frame. Floor snapping doesn't always report a slide collision, so a
	# remembered floor went stale: after stepping on a rock, every later
	# step still counted as the rock and the grass went silent.
	_floor = _ground_below() if is_on_floor() else null
	mesh.set_move(Vector2(velocity.x, velocity.z).length() / SPEED)
	_fit_shoulder(delta)
	# Hide the body when a wall shoves the camera right up against it.
	mesh.visible = spring_arm.get_hit_length() > 0.9
	_update_target(busy)

# Picks the in-range interactable closest to where the camera is facing.
func _update_target(busy: bool) -> void:
	var previous := current_target
	current_target = null
	if not busy:
		var forward := -pivot.global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()
		var best_facing := 0.3
		for node in get_tree().get_nodes_in_group("interactables"):
			var to: Vector3 = node.global_position - global_position
			to.y = 0
			var dist := to.length()
			if dist > node.interact_range:
				continue
			var facing := forward.dot(to / dist) if dist > 0.01 else 1.0
			if facing > best_facing:
				best_facing = facing
				current_target = node

	# The thing Gana is looking at glows, with a tiny [E] above it when it
	# can be used (interactable.gd).
	var usable := current_target != null and current_target.can_interact(self) and _has_power(current_target)
	if current_target != previous or usable != _target_usable:
		if previous and is_instance_valid(previous) and previous != current_target:
			previous.set_highlighted(false)
		if current_target:
			current_target.set_highlighted(true, usable)
	_target_usable = usable
	if current_target == null:
		hud.set_prompt("")
	elif not _has_power(current_target):
		hud.set_prompt(current_target.get_prompt() + "   (no power)")
	elif current_target.can_interact(self):
		hud.set_prompt("[E] " + current_target.get_prompt())
	else:
		hud.set_prompt(current_target.get_prompt())

# Random grass step samples, triggered by the model's footstep signal.
func _setup_footsteps() -> void:
	var random := AudioStreamRandomizer.new()
	random.random_pitch = 1.12
	random.random_volume_offset_db = 2.0
	for i in 6:
		random.add_stream(i, load("res://audio/steps/grass_%d.ogg" % (i + 1)))
	_steps = AudioStreamPlayer.new()
	_steps.stream = random
	add_child(_steps)
	if mesh.has_signal("footstep"):
		mesh.footstep.connect(_on_footstep)

## The collider straight below Gana's feet (the capsule's centre is 1 m
## above them), else this frame's floor collision, else the last floor.
func _ground_below() -> Object:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 1.3)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		return hit.collider
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y > 0.7:
			return c.get_collider()
	return _floor


func _on_footstep() -> void:
	if _floor is Node and (_floor as Node).is_in_group("grass_surface"):
		var running := Vector2(velocity.x, velocity.z).length() > SPEED * 0.55
		_steps.volume_db = -6.0 if running else -11.0
		_steps.play()

# ---------- sitting ----------

## Sit on a couch seat: first-person view toward the holo-table, and the
## hologram turns to face us. E then works the media player; Space stands.
func sit(seat: Node3D) -> void:
	_seat = seat
	velocity = Vector3.ZERO
	mesh.set_move(0.0)
	mesh.visible = false
	global_position = seat.global_position + Vector3(0, 0.5, 0)
	if not _sit_cam:
		_sit_cam = Camera3D.new()
		_sit_cam.fov = 70
		_sit_cam.near = 0.05
		get_parent().add_child(_sit_cam)
	_sit_look = Vector2.ZERO
	_aim_sit_cam()
	_sit_cam.make_current()
	if seat.has_method("on_sit"):
		seat.on_sit(self)


func stand() -> void:
	var seat := _seat
	_seat = null
	if seat.has_method("on_stand"):
		seat.on_stand(self)
	if seat.has_method("stand_position"):
		var spot: Transform3D = seat.stand_position()
		global_position = spot.origin
		var face := -spot.basis.z
		var y := atan2(-face.x, -face.z)
		pivot.rotation = Vector3(-0.15, y, 0)
		mesh.rotation.y = y
		mesh.visible = true
		($CameraPivot/SpringArm3D/Camera3D as Camera3D).make_current()
		return
	# Step off the couch toward the room.
	var ahead: Vector3 = seat.look_target() - seat.global_position
	ahead.y = 0
	ahead = ahead.normalized()
	global_position = seat.global_position + ahead * 0.85 + Vector3(0, 1.0, 0)
	var yaw := atan2(-ahead.x, -ahead.z)
	pivot.rotation = Vector3(-0.15, yaw, 0)
	mesh.rotation.y = yaw
	mesh.visible = true
	($CameraPivot/SpringArm3D/Camera3D as Camera3D).make_current()


func _aim_sit_cam() -> void:
	var eye: Vector3 = _seat.eye_position()
	_sit_cam.global_position = eye
	_sit_cam.look_at(_seat.look_target())
	_sit_cam.rotate_y(_sit_look.x)
	_sit_cam.rotate_object_local(Vector3.RIGHT, _sit_look.y)


## Point the seated camera again (seats call this when they change view).
func reaim() -> void:
	_sit_look = Vector2.ZERO
	_aim_sit_cam()


func _seated_input(event: InputEvent) -> void:
	# The seat gets first go (e.g. the pilot seat's menu and panel).
	if _seat.has_method("seated_input") and _seat.seated_input(self, event):
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_sit_look.x = clampf(_sit_look.x - event.relative.x * MOUSE_SENSITIVITY, -1.1, 1.1)
		_sit_look.y = clampf(_sit_look.y - event.relative.y * MOUSE_SENSITIVITY, -0.5, 0.45)
		_aim_sit_cam()
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("jump") or event.is_action_pressed("move_back"):
		stand()
	elif event.is_action_pressed("interact") and _seat.has_method("media"):
		var media: Node = _seat.media()
		if media and _has_power(media):
			media.interact(self)
	elif event.is_action_pressed("read") and held_book != "":
		hud.open_book(held_book)


func _update_seated_prompt() -> void:
	current_target = null
	if _seat.has_method("seated_prompt"):
		hud.set_prompt(_seat.seated_prompt(self))
		return
	var media: Node = _seat.media()
	var text := "[Space] Stand up"
	if held_book != "":
		text = "[R] Read      " + text
	if media and _has_power(media):
		text = "[E] " + media.get_prompt() + "      " + text
	hud.set_prompt(text)


func _show_held() -> void:
	var lines := PackedStringArray()
	if has_coffee:
		lines.append("Coffee   [F] Drink")
	if held_book != "":
		lines.append("%s   [R] Read" % Library.find(held_book).title)
	hud.set_held("\n".join(lines))


func _has_power(target: Interactable) -> bool:
	return not target.needs_power or Game.state().power_restored


# ---------- riding the hover bike ----------

const RIDE_CAMERA_LENGTH := 4.2
const RIDE_PIVOT_HEIGHT := 1.05
const WALK_PIVOT_HEIGHT := 0.75

## Get on the hover bike: Gana is carried by it (ride_follow) and posed on
## its seat; the camera pulls back and follows behind.
func mount(bike: Node3D, instant := false) -> void:
	_bike = bike
	velocity = Vector3.ZERO
	mesh.set_move(0.0)
	($CollisionShape3D as CollisionShape3D).disabled = true
	spring_arm.add_excluded_object(bike.get_rid())
	bike.mount(self)
	if _ride_pose == null:
		var sk: Skeleton3D = mesh.find_children("*", "Skeleton3D", true, false)[0]
		_ride_pose = load("res://character/ride_pose.gd").new()
		_ride_pose.name = "RidePose"
		sk.add_child(_ride_pose)
	_ride_pose.set("active", true)
	if _ride_tween:
		_ride_tween.kill()
	_ride_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	var t := 0.01 if instant else 0.35
	_ride_tween.tween_property(_ride_pose, "amount", 1.0, t)
	_ride_tween.tween_property(spring_arm, "spring_length", RIDE_CAMERA_LENGTH, t * 2.0)
	_ride_tween.tween_property(pivot, "position:y", RIDE_PIVOT_HEIGHT, t * 2.0)
	ride_follow(bike)
	current_target = null


## Get off on whichever side is clear, standing beside the bike.
func dismount() -> void:
	var bike := _bike
	if bike == null:
		return
	var spot := _dismount_spot(bike)
	bike.dismount()
	_bike = null
	spring_arm.remove_excluded_object(bike.get_rid())
	($CollisionShape3D as CollisionShape3D).disabled = false
	global_position = spot
	velocity = Vector3.ZERO
	mesh.position = Vector3(0, -1, 0)
	var fwd := -bike.global_basis.z
	mesh.rotation = Vector3(0, atan2(-fwd.x, -fwd.z), 0)
	if _ride_tween:
		_ride_tween.kill()
	_ride_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	_ride_tween.tween_property(_ride_pose, "amount", 0.0, 0.25)
	_ride_tween.tween_property(spring_arm, "spring_length", 2.4, 0.5)
	_ride_tween.tween_property(pivot, "position:y", WALK_PIVOT_HEIGHT, 0.5)


## Beside the bike (left, then right, then behind), where Gana's capsule fits
## and there's ground.
func _dismount_spot(bike: Node3D) -> Vector3:
	var space := get_world_3d().direct_space_state
	var shape := PhysicsShapeQueryParameters3D.new()
	shape.shape = ($CollisionShape3D as CollisionShape3D).shape
	shape.exclude = [get_rid(), bike.get_rid()]
	for local in [Vector3(-1.3, 0, 0.3), Vector3(1.3, 0, 0.3), Vector3(0, 0, 2.2), Vector3(-1.3, 0, -1.0), Vector3(1.3, 0, -1.0)]:
		var p: Vector3 = bike.global_transform * local
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p + Vector3.DOWN * 3.0)
		q.exclude = [get_rid(), bike.get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var at: Vector3 = hit.position + Vector3.UP * 1.02
		shape.transform = Transform3D(Basis(), at)
		if space.intersect_shape(shape, 1).is_empty():
			return at
	return bike.global_position + Vector3.UP * 2.2


## Called by the bike each physics frame after it moves: Gana sits on it.
func ride_follow(bike: Node3D) -> void:
	var seat: Transform3D = bike.rider_transform()
	var hips_up: float = mesh.hip_height() if mesh.has_method("hip_height") else 0.95
	# The model's feet are hip height below the hips, along the bike's up.
	var feet := seat.origin - seat.basis.y * hips_up
	mesh.global_transform = Transform3D(seat.basis, feet)
	global_position = Vector3(feet.x, feet.y + 1.0, feet.z)
	if _ride_pose:
		var g: Array = bike.grips()
		var f: Array = bike.footrests()
		_ride_pose.set("left_hand", g[0])
		_ride_pose.set("right_hand", g[1])
		_ride_pose.set("left_foot", f[0])
		_ride_pose.set("right_foot", f[1])
		_ride_pose.set("forward", -bike.global_basis.z)


func _riding_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		pivot.rotation.x = clamp(pivot.rotation.x - event.relative.y * MOUSE_SENSITIVITY, deg_to_rad(-50), deg_to_rad(25))
		_look_idle = 0.0
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("interact"):
		dismount()
		get_viewport().set_input_as_handled()


func _riding_update(delta: float) -> void:
	current_target = null
	hud.set_prompt("[W/S] Throttle      [A/D] Steer      [Shift] Boost      [E] Get off")
	# Once the mouse has been left alone a moment, the camera swings round
	# behind the bike while it's moving.
	_look_idle += delta
	var spd: float = absf(float(_bike.get("speed")))
	if _look_idle > 1.0 and spd > 2.0:
		var fwd := -_bike.global_basis.z
		var behind := atan2(-fwd.x, -fwd.z)
		var k := clampf(delta * 2.5 * clampf(spd / 8.0, 0.3, 1.0), 0.0, 1.0)
		pivot.rotation.y = lerp_angle(pivot.rotation.y, behind, k)
		pivot.rotation.x = lerp_angle(pivot.rotation.x, -0.2, k)
