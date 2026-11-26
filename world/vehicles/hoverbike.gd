class_name Hoverbike
extends CharacterBody3D

## The Kestrel's hover bike (model: world/vehicles/hoverbike/). Gana gets on
## with E (the "Seat" interactable), starts it with Space (the switch panel's
## two toggles: see "power"), rides with W/S (throttle, slowing and
## reversing), A/D (steer), Shift (boost) and B (brake), and gets off with E,
## which shuts it down.
##
## Started, it floats `hover_height` above whatever is below it, found with rays
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
## The headlight (on while running at night): brightness and reach.
@export var headlight_energy := 16.0
@export var headlight_range := 40.0

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
	add_to_group("night_glow")      # day_night.gd tells it when night falls
	# Smoothed between physics steps (see game_state.gd _ready).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_build_model()
	_build_collision()
	_build_power()
	_build_headlight()
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
	_build_cockpit()


# ------------------------------------------------------------------ cockpit

## The rider's controls are separate, more detailed models (the near model
## has its own grips and stem display cut out; the far and shadow ones keep
## them, which can't be told apart from beyond NEAR_DISTANCE). Each model is
## about 1.9 units long, centred on its origin.
const PART_CONSOLE := "res://world/vehicles/hoverbike/parts/steering_console.glb"
const PART_THROTTLE := "res://world/vehicles/hoverbike/parts/throttle_grip.glb"
const PART_BRAKE := "res://world/vehicles/hoverbike/parts/brake_lever_grip.glb"
const PART_LENGTH := 1.903
## The handlebar's grip line in the model's frame: through this point (at
## |z| = its z on each side), drooping 8 degrees outward.
const BAR_POINT := Vector3(-0.1164, 0.2366, 0.4104)
const BAR_DROOP := 0.1396
## Each grip runs from `inner` to the bar's end (|z|); the throttle is on the
## rider's right (-Z: he faces -X), the brake lever on his left.
const BAR_END := 0.455
const THROTTLE_INNER := 0.235
const BRAKE_SCALE := 0.125
## Where each grip's own axis is in its model (y, z): the brake's lever sits
## on top, so its grip is below the middle.
const THROTTLE_AXIS := Vector2(-0.016, 0.0)
const BRAKE_AXIS := Vector2(-0.129, 0.036)
## The brake grip turns forward about the bar so its lever (on top in the
## model) is ahead of the grip, where the fingers reach it (radians).
const BRAKE_ROLL := -1.0
## The console stands on the stem, its screen tipped back toward the rider.
const CONSOLE_SCALE := 0.105
const CONSOLE_FOOT := Vector3(-0.06, 0.245, 0.0)   # middle of its bottom edge
const CONSOLE_TILT := 0.44                         # radians back from upright
const CONSOLE_HALF_HEIGHT := 0.823

## The switch panel lies on the fairing ahead of the console, tipped toward
## the rider; its toggles (left, then right) start the bike.
const PART_SWITCHES := "res://world/vehicles/hoverbike/parts/switch_panel.glb"
const SWITCHES_SCALE := 0.075
const SWITCHES_AT := Vector3(-0.5, 0.225, 0.0)     # middle of its back, on the fairing
const SWITCHES_TILT := 0.21                       # radians toward the rider
const SWITCHES_BACK := 0.952                      # its back plate, from its middle
## Moving pieces, in their part's own frame: where each turns, and how far.
const TOGGLE_PIVOTS := {"ToggleL": Vector3(-0.235, 0.0, -0.40), "ToggleR": Vector3(0.235, 0.0, -0.40)}
const TOGGLE_DOWN := 0.55        # radians: leaning toward the rider (off)
const TOGGLE_UP := -0.55         # leaning away (on)
const LEVER_PIVOT := Vector3(0.12, 0.40, 0.0)
const LEVER_PULL := 0.13         # radians: the lever's tip comes in to the grip
const THROTTLE_PIVOT := Vector3(0.0, -0.016, 0.0)
const THROTTLE_TWIST := 0.75     # radians at full throttle (the top rolls back)

var _cockpit: Array[Node] = []
var _toggles: Array[Node3D] = []
var _lever: Node3D
var _twist_grip: Node3D
var _switch_panel: Node3D


func _build_cockpit() -> void:
	# Throttle: its housing is at the model's -X end, its markings face +Z.
	var t_scale := (BAR_END - THROTTLE_INNER) / cos(BAR_DROOP) / PART_LENGTH
	var throttle := _add_part("Throttle", PART_THROTTLE, _grip_transform(-1.0, THROTTLE_INNER, t_scale, THROTTLE_AXIS, false, 0.0), {"Grip": THROTTLE_PIVOT})
	_twist_grip = throttle.get("Grip")
	# Brake lever grip: its housing is at +X, buttons facing +Z, lever on top.
	var b_inner := BAR_END - BRAKE_SCALE * PART_LENGTH * cos(BAR_DROOP)
	var brake := _add_part("BrakeLever", PART_BRAKE, _grip_transform(1.0, b_inner, BRAKE_SCALE, BRAKE_AXIS, true, BRAKE_ROLL), {"Lever": LEVER_PIVOT})
	_lever = brake.get("Lever")
	# Console: screen (+Z) toward the rider (+X), its right (+X) to his right (-Z).
	var n := Vector3(cos(CONSOLE_TILT), sin(CONSOLE_TILT), 0.0)
	var up := Vector3(-sin(CONSOLE_TILT), cos(CONSOLE_TILT), 0.0)
	var b := Basis(Vector3(0, 0, -1), up, n).scaled_local(Vector3.ONE * CONSOLE_SCALE)
	_add_part("Console", PART_CONSOLE, Transform3D(b, CONSOLE_FOOT + up * CONSOLE_HALF_HEIGHT * CONSOLE_SCALE))
	# Switch panel: its face (+Z) up and toward the rider, its -X end on his
	# left (+Z), so ToggleL is the left one.
	var sn := Vector3(sin(SWITCHES_TILT), cos(SWITCHES_TILT), 0.0)
	var sx := Vector3(0, 0, -1)
	var sb := Basis(sx, sn.cross(sx), sn).scaled_local(Vector3.ONE * SWITCHES_SCALE)
	var panel := _add_part("Switches", PART_SWITCHES, Transform3D(sb, SWITCHES_AT + sn * SWITCHES_BACK * SWITCHES_SCALE), TOGGLE_PIVOTS)
	_switch_panel = _cockpit.back()
	_toggles = [panel.get("ToggleL"), panel.get("ToggleR")]
	for t in _toggles:
		if t:
			t.rotation.x = TOGGLE_DOWN


## A grip on one side (`side` +1 or -1 in z), from |z| = inner out to the
## bar's end, along the bar's line. `flipped`: the part's housing is at its +X.
## `roll` turns it about the bar.
func _grip_transform(side: float, inner: float, part_scale: float, axis: Vector2, flipped: bool, roll: float) -> Transform3D:
	var out := Vector3(0, -sin(BAR_DROOP), side * cos(BAR_DROOP))   # along the bar, outward
	var x_dir := -out if flipped else out
	var z_dir := Vector3.RIGHT          # toward the rider
	var b := (Basis(x_dir, roll) * Basis(x_dir, z_dir.cross(x_dir), z_dir)).scaled_local(Vector3.ONE * part_scale)
	var mid := (inner + BAR_END) / 2.0
	var start := Vector3(BAR_POINT.x, BAR_POINT.y, side * BAR_POINT.z)
	var centre := start + out * ((mid - BAR_POINT.z) / cos(BAR_DROOP))
	return Transform3D(b, centre - b * Vector3(0, axis.x, axis.y))


## One part model, placed at `xf`. Its pieces named in `pivots` turn about
## the given points (in the part's frame): returns each one's pivot node.
func _add_part(part_name: String, path: String, xf: Transform3D, pivots := {}) -> Dictionary:
	var root := Node3D.new()
	root.name = part_name
	root.transform = xf
	_model.add_child(root)
	_cockpit.append(root)
	var moving := {}
	var meshes := _glb_meshes(path)
	for piece: String in meshes:
		var mi := MeshInstance3D.new()
		mi.name = piece
		mi.mesh = meshes[piece]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = NEAR_DISTANCE
		mi.visibility_range_end_margin = 1.0
		if pivots.has(piece):
			var pivot := Node3D.new()
			pivot.name = piece + "Pivot"
			pivot.position = pivots[piece]
			root.add_child(pivot)
			mi.position = -pivots[piece]
			pivot.add_child(mi)
			moving[piece] = pivot
		else:
			root.add_child(mi)
	return moving


## Every mesh in a model file, by its node's name.
func _glb_meshes(path: String) -> Dictionary:
	var out := {}
	var scene := load(path) as PackedScene
	if scene == null:
		return out
	var root := scene.instantiate()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		out[String(mi.name)] = mi.mesh
	root.free()
	return out


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
	var t: Array[Node] = [_near_mesh]
	t.append_array(_cockpit)
	return t


# ------------------------------------------------------------------ power

## Starting up: once on, Gana flips the switch panel's toggles (Space), left
## then right; the engine revs, and the bike lifts off the ground to hover.
## Getting off shuts it down: it powers down (its sound), still hovering,
## and drops to the ground as the sound ends. Getting off while it's moving,
## it drifts on a little first.
const REV_TIME := 0.95           # seconds from the start-up sound to its loud part, when it lifts
const LIFT_TIME := 1.1           # seconds to rise to hover height
const DROP_TIME := 0.3           # seconds to drop to the ground once powered down
const DRIFT_SLOWING := 5.0       # m/s each second, riderless and still on
const SHUT_OFF_SPEED := 1.5      # a riderless bike stops its engine below this
const GROUND_FRICTION := 14.0    # m/s each second, resting on the ground
const SWITCH_TIME := 0.12        # seconds for a toggle to flip
const BRAKE_FORCE := 1.6         # B brakes this much harder than S

var running := false             # engine on (it hovers once lifted)
var switches: Array[bool] = [false, false]   # left, right: flipped up
var _switch_at: Array[float] = [0.0, 0.0]   # 0 down .. 1 up, as drawn
var _lift := 0.0                 # 0 resting on the ground .. 1 hovering
var _since_start := -1.0         # seconds since the second toggle went up
var _powering_down := 0.0        # seconds left of the power-down sound (it hovers till then)
var _rev := 0.0                  # 0..1: high while starting (the body shakes)
var _run_level := 0.0            # the running sound, 0 silent .. 1 full
var _accel := 0.0                # 0..1, how hard it's speeding up (a little louder)
var _twist := 0.0                # throttle grip, 0..1 as drawn
var _pull := 0.0                 # brake lever, 0..1 as drawn
var _switches_lit := false
var _switches_glow: Node3D       # outlines the switch panel (hoverbike_switches.gd)
var _click: AudioStreamPlayer3D
## Engine sound (audio/hoverbike/, cut from the user's
## SpaceshipStartUp_HV.770_1.wav): the start-up from its 8 s mark (its loud
## part, REV_TIME in, is when it lifts) and a loop from its steady middle,
## which fades in as the start-up fades out: quiet when slow or stopped,
## louder with speed, and a little louder again while accelerating.
const SOUND_START := "res://audio/hoverbike/start.wav"
const SOUND_RUNNING := "res://audio/hoverbike/running.wav"
const START_DB := -10.0
const IDLE_DB := -24.0           # stopped or slow
const SPEED_DB := 10.0           # extra at top speed (boost speed: a little more)
const ACCEL_DB := 3.0            # extra while accelerating
const RUN_FADE_IN_AT := 5.5      # seconds into the start-up the loop starts
const RUN_FADE_IN := 2.0
const RUN_FADE_OUT := 0.5        # shutting down (the power-down sound takes over)
## Shutting down: the user's FF_FM_foley_mechanical_machine_power_down_full.wav,
## its first 3.6 s (the rest is silence).
const SOUND_POWER_DOWN := "res://audio/hoverbike/power_down.wav"
const POWER_DOWN_DB := -12.0
var _start_sound: AudioStreamPlayer3D
var _run_sound: AudioStreamPlayer3D
var _down_sound: AudioStreamPlayer3D


## Ready to drive: started and up at hover height.
func can_drive() -> bool:
	return running and _lift > 0.95


## Space while riding: flips the next toggle up (left, then right); the
## second starts the engine. False if there was nothing to flip.
func flip_switch() -> bool:
	if running:
		return false
	var i := switches.find(false)
	if i < 0:
		return false
	switches[i] = true
	_play_click()
	if not switches.has(false):
		running = true
		_since_start = 0.0
		_powering_down = 0.0
		if _down_sound and _down_sound.playing:
			_down_sound.stop()
		if _start_sound and _start_sound.is_inside_tree():
			_start_sound.volume_db = START_DB
			_start_sound.play()
	return true


func shut_down() -> void:
	if not running and not switches.has(true):
		return
	var was_running := running
	running = false
	switches = [false, false]
	_since_start = -1.0
	_play_click()
	if was_running and _down_sound and _down_sound.is_inside_tree():
		_powering_down = _down_sound.stream.get_length()
		_down_sound.play()


## What the rider can do now (the HUD's prompt while riding).
func riding_prompt() -> String:
	if not running:
		return "[Space] Flip the %s switch      [E] Get off" % ("left" if not switches[0] else "right")
	if not can_drive():
		return "Starting up...      [E] Get off"
	return "[W/S] Throttle      [A/D] Steer      [Shift] Boost      [B] Brake      [E] Get off"


func _build_power() -> void:
	_switches_glow = Node3D.new()
	_switches_glow.name = "SwitchGlow"
	_switches_glow.set_script(load("res://world/vehicles/hoverbike_switches.gd"))
	var glow: Array[Node] = [_switch_panel]
	_switches_glow.set("targets", glow)
	add_child(_switches_glow)
	_click = AudioStreamPlayer3D.new()
	_click.name = "Click"
	_click.stream = load("res://audio/sfx/click.ogg")
	_click.volume_db = -4.0
	_click.unit_size = 2.0
	_model.add_child(_click)
	_click.position = SWITCHES_AT
	_start_sound = _engine_player("StartSound", SOUND_START, START_DB)
	_run_sound = _engine_player("RunSound", SOUND_RUNNING, -80.0)
	_down_sound = _engine_player("PowerDownSound", SOUND_POWER_DOWN, POWER_DOWN_DB)


func _engine_player(n: String, path: String, db: float) -> AudioStreamPlayer3D:
	var a := AudioStreamPlayer3D.new()
	a.name = n
	a.stream = load(path)
	a.volume_db = db
	a.unit_size = 5.0
	a.max_db = 3.0
	_body.add_child(a)
	a.position = Vector3(0, 0.8, 0)
	return a


func _play_click() -> void:
	if _click and _click.is_inside_tree():
		_click.play()


## Each physics frame: lift and settling, revs, and the moving controls.
func _power(delta: float, throttle: float, braking_hard: bool) -> void:
	if _since_start >= 0.0:
		_since_start += delta
	var lifting := running and _since_start > REV_TIME
	_powering_down = maxf(_powering_down - delta, 0.0)
	if lifting:
		_lift = move_toward(_lift, 1.0, delta / LIFT_TIME)
	elif _powering_down <= 0.0:
		_lift = move_toward(_lift, 0.0, delta / DROP_TIME)
	_rev = move_toward(_rev, 1.0 if running and _since_start < REV_TIME + 0.4 else 0.0, delta * 2.5)
	_engine_sounds(delta, throttle)
	# The controls as drawn.
	for i in 2:
		_switch_at[i] = move_toward(_switch_at[i], 1.0 if switches[i] else 0.0, delta / SWITCH_TIME)
		if i < _toggles.size() and _toggles[i]:
			_toggles[i].rotation.x = lerpf(TOGGLE_DOWN, TOGGLE_UP, smoothstep(0.0, 1.0, _switch_at[i]))
	_twist = lerpf(_twist, clampf(throttle, 0.0, 1.0), clampf(delta * 10.0, 0.0, 1.0))
	if _twist_grip:
		_twist_grip.rotation.x = THROTTLE_TWIST * _twist
	_pull = move_toward(_pull, 1.0 if braking_hard else 0.0, delta * 9.0)
	if _lever:
		_lever.rotation.z = LEVER_PULL * _pull
	# The switch panel glows while it's waiting to be used.
	var lit := rider != null and not running
	if lit != _switches_lit and _switches_glow:
		_switches_lit = lit
		_switches_glow.call("set_highlighted", lit, false)


## The running loop: in as the start-up fades, steady at idle, a little
## louder while speeding up; out (and down in pitch) when shut off.
func _engine_sounds(delta: float, throttle: float) -> void:
	if _run_sound == null or not _run_sound.is_inside_tree():
		return
	var on := running and _since_start >= RUN_FADE_IN_AT
	_run_level = move_toward(_run_level, 1.0 if on else 0.0, delta / (RUN_FADE_IN if on else RUN_FADE_OUT))
	var speeding_up := can_drive() and throttle > 0.0 and speed < (boost_speed if Input.is_action_pressed("walk") else max_speed) - 0.5
	_accel = move_toward(_accel, 1.0 if speeding_up else 0.0, delta * 2.0)
	if _run_level > 0.0:
		if not _run_sound.playing:
			_run_sound.play()
		var fast := clampf(absf(speed) / max_speed, 0.0, 1.3)
		_run_sound.volume_db = IDLE_DB + SPEED_DB * fast + ACCEL_DB * _accel + linear_to_db(_run_level)
		_run_sound.pitch_scale = 1.0 if running else lerpf(0.8, 1.0, _run_level)
	elif _run_sound.playing:
		_run_sound.stop()
	if not running and _start_sound.playing:
		# Shut off mid start-up: it dies away.
		_start_sound.volume_db -= delta * 40.0
		if _start_sound.volume_db < -50.0:
			_start_sound.stop()


# ------------------------------------------------------------------ headlight

## A headlight from the light panel below the turbine intake, on while the
## engine runs at night (day_night.gd set_night). It fades in and out.
const HEADLIGHT_AT := Vector3(-0.955, -0.24, 0.0)   # model frame: just ahead of the panel
const HEADLIGHT_DIP := 0.05      # radians below level
const HEADLIGHT_ANGLE := 30.0    # degrees, half the cone
const HEADLIGHT_FADE := 0.6      # seconds

var _night := false
var _headlight: SpotLight3D
var _headlight_glow: OmniLight3D
var _beam := 0.0


func _build_headlight() -> void:
	var at := _model.transform * HEADLIGHT_AT
	_headlight = SpotLight3D.new()
	_headlight.name = "Headlight"
	_headlight.light_color = Color(1.0, 0.93, 0.8)
	_headlight.spot_range = headlight_range
	_headlight.spot_angle = HEADLIGHT_ANGLE
	_headlight.spot_attenuation = 0.9
	_headlight.spot_angle_attenuation = 1.6
	_headlight.shadow_enabled = true
	_headlight.light_energy = 0.0
	_headlight.visible = false
	_headlight.position = at
	_headlight.rotation.x = -HEADLIGHT_DIP
	_body.add_child(_headlight)
	# A little light on the panel itself and the ground just ahead.
	_headlight_glow = OmniLight3D.new()
	_headlight_glow.name = "HeadlightGlow"
	_headlight_glow.light_color = Color(1.0, 0.9, 0.75)
	_headlight_glow.omni_range = 1.2
	_headlight_glow.omni_attenuation = 1.5
	_headlight_glow.shadow_enabled = false
	_headlight_glow.light_energy = 0.0
	_headlight_glow.visible = false
	_headlight_glow.position = at + Vector3(0, 0, -0.12)
	_body.add_child(_headlight_glow)
	var clock := get_tree().get_first_node_in_group("day_night")
	if clock and clock.has_method("is_night"):
		_night = clock.is_night()


func set_night(night: bool) -> void:
	_night = night


func _update_headlight(delta: float) -> void:
	if _headlight == null:
		return
	_beam = move_toward(_beam, 1.0 if running and _night else 0.0, delta / HEADLIGHT_FADE)
	var on := _beam > 0.0
	_headlight.visible = on
	_headlight_glow.visible = on
	_headlight.light_energy = headlight_energy * _beam
	_headlight.spot_range = headlight_range
	_headlight_glow.light_energy = 0.8 * _beam


# ------------------------------------------------------------------ riding

func mount(player: Node3D) -> void:
	rider = player
	add_collision_exception_with(player)


## Getting off: stopped, the engine shuts off at once; moving, it drifts on
## and shuts off as it slows (_physics_process).
func dismount() -> void:
	if rider:
		remove_collision_exception_with(rider)
	rider = null
	if absf(speed) < SHUT_OFF_SPEED:
		shut_down()


func _physics_process(delta: float) -> void:
	_t += delta
	var throttle := 0.0
	var steer := 0.0
	var boost := false
	var braking_hard := false
	var twist := 0.0                # the grip turns with W, started or not
	if rider and not _busy():
		braking_hard = Input.is_action_pressed("brake")
		twist = maxf(Input.get_axis("move_back", "move_forward"), 0.0)
		if can_drive():
			throttle = Input.get_axis("move_back", "move_forward")
			steer = Input.get_axis("move_right", "move_left")
			boost = Input.is_action_pressed("walk")
	_drive(delta, throttle, steer, boost)
	if can_drive() and braking_hard:
		speed = move_toward(speed, 0.0, braking * BRAKE_FORCE * delta)
	if rider == null and running:
		# Riderless: it drifts on, slowing, and shuts off.
		speed = move_toward(speed, 0.0, DRIFT_SLOWING * delta)
		if absf(speed) < SHUT_OFF_SPEED:
			shut_down()
	if _lift < 0.5:
		# On (or nearly on) the ground: it scrapes to a stop.
		speed = move_toward(speed, 0.0, GROUND_FRICTION * delta)
	_power(delta, twist, braking_hard)
	_update_headlight(delta)
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


## Keeps its origin on the ground below it, found with rays: a spring
## toward the height they find, falling when there's nothing below. (The
## model sits hover_height above that once lifted: _lean.)
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
	var bob := sin(_t * 2.1) * 0.025 * (1.0 - clampf(absf(speed) / 4.0, 0.0, 1.0)) * _lift
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
## acceleration; lowers it onto the ground when it isn't hovering, and
## shakes it a little as the engine revs up.
func _lean(delta: float, steer: float) -> void:
	var accel := (speed - _last_speed) / maxf(delta, 0.001)
	_last_speed = speed
	var pitch := _slope + clampf(accel * 0.012, -0.12, 0.12)
	var roll := steer * clampf(absf(speed) / max_speed, 0.0, 1.0) * 0.28
	_tilt = _tilt.lerp(Vector2(pitch, roll), clampf(6.0 * delta, 0.0, 1.0))
	var shake := 0.0
	if running and _since_start < REV_TIME + LIFT_TIME:
		shake = 0.005 * _rev * sin(_t * 71.0)
	_body.basis = Basis(Vector3.RIGHT, _tilt.x + shake) * Basis(Vector3.FORWARD, -_tilt.y + shake * 0.7)
	# Rising eases in and out; dropping (lift falling fast) falls.
	var up := smoothstep(0.0, 1.0, _lift) if running else 1.0 - pow(1.0 - _lift, 2.0)
	_body.position.y = -hover_height * (1.0 - up)


# ------------------------------------------------------------------ saving

func save_state() -> Dictionary:
	return {"position": [global_position.x, global_position.y, global_position.z], "yaw": rotation.y, "running": running}


func load_state(d: Dictionary) -> void:
	var p: Array = d.get("position", [])
	if p.size() == 3:
		global_position = Vector3(p[0], p[1], p[2])
	rotation.y = float(d.get("yaw", rotation.y))
	velocity = Vector3.ZERO
	speed = 0.0
	running = bool(d.get("running", false))
	switches = [running, running]
	_switch_at = [1.0 if running else 0.0, 1.0 if running else 0.0]
	_since_start = 99.0 if running else -1.0
	_lift = 1.0 if running else 0.0
	_run_level = 1.0 if running else 0.0
	_rev = 0.0
	_lean(0.0, 0.0)
	reset_physics_interpolation()
