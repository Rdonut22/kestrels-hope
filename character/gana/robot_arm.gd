class_name RobotArm
extends Node3D

## Gana's mechanical right forearm and hand, with the USHIDA wrist terminal
## (characters/gana/wrist_terminal) mounted on the back of the forearm.
##
## His body (character/gana/gana.glb) has the human right forearm and hand
## cut away at the elbow (tools/import_gana.gd). character_model.gd calls
## attach() once the skeleton is ready: every part rides a BoneAttachment3D
## on its own bone (forearm, hand, each finger segment), so the existing
## animations drive it. Built in code at runtime, like the terminal, so the
## saved scene holds only this node.
##
## Each part is laid out in metres in its bone's frame: +Y runs along the
## bone, `dorsal` is the back of the arm/hand (measured from the rest pose:
## palms face down in Mixamo's T-pose).

## Wrist terminal size relative to the standalone prop.
@export var terminal_scale := 0.7
## Where the terminal sits along the forearm (0 = elbow, 1 = wrist).
@export_range(0.0, 1.0) var terminal_position := 0.53
@export var show_terminal := true
## Glowing palm (design: "robotic right arm (glowing palm)").
@export var palm_glow := Color(0.3, 0.85, 1.0)
## Build the mechanical forearm (and its terminal). Off when the body's own
## mesh already has a mechanical forearm and only the hand is replaced.
@export var build_forearm := true
@export_group("Colours")
## Frame / joints and the plates over them.
@export var frame_color := Color(0.16, 0.155, 0.145)
@export var plate_color := Color(0.58, 0.56, 0.47)
## Paint wear on the hand and forearm (0 = clean).
@export_range(0.0, 1.0) var wear := 1.0
## Light hand: off-white plates over dark joints (the stylized Gana's arm)
## instead of the dark frame with cream covers.
@export var light_hand := false

const FOREARM := "mixamorig_RightForeArm"
const HAND := "mixamorig_RightHand"
const FINGERS := ["Thumb", "Index", "Middle", "Ring", "Pinky"]
const SHADER := preload("res://characters/gana/wrist_terminal/wrist_wear.gdshader")

## The terminal (for the wrist-computer feature later).
var terminal: WristTerminal
var _skel: Skeleton3D
var _rig := 1.0  # skeleton units -> metres
var _mats := {}


func attach(skel: Skeleton3D) -> void:
	_skel = skel
	_rig = (skel.global_basis.get_scale().x / global_basis.get_scale().x)
	_make_materials()
	var fore := _skel.find_bone(FOREARM)
	var hand := _skel.find_bone(HAND)
	if fore < 0 or hand < 0:
		push_warning("RobotArm: no %s / %s bone" % [FOREARM, HAND])
		return
	if build_forearm:
		_build_forearm(_holder(fore, "Forearm"), _length(fore, hand), _dorsal(fore))
	_build_hand(_holder(hand, "Hand"), hand)


# ------------------------------------------------------------------ frames

## A metre-scaled node riding a bone.
func _holder(bone: int, name: String) -> Node3D:
	var att := BoneAttachment3D.new()
	att.name = "RobotArm_" + name
	att.bone_name = _skel.get_bone_name(bone)
	_skel.add_child(att)
	var h := Node3D.new()
	h.name = name
	h.scale = Vector3.ONE / _rig
	att.add_child(h)
	return h


## Bone length (to `child`) in metres.
func _length(bone: int, child: int) -> float:
	return _skel.get_bone_rest(child).origin.length() * _rig if child >= 0 else 0.03


## The back of the arm/hand in the bone's frame (perpendicular to +Y).
func _dorsal(bone: int) -> Vector3:
	var d := _skel.get_bone_global_rest(bone).basis.inverse() * Vector3.UP
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.BACK


## Frame for a bone: x across, y along the bone, z = dorsal.
func _bone_basis(dorsal: Vector3) -> Basis:
	var across := Vector3.UP.cross(dorsal).normalized()
	return Basis(across, Vector3.UP, dorsal)


# --------------------------------------------------------------- materials

func _wear(base: Color, chip: Color, metal: float, rough: float, chip_amt: float, grime: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("chip_color", chip)
	m.set_shader_parameter("metallic_base", metal)
	m.set_shader_parameter("rough_base", rough)
	m.set_shader_parameter("chip_amount", chip_amt)
	m.set_shader_parameter("grime_amount", grime)
	return m


func _make_materials() -> void:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = palm_glow
	glow.emission_enabled = true
	glow.emission = palm_glow
	glow.emission_energy_multiplier = 3.0
	_mats = {
		# Same family as the terminal: graphite frame, cream covers, steel joints.
		"Graphite": _wear(frame_color, Color(0.5, 0.47, 0.42), 0.6, 0.48, 0.3 * wear, 0.35 * wear),
		"Cream": _wear(plate_color, Color(0.13, 0.11, 0.09), 0.12, 0.62, 0.4 * wear, 0.6 * wear),
		"Steel": _wear(Color(0.46, 0.44, 0.41), Color(0.24, 0.2, 0.15), 0.85, 0.36, 0.25, 0.35),
		"DarkMetal": _wear(Color(0.07, 0.066, 0.062), Color(0.2, 0.19, 0.17), 0.5, 0.55, 0.1, 0.2),
		"Copper": _wear(Color(0.5, 0.25, 0.11), Color(0.22, 0.12, 0.06), 0.65, 0.42, 0.25, 0.35),
		"Glow": glow,
	}


## Hand material name (kept for the hand code; the light scheme swaps the
## frame and plate materials for the whole arm in _part).
func _hm(m: String) -> String:
	return m


func _part(parent: Node3D, name: String, mb: ProcMesh.Builder) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var table := _mats
	if light_hand:
		# Off-white plates over dark joints: swap the frame and plate looks.
		table = _mats.duplicate()
		table["Graphite"] = _mats["Cream"]
		table["Cream"] = _mats["Graphite"]
	mi.mesh = mb.commit(table)
	parent.add_child(mi)
	return mi


# ----------------------------------------------------------------- forearm

## Elbow socket (covers the cut sleeve), a tapered forearm shell, two
## actuator rods, the wrist joint and the wrist terminal on the back.
func _build_forearm(h: Node3D, length: float, dorsal: Vector3) -> void:
	var b := _bone_basis(dorsal)
	var along := WristTerminal._axis(Vector3.ZERO, Vector3.UP)
	var round := ProcMesh.circle(20)
	var mb := ProcMesh.Builder.new()
	# Socket collar the sleeve ends in (a flared rim fills the cut sleeve),
	# and the elbow knuckle.
	WristTerminal._revolve(mb, "Graphite", [Vector2(0, 0.03), Vector2(0.05, 0.03), Vector2(0.06, 0.012),
		Vector2(0.058, 0.002), Vector2(0.049, -0.006), Vector2(0.049, -0.026), Vector2(0.043, -0.034), Vector2(0, -0.034)], round, along)
	WristTerminal._revolve(mb, "Steel", [Vector2(0, 0.004), Vector2(0.0605, 0.004), Vector2(0.0605, -0.0005), Vector2(0, -0.0005)], round, along)
	WristTerminal._cyl(mb, "Steel", b * Vector3(-0.047, 0.0, 0.0), b * Vector3(0.047, 0.0, 0.0), 0.019, 16, 0.003)
	# Forearm shell, tapering to the wrist.
	var l := length
	WristTerminal._revolve(mb, "Graphite", [Vector2(0, -0.03), Vector2(0.036, -0.03), Vector2(0.034, -l * 0.35),
		Vector2(0.03, -l * 0.75), Vector2(0.026, -l * 0.9), Vector2(0.023, -l * 0.94), Vector2(0, -l * 0.94)], round, along)
	# Cream armour plate on the inner forearm (the terminal covers the back).
	WristTerminal._box(mb, "Cream", Vector3(0, l * 0.5, -0.0305), Vector3(0.032, l * 0.5, 0.006), 0.0015, Transform3D(b, Vector3.ZERO))
	# Actuator rods down both sides.
	for s in [-1.0, 1.0]:
		var side: Vector3 = b * Vector3(s * 0.033, 0, -0.004)
		WristTerminal._cyl(mb, "Steel", side + Vector3(0, l * 0.12, 0), side + Vector3(0, l * 0.82, 0) - (b * Vector3(s * 0.006, 0, 0)), 0.0042, 10, 0.0006)
		WristTerminal._cyl(mb, "Copper", side + Vector3(0, l * 0.1, 0), side + Vector3(0, l * 0.36, 0), 0.006, 10, 0.001)
	# Wrist joint.
	WristTerminal._revolve(mb, "Steel", [Vector2(0, -l * 0.92), Vector2(0.026, -l * 0.92), Vector2(0.027, -l * 0.96),
		Vector2(0.024, -l * 1.0), Vector2(0, -l * 1.0)], round, along)
	_part(h, "Forearm", mb)

	if show_terminal:
		terminal = WristTerminal.new()
		terminal.name = "WristTerminal"
		# Terminal axes: +X along the arm towards the hand, +Y out of the
		# screen (the back of the forearm).
		var tb := Basis(Vector3.UP, dorsal, Vector3.UP.cross(dorsal)).orthonormalized()
		terminal.transform = Transform3D(tb.scaled_local(Vector3.ONE * terminal_scale), Vector3(0, l * terminal_position, 0))
		# Its cuff hugs the forearm shell under it (~0.031 m at the middle).
		terminal.arm_radius = 0.032 / terminal_scale
		h.add_child(terminal)


# -------------------------------------------------------------------- hand

## Palm block with a glowing palm and a cream back plate; each finger
## segment rides its own bone so the hand animates.
func _build_hand(h: Node3D, hand: int) -> void:
	var dorsal := _dorsal(hand)
	var b := _bone_basis(dorsal)
	var bx := Transform3D(b, Vector3.ZERO)
	# Knuckle line: where the four fingers start.
	var knuckles := []
	for f in ["Index", "Middle", "Ring", "Pinky"]:
		var i := _skel.find_bone("mixamorig_RightHand%s1" % f)
		if i >= 0:
			knuckles.append(_skel.get_bone_rest(i).origin * _rig)
	var reach := 0.085
	var width := 0.08
	if knuckles.size() == 4:
		reach = 0.0
		for k: Vector3 in knuckles:
			reach += k.y / 4.0
		width = ((knuckles[0] as Vector3) - (knuckles[3] as Vector3)).length() + (0.012 if light_hand else 0.024)
	var thick := 0.022 if light_hand else 0.026
	var mb := ProcMesh.Builder.new()
	WristTerminal._box(mb, _hm("Graphite"), Vector3(0, reach * 0.5, 0), Vector3(width, reach * 1.02, thick), 0.007 if light_hand else 0.004, bx)
	WristTerminal._box(mb, _hm("Cream"), Vector3(0, reach * 0.6, thick * 0.5 + 0.0015), Vector3(width * 0.62, reach * 0.5, 0.004), 0.0012, bx)
	for sx in [-0.3, 0.3]:
		WristTerminal._box(mb, "Steel", Vector3(width * sx, reach * 0.22, thick * 0.5 + 0.0008), Vector3(0.006, 0.006, 0.003), 0.001, bx)
	# Glowing palm, on the palm side.
	var palm_c := b * Vector3(0, reach * 0.5, -(thick * 0.5 + 0.0005))
	var palm_n := b * Vector3(0, 0, -1)
	WristTerminal._cyl(mb, "Steel", palm_c - palm_n * 0.0005, palm_c + palm_n * 0.0025, 0.019, 20, 0.0006)
	WristTerminal._cyl(mb, "Glow", palm_c + palm_n * 0.0024, palm_c + palm_n * 0.0034, 0.013, 20)
	# Knuckle bar.
	WristTerminal._cyl(mb, "Steel", b * Vector3(-width * 0.5, reach, 0), b * Vector3(width * 0.5, reach, 0), 0.0075, 12, 0.0015)
	_part(h, "Palm", mb)
	var light := OmniLight3D.new()
	light.name = "PalmLight"
	light.light_color = palm_glow
	light.light_energy = 0.3
	light.omni_range = 0.6
	light.position = palm_c + palm_n * 0.04
	h.add_child(light)

	if _skel.find_bone("mixamorig_RightHandIndex1") < 0:
		# A rig without finger bones: fixed, relaxed fingers on the hand.
		_build_static_fingers(h, b, dorsal, reach, width)
		return
	for f in FINGERS:
		var r := 0.0095 if f == "Thumb" else (0.0072 if f == "Pinky" else 0.0082)
		var prev_len := 0.03
		for seg in [1, 2, 3]:
			var bone := _skel.find_bone("mixamorig_RightHand%s%d" % [f, seg])
			if bone < 0:
				break
			var next := _skel.find_bone("mixamorig_RightHand%s%d" % [f, seg + 1])
			var len := _length(bone, next) if next >= 0 else prev_len * 0.8
			prev_len = len
			_build_finger_segment(_holder(bone, "%s%d" % [f, seg]), len, r * (1.0 - 0.1 * (seg - 1)), seg == 3, _dorsal(bone))


## Fingers for a rig with no finger bones: four fingers along the knuckle
## bar and a thumb, each three segments curled a little towards the palm.
func _build_static_fingers(h: Node3D, b: Basis, dorsal: Vector3, reach: float, width: float) -> void:
	var across := b.x
	# (offset across the knuckles, length, radius, base curl, spread)
	var fingers := [[-0.36, 0.034, 0.0082, 0.25, -0.05], [-0.12, 0.038, 0.0084, 0.3, 0.0], [0.12, 0.036, 0.0082, 0.35, 0.03],
		[0.36, 0.029, 0.0072, 0.4, 0.07]]
	for f in fingers.size():
		var spec: Array = fingers[f]
		var parent := h
		var at := b * Vector3(width * float(spec[0]), reach, 0)
		var seg_len: float = spec[1] * 0.42
		for seg in 3:
			var n := Node3D.new()
			n.name = "Finger%d_%d" % [f + 1, seg + 1]
			var curl: float = spec[3] + seg * 0.18
			n.transform = Transform3D(Basis(across, -curl) * Basis(b.z, float(spec[4]) if seg == 0 else 0.0), at)
			parent.add_child(n)
			_build_finger_segment(n, seg_len, float(spec[2]) * (1.0 - 0.1 * seg), seg == 2, dorsal)
			parent = n
			at = b * Vector3(0, seg_len, 0)
			seg_len *= 0.85
	# Thumb: from the inner side of the palm, angled across and forward.
	var parent := h
	var at := b * Vector3(-width * 0.5, reach * 0.3, -0.006)
	var tl := 0.03
	for seg in 3:
		var n := Node3D.new()
		n.name = "Thumb_%d" % (seg + 1)
		var rot := Basis(b.z, 0.7) * Basis(across, -0.35) if seg == 0 else Basis(across, -0.2)
		n.transform = Transform3D(rot, at)
		parent.add_child(n)
		_build_finger_segment(n, tl, 0.0095 * (1.0 - 0.1 * seg), seg == 2, dorsal)
		parent = n
		at = b * Vector3(0, tl, 0)
		tl *= 0.8


## One phalanx: a joint barrel at its base, a graphite link, a cream cap on
## the back; the last one gets a rounded tip.
func _build_finger_segment(h: Node3D, len: float, r: float, tip: bool, dorsal: Vector3) -> void:
	var b := _bone_basis(dorsal)
	var mb := ProcMesh.Builder.new()
	WristTerminal._cyl(mb, "Steel", b * Vector3(-r * 1.05, 0, 0), b * Vector3(r * 1.05, 0, 0), r * 0.8, 10, r * 0.15)
	var along := WristTerminal._axis(Vector3.ZERO, Vector3.UP)
	var end := len * (0.95 if tip else 0.9)
	var prof := [Vector2(0, -r * 0.4), Vector2(r * 0.82, -r * 0.4), Vector2(r * 0.9, -len * 0.3), Vector2(r * 0.82, -end)]
	if tip:
		prof.append_array([Vector2(r * 0.6, -end - r * 0.45), Vector2(0, -end - r * 0.6)])
	else:
		prof.append(Vector2(0, -end))
	WristTerminal._revolve(mb, _hm("Graphite"), prof, ProcMesh.circle(8), along, false)
	WristTerminal._box(mb, _hm("Cream"), Vector3(0, len * 0.5, r * 0.85), Vector3(r * 1.3, len * 0.55, r * 0.35), r * 0.15, Transform3D(b, Vector3.ZERO))
	_part(h, "Segment", mb)
