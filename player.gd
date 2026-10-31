extends CharacterBody3D

const SPEED = 5.0
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
var _steps: AudioStreamPlayer
var _floor: Object
var _seat: Node3D  # couch seat we're sitting on, if any
var _sit_cam: Camera3D
var _sit_look := Vector2.ZERO  # yaw, pitch offsets while seated

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
	_add_key("interact", KEY_E)
	_add_key("drink", KEY_F)
	_add_key("read", KEY_R)
	spring_arm.add_excluded_object(get_rid())
	_setup_footsteps()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Coming from the intro cinematic: start sat in the pilot seat.
	if get_tree().root.has_meta("spawn_cockpit"):
		get_tree().root.remove_meta("spawn_cockpit")
		_start_in_pilot_seat.call_deferred()
	# Continuing a saved game: back where we were (GameState.load_game).
	elif get_tree().root.has_meta("load_spawn"):
		var spawn: Dictionary = get_tree().root.get_meta("load_spawn")
		get_tree().root.remove_meta("load_spawn")
		_apply_save.call_deferred(spawn)


func _apply_save(spawn: Dictionary) -> void:
	var clock := get_tree().get_first_node_in_group("day_night")
	if clock and spawn.has("hour"):
		clock.skip_to(float(spawn["hour"]))
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

	var input_dir := Vector2.ZERO if busy else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := pivot.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	direction.y = 0
	direction = direction.normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		mesh.rotation.y = lerp_angle(mesh.rotation.y, atan2(-direction.x, -direction.z), 10 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	# Floor snapping doesn't always report a collision, so keep the last
	# floor we touched until we leave the ground.
	if not is_on_floor():
		_floor = null
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y > 0.7:
			_floor = c.get_collider()
	mesh.set_move(Vector2(velocity.x, velocity.z).length() / SPEED)
	# Hide the body when a wall shoves the camera right up against it.
	mesh.visible = spring_arm.get_hit_length() > 0.9
	_update_target(busy)

# Picks the in-range interactable closest to where the camera is facing.
func _update_target(busy: bool) -> void:
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
