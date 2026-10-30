extends CharacterBody3D

const MOUSE_SENSITIVITY = 0.003

@export_group("Movement")
## Default pace (m/s). The Run animation lands its feet at about 2.5 m/s;
## the model speeds the cycle up to match, so keep this under ~4.
@export var jog_speed := 3.6
## Pace while holding Shift (m/s). The Walk animation matches ~1.3 m/s.
@export var walk_speed := 1.45
## Hold Shift to jog instead (walking is the default).
@export var walk_by_default := false
## How quickly he gets up to speed (m/s per second).
@export var acceleration := 18.0
## How quickly he slows down when you let go (m/s per second).
@export var deceleration := 20.0
## Fastest he turns, standing / at a jog (degrees per second).
@export var turn_speed_standing := 1000.0
@export var turn_speed_moving := 620.0
## Fraction of ground control he keeps in the air.
@export_range(0.0, 1.0) var air_control := 0.5
@export var jump_velocity := 4.5
## Jumping still works this long after stepping off a ledge (seconds).
@export var coyote_time := 0.12

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
var _air_time := 0.0
var _jump_buffer := 0.0
var _fall_speed := 0.0
var _turn_rate := 0.0  # radians per second the body is turning

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
	_add_key("walk", KEY_SHIFT)
	# Grounded on slopes and small bumps: keep to the floor, same speed up
	# and down hill, and don't slide when standing on a slope.
	floor_snap_length = 0.35
	floor_constant_speed = true
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(46.0)
	spring_arm.add_excluded_object(get_rid())
	_setup_footsteps()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Coming from the intro cinematic: start sat in the pilot seat.
	if get_tree().root.has_meta("spawn_cockpit"):
		get_tree().root.remove_meta("spawn_cockpit")
		_start_in_pilot_seat.call_deferred()

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

	var grounded := is_on_floor()
	if not grounded:
		velocity += get_gravity() * delta
		_air_time += delta
		_fall_speed = maxf(_fall_speed, -velocity.y)
	# Jump: a little forgiving on both ends (pressed just before landing,
	# or just after walking off an edge).
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if not busy and Input.is_action_just_pressed("jump"):
		_jump_buffer = 0.12
	if _jump_buffer > 0.0 and _air_time < coyote_time and velocity.y <= 0.5:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_air_time = coyote_time
		if mesh.has_method("jumped"):
			mesh.jumped()

	var input_dir := Vector2.ZERO if busy else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := pivot.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	direction.y = 0
	direction = direction.normalized() * minf(input_dir.length(), 1.0)
	var walking := Input.is_action_pressed("walk") != walk_by_default
	var pace := walk_speed if walking else jog_speed

	# Turn the body toward where we're heading at a limited rate, so he
	# swings round instead of snapping. A sharp reversal slows him first
	# (a pivot) rather than moonwalking backwards.
	var facing := -mesh.global_transform.basis.z
	facing.y = 0
	facing = facing.normalized()
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	var align := 1.0
	_turn_rate = 0.0
	if direction.length() > 0.01:
		var want := atan2(-direction.x, -direction.z)
		var diff := wrapf(want - mesh.rotation.y, -PI, PI)
		var max_turn := deg_to_rad(lerpf(turn_speed_standing, turn_speed_moving, clampf(flat_speed / jog_speed, 0.0, 1.0)))
		var step := clampf(diff * 18.0 * delta, -max_turn * delta, max_turn * delta)
		mesh.rotation.y = wrapf(mesh.rotation.y + step, -PI, PI)
		_turn_rate = step / delta
		# Only a sharp reversal (more than ~110 degrees) slows him down.
		align = smoothstep(-0.35, 0.2, facing.dot(direction.normalized()))

	# On the ground he goes where you point straight away (no drifting);
	# only his speed ramps up and down, briefly. In the air the velocity
	# itself turns, slowly, so a jump keeps its momentum.
	var target_speed := pace * lerpf(0.35, 1.0, align) if direction.length() > 0.01 else 0.0
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	if grounded:
		var rate := acceleration if target_speed > flat_speed else deceleration
		var new_speed := move_toward(flat_speed, target_speed, rate * delta)
		var heading := direction.normalized() if direction.length() > 0.01 else horizontal.normalized()
		horizontal = heading * new_speed
	else:
		horizontal = horizontal.move_toward(direction * pace, acceleration * air_control * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()
	# Floor snapping doesn't always report a collision, so keep the last
	# floor we touched until we leave the ground.
	if not is_on_floor():
		_floor = null
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y > 0.7:
			_floor = c.get_collider()
	if is_on_floor():
		if _air_time > 0.25 and mesh.has_method("landed"):
			mesh.landed(_fall_speed)
		_air_time = 0.0
		_fall_speed = 0.0
	if mesh.has_method("set_locomotion"):
		var accel := (Vector2(velocity.x, velocity.z).length() - flat_speed) / maxf(delta, 0.0001)
		mesh.set_locomotion(Vector2(velocity.x, velocity.z).length(), walk_speed, jog_speed, is_on_floor() or _air_time < 0.15, _turn_rate, accel)
	else:
		mesh.set_move(Vector2(velocity.x, velocity.z).length() / jog_speed)
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
		var running := Vector2(velocity.x, velocity.z).length() > (walk_speed + jog_speed) * 0.5
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
