extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003

var has_coffee := false:
	set(value):
		has_coffee = value
		hud.set_held("Coffee   [F] Drink" if value else "")

var current_target: Interactable

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
	spring_arm.add_excluded_object(get_rid())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _add_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)

func _unhandled_input(event: InputEvent) -> void:
	if hud.is_busy():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		pivot.rotation.x = clamp(pivot.rotation.x - event.relative.y * MOUSE_SENSITIVITY, deg_to_rad(-60), deg_to_rad(30))
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("interact") and current_target and current_target.can_interact(self):
		current_target.interact(self)
		if mesh.has_method("play_action"):
			mesh.play_action("Interact")
	if event.is_action_pressed("drink") and has_coffee:
		has_coffee = false
		hud.show_message("Ahh. That's the stuff.")

func _physics_process(delta: float) -> void:
	var busy: bool = hud.is_busy()

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
	elif current_target.can_interact(self):
		hud.set_prompt("[E] " + current_target.get_prompt())
	else:
		hud.set_prompt(current_target.get_prompt())
