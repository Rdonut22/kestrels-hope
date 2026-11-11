class_name FarmDroid
extends Node3D

## The little farming droid: putters around on its own within `roam_radius`
## of where it was placed, turning towards a random spot, driving there,
## and now and then stopping to rest: the body settles down onto its wheel
## pods for a few seconds, then lifts and carries on.
##
## The model (droid.glb, built by tools/import_droid.gd) is in parts: Body
## and the four wheel pods. Follows the ground with a ray; turns away from
## anything in front of it.

@export var roam_radius := 12.0
## Height in metres (about 3 ft).
@export var height := 0.92
@export var speed := 0.7
@export var turn_speed := 1.6
## Chance to rest each time it reaches a spot, and how long (seconds).
@export_range(0.0, 1.0) var rest_chance := 0.35
@export var rest_time := Vector2(3.0, 7.0)
## How far the body drops when resting (metres, at full size).
@export var rest_drop := 0.26
## Seconds between its little chirps (random within this range).
@export var chirp_every := Vector2(8.0, 22.0)

const SOUNDS := "res://characters/droid/sounds/"

enum State { TURN, DRIVE, PAUSE, REST }

var _model: Node3D
var _body: Node3D
var _body_rest := Vector3.ZERO
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _state := State.PAUSE
var _timer := 1.0
var _t := 0.0
var _rest_amount := 0.0
var _rng := RandomNumberGenerator.new()
var _voice: AudioStreamPlayer3D
var _chirps: Array[AudioStream] = []
var _chirp_in := 4.0


func _ready() -> void:
	_rng.randomize()
	_model = (load("res://characters/droid/droid.glb") as PackedScene).instantiate()
	_model.name = "Model"
	add_child(_model)
	var aabb := AABB()
	var first := true
	for m: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		var b := m.transform * m.get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	_model.scale = Vector3.ONE * (height / maxf(aabb.size.y, 0.01))
	_body = _model.find_child("Body", true, false) as Node3D
	if _body:
		_body_rest = _body.position
	_home = global_position
	_snap_to_ground()
	_voice = AudioStreamPlayer3D.new()
	_voice.name = "Voice"
	_voice.position = Vector3(0, height * 0.8, 0)
	_voice.unit_size = 3.0
	_voice.max_distance = 30.0
	_voice.volume_db = -6.0
	add_child(_voice)
	var dir := DirAccess.open(SOUNDS)
	if dir:
		for f in dir.get_files():
			if f.ends_with(".wav"):
				_chirps.append(load(SOUNDS + f))
	_chirp_in = _rng.randf_range(2.0, chirp_every.x)


func _process(delta: float) -> void:
	_t += delta
	_chirp_in -= delta
	if _chirp_in <= 0.0 and not _chirps.is_empty():
		chirp()
	match _state:
		State.PAUSE:
			_timer -= delta
			if _timer <= 0.0:
				_pick_target()
		State.TURN:
			if _turn_towards(_target, delta):
				_state = State.DRIVE
		State.DRIVE:
			var to := _target - global_position
			to.y = 0.0
			if to.length() < 0.4:
				_arrive()
			elif _blocked():
				_pick_target()
			else:
				_turn_towards(_target, delta)
				global_position += -global_basis.z * speed * delta
				_snap_to_ground()
		State.REST:
			# A sleepy chirp now and then while it rests.
			if _timer > 0.0 and _timer - delta <= 0.0 and _rng.randf() < 0.5:
				chirp()
			_timer -= delta
			if _timer <= 0.0:
				_state = State.PAUSE
				_timer = 0.8
	# Settle down while resting, lift up again otherwise.
	var want := 1.0 if _state == State.REST else 0.0
	_rest_amount = move_toward(_rest_amount, want, delta / 0.9)
	var ease := _rest_amount * _rest_amount * (3.0 - 2.0 * _rest_amount)
	if _body:
		var bob := 0.0
		if _state == State.DRIVE:
			# A little jiggle over the ground while it putters along.
			bob = sin(_t * 17.0) * 0.006 + sin(_t * 6.3) * 0.004
		_body.position = _body_rest + Vector3(0, bob - rest_drop / _model.scale.y * ease, 0)
		_body.rotation.x = (sin(_t * 1.3) * 0.01 if _state != State.REST else 0.0) - ease * 0.04


## Say something (a random phrase, slightly varied in pitch).
func chirp() -> void:
	_chirp_in = _rng.randf_range(chirp_every.x, chirp_every.y)
	if _chirps.is_empty() or _voice.playing:
		return
	_voice.stream = _chirps[_rng.randi() % _chirps.size()]
	_voice.pitch_scale = _rng.randf_range(0.92, 1.12)
	_voice.play()


func _arrive() -> void:
	if _rng.randf() < rest_chance:
		_state = State.REST
		_timer = _rng.randf_range(rest_time.x, rest_time.y)
	else:
		_state = State.PAUSE
		_timer = _rng.randf_range(0.3, 1.5)


func _pick_target() -> void:
	for i in 12:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * roam_radius
		var p := _home + Vector3(cos(a) * d, 0, sin(a) * d)
		if p.distance_to(global_position) > 2.0:
			_target = p
			_state = State.TURN
			return
	_state = State.PAUSE
	_timer = 1.0


## Turns on the spot towards p; true once it's facing it.
func _turn_towards(p: Vector3, delta: float) -> bool:
	var to := p - global_position
	to.y = 0.0
	if to.length() < 0.01:
		return true
	var want := atan2(-to.x, -to.z)
	var diff := wrapf(want - rotation.y, -PI, PI)
	var step := turn_speed * delta
	rotation.y += clampf(diff, -step, step)
	return absf(diff) < 0.05


func _blocked() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, height * 0.5, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from - global_basis.z * 1.0)
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and (hit.normal as Vector3).y < 0.6


func _snap_to_ground() -> void:
	var space := get_world_3d().direct_space_state
	var p := global_position
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 2.0, 0), p - Vector3(0, 4.0, 0))
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		global_position.y = (hit.position as Vector3).y
