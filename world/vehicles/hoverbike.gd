class_name Hoverbike
extends CharacterBody3D

## The Kestrel's hover bike (model: world/vehicles/hoverbike/). Gana gets on
## with E (the "Seat" interactable), rides with W/S (throttle and brake),
## A/D (steer) and Shift (boost), and gets off with E.
##
## It floats `hover_height` above whatever is below it, found with rays
## each physics frame, and tips with the ground, its turns and its
## acceleration. While ridden it carries the player (player.gd ride_follow),
## who sees it in first person from the seat (eye_transform).
##
## Frames: the bike faces -Z, its origin is on the ground below its middle.
## The model's own frame faces -X (MODEL_*), scaled by MODEL_SCALE.

@export var hover_height := 0.45
@export var max_speed := 13.0
@export var boost_speed := 20.0
@export var reverse_speed := 4.0
@export var acceleration := 7.0
@export var boost_acceleration := 10.0
@export var braking := 14.0
@export var coasting := 3.5
@export var turn_rate := 1.9       # radians a second at speed
@export var grip := 6.0            # how fast sideways drift dies away

const MODEL_NEAR := "res://world/vehicles/hoverbike/hoverbike.glb"
const MODEL_FAR := "res://world/vehicles/hoverbike/hoverbike_far.glb"
const MODEL_SHADOW := "res://world/vehicles/hoverbike/hoverbike_shadow.glb"
const MODEL_SCALE := 1.35
const MODEL_BOTTOM := -0.344        # the model's lowest point (model units)
## Beyond this the lighter model is drawn (it looks the same from there).
const NEAR_DISTANCE := 8.0
## The rider's hips over the seat, in the model's frame (measured from the
## mesh), and how far above them his eyes are when sat (metres) and how far
## he leans forward toward the handlebars.
const MODEL_HIPS := Vector3(0.33, 0.11, 0.0)
const EYE_HEIGHT := 0.72
const EYE_FORWARD := 0.12
## The first-person view looks down this much (radians), so the
## handlebars and the front of the bike are in view.
const EYE_PITCH := -0.24

var rider: Node3D               # the player while riding
var speed := 0.0                # along the bike's facing, m/s
var _body: Node3D               # tips and bobs; holds the model
var _model: Node3D
var _near_mesh: MeshInstance3D
var _ground_ok := false
var _slope := 0.0
var _tilt := Vector2.ZERO       # pitch, roll (radians)
var _steer := 0.0
var _last_speed := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("hoverbike")
	# Smoothed between physics steps (see game_state.gd _ready).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_build_model()
	_build_collision()
	var seat := Node3D.new()
	seat.name = "Seat"
	seat.set_script(load("res://world/vehicles/hoverbike_seat.gd"))
	add_child(seat)
	var saved: Dictionary = Game.state().get("hoverbike")
	if not saved.is_empty():
		load_state(saved)


# ------------------------------------------------------------------ building

func _build_model() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_model = Node3D.new()
	_model.name = "Model"
	_model.transform = Transform3D(Basis(Vector3.UP, -PI / 2).scaled(Vector3.ONE * MODEL_SCALE), Vector3(0, _model_y(), 0))
	_body.add_child(_model)
	var near_mesh := _glb_mesh(MODEL_NEAR)
	var mat: Material = near_mesh.surface_get_material(0) if near_mesh else null
	_near_mesh = MeshInstance3D.new()
	_near_mesh.name = "Near"
	_near_mesh.mesh = near_mesh
	_near_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_near_mesh.visibility_range_end = NEAR_DISTANCE
	_near_mesh.visibility_range_end_margin = 1.0
	_model.add_child(_near_mesh)
	var far := MeshInstance3D.new()
	far.name = "Far"
	far.mesh = _glb_mesh(MODEL_FAR)
	far.material_override = mat
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far.visibility_range_begin = NEAR_DISTANCE
	far.visibility_range_begin_margin = 1.0
	_model.add_child(far)
	# Its shadow comes from a rough version: only the outline shows.
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	shadow.mesh = _glb_mesh(MODEL_SHADOW)
	shadow.material_override = mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_model.add_child(shadow)


func _glb_mesh(path: String) -> Mesh:
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate()
	var mi := root.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (mi[0] as MeshInstance3D).mesh if not mi.is_empty() else null
	root.free()
	return mesh


func _build_collision() -> void:
	# A box round the body, clear of the ground (small bumps pass under).
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 0.75, 2.4)
	cs.shape = box
	cs.position = Vector3(0, _model_y() + 0.05, 0)
	add_child(cs)


func _model_y() -> float:
	return hover_height - MODEL_BOTTOM * MODEL_SCALE


## A point given in the model's frame, in world space (tipping included).
func model_point(p: Vector3) -> Vector3:
	return _model.global_transform * p


## The rider's eyes on the seat: up and forward with the bike as it tips.
func eye_transform() -> Transform3D:
	return global_transform * eye_local()


## The same in the bike's own frame (the rider's camera follows the bike's
## smoothed transform with it: player.gd _process).
func eye_local() -> Transform3D:
	var b := _body.basis
	var hips := _body.transform * (_model.transform * MODEL_HIPS)
	var at := hips + b.y * EYE_HEIGHT - b.z * EYE_FORWARD
	return Transform3D(b * Basis(Vector3.RIGHT, EYE_PITCH), at)


func outline_targets() -> Array[Node]:
	return [_near_mesh]


# ------------------------------------------------------------------ riding

func mount(player: Node3D) -> void:
	rider = player
	add_collision_exception_with(player)


func dismount() -> void:
	if rider:
		remove_collision_exception_with(rider)
	rider = null


func _physics_process(delta: float) -> void:
	_t += delta
	var throttle := 0.0
	var steer := 0.0
	var boost := false
	if rider and not _busy():
		throttle = Input.get_axis("move_back", "move_forward")
		steer = Input.get_axis("move_right", "move_left")
		boost = Input.is_action_pressed("walk")
	_drive(delta, throttle, steer, boost)
	_hover(delta)
	var before := velocity
	move_and_slide()
	_bump(before)
	_lean(delta, steer)
	if rider:
		rider.ride_follow(self)


func _busy() -> bool:
	var hud := get_tree().get_first_node_in_group("hud")
	return hud != null and hud.is_busy()


func _drive(delta: float, throttle: float, steer: float, boost: bool) -> void:
	var top := boost_speed if boost else max_speed
	if throttle > 0.0:
		if speed < 0.0:
			speed = move_toward(speed, 0.0, braking * delta)
		else:
			speed = move_toward(speed, top * throttle, (boost_acceleration if boost else acceleration) * delta)
	elif throttle < 0.0:
		if speed > 0.0:
			speed = move_toward(speed, 0.0, braking * delta)
		else:
			speed = move_toward(speed, -reverse_speed, acceleration * 0.5 * delta)
	else:
		speed = move_toward(speed, 0.0, coasting * delta)
	if speed > top:
		speed = move_toward(speed, top, coasting * 2.0 * delta)
	# Turning: slower when nearly still, reversed when backing up.
	var amount := 0.35 + 0.65 * clampf(absf(speed) / 6.0, 0.0, 1.0)
	_steer = steer
	rotate_y(steer * turn_rate * amount * delta * (-1.0 if speed < -0.1 else 1.0))
	var forward := -global_basis.z
	var want := forward * speed
	var flat := Vector3(velocity.x, 0, velocity.z)
	flat = flat.lerp(want, clampf(grip * delta, 0.0, 1.0))
	velocity.x = flat.x
	velocity.z = flat.z


## Floats `hover_height` above the ground: a spring toward the height the
## rays find, falling when there's nothing below.
func _hover(delta: float) -> void:
	var f: Variant = _ground_at(Vector3(0, 0, -1.0))
	var b: Variant = _ground_at(Vector3(0, 0, 1.0))
	var l: Variant = _ground_at(Vector3(-0.4, 0, 0))
	var r: Variant = _ground_at(Vector3(0.4, 0, 0))
	var hits := [f, b, l, r].filter(func(h: Variant) -> bool: return h != null)
	_ground_ok = not hits.is_empty()
	if not _ground_ok:
		velocity.y -= 9.8 * delta
		return
	var top: float = hits.max()
	var mean := 0.0
	for h in hits:
		mean += float(h)
	mean /= hits.size()
	var ground := maxf(mean, top - 0.25)
	var bob := sin(_t * 2.1) * 0.025 * (1.0 - clampf(absf(speed) / 4.0, 0.0, 1.0))
	var err := ground + bob - global_position.y
	velocity.y += (err * 45.0 - velocity.y * 10.0) * delta
	if f != null and b != null:
		_slope = atan2(float(f) - float(b), 2.0)


func _ground_at(local: Vector3) -> Variant:
	var from := global_transform * (local + Vector3(0, 1.6, 0))
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.0, 1)
	var ex: Array[RID] = [get_rid()]
	if rider is CollisionObject3D:
		ex.append((rider as CollisionObject3D).get_rid())
	q.exclude = ex
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return float(hit.position.y) if hit else null


## Running into something: lose the speed going into it.
func _bump(before: Vector3) -> void:
	for i in get_slide_collision_count():
		var n: Vector3 = get_slide_collision(i).get_normal()
		if absf(n.y) > 0.6:
			continue
		var into: float = -Vector3(before.x, 0, before.z).dot(Vector3(n.x, 0, n.z).normalized())
		if into > 0.5:
			var forward := -global_basis.z
			var kept := Vector3(velocity.x, 0, velocity.z).dot(forward)
			speed = clampf(kept, -reverse_speed, absf(speed)) * 0.6


## Tips the body with the ground's slope, into turns and back under
## acceleration.
func _lean(delta: float, steer: float) -> void:
	var accel := (speed - _last_speed) / maxf(delta, 0.001)
	_last_speed = speed
	var pitch := _slope + clampf(accel * 0.012, -0.12, 0.12)
	var roll := steer * clampf(absf(speed) / max_speed, 0.0, 1.0) * 0.28
	_tilt = _tilt.lerp(Vector2(pitch, roll), clampf(6.0 * delta, 0.0, 1.0))
	_body.basis = Basis(Vector3.RIGHT, _tilt.x) * Basis(Vector3.FORWARD, -_tilt.y)


# ------------------------------------------------------------------ saving

func save_state() -> Dictionary:
	return {"position": [global_position.x, global_position.y, global_position.z], "yaw": rotation.y}


func load_state(d: Dictionary) -> void:
	var p: Array = d.get("position", [])
	if p.size() == 3:
		global_position = Vector3(p[0], p[1], p[2])
	rotation.y = float(d.get("yaw", rotation.y))
	velocity = Vector3.ZERO
	speed = 0.0
	reset_physics_interpolation()
