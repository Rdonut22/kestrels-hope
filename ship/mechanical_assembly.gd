@tool
extends Node3D

## A heavy circular industrial socket set into a wall panel: Meki's power
## jack-in point. Iris jaws inside close around his jack arm. Everything is
## generated in code from lathe profiles, so it's light and every major
## part can be tweaked from the inspector.
##
## Axes: X across, Y up, the flange in the XY plane facing -Z; the housing
## sits behind it (+Z).

## Outer radius of the flange; everything else scales with it.
@export var outer_radius := 0.5:
	set(v):
		outer_radius = v
		_queue_rebuild()
## How far the flange stands proud of the housing.
@export var flange_thickness := 0.085:
	set(v):
		flange_thickness = v
		_queue_rebuild()
## How deep the socket goes into the wall behind the face.
@export var socket_depth := 0.2:
	set(v):
		socket_depth = v
		_queue_rebuild()
@export_range(12, 96) var radial_segments := 48:
	set(v):
		radial_segments = v
		_queue_rebuild()
## How far the housing box goes back (it hides the socket's depth).
@export var housing_depth := 0.26:
	set(v):
		housing_depth = v
		_queue_rebuild()
@export_group("Clamp")
## 0 = iris jaws open, 1 = closed on a plugged-in jack.
@export_range(0.0, 1.0) var clamp_amount := 0.0:
	set(v):
		clamp_amount = v
		_place_jaws()
## Where the closed jaws stop (radius at outer_radius 0.5), i.e. the jack's
## half-width.
@export var jaw_closed_radius := 0.05:
	set(v):
		jaw_closed_radius = v
		_place_jaws()
@export_group("Indicators")
@export var upper_indicator_on := true:
	set(v):
		upper_indicator_on = v
		_update_indicators()
@export var lower_indicator_on := false:
	set(v):
		lower_indicator_on = v
		_update_indicators()

var _mats := {}
## Seen from the front (looking along +Z) world +X is on the viewer's left,
## so "screen right" features use -X; these helpers keep that readable.
const _RIGHT := -1.0
var _jaws: Array[Node3D] = []
var _inner: Node3D
const JAW_OPEN_INNER := 0.197
var _rebuild_queued := false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


# ---------- materials ----------

func _mat(name: String, color: Color, metal: float, rough: float, emit := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = energy
	return m


func _make_materials() -> void:
	_mats = {
		"WornSteel": _mat("WornSteel", Color(0.56, 0.51, 0.47), 0.55, 0.42),
		"FaceSteel": _mat("FaceSteel", Color(0.47, 0.42, 0.39), 0.5, 0.48),
		"OxidizedBronze": _mat("OxidizedBronze", Color(0.5, 0.36, 0.24), 0.45, 0.55),
		"PaleSteel": _mat("PaleSteel", Color(0.78, 0.74, 0.7), 0.3, 0.5),
		"DarkRecessedMetal": _mat("DarkRecessedMetal", Color(0.11, 0.09, 0.08), 0.35, 0.65),
		"Hole": _mat("Hole", Color(0.03, 0.025, 0.02), 0.0, 1.0),
		"DarkSteel": _mat("DarkSteel", Color(0.15, 0.13, 0.12), 0.45, 0.55),
		"CharcoalHousing": _mat("CharcoalHousing", Color(0.13, 0.12, 0.11), 0.3, 0.7),
		"HousingPlate": _mat("HousingPlate", Color(0.42, 0.38, 0.34), 0.4, 0.62),
		"ShaftMetal": _mat("ShaftMetal", Color(0.55, 0.44, 0.31), 0.45, 0.5),
		"ShaftDark": _mat("ShaftDark", Color(0.17, 0.15, 0.13), 0.5, 0.5),
		"RedRing": _mat("RedRing", Color(0.78, 0.33, 0.24), 0.2, 0.6),
		"IndicatorGreen": _mat("IndicatorGreen", Color(0.8, 1.0, 0.15), 0.0, 0.4, Color(0.72, 1.0, 0.08), 1.1),
		"IndicatorUnlit": _mat("IndicatorUnlit", Color(0.22, 0.27, 0.32), 0.3, 0.6),
		"IndicatorCore": _mat("IndicatorCore", Color(0.4, 0.17, 0.12), 0.2, 0.6),
		"LedOrange": _mat("LedOrange", Color(1.0, 0.6, 0.3), 0.0, 0.4, Color(1.0, 0.55, 0.25), 3.0),
	}


# ---------- mesh helpers ----------

## Angle as seen from the front (0 = screen right, 90 = up) to model angle.
static func _sa(deg: float) -> float:
	return PI - deg_to_rad(deg)


## Front face of a w x h plate at z = 0 with a circular hole of radius r,
## plus its back face and outer edges (depth into +Z).
func _plate_with_hole(mb: ProcMesh.Builder, mat: String, size: Vector2, r: float, depth: float) -> void:
	var h := size * 0.5
	var angles := []
	for i in radial_segments:
		angles.append(TAU * i / radial_segments)
	for c in [Vector2(h.x, h.y), Vector2(-h.x, h.y), Vector2(-h.x, -h.y), Vector2(h.x, -h.y)]:
		angles.append(fposmod(atan2(c.y, c.x), TAU))
	angles.sort()
	var edge := func(a: float) -> Vector2:
		var d := Vector2(cos(a), sin(a))
		var t := minf(h.x / maxf(absf(d.x), 1e-6), h.y / maxf(absf(d.y), 1e-6))
		return d * t
	var front := Vector3(0, 0, -1)
	for i in angles.size():
		var a0: float = angles[i]
		var a1: float = angles[(i + 1) % angles.size()]
		var i0 := Vector2(cos(a0), sin(a0)) * r
		var i1 := Vector2(cos(a1), sin(a1)) * r
		var o0: Vector2 = edge.call(a0)
		var o1: Vector2 = edge.call(a1)
		mb.quad(mat, Vector3(i0.x, i0.y, 0), Vector3(i1.x, i1.y, 0), Vector3(o1.x, o1.y, 0), Vector3(o0.x, o0.y, 0), front)
	# Edges and back.
	var corners := [Vector2(h.x, h.y), Vector2(-h.x, h.y), Vector2(-h.x, -h.y), Vector2(h.x, -h.y)]
	for i in 4:
		var c0: Vector2 = corners[i]
		var c1: Vector2 = corners[(i + 1) % 4]
		var mid := (c0 + c1) * 0.5
		mb.quad(mat, Vector3(c0.x, c0.y, 0), Vector3(c1.x, c1.y, 0), Vector3(c1.x, c1.y, depth), Vector3(c0.x, c0.y, depth), Vector3(mid.x, mid.y, 0))
	mb.quad(mat, Vector3(h.x, h.y, depth), Vector3(-h.x, h.y, depth), Vector3(-h.x, -h.y, depth), Vector3(h.x, -h.y, depth), Vector3(0, 0, 1))


func _instance(parent: Node, name: String, mesh: Mesh, xf := Transform3D.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.transform = xf
	parent.add_child(mi)
	return mi


func _group(name: String) -> Node3D:
	var n := Node3D.new()
	n.name = name
	add_child(n)
	return n


# ---------- build ----------

func _rebuild() -> void:
	_rebuild_queued = false
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_make_materials()
	var k := outer_radius / 0.5
	_build_housing(k)
	_build_outer_ring(k)
	_build_ring_details(k)
	_build_inner_rings(k)
	_build_inner_mechanism(k)
	_build_socket(k)
	_build_jaws(k)
	_build_indicators(k)
	_place_jaws()
	_update_indicators()


func _build_housing(k: float) -> void:
	var g := _group("Housing")
	var mb := ProcMesh.Builder.new()
	# Main plate (front face at z = 0) with a round opening for the socket,
	# and a raised lip along the top.
	_plate_with_hole(mb, "HousingPlate", Vector2(2.3, 1.25) * k, 0.495 * k, housing_depth * k)
	ProcMesh.box(mb, "HousingPlate", Vector3(0, 0.455, -0.012) * k, Vector3(2.3, 0.035, 0.024) * k)
	ProcMesh.box(mb, "CharcoalHousing", Vector3(0, 0.432, -0.004) * k, Vector3(2.3, 0.01, 0.008) * k)
	# Dark recessed panels (each with a thin bright frame) left and right.
	var insets := [Rect2(-0.69, 0.25, 0.39, 0.15), Rect2(-0.69, -0.39, 0.39, 0.6),
		Rect2(0.34, 0.25, 0.46, 0.15), Rect2(0.47, -0.34, 0.33, 0.56)]
	for r: Rect2 in insets:
		var c := Vector3(r.get_center().x * _RIGHT, r.get_center().y, 0) * k
		ProcMesh.box(mb, "WornSteel", c + Vector3(0, 0, -0.003) * k, Vector3(r.size.x + 0.024, r.size.y + 0.024, 0.006) * k)
		ProcMesh.box(mb, "CharcoalHousing", c + Vector3(0, 0, -0.007) * k, Vector3(r.size.x, r.size.y, 0.004) * k)
		# A horizontal seam across the taller panels.
		if r.size.y > 0.3:
			ProcMesh.box(mb, "HousingPlate", c + Vector3(0, r.size.y * 0.18, -0.01) * k, Vector3(r.size.x, 0.012, 0.004) * k)
	_instance(g, "Plate", mb.commit(_mats))


func _build_outer_ring(k: float) -> void:
	var g := _group("OuterRing")
	var mb := ProcMesh.Builder.new()
	var R := 0.5 * k
	var f := -flange_thickness * k
	var face := f + 0.01 * k
	# Profile from the outer rim (at the wall) inward down into the socket.
	var rim := f - 0.014 * k
	var prof := [
		Vector2(R, 0.0), Vector2(R, rim + 0.03 * k), Vector2(R - 0.006 * k, rim + 0.008 * k), Vector2(R - 0.016 * k, rim),
		Vector2(0.474 * k, rim + 0.004 * k), Vector2(0.466 * k, face - 0.004 * k), Vector2(0.46 * k, face),
		Vector2(0.318 * k, face), Vector2(0.31 * k, face + 0.008 * k), Vector2(0.288 * k, -0.035 * k),
		Vector2(0.282 * k, -0.03 * k),
	]
	var m := ["WornSteel", "PaleSteel", "WornSteel", "WornSteel", "WornSteel", "DarkSteel", "FaceSteel", "PaleSteel", "WornSteel", "DarkSteel"]
	ProcMesh.loft(mb, "WornSteel", prof, ProcMesh.circle(radial_segments), true, m)
	_instance(g, "Flange", mb.commit(_mats))


# Slots, holes and fasteners around the face band, as MultiMeshes.
func _build_ring_details(k: float) -> void:
	var g := _group("OuterRingDetails")
	var face := (-flange_thickness + 0.01) * k
	var slot := CapsuleMesh.new()
	slot.radius = 0.014 * k
	slot.height = 0.088 * k
	slot.radial_segments = 10
	slot.rings = 2
	slot.material = _mats["Hole"]
	var short_slot := slot.duplicate() as CapsuleMesh
	short_slot.height = 0.05 * k
	var hole := SphereMesh.new()
	hole.radius = 0.0125 * k
	hole.height = 0.025 * k
	hole.radial_segments = 10
	hole.rings = 4
	hole.material = _mats["Hole"]
	var slots := []
	var shorts := []
	var holes := []
	# Dash-dot pattern every 15 degrees; small hole pairs at the four points.
	for i in 32:
		var a := deg_to_rad(5.625 + i * 11.25)
		var r := 0.39 * k
		var p := Vector3(cos(a) * r, sin(a) * r, face + 0.008 * k)
		if i % 2 == 0:
			# Capsules lie along Y; turn them to run along the ring.
			var basis := Basis(Vector3(0, 0, 1), a)
			((shorts if i % 8 == 6 else slots) as Array).append(Transform3D(basis, p))
		else:
			holes.append(Transform3D(Basis(), p))
	for q in 4:
		var a := q * PI / 2.0
		var d := Vector2(cos(a), sin(a))
		var t := Vector2(-d.y, d.x)
		for s in [-1.0, 1.0]:
			var pp: Vector2 = d * 0.448 * k + t * s * 0.024 * k
			holes.append(Transform3D(Basis(), Vector3(pp.x, pp.y, face + 0.008 * k)))
	for set in [["Slots", slot, slots], ["ShortSlots", short_slot, shorts], ["Holes", hole, holes]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = set[1]
		mm.instance_count = set[2].size()
		for i in set[2].size():
			mm.set_instance_transform(i, set[2][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = set[0]
		mmi.multimesh = mm
		g.add_child(mmi)


# The dark stepped tunnel between the funnel and the inner mechanism.
func _build_inner_rings(k: float) -> void:
	var g := _group("InnerRings")
	var mb := ProcMesh.Builder.new()
	var d := socket_depth * k
	# Stepped rings receding into the dark, each lip catching a little light.
	var prof := [
		Vector2(0.282 * k, -0.03 * k), Vector2(0.28 * k, 0.0), Vector2(0.262 * k, 0.0),
		Vector2(0.258 * k, d * 0.3), Vector2(0.24 * k, d * 0.3), Vector2(0.236 * k, d * 0.52),
		Vector2(0.218 * k, d * 0.52), Vector2(0.214 * k, d * 0.72), Vector2(0.196 * k, d * 0.72),
		Vector2(0.192 * k, d), Vector2(0.0, d),
	]
	var m := ["DarkRecessedMetal", "DarkSteel", "DarkRecessedMetal", "DarkSteel", "DarkRecessedMetal", "DarkSteel", "DarkRecessedMetal", "DarkSteel", "DarkRecessedMetal", "DarkRecessedMetal"]
	ProcMesh.loft(mb, "DarkRecessedMetal", prof, ProcMesh.circle(radial_segments), true, m)
	_instance(g, "Tunnel", mb.commit(_mats))


# Layered plates at the bottom of the socket: notched outer plate, the fine
# bronze trace arc, pale angular plates and a darker inner ring.
func _build_inner_mechanism(k: float) -> void:
	var g := _group("InnerMechanism")
	var mb := ProcMesh.Builder.new()
	var d := socket_depth * k
	var z := d * 0.78
	# Outer plate ring with a gap pattern of tabs around its rim.
	ProcMesh.loft(mb, "WornSteel", [Vector2(0.183 * k, d), Vector2(0.183 * k, z), Vector2(0.138 * k, z), Vector2(0.138 * k, d)], ProcMesh.circle(radial_segments))
	for i in 10:
		var a := deg_to_rad(i * 36.0 + 12.0)
		ProcMesh.sector(mb, "DarkRecessedMetal", 0.168 * k, 0.184 * k, a, a + deg_to_rad(9.0), z - 0.004 * k, z + 0.002 * k, 2)
	# Bronze trace arc across the top-left, with comb teeth.
	ProcMesh.sector(mb, "OxidizedBronze", 0.15 * k, 0.16 * k, _sa(175), _sa(30), z - 0.006 * k, z, 24)
	for i in 34:
		var a := _sa(32 + i * 4.2)
		ProcMesh.sector(mb, "OxidizedBronze", 0.141 * k, 0.15 * k, a - deg_to_rad(1.6), a, z - 0.005 * k, z, 1)
	ProcMesh.sector(mb, "OxidizedBronze", 0.128 * k, 0.138 * k, _sa(120), _sa(60), z - 0.004 * k, z + 0.01 * k, 8)
	# Pale angular plates at the upper right.
	ProcMesh.sector(mb, "PaleSteel", 0.125 * k, 0.178 * k, _sa(52), _sa(28), z - 0.012 * k, z - 0.004 * k, 4)
	ProcMesh.sector(mb, "PaleSteel", 0.11 * k, 0.15 * k, _sa(26), _sa(8), z - 0.01 * k, z - 0.002 * k, 3)
	ProcMesh.sector(mb, "OxidizedBronze", 0.13 * k, 0.17 * k, _sa(4), _sa(-12), z - 0.009 * k, z - 0.003 * k, 3)
	# Darker inner ring, stepped deeper, with small rectangular tabs.
	var z2 := d * 0.86
	ProcMesh.loft(mb, "FaceSteel", [Vector2(0.138 * k, z), Vector2(0.136 * k, z2 - 0.02 * k), Vector2(0.1 * k, z2 - 0.02 * k), Vector2(0.1 * k, d)], ProcMesh.circle(radial_segments))
	for i in 6:
		var a := deg_to_rad(i * 60.0 + 20.0)
		ProcMesh.sector(mb, "DarkRecessedMetal", 0.112 * k, 0.13 * k, a, a + deg_to_rad(12.0), z2 - 0.026 * k, z2 - 0.018 * k, 2)
	_instance(g, "Plates", mb.commit(_mats))


# The salmon segmented ring, the coil-spring coupling and the socket hole.
func _build_socket(k: float) -> void:
	var g := _group("CentralSocket")
	var mb := ProcMesh.Builder.new()
	var d := socket_depth * k
	var z := d * 0.8
	ProcMesh.loft(mb, "RedRing", [Vector2(0.088 * k, d), Vector2(0.088 * k, z - 0.01 * k), Vector2(0.05 * k, z - 0.01 * k), Vector2(0.05 * k, d)], ProcMesh.circle(radial_segments))
	for i in 24:
		var a := deg_to_rad(i * 15.0)
		ProcMesh.sector(mb, "DarkRecessedMetal", 0.07 * k, 0.088 * k, a, a + deg_to_rad(2.5), z - 0.013 * k, z - 0.009 * k, 1)
	ProcMesh.loft(mb, "Hole", [Vector2(0.05 * k, z - 0.01 * k), Vector2(0.044 * k, d), Vector2(0.0, d)], ProcMesh.circle(24))
	_instance(g, "Socket", mb.commit(_mats))


# Iris jaws in the socket mouth that close around a plugged-in jack.
func _build_jaws(k: float) -> void:
	var g := _group("Clamp")
	_jaws.clear()
	var z := socket_depth * k * 0.715
	for i in 6:
		var mb := ProcMesh.Builder.new()
		var a0 := deg_to_rad(i * 60.0 + 6.0)
		var a1 := deg_to_rad(i * 60.0 + 54.0)
		# Open, they sit hidden in the tunnel wall; closing slides them in.
		ProcMesh.sector(mb, "DarkSteel", JAW_OPEN_INNER * k, (JAW_OPEN_INNER + 0.065) * k, a0, a1, z - 0.012 * k, z, 6)
		# A bright bevelled lip on each jaw's inner edge.
		ProcMesh.sector(mb, "WornSteel", JAW_OPEN_INNER * k, (JAW_OPEN_INNER + 0.008) * k, a0, a1, z - 0.014 * k, z - 0.012 * k, 6)
		var jaw := Node3D.new()
		jaw.name = "Jaw%d" % i
		jaw.set_meta("dir", Vector2(cos((a0 + a1) / 2.0), sin((a0 + a1) / 2.0)))
		g.add_child(jaw)
		_instance(jaw, "Mesh", mb.commit(_mats))
		_jaws.append(jaw)


func _place_jaws() -> void:
	if _jaws.is_empty():
		return
	var k := outer_radius / 0.5
	var travel := (JAW_OPEN_INNER - jaw_closed_radius) * k * clamp_amount
	for jaw in _jaws:
		var d: Vector2 = jaw.get_meta("dir")
		jaw.position = Vector3(-d.x * travel, -d.y * travel, 0)
	# The inner plates turn a little as it locks.
	var inner := get_node_or_null("InnerMechanism") as Node3D
	if inner:
		inner.rotation.z = deg_to_rad(18.0) * clamp_amount


## World position at the back of the socket where a jack's tip should end.
func seat_position() -> Vector3:
	return to_global(Vector3(0, 0, socket_depth * (outer_radius / 0.5) * 0.74))


## World direction straight out of the socket face.
func face_normal() -> Vector3:
	return -global_transform.basis.z.normalized()


func _build_indicators(k: float) -> void:
	var c := Vector2(0.645 * _RIGHT, -0.025) * k
	var mount := _group("IndicatorMount")
	var mb := ProcMesh.Builder.new()
	# Raised pill-shaped plate the two lights sit in.
	var pill := []
	for i in 13:
		var a := PI * i / 12.0
		pill.append(Vector2(cos(a) * 0.075, 0.115 + sin(a) * 0.075) * k)
	for i in 13:
		var a := PI + PI * i / 12.0
		pill.append(Vector2(cos(a) * 0.075, -0.115 + sin(a) * 0.075) * k)
	var zf := -0.022 * k
	for i in pill.size():
		var p0: Vector2 = pill[i] + c
		var p1: Vector2 = pill[(i + 1) % pill.size()] + c
		var mid: Vector2 = (pill[i] + pill[(i + 1) % pill.size()]) * 0.5
		mb.quad("WornSteel", Vector3(p0.x, p0.y, 0), Vector3(p1.x, p1.y, 0), Vector3(p1.x, p1.y, zf), Vector3(p0.x, p0.y, zf), Vector3(mid.x, mid.y, 0))
		mb.tri("FaceSteel", Vector3(c.x, c.y, zf), Vector3(p0.x, p0.y, zf), Vector3(p1.x, p1.y, zf), Vector3(0, 0, -1))
	_instance(mount, "Mount", mb.commit(_mats))
	for spec in [["UpperIndicator", 0.103, "IndicatorGreen"], ["LowerIndicator", -0.103, "IndicatorUnlit"]]:
		var g := _group(spec[0])
		g.position = Vector3(c.x, c.y + spec[1] * k, zf)
		var ib := ProcMesh.Builder.new()
		# Dark bezel ring, then the light face, then the centre.
		ProcMesh.loft(ib, "DarkRecessedMetal", [Vector2(0.064 * k, 0.0), Vector2(0.064 * k, -0.012 * k), Vector2(0.054 * k, -0.014 * k), Vector2(0.054 * k, -0.006 * k)], ProcMesh.circle(32))
		var face_mat: String = spec[2]
		if face_mat == "IndicatorGreen":
			ProcMesh.loft(ib, face_mat, [Vector2(0.054 * k, -0.006 * k), Vector2(0.022 * k, -0.011 * k)], ProcMesh.circle(32))
			ProcMesh.loft(ib, "DarkRecessedMetal", [Vector2(0.022 * k, -0.011 * k), Vector2(0.022 * k, -0.006 * k), Vector2(0.0, -0.006 * k)], ProcMesh.circle(16))
		else:
			ProcMesh.loft(ib, face_mat, [Vector2(0.054 * k, -0.006 * k), Vector2(0.018 * k, -0.008 * k)], ProcMesh.circle(32))
			ProcMesh.loft(ib, "IndicatorCore", [Vector2(0.018 * k, -0.008 * k), Vector2(0.0, -0.01 * k)], ProcMesh.circle(16))
		_instance(g, "Light", ib.commit(_mats))
	var lighting := _group("Lighting")
	var spill := OmniLight3D.new()
	spill.name = "UpperIndicatorSpill"
	spill.light_color = Color(0.75, 1.0, 0.3)
	spill.omni_range = 0.45 * k
	spill.position = Vector3(c.x, c.y + 0.103 * k, -0.09 * k)
	lighting.add_child(spill)


func _update_indicators() -> void:
	var up := get_node_or_null("UpperIndicator/Light") as MeshInstance3D
	if not up or _mats.is_empty():
		return
	var spill := get_node_or_null("Lighting/UpperIndicatorSpill") as OmniLight3D
	spill.light_energy = 0.5 if upper_indicator_on else 0.0
	(_mats["IndicatorGreen"] as StandardMaterial3D).emission_energy_multiplier = 1.1 if upper_indicator_on else 0.0
	var low := _mats["IndicatorCore"] as StandardMaterial3D
	low.emission_enabled = lower_indicator_on
	low.emission = Color(1.0, 0.35, 0.2)
	low.emission_energy_multiplier = 2.0 if lower_indicator_on else 0.0
