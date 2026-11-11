extends Node3D

## Drives Gana's body (character/gana/gana.glb, a Mixamo rig) from the
## player's movement. The player calls set_move() every frame with 0 (still)
## to 1 (full speed), and play_action() for one-shot gestures like
## "Interact" (skipped if the body has no such animation).
##
## Animations: "Idle", "Walk", and optionally "Run" and "Interact"
## (tools/import_gana.gd). Without a Run, the walk is sped up (up to
## max_walk_rate) at higher speeds.

## Emitted when a foot touches down during the walk or run animation.
signal footstep

## Generic bone names used by other scripts (menu.gd's seated pose) and
## their names on the Mixamo rig.
const BONES := {
	"UpperLeg.L": "mixamorig_LeftUpLeg", "UpperLeg.R": "mixamorig_RightUpLeg",
	"LowerLeg.L": "mixamorig_LeftLeg", "LowerLeg.R": "mixamorig_RightLeg",
	"Foot.L": "mixamorig_LeftFoot", "Foot.R": "mixamorig_RightFoot",
	"Abdomen": "mixamorig_Spine", "Hips": "mixamorig_Hips",
	"UpperArm.R": "mixamorig_RightArm", "LowerArm.R": "mixamorig_RightForeArm", "Wrist.R": "mixamorig_RightHand",
}

@export var walk_threshold := 0.05
@export var run_threshold := 0.55
## Between this and run_threshold he walks briskly (QuickWalk).
@export var quick_walk_threshold := 0.35
## Ground speed of the brisk walk, m/s.
@export var quick_walk_speed := 1.6
@export var blend_time := 0.2
## The player's top speed (player.gd SPEED), m/s, for matching the feet.
@export var full_speed := 5.0
## Ground speed the walk animation was made for, m/s (its stride / length).
@export var walk_speed := 0.99
## Ground speed of the run animation, if there is one.
@export var run_speed := 3.6
## Fastest the walk is played when there's no run (higher slides the feet).
@export var max_walk_rate := 1.8

var anim: AnimationPlayer
var _move := 0.0
var _current := ""
var _action_left := 0.0
var _skel: Skeleton3D
var _feet := []  # [bone index, last height, was descending, lowest height seen]


func _ready() -> void:
	anim = find_children("*", "AnimationPlayer", true, false)[0]
	_skel = find_children("*", "Skeleton3D", true, false)[0]
	_attach_robot_arm()
	_raise = WristRaise.new()
	_raise.name = "WristRaise"
	_skel.add_child(_raise)
	for n in ["Idle", "Walk", "QuickWalk", "Run"]:
		if anim.has_animation(n):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	for side in ["L", "R"]:
		var b := bone("Foot." + side)
		if b >= 0:
			_feet.append([b, 0.0, false, INF])
	_find_contacts()
	_play("Idle")


## Index of a bone by generic name ("UpperLeg.L", ...) or its own name.
func bone(name: String) -> int:
	var i := _skel.find_bone(name)
	if i < 0 and BONES.has(name):
		i = _skel.find_bone(BONES[name])
	return i


## Height of the hips above the feet when standing, in metres.
func hip_height() -> float:
	var hips := bone("Hips")
	return _foot_height(hips, true) if hips >= 0 else 0.9


## Hold a frame of an animation (posing a still character).
func hold(name: String, time: float) -> void:
	if anim.has_animation(name):
		anim.play(name)
		anim.seek(time, true)
		anim.pause()


func set_move(amount: float) -> void:
	_move = clampf(amount, 0.0, 1.0)


## Gestures by the names the player uses -> [animation, playback speed].
## (The body's pick-up is long: it bends, grabs, then looks at the find.)
const ACTIONS := {"Interact": ["PickUp", 2.2]}
## After this long running, stopping plays the catch-breath animation.
@export var winded_after := 8.0
var _locked := false
var _raise: WristRaise
var _raise_tween: Tween
var _run_time := 0.0


func play_action(name: String) -> void:
	var a: String = name
	var speed := 1.0
	if ACTIONS.has(name) and anim.has_animation(ACTIONS[name][0]):
		a = ACTIONS[name][0]
		speed = ACTIONS[name][1]
	if anim.has_animation(a):
		_start(a, speed, false)


## Raise the arm with the wrist terminal (up = true) or lower it, over
## `secs` seconds, easing in and out.
func raise_terminal(up: bool, secs := 0.7) -> void:
	if _raise == null:
		return
	if _raise_tween:
		_raise_tween.kill()
	_raise_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_raise_tween.tween_property(_raise, "amount", 1.0 if up else 0.0, secs)


## A jump: the vault over an obstacle when running, else the standing
## jump. Plays through to the landing even while moving.
func play_jump(running: bool) -> void:
	var a := "Vault" if running and anim.has_animation("Vault") else "Jump"
	if anim.has_animation(a):
		_start(a, 1.3 if a == "Jump" else 1.0, true)


func _start(a: String, speed: float, locked: bool) -> void:
	_current = a
	anim.play(a, 0.1)
	anim.speed_scale = speed
	_action_left = anim.get_animation(a).length / speed * 0.9
	_locked = locked


func _process(delta: float) -> void:
	if _action_left > 0.0:
		_action_left -= delta
		if _locked or _move < walk_threshold:
			return
		_action_left = 0.0
	_locked = false
	_detect_footsteps()
	var speed := _move * full_speed
	if _move >= run_threshold:
		_run_time += delta
	elif _move < walk_threshold and _run_time > winded_after and anim.has_animation("CatchBreath"):
		# Stopped after a long run: get his breath back.
		_run_time = 0.0
		_start("CatchBreath", 1.0, false)
		return
	elif _move >= walk_threshold:
		_run_time = 0.0
	if _move < walk_threshold:
		_play("Idle")
		anim.speed_scale = 1.0
	elif _move < quick_walk_threshold or not anim.has_animation("QuickWalk"):
		if _move >= run_threshold and anim.has_animation("Run"):
			_play("Run")
			anim.speed_scale = clampf(speed / run_speed, 0.7, 1.4)
		else:
			_play("Walk")
			anim.speed_scale = clampf(speed / walk_speed, 0.7, max_walk_rate)
	elif _move < run_threshold:
		_play("QuickWalk")
		anim.speed_scale = clampf(speed / quick_walk_speed, 0.7, 1.4)
	else:
		_play("Run")
		anim.speed_scale = clampf(speed / run_speed, 0.7, 1.4)


func _play(name: String) -> void:
	if name != _current and anim.has_animation(name):
		_current = name
		anim.play(name, blend_time)


# Gana's mechanical arm (character/gana/robot_arm.gd) rides the skeleton.
func _attach_robot_arm() -> void:
	var arm := get_node_or_null("RobotArm")
	if arm and arm.has_method("attach"):
		arm.attach(_skel)


## A bone's height above the character's feet (origin), in metres.
func _foot_height(b: int, rest := false) -> float:
	var pose := _skel.get_bone_global_rest(b) if rest else _skel.get_bone_global_pose(b)
	return (_skel.global_transform * pose.origin).y - global_position.y


## When each foot lands in the walking animations (seconds into the clip),
## found once by stepping through them: a foot lands where its height is
## at a low point near the clip's lowest. Footsteps fire as playback
## passes those times, whatever the frame rate.
var _contacts := {}  # animation name -> Array[float]
var _last_pos := -1.0
var _last_anim := ""


func _find_contacts() -> void:
	var was := anim.current_animation
	for n in ["Walk", "QuickWalk", "Run"]:
		if not anim.has_animation(n):
			continue
		var length := anim.get_animation(n).length
		var steps := 90
		var times: Array[float] = []
		for foot in _feet:
			var hs: Array[float] = []
			anim.play(n)
			for k in steps:
				anim.seek(length * k / steps, true)
				hs.append(_foot_height(foot[0]))
			var lo: float = hs.min()
			var hi: float = hs.max()
			var near := lo + (hi - lo) * 0.25
			# Landing: the first sample of each stretch spent near the bottom.
			for k in steps:
				var prev := hs[(k - 1 + steps) % steps]
				if hs[k] <= near and prev > near:
					times.append(length * k / steps)
		times.sort()
		_contacts[n] = times
	anim.stop()
	if was != "":
		anim.play(was)


func _detect_footsteps() -> void:
	var moving := _move >= walk_threshold and _action_left <= 0.0
	var n := anim.current_animation
	var pos := anim.current_animation_position
	if not moving or not _contacts.has(n):
		_last_pos = -1.0
		_last_anim = n
		return
	if n == _last_anim and _last_pos >= 0.0:
		for t: float in _contacts[n]:
			var crossed := (_last_pos < t and pos >= t) if pos >= _last_pos else (_last_pos < t or pos >= t)
			if crossed and pos != _last_pos:
				footstep.emit()
	_last_pos = pos
	_last_anim = n
