extends Node

## The opening cinematic's second half, in Gana's quarters aboard the
## Kestrel (main.tscn; intro.tscn plays the flyby and hands over with the
## root meta "opening_cinematic"). One sequence, run once:
##
##   bed    Gana asleep in his pod, window light on him; he stirs, yawns
##          and sits on the edge. Two thoughts.
##   walk   he gets up and walks to the round window; the camera follows
##          from behind.
##   reveal the camera settles over his shoulder on the planet through the
##          window and stays there (a slow push, then a hold) through all
##          the dialogue: no cuts until the end.
##   end    a hold, fade to black, then the existing next sequence (the
##          player in the pilot seat: pilot_seat.gd opening()).
##
## Player control and the gameplay HUD are off for all of it. Lines are
## shown with the game's dialogue box (ui/dialogue/dialogue_box.tscn:
## Ganna's thoughts with his portrait, the ship computer with its
## symbol), advanced only by the player.
## Positions are in the ship's frame (forward -Z, floor y 0).

## Music slots (no suitable track in the project yet: see the report).
## Either may be missing; the scene plays without it.
const PIANO := "res://audio/music/opening_piano.ogg"     # soft chiptune piano, from the bed shot
const REVEAL := "res://audio/music/opening_reveal.ogg"   # fuller passage at the planet reveal
const MUSIC_DB := -8.0

## Gana in his pod (SleepPod1: centre z -7.25, mattress top y 0.53, open
## to +X at x -2.65) and where he stops at the window (QuartersWindow:
## centre x -0.4, y 1.5, wall z -9.6).
const POD_Z := -7.25
const LIE_FEET := Vector3(-2.85, 0.66, POD_Z)
const SIT_AT := Vector3(-2.82, 0.0, POD_Z)
const SIT_HIPS := 0.6
const STAND_AT := Vector3(-2.4, 0.0, POD_Z)
const WINDOW_AT := Vector3(-0.85, 0.0, -8.95)
const WALK_SPEED := 0.85

## Cameras.
const BED_EYE := Vector3(0.55, 1.4, -6.15)
const BED_LOOK := Vector3(-3.3, 0.75, -7.45)
const REVEAL_EYE := Vector3(-0.2, 1.72, -7.9)
const REVEAL_PUSH := Vector3(-0.22, 1.71, -8.25)
const REVEAL_LOOK := Vector3(-0.38, 1.78, -14.0)
## The room the follow camera stays inside (x, z ranges).
const ROOM_X := Vector2(-2.3, 1.6)
const ROOM_Z := Vector2(-9.3, -6.1)


var _ship: Node3D
var _player: Node
var _hud: CanvasLayer
var _cam: Camera3D
var _actor: Node3D
var _pose: CinematicPose
var _ui: CanvasLayer
var _bars: Array[ColorRect] = []
var _fade: ColorRect
var _box: DialogueBox
var _music: AudioStreamPlayer
var _reveal: AudioStreamPlayer
var _steps: AudioStreamPlayer
var _tone: AudioStreamPlayer
var _window_light: SpotLight3D
var _follow := false
var _ran := false


func _ready() -> void:
	_player = get_parent().get_node_or_null("Player")
	_ship = get_parent().get_node_or_null("ShipInterior")
	_hud = get_parent().get_node_or_null("HUD")
	run.call_deferred()


func run() -> void:
	if _ran or _ship == null or _player == null:
		return
	_ran = true
	_take_over()
	_build_ui()
	_build_actor()
	_build_audio()
	await _bed()
	await _walk()
	await _reveal_and_dialogue()
	await _end()


# ---------- setup ----------

func _take_over() -> void:
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	(_player.get("mesh") as Node3D).visible = false
	if _hud:
		_hud.visible = false
	_cam = Camera3D.new()
	_cam.fov = 55
	_cam.near = 0.05
	_cam.far = 20000
	_ship.add_child(_cam)
	_cam.make_current()
	_place_cam(BED_EYE, BED_LOOK)
	# Soft light from the window across the pod: the planet's glow.
	_window_light = SpotLight3D.new()
	_window_light.light_color = Color(0.78, 0.88, 1.0)
	_window_light.light_energy = 1.4
	_window_light.spot_range = 7.0
	_window_light.spot_angle = 38.0
	_window_light.spot_attenuation = 0.8
	_window_light.shadow_enabled = true
	_ship.add_child(_window_light)
	_window_light.position = Vector3(-0.45, 1.75, -9.35)
	_window_light.look_at(_ship.to_global(Vector3(-3.0, 0.7, POD_Z)))


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	# Letterbox bars (the flyby brought them in; they're already there).
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 0.88
		bar.anchor_bottom = 0.12 if top else 1.0
		_ui.add_child(bar)
		_bars.append(bar)
	# The game's dialogue box (portraits from DialogueSpeakers), sized to
	# sit low in the frame over the bottom letterbox bar.
	_box = (load("res://ui/dialogue/dialogue_box.tscn") as PackedScene).instantiate()
	_box.set("width_share", 0.5)
	_box.set("max_width", 860.0)
	_ui.add_child(_box)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fade)


func _build_actor() -> void:
	_actor = (load("res://character/character.tscn") as PackedScene).instantiate()
	_actor.name = "CinematicGana"
	_ship.add_child(_actor)
	var skel: Skeleton3D = _actor.find_children("*", "Skeleton3D", true, false)[0]
	_pose = CinematicPose.new()
	skel.add_child(_pose)
	_lie()
	if _actor.has_signal("footstep"):
		_actor.footstep.connect(_on_footstep)


func _build_audio() -> void:
	_music = _slot(PIANO)
	_reveal = _slot(REVEAL)
	# Footsteps: the game's step sounds, soft and low for the deck plates
	# (there is no metal-floor step set yet).
	var random := AudioStreamRandomizer.new()
	random.random_pitch = 1.08
	for i in 6:
		random.add_stream(i, load("res://audio/steps/grass_%d.ogg" % (i + 1)))
	_steps = AudioStreamPlayer.new()
	_steps.stream = random
	_steps.volume_db = -20.0
	_steps.pitch_scale = 0.72
	add_child(_steps)
	_tone = AudioStreamPlayer.new()
	_tone.stream = load("res://audio/sfx/beep.ogg")
	add_child(_tone)


func _slot(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	if ResourceLoader.exists(path):
		p.stream = load(path)
		p.volume_db = MUSIC_DB
	else:
		push_warning("Opening cinematic: no music at %s (slot left empty)" % path)
	return p


# ---------- beats ----------

func _bed() -> void:
	_tw(_fade, "color:a", 0.0, 2.5)
	if _music.stream:
		_music.play()
	await _wait(4.0)
	# He stirs: a small shift under the blanket.
	await _stir()
	await _wait(1.0)
	# Sits up and swings round onto the edge, yawning on the way.
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(_rise, 0.0, 1.0, 3.2)
	t.tween_property(_pose, "sit", 1.0, 3.2)
	await t.finished
	var y := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	y.tween_property(_pose, "yawn", 1.0, 1.4)
	y.tween_interval(1.2)
	y.tween_property(_pose, "yawn", 0.0, 1.6)
	await y.finished
	await _wait(1.6)
	await _box.show_line("ganna_thoughts", "It's been 43 days already.", {"hold": 1.6})
	await _wait(1.4)
	await _box.show_line("ganna_thoughts", "Not sure what I'm hoping for at this point.", {"hold": 1.8})
	await _wait(1.2)


func _walk() -> void:
	# Stands up off the edge.
	var up := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	up.tween_property(_pose, "sit", 0.0, 1.5)
	up.tween_method(_stand_up, 0.0, 1.0, 1.5)
	await up.finished
	# Turns toward the window, then walks there; the camera follows.
	var dir := (WINDOW_AT - STAND_AT)
	dir.y = 0.0
	var dist := dir.length()
	dir = dir.normalized()
	var turn := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn.tween_property(_actor, "rotation:y", atan2(-dir.x, -dir.z), 0.8)
	_follow = true
	await turn.finished
	_actor.set_move(WALK_SPEED / 5.0)
	var w := create_tween()
	w.tween_property(_actor, "position", WINDOW_AT, dist / WALK_SPEED)
	await w.finished
	_actor.set_move(0.0)
	# Faces the window.
	var face := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	face.tween_property(_actor, "rotation:y", 0.0, 0.9)
	await face.finished


func _reveal_and_dialogue() -> void:
	# The camera glides from behind him up over his shoulder onto the
	# planet and stays there for everything that follows.
	_follow = false
	var from := _cam.position
	var from_look := _cam.position - _cam.global_basis.z
	var glide := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glide.tween_method(func(k: float) -> void: _place_cam(from.lerp(REVEAL_EYE, k), from_look.lerp(REVEAL_LOOK, k)), 0.0, 1.0, 3.0)
	if _reveal.stream:
		create_tween().tween_property(_music, "volume_db", -40.0, 3.0)
		_reveal.volume_db = -30.0
		_reveal.play()
		create_tween().tween_property(_reveal, "volume_db", MUSIC_DB, 3.0)
	await glide.finished
	# Then a very slow push toward the glass, settling into a hold.
	var push := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	push.tween_method(func(k: float) -> void: _place_cam(REVEAL_EYE.lerp(REVEAL_PUSH, k), REVEAL_LOOK), 0.0, 1.0, 18.0)
	await _wait(4.5)
	await _box.show_line("ganna_thoughts", "It's… beautiful.", {"hold": 1.6})
	await _wait(1.0)
	await _box.show_line("ganna_thoughts", "But how?", {"hold": 1.4})
	await _wait(1.2)
	# The ship's computer: a quiet tone, the music dips under it.
	_tone.volume_db = -16.0
	_tone.pitch_scale = 0.85
	_tone.play()
	_duck(true)
	await _wait(1.0)
	await _box.show_line("ship_computer", "Good morning, Ganna.", {"hold": 1.2})
	await _wait(0.6)
	await _box.show_line("ship_computer", "Forty-three days since the attack. No sign of Hale.", {"hold": 3.2})
	await _wait(2.4)
	await _box.show_line("ship_computer", "The drive sustained extensive damage. Fuel reserves are low.", {"hold": 1.4})
	await _wait(0.6)
	await _box.show_line("ship_computer", "I've established a stable orbit.", {"hold": 1.2})
	await _wait(0.6)
	await _box.show_line("ship_computer", "This planet isn't on our system map.", {"hold": 2.8})
	await _wait(2.2)
	await _box.show_line("ship_computer", "But… there's a signal.", {"hold": 1.6})
	_duck(false)
	# A faint signal pulse under the music while the view holds.
	for k in 3:
		_tone.volume_db = -26.0
		_tone.pitch_scale = 0.6
		_tone.play()
		await _wait(1.35)


func _end() -> void:
	var out := create_tween().set_parallel()
	out.tween_property(_fade, "color:a", 1.0, 2.2)
	for p in [_music, _reveal]:
		out.tween_property(p, "volume_db", -50.0, 2.2)
	await out.finished
	# Hand over to the existing next sequence: the pilot seat opening.
	_actor.queue_free()
	_window_light.queue_free()
	(_player.get("mesh") as Node3D).visible = true
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	_player.call("_start_in_pilot_seat")
	for b in _bars:
		create_tween().tween_property(b, "modulate:a", 0.0, 1.5)
	if _hud:
		_hud.visible = true
	_cam.queue_free()
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, 1.8)
	await back.finished
	queue_free()


# ---------- body ----------

## Lying on his back in the pod, head at the pillow (-X), feet at the
## pod's mouth.
func _lie() -> void:
	_actor.transform = Transform3D(_lie_basis(), LIE_FEET)


static func _lie_basis() -> Basis:
	# Model: up +Y, faces -Z. Lying: up -> -X (head to the pillow), face up.
	return Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))


static func _sit_basis() -> Basis:
	# Upright, facing out of the pod (+X).
	return Basis(Vector3.UP, -PI / 2)


func _sit_origin() -> Vector3:
	return SIT_AT + Vector3(0, SIT_HIPS - float(_actor.call("hip_height")), 0)


func _stir() -> void:
	var base := _actor.transform
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(func(k: float) -> void:
		_actor.transform = Transform3D(base.basis.rotated(Vector3.LEFT, 0.12 * sin(k * PI)), base.origin), 0.0, 1.0, 1.6)
	await t.finished


## 0 lying .. 1 sitting on the edge.
func _rise(k: float) -> void:
	var q := Quaternion(_lie_basis()).slerp(Quaternion(_sit_basis()), k)
	_actor.transform = Transform3D(Basis(q), LIE_FEET.lerp(_sit_origin(), k))


## 0 sitting .. 1 standing just out of the pod.
func _stand_up(k: float) -> void:
	_actor.transform = Transform3D(_sit_basis(), _sit_origin().lerp(STAND_AT, k))


func _on_footstep() -> void:
	_steps.play()


# ---------- camera and helpers ----------

func _place_cam(eye: Vector3, look: Vector3) -> void:
	_cam.position = eye
	_cam.look_at(_ship.to_global(look))


func _process(delta: float) -> void:
	if not _follow or _actor == null:
		return
	# Close behind him at head height: his head and shoulders hide most of
	# the window until he reaches it.
	var p := _actor.position
	var dir := (WINDOW_AT - p)
	dir.y = 0.0
	if dir.length() < 0.2:
		dir = Vector3(0, 0, -1)
	dir = dir.normalized()
	var eye := p - dir * 1.25 + Vector3(0, 1.52, 0)
	eye.x = clampf(eye.x, ROOM_X.x, ROOM_X.y)
	eye.z = clampf(eye.z, ROOM_Z.x, ROOM_Z.y)
	var look := p + dir * 2.2 + Vector3(0, 1.3, 0)
	var k := minf(delta * 1.6, 1.0)
	var cur_look := _cam.position - _cam.global_basis.z * 2.0
	_place_cam(_cam.position.lerp(eye, k), cur_look.lerp(look, k))


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, false).timeout


func _tw(obj: Object, prop: String, to: Variant, secs: float) -> void:
	create_tween().tween_property(obj, prop, to, secs)


func _duck(on: bool) -> void:
	for p in [_music, _reveal]:
		if p.playing:
			create_tween().tween_property(p, "volume_db", MUSIC_DB - (6.0 if on else 0.0), 1.2)
