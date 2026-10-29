extends Interactable

## The engineering jack socket (ship/mechanical_assembly.tscn). After his
## diagnosis Meki floats over and waits here; when Gana walks up he asks to
## start the alternate current sequence. "Go ahead" plays the jack-in:
## letterbox bars, a close-up, Meki's arm telescopes into the socket and the
## jaws clamp on it. Then Gana reroutes the backup cell (the reroute
## puzzle), which brings the ship's power back.

## The socket scene this interactable drives.
@export var socket_path: NodePath

const ASK_RANGE := 2.3
const BODY_FRONT := 0.11  # Meki's centre to where the arm comes out

var _socket: Node3D
var _puzzle: Control
var _bars: Control
var _jacked := false
var _busy := false
var _asked := false


func _ready() -> void:
	_socket = get_node_or_null(socket_path)


func _meki() -> Node:
	return get_tree().get_first_node_in_group("meki")


func _waiting() -> bool:
	var gs := Game.state()
	return gs.meki_online and not gs.power_restored and gs.has_flag("meki_waiting")


func get_prompt() -> String:
	if _waiting():
		return "Reroute power" if _jacked else "Go ahead"
	return "Jack socket"


func can_interact(_player: Node) -> bool:
	return not _busy


func _process(_delta: float) -> void:
	if not _waiting() or _jacked or _busy or not _socket:
		return
	var meki := _meki()
	if not meki:
		return
	var n: Vector3 = _socket.face_normal()
	var side: Vector3 = _socket.global_transform.basis.x
	meki.hold_at(_socket.global_position + n * 0.7 + side * 0.3 + Vector3(0, 0.05, 0), _socket.global_position)
	# Ask as Gana walks up (again if he wanders off and comes back).
	var player: Node3D = get_tree().current_scene.get_node_or_null("Player")
	if not player:
		return
	var to := player.global_position - global_position
	to.y = 0
	if to.length() > ASK_RANGE + 1.2:
		_asked = false
	elif to.length() < ASK_RANGE and not _asked and not hud().is_thinking() and not hud().is_busy():
		_asked = true
		hud().think([["MEKI", "Ready when you are. Shall I initiate the alternate current sequence?"]])


func interact(_player: Node) -> void:
	var gs := Game.state()
	if not gs.meki_online:
		hud().think(["Main cell's cracked. The backup's fine, but I can't reach the routing without the ship's brain.", "And the ship's brain is lying on my workbench."])
		return
	if gs.power_restored:
		hud().think(["Backup cell holding at forty-one percent. Not pretty, but she's breathing."])
		return
	if not _waiting():
		return
	if _jacked:
		_open_puzzle()
	else:
		_jack_in(_player)


func _jack_in(player: Node3D) -> void:
	_busy = true
	var meki := _meki()
	var arm: Node3D = meki.jack_arm()
	var n: Vector3 = _socket.face_normal()
	var seat: Vector3 = _socket.seat_position()
	# Letterbox bars and a close-up from the side.
	_cinema(true)
	var cam := Camera3D.new()
	cam.fov = 52
	var prev := get_viewport().get_camera_3d()
	get_tree().current_scene.add_child(cam)
	var side: Vector3 = _socket.global_transform.basis.x
	var mid := seat + n * 0.4
	cam.global_position = mid + side * 0.95 + n * 0.45 + Vector3(0, 0.12, 0)
	cam.look_at(mid + Vector3(0, -0.02, 0))
	await get_tree().create_timer(0.5).timeout
	cam.make_current()
	# Gana steps out of the shot.
	player.visible = false
	hud().think([["MEKI", "Alternate current sequence. Jacking in."]], "", true)
	# Float square to the socket, the arm's full length away.
	arm.set("extension", 1.0)
	var reach: float = arm.tip_distance()
	arm.set("extension", 0.0)
	# Arm comes out just under his lens.
	var spot := seat + n * (reach + BODY_FRONT) + Vector3(0, 0.05, 0)
	await meki.dock(spot, seat)
	arm.global_transform = Transform3D(Basis.looking_at(n, Vector3.UP), spot - n * BODY_FRONT + Vector3(0, -0.05, 0))
	meki.play_sfx("res://audio/sfx/click.ogg")
	var tw := create_tween()
	tw.tween_property(arm, "extension", 1.0, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	# The jaws close on the plug.
	tw = create_tween()
	tw.tween_property(_socket, "clamp_amount", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sparks(seat + n * 0.02)
	meki.play_sfx("res://audio/sfx/click.ogg")
	await tw.finished
	_socket.set("lower_indicator_on", true)
	meki.play_sfx("res://audio/sfx/beep.ogg")
	await get_tree().create_timer(0.3).timeout
	await hud().think([["MEKI", "Locked in. I can see the whole grid from here. Your turn, Gana."]], "", true)
	_jacked = true
	_cinema(false)
	await get_tree().create_timer(0.45).timeout
	if is_instance_valid(prev):
		prev.make_current()
	player.visible = true
	cam.queue_free()
	_busy = false
	_open_puzzle()


func _open_puzzle() -> void:
	if not _puzzle:
		_puzzle = (load("res://ui/reroute_puzzle.gd") as GDScript).new()
		hud().add_overlay(_puzzle)
		_puzzle.solved.connect(_on_solved)
	_puzzle.open()


func _on_solved() -> void:
	Game.state().power_restored = true
	await get_tree().create_timer(0.6).timeout
	await hud().think([
		["MEKI", "Route's holding. Lights, life support, galley... and the cockpit."],
		"So she'll listen now.",
		["MEKI", "Go try the switches. I'll be right behind you."],
	])
	# Unclamp, pull the arm in and follow Gana again.
	var meki := _meki()
	var tw := create_tween()
	tw.tween_property(_socket, "clamp_amount", 0.0, 0.3)
	_socket.set("lower_indicator_on", false)
	if meki:
		meki.play_sfx("res://audio/sfx/click.ogg")
		await tw.finished
		tw = create_tween()
		tw.tween_property(meki.jack_arm(), "extension", 0.0, 0.9).set_trans(Tween.TRANS_QUAD)
		await tw.finished
		meki.release()
	_jacked = false


## Black bars slide in from the top and bottom of the screen (or back out).
func _cinema(on: bool) -> void:
	if not _bars:
		_bars = Control.new()
		_bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 2:
			var bar := ColorRect.new()
			bar.color = Color.BLACK
			bar.set_anchors_preset(Control.PRESET_TOP_WIDE if i == 0 else Control.PRESET_BOTTOM_WIDE)
			bar.anchor_bottom = 0.0 if i == 0 else 1.0
			bar.anchor_top = 0.0 if i == 0 else 1.0
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_bars.add_child(bar)
		hud().add_overlay(_bars)
	var h := 0.12 * _bars.get_viewport_rect().size.y if on else 0.0
	_bars.show()
	var tw := create_tween().set_parallel()
	tw.tween_property(_bars.get_child(0), "offset_bottom", h, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bars.get_child(1), "offset_top", -h, 0.45).set_trans(Tween.TRANS_SINE)
	if not on:
		await tw.finished
		_bars.hide()


func _sparks(pos: Vector3) -> void:
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.amount = 24
	sparks.lifetime = 0.5
	sparks.explosiveness = 0.95
	sparks.direction = _socket.face_normal()
	sparks.spread = 60.0
	sparks.initial_velocity_min = 0.8
	sparks.initial_velocity_max = 2.0
	sparks.gravity = Vector3(0, -6, 0)
	sparks.scale_amount_min = 0.006
	sparks.scale_amount_max = 0.014
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
	get_tree().current_scene.add_child(sparks)
	sparks.global_position = pos
	sparks.emitting = true
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.5)
	flash.omni_range = 1.2
	flash.light_energy = 2.0
	sparks.add_child(flash)
	get_tree().create_timer(0.15).timeout.connect(flash.queue_free)
	get_tree().create_timer(1.2).timeout.connect(sparks.queue_free)
