@tool
class_name WristTerminal
extends Node3D

## Gana's wrist computer: the USHIDA Field Terminal, Wrist Unit G-07.
## A standalone prop (no UI or gameplay yet), built entirely in code from
## bevelled prisms, frames, lathes and swept tubes (ProcMesh.Builder), so
## every part can be refined on its own. See README.md next to this file.
##
## Axes (metres; the forearm is a cylinder of arm_radius along X):
##   +X  along the forearm towards the hand (wrist band end),
##   -X  towards the elbow (olive latch end, webbing strap),
##   +Y  out of the screen (the top of the forearm),
##   -Z  the "top" edge in the reference's hero view (handle rail, D-ring,
##       side port), +Z the "bottom" edge (piston, cable, USHIDA label).
## Looking down from +Y with -Z up the screen, +X is screen right: that is
## the reference's hero view.
##
## Built at runtime in _ready() without owners, so the saved scene only
## holds this node and its exported values.

## Radius of the forearm the cuff is fitted to. The housing rides up and
## down with it; the cuff, straps and band are rebuilt to fit.
@export_range(0.03, 0.06, 0.001) var arm_radius := 0.040:
	set(v):
		arm_radius = v
		_queue_rebuild()
## Overall paint wear (0 = new, 1 = badly chipped).
@export_range(0.0, 1.0) var wear := 0.5:
	set(v):
		wear = v
		_apply_wear()
@export_group("Controls")
## Rotary knob angle in degrees (turns about the knob's own axis).
@export_range(-180.0, 180.0) var knob_angle := 0.0:
	set(v):
		knob_angle = v
		_pose_controls()
## 0 = up, 1 = pressed in.
@export_range(0.0, 1.0) var button_a_pressed := 0.0:
	set(v):
		button_a_pressed = v
		_pose_controls()
@export_range(0.0, 1.0) var button_b_pressed := 0.0:
	set(v):
		button_b_pressed = v
		_pose_controls()
## Green status lamp above the knob.
@export var indicator_on := true:
	set(v):
		indicator_on = v
		_update_indicator()
## Flip cover over the side data port: 0 = closed, 1 = hanging open.
@export_range(0.0, 1.0) var port_cover_open := 0.0:
	set(v):
		port_cover_open = v
		_pose_controls()
@export_group("Detail")
## Segments for round parts (knob, piston, cable, screws scale from it).
@export_range(8, 48) var round_segments := 20:
	set(v):
		round_segments = v
		_queue_rebuild()
## Segments around the forearm for the cuff and straps.
@export_range(16, 96) var cuff_segments := 48:
	set(v):
		cuff_segments = v
		_queue_rebuild()

## The housing is modelled for this arm radius and raised by the difference.
const DESIGN_ARM_R := 0.040
const BUTTON_TRAVEL := 0.0016

var _mats := {}
var _rebuild_queued := false
var _knob: Node3D
var _button_a: Node3D
var _button_b: Node3D
var _cover: Node3D
var _screws: Array[Transform3D] = []


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


## The blank display surface (UVs 0..1, u along +X, v along +Z), for a
## future SubViewport UI.
func get_display() -> MeshInstance3D:
	return find_child("Display", true, false) as MeshInstance3D


func _rebuild() -> void:
	_rebuild_queued = false
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_screws.clear()
	_make_materials()

	var mount := _group(self, "ForearmMount")
	_build_cuff(mount)
	_build_wrist_band(mount)
	_build_elbow_strap(mount)
	_build_center_strap(mount)

	var unit := _group(self, "Unit")
	unit.position.y = arm_radius - DESIGN_ARM_R
	_build_housing(_group(unit, "Housing"))
	_build_screen(_group(unit, "Screen"))
	_build_latch_panel(_group(unit, "LatchPanel"))
	_build_controls(_group(unit, "Controls"))
	_build_vent(_group(unit, "Vent"))
	_build_brackets(_group(unit, "Brackets"))
	_build_piston(_group(unit, "Piston"))
	_build_port(_group(unit, "Ports"))
	_build_cable(_group(unit, "Cables"))
	_build_labels(_group(unit, "Labels"))
	_build_screws(unit)

	_apply_wear()
	_pose_controls()
	_update_indicator()


# ---------------------------------------------------------------- materials

func _wear_mat(name: String, base: Color, chip: Color, metal: float, rough: float, chip_amt: float,
		grime: float, metal_chip := 0.85, rough_chip := 0.38, edge := 0.6) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.resource_name = name
	m.shader = preload("res://characters/gana/wrist_terminal/wrist_wear.gdshader")
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("chip_color", chip)
	m.set_shader_parameter("metallic_base", metal)
	m.set_shader_parameter("rough_base", rough)
	m.set_shader_parameter("metallic_chip", metal_chip)
	m.set_shader_parameter("rough_chip", rough_chip)
	m.set_shader_parameter("grime_amount", grime)
	m.set_shader_parameter("edge_wear", edge)
	m.set_meta("chip_amount", chip_amt)
	return m


func _make_materials() -> void:
	var bare := Color(0.13, 0.11, 0.09)
	_mats = {
		# Weathered cream enamel over steel (housing, control block).
		"Cream": _wear_mat("Cream", Color(0.58, 0.56, 0.47), bare, 0.12, 0.62, 0.42, 0.7),
		# Olive drab paint (latch plate, control panel, side rail).
		"Olive": _wear_mat("Olive", Color(0.27, 0.29, 0.18), Color(0.42, 0.38, 0.3), 0.12, 0.58, 0.45, 0.45),
		# Graphite / gunmetal (bezel, brackets, skirts); worn edges go bright.
		"Graphite": _wear_mat("Graphite", Color(0.16, 0.155, 0.145), Color(0.5, 0.47, 0.42), 0.6, 0.48, 0.35, 0.35, 0.9, 0.3),
		# Recess floors, vent backs, port insides.
		"DarkMetal": _wear_mat("DarkMetal", Color(0.07, 0.066, 0.062), Color(0.2, 0.19, 0.17), 0.5, 0.55, 0.1, 0.2),
		# Bare steel (piston rod, hinge pins, screw heads, buckle).
		"Steel": _wear_mat("Steel", Color(0.46, 0.44, 0.41), Color(0.24, 0.2, 0.15), 0.85, 0.36, 0.3, 0.35, 0.6, 0.6),
		# Black rubber (ribbed wrist band, button, knob grip).
		"Rubber": _wear_mat("Rubber", Color(0.05, 0.048, 0.045), Color(0.13, 0.12, 0.1), 0.0, 0.82, 0.15, 0.4, 0.0, 0.9, 0.2),
		# Cuff shell: dark moulded rubber/leather.
		"Cuff": _wear_mat("Cuff", Color(0.085, 0.078, 0.066), Color(0.16, 0.14, 0.11), 0.0, 0.72, 0.2, 0.5, 0.0, 0.8, 0.0),
		# Nylon webbing straps.
		"Webbing": _wear_mat("Webbing", Color(0.1, 0.095, 0.078), Color(0.17, 0.15, 0.12), 0.0, 0.95, 0.15, 0.5, 0.0, 0.95, 0.0),
		# Amber paint (bar, button, latch, handle sleeve).
		"Amber": _wear_mat("Amber", Color(0.72, 0.42, 0.09), bare, 0.15, 0.5, 0.4, 0.45),
		# Orange label stripe.
		"Orange": _wear_mat("Orange", Color(0.86, 0.43, 0.09), Color(0.62, 0.58, 0.47), 0.05, 0.6, 0.4, 0.25, 0.1, 0.6),
		# Braided copper cable sheath.
		"Copper": _wear_mat("Copper", Color(0.5, 0.25, 0.11), Color(0.22, 0.12, 0.06), 0.65, 0.42, 0.3, 0.4, 0.4, 0.6),
		"Hole": _std("Hole", Color(0.012, 0.012, 0.012), 0.0, 1.0),
		"Display": _display_mat(),
		"LedOn": _std("LedOn", Color(0.08, 0.3, 0.04), 0.0, 0.3, Color(0.22, 0.85, 0.08), 0.85),
		"LedOff": _std("LedOff", Color(0.08, 0.13, 0.07), 0.0, 0.25),
	}


func _std(name: String, color: Color, metal: float, rough: float, emit := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
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


## Blank screen: near-black glossy glass.
func _display_mat() -> StandardMaterial3D:
	var m := _std("Display", Color(0.012, 0.014, 0.014), 0.0, 0.14)
	m.metallic_specular = 0.7
	return m


func _apply_wear() -> void:
	for k in _mats:
		var m = _mats[k]
		if m is ShaderMaterial and (m as ShaderMaterial).has_meta("chip_amount"):
			var base: float = m.get_meta("chip_amount")
			m.set_shader_parameter("chip_amount", clampf(base * wear * 2.0, 0.0, 1.0))


# ------------------------------------------------------------ scene helpers

func _group(parent: Node, name: String) -> Node3D:
	var n := Node3D.new()
	n.name = name
	parent.add_child(n)
	return n


func _part(parent: Node, name: String, mb: ProcMesh.Builder) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mb.commit(_mats)
	parent.add_child(mi)
	return mi


func _screw(pos: Vector3, normal := Vector3.UP, spin := 0.0) -> void:
	var up := normal.normalized()
	var side := Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD
	var z := side.cross(up).normalized()
	var x := up.cross(z).normalized()
	var b := Basis(x, up, z) * Basis(Vector3.UP, spin)
	_screws.append(Transform3D(b, pos))


# ----------------------------------------------------------- polygon helpers

## Chamfered rectangle in the XZ plane (8 points), corner chamfer c.
static func _crect(x0: float, z0: float, x1: float, z1: float, c: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0 + c, z0), Vector2(x1 - c, z0), Vector2(x1, z0 + c), Vector2(x1, z1 - c),
		Vector2(x1 - c, z1), Vector2(x0 + c, z1), Vector2(x0, z1 - c), Vector2(x0, z0 + c)])


## Same, from a centre and size.
static func _crect_c(cx: float, cz: float, w: float, h: float, c: float) -> PackedVector2Array:
	return _crect(cx - w * 0.5, cz - h * 0.5, cx + w * 0.5, cz + h * 0.5, c)


static func _signed_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## Outward normal of edge a->b for a polygon of the given orientation.
static func _edge_out(a: Vector2, b: Vector2, ccw: bool) -> Vector2:
	var d := (b - a).normalized()
	return Vector2(d.y, -d.x) if ccw else Vector2(-d.y, d.x)


## Shrink a polygon by d (negative d grows it), keeping vertex order.
static func _inset(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var ccw := _signed_area(poly) > 0.0
	var n := poly.size()
	var out := PackedVector2Array()
	for i in n:
		var p := poly[i]
		var n0 := _edge_out(poly[(i - 1 + n) % n], p, ccw)
		var n1 := _edge_out(p, poly[(i + 1) % n], ccw)
		var m := (n0 + n1).normalized()
		var k := maxf(m.dot(n0), 0.35)
		out.append(p - m * (d / k))
	return out


static func _v(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


## Transform whose local Y is `normal`, local X roughly `along`.
static func _frame_xf(origin: Vector3, normal: Vector3, along := Vector3.RIGHT) -> Transform3D:
	var y := normal.normalized()
	var x := (along - y * along.dot(y)).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x, y, z), origin)


## Prism profiles drawn in the (z, y) plane, extruded along X.
const XF_ALONG_X := Transform3D(Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)), Vector3.ZERO)
## Prism profiles drawn in the (x, y) plane, extruded along Z.
const XF_ALONG_Z := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)), Vector3.ZERO)


# ------------------------------------------------------------ mesh builders

## Smooth-shaded triangle (normals given per corner).
static func _tri_n(mb: ProcMesh.Builder, mat: String, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	if (b - a).cross(c - a).dot(na + nb + nc) < 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	var st := mb._st(mat)
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nc)
	st.add_vertex(c)
	st.set_normal(nb)
	st.add_vertex(b)


static func _quad_n(mb: ProcMesh.Builder, mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3) -> void:
	_tri_n(mb, mat, a, b, c, na, nb, nc)
	_tri_n(mb, mat, a, c, d, na, nc, nd)


static func _cap(mb: ProcMesh.Builder, mat: String, poly: PackedVector2Array, y: float, up: bool, xf: Transform3D) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	var out := xf.basis * Vector3(0, 1 if up else -1, 0)
	for t in range(0, idx.size(), 3):
		mb.tri(mat, xf * _v(poly[idx[t]], y), xf * _v(poly[idx[t + 1]], y), xf * _v(poly[idx[t + 2]], y), out)


## Side walls of a polygon from y0 up to y1, the top edge rolled over by a
## bevel. inward = walls of a hole (normals face the hole's centre, the
## bevel grows outwards). Returns the polygon at the top of the bevel.
static func _walls(mb: ProcMesh.Builder, mat: String, poly: PackedVector2Array, y0: float, y1: float, bevel: float,
		xf: Transform3D, inward := false) -> PackedVector2Array:
	var ccw := _signed_area(poly) > 0.0
	var top := _inset(poly, -bevel if inward else bevel) if bevel > 0.0 else poly
	var yw := y1 - bevel
	var s := -1.0 if inward else 1.0
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		var o := _edge_out(a, b, ccw) * s
		if yw > y0:
			mb.quad(mat, xf * _v(a, y0), xf * _v(b, y0), xf * _v(b, yw), xf * _v(a, yw), xf.basis * Vector3(o.x, 0, o.y))
		if bevel > 0.0:
			mb.quad(mat, xf * _v(a, yw), xf * _v(b, yw), xf * _v(top[(i + 1) % n], y1), xf * _v(top[i], y1),
				xf.basis * Vector3(o.x, 1, o.y))
	return top


## Solid prism of a polygon (XZ) from y0 to y1, top edges bevelled.
static func _prism(mb: ProcMesh.Builder, mat: String, poly: PackedVector2Array, y0: float, y1: float, bevel := 0.0,
		xf := Transform3D.IDENTITY, bottom := true, bevel_bottom := 0.0) -> void:
	var lo := poly
	var ys := y0
	if bevel_bottom > 0.0:
		# Mirror the walls for a bevel at the bottom edge too.
		lo = _inset(poly, bevel_bottom)
		var ccw := _signed_area(poly) > 0.0
		ys = y0 + bevel_bottom
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			var o := _edge_out(a, b, ccw)
			mb.quad(mat, xf * _v(lo[i], y0), xf * _v(lo[(i + 1) % poly.size()], y0), xf * _v(b, ys), xf * _v(a, ys),
				xf.basis * Vector3(o.x, -1, o.y))
	var top := _walls(mb, mat, poly, ys, y1, bevel, xf)
	_cap(mb, mat, top, y1, true, xf)
	if bottom:
		_cap(mb, mat, lo, y0, false, xf)


## Bevelled box from centre and size, optionally placed by xf.
static func _box(mb: ProcMesh.Builder, mat: String, c: Vector3, s: Vector3, bevel := 0.0, xf := Transform3D.IDENTITY) -> void:
	var ch := minf(bevel, minf(s.x, s.z) * 0.3)
	var poly := _crect_c(c.x, c.z, s.x, s.z, ch) if ch > 0.0 else PackedVector2Array([
		Vector2(c.x - s.x * 0.5, c.z - s.z * 0.5), Vector2(c.x + s.x * 0.5, c.z - s.z * 0.5),
		Vector2(c.x + s.x * 0.5, c.z + s.z * 0.5), Vector2(c.x - s.x * 0.5, c.z + s.z * 0.5)])
	_prism(mb, mat, poly, c.y - s.y * 0.5, c.y + s.y * 0.5, minf(bevel, s.y * 0.4), xf, true, minf(bevel, s.y * 0.4) * 0.5)


## Raised frame between an outer and an inner polygon (same vertex count):
## outer walls y0..y1, a flat top ring, and the hole's walls down to floor_y.
static func _frame(mb: ProcMesh.Builder, mat: String, outer: PackedVector2Array, inner: PackedVector2Array, y0: float,
		y1: float, floor_y: float, bevel: float, xf := Transform3D.IDENTITY) -> void:
	var to := _walls(mb, mat, outer, y0, y1, bevel, xf)
	var ti := _walls(mb, mat, inner, floor_y, y1, bevel * 0.7, xf, true)
	var n := outer.size()
	for i in n:
		mb.quad(mat, xf * _v(to[i], y1), xf * _v(to[(i + 1) % n], y1), xf * _v(ti[(i + 1) % n], y1), xf * _v(ti[i], y1),
			xf.basis * Vector3.UP)


## Lathe / loft around local Z of xf with smooth normals. profile: Vector2
## (r, z), walked from the back (+z) on the axis, out, forward and back to
## the axis at the front (-z); the front faces local -Z. section: 2D points
## (unit circle = lathe). smooth_around = round section; profile corners
## sharper than ~35 degrees stay hard.
static func _revolve(mb: ProcMesh.Builder, mat: String, profile: Array, section: Array, xf: Transform3D,
		smooth_around := true, mats := []) -> void:
	var ns := section.size()
	var segn := []
	for j in profile.size() - 1:
		var p0: Vector2 = profile[j]
		var p1: Vector2 = profile[j + 1]
		segn.append(Vector2(-(p1.y - p0.y), p1.x - p0.x).normalized())
	var hard := cos(deg_to_rad(35.0))
	for j in profile.size() - 1:
		var p0: Vector2 = profile[j]
		var p1: Vector2 = profile[j + 1]
		if p0.x <= 0.0 and p1.x <= 0.0:
			continue
		var m: String = mats[j] if j < mats.size() and mats[j] != "" else mat
		var sn: Vector2 = segn[j]
		var n0 := sn
		var n1 := sn
		if j > 0 and (segn[j - 1] as Vector2).dot(sn) > hard:
			n0 = ((segn[j - 1] as Vector2) + sn).normalized()
		if j < segn.size() - 1 and (segn[j + 1] as Vector2).dot(sn) > hard:
			n1 = ((segn[j + 1] as Vector2) + sn).normalized()
		for i in ns:
			var s0: Vector2 = section[i]
			var s1: Vector2 = section[(i + 1) % ns]
			var a := xf * Vector3(s0.x * p0.x, s0.y * p0.x, p0.y)
			var b := xf * Vector3(s1.x * p0.x, s1.y * p0.x, p0.y)
			var c := xf * Vector3(s1.x * p1.x, s1.y * p1.x, p1.y)
			var d := xf * Vector3(s0.x * p1.x, s0.y * p1.x, p1.y)
			if smooth_around:
				var d0 := s0.normalized()
				var d1 := s1.normalized()
				_quad_n(mb, m, a, b, c, d,
					(xf.basis * Vector3(d0.x * n0.x, d0.y * n0.x, n0.y)).normalized(),
					(xf.basis * Vector3(d1.x * n0.x, d1.y * n0.x, n0.y)).normalized(),
					(xf.basis * Vector3(d1.x * n1.x, d1.y * n1.x, n1.y)).normalized(),
					(xf.basis * Vector3(d0.x * n1.x, d0.y * n1.x, n1.y)).normalized())
			else:
				var dm := ((s0 + s1) * 0.5).normalized()
				mb.quad(m, a, b, c, d, xf.basis * Vector3(dm.x * sn.x, dm.y * sn.x, sn.y))


## xf whose local -Z (a revolve's front) points along `front`.
static func _axis(origin: Vector3, front: Vector3) -> Transform3D:
	var up := Vector3.UP if absf(front.normalized().y) < 0.9 else Vector3.BACK
	return Transform3D(Basis.looking_at(front, up), origin)


## Plain cylinder (with small edge chamfers) from a to b.
static func _cyl(mb: ProcMesh.Builder, mat: String, a: Vector3, b: Vector3, r: float, segs: int, chamfer := 0.0) -> void:
	var l := a.distance_to(b)
	var c := minf(chamfer, minf(r * 0.4, l * 0.3))
	var prof := [Vector2(0, 0), Vector2(r - c, 0), Vector2(r, -c), Vector2(r, -l + c), Vector2(r - c, -l), Vector2(0, -l)]
	_revolve(mb, mat, prof, ProcMesh.circle(segs), _axis(a, b - a))


## Swept round tube through control points (Catmull-Rom), optional ribs
## (alternate rings raised by rib * radius), capped ends.
static func _tube(mb: ProcMesh.Builder, mat: String, pts: Array, radius: float, segs: int, step: float, rib := 0.0) -> void:
	var curve := Curve3D.new()
	curve.bake_interval = step
	for i in pts.size():
		var p: Vector3 = pts[i]
		var prev: Vector3 = pts[maxi(i - 1, 0)]
		var next: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var t := (next - prev) / 6.0
		curve.add_point(p, -t, t)
	var path := curve.get_baked_points()
	var count := path.size()
	if count < 2:
		return
	var tangents: Array[Vector3] = []
	for i in count:
		var t := path[mini(i + 1, count - 1)] - path[maxi(i - 1, 0)]
		tangents.append(t.normalized())
	# Parallel-transported frame.
	var nrm := tangents[0].cross(Vector3.UP if absf(tangents[0].y) < 0.9 else Vector3.RIGHT).normalized()
	var rings := []
	var normals := []
	for i in count:
		var t := tangents[i]
		nrm = (nrm - t * nrm.dot(t)).normalized()
		var bn := t.cross(nrm)
		var r := radius * (1.0 + (rib if i % 2 == 1 else 0.0))
		var ring := []
		var rn := []
		for k in segs:
			var ang := TAU * k / segs
			var dir := nrm * cos(ang) + bn * sin(ang)
			ring.append(path[i] + dir * r)
			rn.append(dir)
		rings.append(ring)
		normals.append(rn)
	for i in count - 1:
		for k in segs:
			var k1 := (k + 1) % segs
			_quad_n(mb, mat, rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k],
				normals[i][k], normals[i][k1], normals[i + 1][k1], normals[i + 1][k])
	for e in [0, count - 1]:
		var out: Vector3 = -tangents[0] if e == 0 else tangents[count - 1]
		for k in segs:
			mb.tri(mat, path[e], rings[e][k], rings[e][(k + 1) % segs], out)


## Point on a cylinder around the X axis; angle from +Y towards +Z.
static func _cp(x: float, r: float, a: float) -> Vector3:
	return Vector3(x, r * cos(a), r * sin(a))


## Cylindrical shell around the forearm (X axis): radii r0..r1, angles
## a0..a1 (full ring if the span is TAU), x0..x1. Smooth round surfaces,
## flat ends and side faces.
static func _shell(mb: ProcMesh.Builder, mat: String, r0: float, r1: float, a0: float, a1: float, x0: float, x1: float, segs: int) -> void:
	var full := is_equal_approx(a1 - a0, TAU)
	for i in segs:
		var aa := a0 + (a1 - a0) * i / segs
		var ab := a0 + (a1 - a0) * (i + 1) / segs
		var na := Vector3(0, cos(aa), sin(aa))
		var nb := Vector3(0, cos(ab), sin(ab))
		_quad_n(mb, mat, _cp(x0, r1, aa), _cp(x1, r1, aa), _cp(x1, r1, ab), _cp(x0, r1, ab), na, na, nb, nb)
		_quad_n(mb, mat, _cp(x0, r0, aa), _cp(x1, r0, aa), _cp(x1, r0, ab), _cp(x0, r0, ab), -na, -na, -nb, -nb)
		for e in [[x0, -1.0], [x1, 1.0]]:
			mb.quad(mat, _cp(e[0], r0, aa), _cp(e[0], r1, aa), _cp(e[0], r1, ab), _cp(e[0], r0, ab), Vector3(e[1], 0, 0))
	if not full:
		for e in [[a0, -1.0], [a1, 1.0]]:
			var a: float = e[0]
			var t: Vector3 = Vector3(0, -sin(a), cos(a)) * float(e[1])
			mb.quad(mat, _cp(x0, r0, a), _cp(x1, r0, a), _cp(x1, r1, a), _cp(x0, r1, a), t)


# ============================================================ FOREARM MOUNT

func _cuff_r() -> Vector2:
	return Vector2(arm_radius + 0.0006, arm_radius + 0.0046)


## Curved cuff shell the unit sits on: moulded, wraps ~250 degrees of the
## forearm (the underside is closed by the straps), raised rims at the ends.
func _build_cuff(g: Node3D) -> void:
	var mb := ProcMesh.Builder.new()
	var r := _cuff_r()
	var span := deg_to_rad(110.0)
	_shell(mb, "Cuff", r.x, r.y, -span, span, -0.106, 0.104, cuff_segments)
	for x in [[-0.106, -0.1025], [0.1005, 0.104]]:
		_shell(mb, "Cuff", r.y - 0.001, r.y + 0.0016, -span, span, x[0], x[1], cuff_segments)
	_part(g, "Cuff", mb)


## Thick ribbed rubber band hugging the hand end of the unit.
func _build_wrist_band(g: Node3D) -> void:
	var mb := ProcMesh.Builder.new()
	var r0 := arm_radius + 0.0004
	var r1 := arm_radius + 0.012
	var x0 := 0.1055
	var x1 := 0.128
	_shell(mb, "Rubber", r0, r1, 0.0, TAU, x0, x1, cuff_segments)
	# Edge lips.
	for x in [[x0, x0 + 0.0022], [x1 - 0.0022, x1]]:
		_shell(mb, "Rubber", r1 - 0.001, r1 + 0.0012, 0.0, TAU, x[0], x[1], cuff_segments)
	# Tread ribs running along the arm.
	var ribs := 44
	for i in ribs:
		var a := TAU * (i + 0.5) / ribs
		var n := Vector3(0, cos(a), sin(a))
		var xf := _frame_xf(n * r1, n, Vector3.RIGHT)
		_box(mb, "Rubber", Vector3((x0 + x1) * 0.5, 0.0013, 0), Vector3(x1 - x0 - 0.0056, 0.0034, 0.0032), 0.0007, xf)
	_part(g, "WristBand", mb)


## Woven webbing strap at the elbow end, with stitched edge ridges.
func _build_elbow_strap(g: Node3D) -> void:
	var mb := ProcMesh.Builder.new()
	var r0 := arm_radius + 0.0004
	var r1 := arm_radius + 0.0062
	var x0 := -0.131
	var x1 := -0.1075
	_shell(mb, "Webbing", r0, r1, 0.0, TAU, x0, x1, cuff_segments)
	for x in [x0 + 0.0015, x1 - 0.0035]:
		_shell(mb, "Webbing", r1 - 0.0005, r1 + 0.0007, 0.0, TAU, x, x + 0.002, cuff_segments)
	# Keeper loop on top.
	var xf := _frame_xf(Vector3(0, r1, 0), Vector3.UP)
	_box(mb, "Graphite", Vector3((x0 + x1) * 0.5, 0.0012, 0), Vector3(x1 - x0 + 0.003, 0.0026, 0.012), 0.0007, xf)
	_part(g, "ElbowStrap", mb)


## Webbing strap round the underside of the arm (between the two side
## brackets) with the steel buckle on the inner forearm.
func _build_center_strap(g: Node3D) -> void:
	var mb := ProcMesh.Builder.new()
	var r := _cuff_r()
	var r0 := r.y - 0.0004
	var r1 := r.y + 0.0026
	var x0 := 0.0245
	var x1 := 0.0375
	_shell(mb, "Webbing", r0, r1, deg_to_rad(76.0), deg_to_rad(284.0), x0, x1, cuff_segments)
	# Tail beyond the buckle (a second layer).
	_shell(mb, "Webbing", r1, r1 + 0.0024, deg_to_rad(206.0), deg_to_rad(246.0), x0 + 0.0005, x1 - 0.0005, 10)
	_part(g, "CenterStrap", mb)

	var bk := ProcMesh.Builder.new()
	var a := deg_to_rad(198.0)
	var n := Vector3(0, cos(a), sin(a))
	var xf := Transform3D(Basis(Vector3.RIGHT, n, Vector3.RIGHT.cross(n)), n * r1)
	var outer := _crect_c(0.031, 0, 0.0215, 0.017, 0.003)
	var inner := _crect_c(0.031, 0, 0.0155, 0.011, 0.0018)
	_frame(bk, "Steel", outer, inner, -0.0004, 0.0024, -0.0004, 0.0007, xf)
	_cap(bk, "Steel", outer, -0.0004, false, xf)
	# Centre bar and prong.
	_cyl(bk, "Steel", xf * Vector3(0.0225, 0.0012, 0), xf * Vector3(0.0395, 0.0012, 0), 0.0011, 10)
	_box(bk, "Steel", Vector3(0.031, 0.0026, -0.003), Vector3(0.0018, 0.0012, 0.0068), 0.0004, xf)
	_part(g, "Buckle", bk)


# ================================================================ HOUSING

## Graphite saddle that fills the gap between the flat-bottomed housing
## and the curved cuff, plus the cream main body, the sloped olive-latch
## end block, the side skirts and the taller control block.
func _build_housing(g: Node3D) -> void:
	var dy := arm_radius - DESIGN_ARM_R
	var cr := _cuff_r().y - 0.0006
	# Saddle profile (z, y) in Unit space: flat top, vertical sides, the
	# bottom following the cuff.
	var sad := ProcMesh.Builder.new()
	var prof := PackedVector2Array([Vector2(-0.047, 0.0545), Vector2(0.047, 0.0545), Vector2(0.047, 0.03)])
	var a_side := deg_to_rad(64.0)
	var steps := 14
	for i in steps + 1:
		var a := a_side - 2.0 * a_side * i / steps
		prof.append(Vector2(cr * sin(a), cr * cos(a) - dy))
	prof.append(Vector2(-0.047, 0.03))
	_prism(sad, "Graphite", prof, -0.097, 0.099, 0.0, XF_ALONG_X)
	_part(g, "Saddle", sad)

	var body := ProcMesh.Builder.new()
	_prism(body, "Cream", _crect(-0.09, -0.052, 0.052, 0.049, 0.006), 0.052, 0.0665, 0.0018)
	_part(g, "MainBody", body)

	# End block at the elbow end: flat top, a steep chamfer down towards
	# the elbow (profile in x, y; extruded across z).
	var lb := ProcMesh.Builder.new()
	var lp := PackedVector2Array([Vector2(-0.074, 0.044), Vector2(-0.074, 0.0685), Vector2(-0.0955, 0.0685),
		Vector2(-0.1045, 0.0595), Vector2(-0.1045, 0.044)])
	_prism(lb, "Cream", lp, -0.0505, 0.0465, 0.0015, XF_ALONG_Z, true, 0.0015)
	_part(g, "EndBlock", lb)

	# Lower deck / skirt along the +Z edge (carries the piston and cable).
	var deck := ProcMesh.Builder.new()
	_prism(deck, "Cream", _crect(-0.1005, 0.045, 0.051, 0.0645, 0.004), 0.024, 0.0565, 0.0016, Transform3D.IDENTITY, true, 0.001)
	_part(g, "LowerDeck", deck)

	# Graphite skirt along the -Z edge (carries the handle rail brackets).
	var sk := ProcMesh.Builder.new()
	_prism(sk, "Graphite", _crect(-0.074, -0.0578, 0.05, -0.05, 0.002), 0.034, 0.0635, 0.0012, Transform3D.IDENTITY, true, 0.0008)
	_part(g, "SideSkirt", sk)

	# Control block at the hand end, a little taller than the main body.
	var cb := ProcMesh.Builder.new()
	_prism(cb, "Cream", _crect(0.05, -0.054, 0.102, 0.052, 0.006), 0.05, 0.0705, 0.0018)
	_part(g, "ControlBody", cb)

	# Olive side rail on the hand end.
	var rail := ProcMesh.Builder.new()
	_prism(rail, "Olive", _crect(0.0985, -0.048, 0.1045, 0.044, 0.0028), 0.052, 0.0735, 0.0012, Transform3D.IDENTITY, true, 0.0008)
	_part(g, "SideRail", rail)

	_screw(Vector3(-0.094, 0.0565, 0.0645 + 0.0001), Vector3.BACK)
	_screw(Vector3(-0.094, 0.030, 0.0645 + 0.0001), Vector3.BACK)
	_screw(Vector3(0.044, 0.030, 0.0645 + 0.0001), Vector3.BACK)
	_screw(Vector3(0.0035, 0.033, 0.0645 + 0.0001), Vector3.BACK)
	_screw(Vector3(0.1015, 0.0735, -0.0435), Vector3.UP)
	_screw(Vector3(0.1015, 0.0735, 0.0395), Vector3.UP)
	_screw(Vector3(0.1015, 0.0735, -0.002), Vector3.UP)
	_screw(Vector3(-0.0985, 0.0685, -0.046), Vector3.UP)
	_screw(Vector3(-0.0985, 0.0685, 0.0425), Vector3.UP)
	var slope := Vector3(-1, 1, 0).normalized()
	for z in [-0.04, 0.0, 0.04]:
		_screw(Vector3(-0.1, 0.064, z) + slope * 0.0001, slope)
	for x in [-0.06, -0.02, 0.02]:
		_screw(Vector3(x, 0.0565, 0.06), Vector3.UP)


# ================================================================= SCREEN

## Thick two-step graphite bezel with chamfered corners around a recessed
## blank display.
func _build_screen(g: Node3D) -> void:
	var outer := _crect(-0.0725, -0.0445, 0.0485, 0.0385, 0.012)
	var mid := _crect(-0.0665, -0.0385, 0.0425, 0.0325, 0.0095)
	var inner := _crect(-0.0625, -0.0345, 0.0385, 0.0285, 0.0078)
	var mb := ProcMesh.Builder.new()
	_frame(mb, "Graphite", outer, mid, 0.062, 0.0758, 0.0732, 0.0012)
	_frame(mb, "Graphite", mid, inner, 0.066, 0.0732, 0.0700, 0.0007)
	# Hinge tabs on the +Z edge, and a corner block on the -Z/elbow corner.
	for x in [-0.036, 0.016]:
		_box(mb, "Graphite", Vector3(x, 0.0675, 0.040), Vector3(0.009, 0.010, 0.006), 0.0012)
		_cyl(mb, "Steel", Vector3(x - 0.0055, 0.0655, 0.0428), Vector3(x + 0.0055, 0.0655, 0.0428), 0.0016, 10, 0.0003)
	_part(g, "Bezel", mb)

	var disp := MeshInstance3D.new()
	disp.name = "Display"
	disp.mesh = _display_mesh(inner, 0.0702)
	disp.material_override = _mats["Display"]
	g.add_child(disp)

	# Screws round the outer frame.
	var ring := _inset(outer, 0.0031)
	for i in [0, 2, 4, 6]:
		var p := (ring[i] + ring[(i + 1) % 8]) * 0.5
		_screw(_v(p, 0.0758), Vector3.UP, 0.3 * i)
	for p in [Vector2(-0.012, -0.0414), Vector2(-0.012, 0.0354)]:
		_screw(_v(p, 0.0758), Vector3.UP, 0.7)


## Flat display polygon with 0..1 UVs (u along +X, v along +Z).
func _display_mesh(poly: PackedVector2Array, y: float) -> ArrayMesh:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(poly)
	for t in range(0, idx.size(), 3):
		var a := _v(poly[idx[t]], y)
		var b := _v(poly[idx[t + 1]], y)
		var c := _v(poly[idx[t + 2]], y)
		if (b - a).cross(c - a).y < 0.0:
			var tmp := b
			b = c
			c = tmp
		for v in [a, c, b]:
			var p: Vector3 = v
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2((p.x - lo.x) / (hi.x - lo.x), (p.z - lo.y) / (hi.y - lo.y)))
			st.add_vertex(p)
	st.generate_tangents()
	return st.commit()


# =========================================================== LATCH PANEL

## Olive plate on the elbow end block: a recessed slot with a raised bar,
## and the small amber latch.
func _build_latch_panel(g: Node3D) -> void:
	var mb := ProcMesh.Builder.new()
	_prism(mb, "Olive", _crect(-0.0945, -0.0425, -0.0765, 0.0365, 0.003), 0.0675, 0.0705, 0.001)
	var so := _crect(-0.0905, -0.034, -0.0805, 0.0065, 0.0022)
	var si := _inset(so, 0.0018)
	_frame(mb, "Graphite", so, si, 0.0698, 0.0728, 0.0712, 0.0006)
	_cap(mb, "DarkMetal", si, 0.0712, true, Transform3D.IDENTITY)
	_prism(mb, "Olive", _crect(-0.0882, -0.0305, -0.0828, 0.003, 0.0016), 0.071, 0.0736, 0.0007)
	_part(g, "OlivePanel", mb)

	var lt := ProcMesh.Builder.new()
	_box(lt, "Amber", Vector3(-0.0855, 0.0722, 0.0185), Vector3(0.0065, 0.0045, 0.0085), 0.0009)
	_box(lt, "DarkMetal", Vector3(-0.0855, 0.0745, 0.0185), Vector3(0.0028, 0.0004, 0.0045), 0.0)
	_part(g, "AmberLatch", lt)

	for p in [Vector2(-0.0925, -0.0405), Vector2(-0.0785, -0.0405), Vector2(-0.0925, 0.0345), Vector2(-0.0785, 0.0345)]:
		_screw(_v(p, 0.0705), Vector3.UP)


# ============================================================== CONTROLS

## Control block top: amber bar, olive panel with the green status lamp,
## two square push buttons and the ribbed rotary knob.
func _build_controls(g: Node3D) -> void:
	var mb := ProcMesh.Builder.new()
	_prism(mb, "Amber", _crect(0.0535, -0.0425, 0.0595, -0.0035, 0.0026), 0.0695, 0.0748, 0.0012)
	_prism(mb, "Olive", _crect(0.0615, -0.034, 0.0975, 0.0205, 0.003), 0.0698, 0.0728, 0.001)
	# Lamp housing.
	var lo := _crect(0.0695, -0.0312, 0.0895, -0.0222, 0.0012)
	var li := _inset(lo, 0.0014)
	_frame(mb, "Graphite", lo, li, 0.0724, 0.0746, 0.0734, 0.0005)
	# Button bezels.
	for z in [-0.0128, -0.0018]:
		var bo := _crect_c(0.0661, z, 0.0088, 0.0088, 0.0012)
		var bi := _inset(bo, 0.0013)
		_frame(mb, "Graphite", bo, bi, 0.0724, 0.0741, 0.0729, 0.0005)
		_cap(mb, "DarkMetal", bi, 0.0729, true, Transform3D.IDENTITY)
	_part(g, "Panel", mb)

	var led := ProcMesh.Builder.new()
	_prism(led, "LedOn", _inset(li, 0.0002), 0.0730, 0.0739, 0.0003)
	var led_mi := _part(g, "StatusLamp", led)
	led_mi.set_meta("lamp", true)

	_button_a = _make_button(g, "ButtonA", Vector3(0.0661, 0.0729, -0.0128), "Rubber")
	_button_b = _make_button(g, "ButtonB", Vector3(0.0661, 0.0729, -0.0018), "Amber")
	_build_knob(g)

	for p in [Vector2(0.064, -0.0315), Vector2(0.095, -0.0315), Vector2(0.064, 0.018), Vector2(0.095, 0.018)]:
		_screw(_v(p, 0.0728), Vector3.UP)
	for p in [Vector2(0.0565, 0.0062), Vector2(0.0565, 0.0485), Vector2(0.0565, -0.0505)]:
		_screw(_v(p, 0.0705), Vector3.UP)


func _make_button(g: Node3D, name: String, at: Vector3, mat: String) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = name
	pivot.position = at
	g.add_child(pivot)
	var mb := ProcMesh.Builder.new()
	_prism(mb, mat, _crect_c(0, 0, 0.0059, 0.0059, 0.0009), -0.0006, 0.0024, 0.0008)
	_part(pivot, "Cap", mb)
	return pivot


## Ribbed rubber knob on a graphite collar with a steel cap and pointer.
## The "Knob" node turns about its local Y (knob_angle).
func _build_knob(g: Node3D) -> void:
	var collar := ProcMesh.Builder.new()
	var up := _axis(Vector3.ZERO, Vector3.UP)
	_revolve(collar, "Graphite", [Vector2(0, 0.0004), Vector2(0.0109, 0.0004), Vector2(0.0109, -0.0010),
		Vector2(0.0101, -0.0018), Vector2(0, -0.0018)], ProcMesh.circle(round_segments * 2), up)
	var cmi := _part(g, "KnobCollar", collar)
	cmi.position = Vector3(0.0855, 0.0728, -0.006)

	_knob = Node3D.new()
	_knob.name = "Knob"
	_knob.position = Vector3(0.0855, 0.0745, -0.006)
	g.add_child(_knob)
	var mb := ProcMesh.Builder.new()
	var ribs := 30
	var star := []
	for i in ribs * 2:
		var a := TAU * i / (ribs * 2)
		var r := 1.0 if i % 2 == 0 else 0.92
		star.append(Vector2(cos(a), sin(a)) * r)
	_revolve(mb, "Rubber", [Vector2(0, 0.0003), Vector2(0.0094, 0.0003), Vector2(0.0094, -0.0060),
		Vector2(0.0086, -0.0072), Vector2(0, -0.0072)], star, up, false)
	# Steel cap, slightly dished, with a raised rim.
	_revolve(mb, "Graphite", [Vector2(0, -0.0068), Vector2(0.0079, -0.0068), Vector2(0.0079, -0.0079),
		Vector2(0.0074, -0.0083), Vector2(0.0068, -0.0081), Vector2(0, -0.0078)], ProcMesh.circle(round_segments * 2), up)
	_box(mb, "Steel", Vector3(0, 0.0081, -0.0045), Vector3(0.0011, 0.0006, 0.0048), 0.0002)
	_part(_knob, "Grip", mb)


# ================================================================== VENT

## Louvred vent on the -Z corner of the control block.
func _build_vent(g: Node3D) -> void:
	var mb := ProcMesh.Builder.new()
	var vo := _crect(0.069, -0.0515, 0.0965, -0.0375, 0.0022)
	var vi := _inset(vo, 0.0021)
	_frame(mb, "Graphite", vo, vi, 0.0698, 0.0742, 0.0708, 0.0007)
	_cap(mb, "Hole", vi, 0.0708, true, Transform3D.IDENTITY)
	var n := 7
	var x0 := 0.0715
	var x1 := 0.094
	for i in n:
		var x := lerpf(x0, x1, (i + 0.5) / n)
		var xf := Transform3D(Basis(Vector3.BACK, deg_to_rad(-35.0)), Vector3(x, 0.0725, -0.0445))
		_box(mb, "Graphite", Vector3.ZERO, Vector3(0.0009, 0.0034, 0.0098), 0.0002, xf)
	_part(g, "Louvres", mb)


# ============================================================== BRACKETS

## Handle rail along the -Z edge, the D-ring carry handle with hinges, and
## the strap guide brackets on both sides.
func _build_brackets(g: Node3D) -> void:
	var seg := maxi(round_segments / 2, 8)
	var rail := ProcMesh.Builder.new()
	_tube(rail, "Graphite", [Vector3(-0.0972, 0.0525, -0.053), Vector3(-0.0975, 0.066, -0.0545),
		Vector3(-0.0962, 0.0738, -0.0555), Vector3(-0.091, 0.0762, -0.0558), Vector3(-0.08, 0.0764, -0.0558),
		Vector3(-0.04, 0.0764, -0.0558), Vector3(0.012, 0.0764, -0.0558)], 0.0023, seg, 0.003)
	_box(rail, "Graphite", Vector3(-0.0972, 0.0505, -0.0527), Vector3(0.0072, 0.006, 0.006), 0.001)
	for x in [-0.07, -0.028, 0.0115]:
		_box(rail, "Graphite", Vector3(x, 0.0705, -0.0556), Vector3(0.0072, 0.0125, 0.0066), 0.0012)
		_screw(Vector3(x, 0.0675, -0.0589), Vector3.FORWARD)
	_part(g, "HandleRail", rail)

	# D-ring: two hinge knuckles on a base plate, a bent steel loop with an
	# amber grip sleeve.
	var dr := ProcMesh.Builder.new()
	_box(dr, "Graphite", Vector3(0.0555, 0.0712, -0.0528), Vector3(0.031, 0.0045, 0.0085), 0.0009)
	for x in [[0.0415, 0.0485], [0.0625, 0.0695]]:
		_cyl(dr, "Graphite", Vector3(x[0], 0.0748, -0.0545), Vector3(x[1], 0.0748, -0.0545), 0.0028, seg, 0.0005)
	_cyl(dr, "Steel", Vector3(0.0405, 0.0748, -0.0545), Vector3(0.0705, 0.0748, -0.0545), 0.0012, 8)
	var loop := [Vector3(0.0452, 0.0748, -0.0545), Vector3(0.0452, 0.0782, -0.0612), Vector3(0.0472, 0.0806, -0.0672),
		Vector3(0.0515, 0.0815, -0.0694), Vector3(0.0595, 0.0815, -0.0694), Vector3(0.0638, 0.0806, -0.0672),
		Vector3(0.0658, 0.0782, -0.0612), Vector3(0.0658, 0.0748, -0.0545)]
	_tube(dr, "Steel", loop, 0.0021, seg, 0.0025)
	_cyl(dr, "Amber", Vector3(0.0508, 0.0815, -0.0694), Vector3(0.0602, 0.0815, -0.0694), 0.0029, seg, 0.0006)
	_part(g, "DRing", dr)
	_screw(Vector3(0.044, 0.0735, -0.0505), Vector3.UP)
	_screw(Vector3(0.067, 0.0735, -0.0505), Vector3.UP)

	# Strap guides: a cream bracket down the +Z side, a graphite one on -Z,
	# each with a foot that turns in to meet the centre strap.
	var sb := ProcMesh.Builder.new()
	var r := _cuff_r()
	var foot_y := r.y * cos(deg_to_rad(76.0)) - (arm_radius - DESIGN_ARM_R)
	_box(sb, "Cream", Vector3(0.031, 0.0335, 0.0662), Vector3(0.0145, 0.051, 0.0034), 0.0008)
	_box(sb, "Cream", Vector3(0.031, 0.0577, 0.0578), Vector3(0.0145, 0.0034, 0.0168), 0.0008)
	_box(sb, "Cream", Vector3(0.031, foot_y + 0.0003, 0.0563), Vector3(0.0145, 0.0034, 0.0222), 0.0008)
	_box(sb, "Graphite", Vector3(0.031, 0.0225, -0.0596), Vector3(0.0145, 0.0420, 0.0034), 0.0008)
	_box(sb, "Graphite", Vector3(0.031, foot_y + 0.0003, -0.0525), Vector3(0.0145, 0.0034, 0.0175), 0.0008)
	_part(g, "StrapBrackets", sb)
	_screw(Vector3(0.031, 0.051, 0.0679), Vector3.BACK)
	_screw(Vector3(0.031, 0.017, 0.0679), Vector3.BACK)
	_screw(Vector3(0.031, 0.036, -0.0613), Vector3.FORWARD)


# ================================================================ PISTON

## Hydraulic-style damper on the +Z deck: sleeve in two clamp rings, a
## polished rod into an eye block. The cable feeds its elbow end.
func _build_piston(g: Node3D) -> void:
	var seg := maxi(round_segments, 10)
	var y := 0.0612
	var z := 0.0566
	var mb := ProcMesh.Builder.new()
	_cyl(mb, "Graphite", Vector3(-0.036, y, z), Vector3(0.011, y, z), 0.0042, seg, 0.0008)
	_cyl(mb, "Steel", Vector3(0.011, y, z), Vector3(0.0355, y, z), 0.0021, seg, 0.0003)
	_cyl(mb, "Graphite", Vector3(0.0105, y, z), Vector3(0.0135, y, z), 0.0046, seg, 0.0004)
	_cyl(mb, "Graphite", Vector3(-0.0385, y, z), Vector3(-0.0355, y, z), 0.0034, seg, 0.0004)
	for x in [-0.028, 0.002]:
		_cyl(mb, "Cream", Vector3(x - 0.0025, y, z), Vector3(x + 0.0025, y, z), 0.0056, seg, 0.0007)
		_box(mb, "Cream", Vector3(x, 0.0572, z), Vector3(0.005, 0.003, 0.009), 0.0006)
	_box(mb, "Graphite", Vector3(0.039, 0.0605, z), Vector3(0.0075, 0.0095, 0.0085), 0.0012)
	_cyl(mb, "Steel", Vector3(0.039, y, z - 0.0052), Vector3(0.039, y, z + 0.0052), 0.0014, 10)
	_part(g, "Damper", mb)


# ================================================================== PORTS

## DB-15 data port on the -Z face of the elbow end block, behind a flip
## cover hinged at its lower edge ("PortCover" turns about X).
func _build_port(g: Node3D) -> void:
	var cx := -0.0855
	var face := -0.0505
	var mb := ProcMesh.Builder.new()
	# Raised boss on the side of the end block.
	var bo := _crect_c(cx, 0.0565, 0.0175, 0.0125, 0.0018)
	_prism(mb, "Graphite", bo, -face - 0.0001, -face + 0.0026, 0.0007, Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3.ZERO))
	# D-shaped shell: trapezoid frame standing out of the boss, dark inside.
	var tf := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3.ZERO)
	var so := PackedVector2Array([Vector2(cx - 0.0062, 0.0587), Vector2(cx + 0.0062, 0.0587),
		Vector2(cx + 0.0052, 0.0541), Vector2(cx - 0.0052, 0.0541)])
	var si := _inset(so, 0.0007)
	_frame(mb, "Steel", so, si, -face + 0.0020, -face + 0.0042, -face + 0.0024, 0.0003, tf)
	_cap(mb, "Hole", si, -face + 0.0024, true, tf)
	# Pin sockets: 8 over 7.
	for row in 2:
		var cnt := 8 if row == 0 else 7
		var py := 0.0573 if row == 0 else 0.0555
		for i in cnt:
			var px := cx + (i - (cnt - 1) * 0.5) * 0.0011
			_box(mb, "Steel", Vector3(px, -face + 0.0028, py), Vector3(0.0005, 0.0008, 0.0005), 0.0, tf)
	_part(g, "DataPort", mb)
	_screw(Vector3(cx - 0.0072, 0.0605, face - 0.0026), Vector3.FORWARD)
	_screw(Vector3(cx + 0.0072, 0.0605, face - 0.0026), Vector3.FORWARD)

	# Flip cover. Pivot on the hinge line below the port.
	_cover = Node3D.new()
	_cover.name = "PortCover"
	_cover.position = Vector3(cx, 0.0503, face - 0.0047)
	g.add_child(_cover)
	var cv := ProcMesh.Builder.new()
	var cf := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3.ZERO)
	_prism(cv, "Graphite", _crect_c(0, 0.0072, 0.0165, 0.0122, 0.0016), -0.0003, 0.0019, 0.0006, cf)
	_prism(cv, "Cream", _crect_c(0, 0.0074, 0.0105, 0.0066, 0.001), 0.0018, 0.0026, 0.0003, cf)
	_cyl(cv, "Steel", Vector3(-0.0085, 0.0005, 0.0006), Vector3(0.0085, 0.0005, 0.0006), 0.0013, 10)
	_box(cv, "Graphite", Vector3(0, 0.0128, -0.0012), Vector3(0.006, 0.0012, 0.0026), 0.0003)
	_part(_cover, "Lid", cv)
	var hinge := ProcMesh.Builder.new()
	for x in [[cx - 0.0088, cx - 0.0062], [cx + 0.0062, cx + 0.0088]]:
		_cyl(hinge, "Graphite", Vector3(x[0], 0.0503, face - 0.0036), Vector3(x[1], 0.0503, face - 0.0036), 0.0016, 10)
	_part(g, "CoverHinge", hinge)


# ================================================================= CABLES

## Braided copper cable: out of a hex fitting on the elbow end of the +Z
## skirt, looping down and forward into the damper's elbow end.
func _build_cable(g: Node3D) -> void:
	var seg := maxi(round_segments / 2, 8)
	var fit := ProcMesh.Builder.new()
	var at := Vector3(-0.0815, 0.040, 0.0645)
	_revolve(fit, "Graphite", [Vector2(0, 0.0), Vector2(0.0058, 0.0), Vector2(0.0058, -0.0032), Vector2(0.0052, -0.0038),
		Vector2(0, -0.0038)], ProcMesh.circle(6), _axis(at, Vector3.BACK), false)
	_revolve(fit, "Steel", [Vector2(0, -0.0035), Vector2(0.0042, -0.0035), Vector2(0.0042, -0.0062),
		Vector2(0.0034, -0.0072), Vector2(0.0024, -0.0075), Vector2(0, -0.0075)], ProcMesh.circle(seg), _axis(at, Vector3.BACK))
	# Ferrule where the cable enters the damper.
	_cyl(fit, "Steel", Vector3(-0.0432, 0.0612, 0.0566), Vector3(-0.0385, 0.0612, 0.0566), 0.0034, seg, 0.0005)
	_part(g, "Fittings", fit)

	var mb := ProcMesh.Builder.new()
	var pts := [Vector3(-0.0815, 0.0398, 0.0715), Vector3(-0.0812, 0.0350, 0.0758), Vector3(-0.0770, 0.0262, 0.0776),
		Vector3(-0.0680, 0.0210, 0.0765), Vector3(-0.0570, 0.0235, 0.0745), Vector3(-0.0490, 0.0335, 0.0710),
		Vector3(-0.0455, 0.0480, 0.0650), Vector3(-0.0448, 0.0585, 0.0590), Vector3(-0.0430, 0.0612, 0.0566)]
	_tube(mb, "Copper", pts, 0.0036, seg, 0.0017, 0.14)
	_part(g, "Cable", mb)


# ================================================================= LABELS

## "USHIDA / FIELD UNIT G-07" and the orange stripe on the control block.
func _build_labels(g: Node3D) -> void:
	var stripe := ProcMesh.Builder.new()
	var sp := PackedVector2Array([Vector2(0.0575, 0.0448), Vector2(0.0955, 0.0448), Vector2(0.0965, 0.0476), Vector2(0.0585, 0.0476)])
	_prism(stripe, "Orange", sp, 0.0702, 0.0708, 0.0)
	_part(g, "Stripe", stripe)
	_label(g, "Brand", "USHIDA", Vector3(0.0775, 0.07065, 0.0312), 0.000085, 96)
	_label(g, "Model", "FIELD UNIT G-07", Vector3(0.0775, 0.07065, 0.0392), 0.000036, 96)


func _label(g: Node3D, name: String, text: String, at: Vector3, pixel: float, size: int) -> void:
	var l := Label3D.new()
	l.name = name
	l.text = text
	l.font_size = size
	l.pixel_size = pixel
	l.outline_size = 0
	l.modulate = Color(0.14, 0.12, 0.1)
	l.shaded = true
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	l.position = at
	l.rotation = Vector3(-PI / 2, 0, 0)
	g.add_child(l)


# ================================================================= SCREWS

## Every screw head is one MultiMesh instance of a single domed, slotted
## head mesh.
func _build_screws(parent: Node3D) -> void:
	var mb := ProcMesh.Builder.new()
	var up := _axis(Vector3.ZERO, Vector3.UP)
	_revolve(mb, "Steel", [Vector2(0, 0.0002), Vector2(0.0017, 0.0002), Vector2(0.0017, -0.0004),
		Vector2(0.0013, -0.0009), Vector2(0.0006, -0.0011), Vector2(0, -0.0011)], ProcMesh.circle(maxi(round_segments / 2, 8)), up)
	_box(mb, "Hole", Vector3(0, 0.00095, 0), Vector3(0.0028, 0.0004, 0.00045), 0.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mb.commit(_mats)
	mm.instance_count = _screws.size()
	for i in _screws.size():
		mm.set_instance_transform(i, _screws[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Screws"
	mmi.multimesh = mm
	parent.add_child(mmi)


# ============================================================ LIVE CONTROLS

func _pose_controls() -> void:
	if _knob and is_instance_valid(_knob):
		_knob.rotation.y = deg_to_rad(knob_angle)
	if _button_a and is_instance_valid(_button_a):
		_button_a.position.y = 0.0729 - BUTTON_TRAVEL * button_a_pressed
	if _button_b and is_instance_valid(_button_b):
		_button_b.position.y = 0.0729 - BUTTON_TRAVEL * button_b_pressed
	if _cover and is_instance_valid(_cover):
		_cover.rotation.x = -deg_to_rad(105.0) * port_cover_open


func _update_indicator() -> void:
	var lamp := find_child("StatusLamp", true, false) as MeshInstance3D
	if lamp:
		lamp.material_override = null if indicator_on else _mats.get("LedOff")
