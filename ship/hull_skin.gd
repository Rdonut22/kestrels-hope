class_name HullSkin
extends RefCounted

## Outer skin for a boxy hull section, in the style of the marauder fuselage:
## raised plates of varied size with grooves between them (the darker hull
## shows through), long horizontal grooves splitting the walls into bands,
## thicker armour plates, and recessed hatches with vent slats. The roof gets
## the same treatment plus a raised spine.
##
## Walls follow a footprint path (x, z) that may include a rounded corner;
## plates sit just outside the path (outward = away from `centre`).
## All geometry is built in code; materials are applied by the caller.

const GAP := 0.08          # groove width between plates
const BASE := 0.01         # plates start this far out from the wall

var _st := SurfaceTool.new()
var _rng := RandomNumberGenerator.new()


## path: footprint points in order (x, z). bands: wall bands [y0, y1].
## roof: Rect2 (x, z) of the roof, roof_y its height; corner (centre, radius)
## of a rounded corner to keep roof plates inside (radius 0 = none).
func build(path: PackedVector2Array, centre: Vector2, bands: Array, roof: Rect2, roof_y: float,
		corner_c: Vector2, corner_r: float, seed := 1) -> ArrayMesh:
	_rng.seed = seed
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Flat shading; faces may wind either way (the paint shader is two-sided
	# and flips back-facing normals).
	_st.set_smooth_group(-1)
	var lens := _lengths(path)
	var total: float = lens[lens.size() - 1]
	# Three bands like the fuselage's side: a belly tucked in underneath, a
	# deep middle band of plates, and an upper band leaning in to the roof.
	# A heavy belt ledge and a shoulder rim mark the two strong lines.
	var b0: Array = bands[0]
	var b1: Array = bands[1]
	var b2: Array = bands[2]
	_wall_slab(path, lens, centre, 0.0, total, b0[0], b0[1], 0.05, 0.42)
	var belt_y: float = (b0[1] + b1[0]) * 0.5
	_wall_slab(path, lens, centre, 0.0, total, belt_y - 0.16, belt_y + 0.16, 0.62)
	var s := 0.0
	while s < total - 0.5:
		var w := _rng.randf_range(1.8, 4.5)
		var s1 := minf(s + w, total)
		if total - s1 < 1.0:
			s1 = total
		_wall_panel(path, lens, centre, s + GAP * 0.5, s1 - GAP * 0.5, b1[0], b1[1])
		s = s1
	_wall_slab(path, lens, centre, 0.0, total, b2[0], b2[1], 0.5, 0.06)
	_wall_slab(path, lens, centre, 0.0, total, b2[0] - 0.1, b2[0] + 0.06, 0.58)
	_roof(roof, roof_y, corner_c, corner_r)
	_st.generate_normals()
	return _st.commit()


func _wall_panel(path: PackedVector2Array, lens: PackedFloat32Array, centre: Vector2,
		s0: float, s1: float, y0: float, y1: float) -> void:
	var kind := _rng.randf()
	if kind < 0.18 and y1 - y0 > 1.2 and s1 - s0 > 1.8:
		# Recessed hatch: a frame of thin plates around a sunken centre with slats.
		var fw := 0.25
		var t := 0.5
		_wall_slab(path, lens, centre, s0, s1, y1 - fw, y1, t)
		_wall_slab(path, lens, centre, s0, s1, y0, y0 + fw, t)
		_wall_slab(path, lens, centre, s0, s0 + fw, y0 + fw, y1 - fw, t)
		_wall_slab(path, lens, centre, s1 - fw, s1, y0 + fw, y1 - fw, t)
		_wall_slab(path, lens, centre, s0 + fw, s1 - fw, y0 + fw, y1 - fw, 0.12)
		var slats := int((y1 - y0 - 2.0 * fw) / 0.22)
		for i in slats:
			var y := y0 + fw + 0.11 + i * 0.22
			_wall_slab(path, lens, centre, s0 + fw + 0.15, s1 - fw - 0.15, y, y + 0.08, 0.3, 0.2)
	elif kind < 0.3:
		# Sunken plate: barely raised, so it reads as a recess between its neighbours.
		_wall_slab(path, lens, centre, s0, s1, y0, y1, 0.2)
	elif kind < 0.5:
		# Thick armour plate.
		_wall_slab(path, lens, centre, s0, s1, y0, y1, _rng.randf_range(0.6, 0.75), _rng.randf_range(0.5, 0.6))
	else:
		_wall_slab(path, lens, centre, s0, s1, y0, y1, _rng.randf_range(0.38, 0.48))
		# Now and then a small raised access plate on top of it.
		if _rng.randf() < 0.3 and s1 - s0 > 1.4 and y1 - y0 > 0.9:
			var a := lerpf(s0, s1, _rng.randf_range(0.15, 0.45))
			var b := a + minf(_rng.randf_range(0.6, 1.2), s1 - a - 0.15)
			var ya := lerpf(y0, y1, 0.25)
			_wall_slab(path, lens, centre, a, b, ya, ya + (y1 - y0) * 0.45, 0.62)


## A plate on the wall from path distance s0 to s1, height y0..y1, standing
## out `t` metres (following any curve in the path).
func _wall_slab(path: PackedVector2Array, lens: PackedFloat32Array, centre: Vector2,
		s0: float, s1: float, y0: float, y1: float, t: float, t_top := -1.0) -> void:
	# The face leans when t_top differs from t (t at y0, t_top at y1).
	var t1 := t if t_top < 0.0 else t_top
	if s1 - s0 < 0.05 or y1 - y0 < 0.02:
		return
	var pts: Array[Vector2] = []
	var nrm: Array[Vector2] = []
	pts.append(_at(path, lens, s0))
	for i in range(1, path.size() - 1):
		if lens[i] > s0 and lens[i] < s1:
			pts.append(path[i])
	pts.append(_at(path, lens, s1))
	for i in pts.size():
		var d := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n := Vector2(-d.y, d.x)
		if n.dot(pts[i] - centre) < 0.0:
			n = -n
		nrm.append(n)
	var inner: Array[Vector3] = []
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	for i in pts.size():
		var p := pts[i] + nrm[i] * BASE
		var a := pts[i] + nrm[i] * (BASE + t)
		var b := pts[i] + nrm[i] * (BASE + t1)
		inner.append(Vector3(p.x, 0, p.y))
		lo.append(Vector3(a.x, y0, a.y))
		hi.append(Vector3(b.x, y1, b.y))
	var up := Vector3.UP
	for i in pts.size() - 1:
		# Front face (may lean), top and bottom edges.
		_quad(lo[i], lo[i + 1], hi[i + 1], hi[i])
		_quad(inner[i] + up * y1, hi[i], hi[i + 1], inner[i + 1] + up * y1)
		_quad(inner[i + 1] + up * y0, lo[i + 1], lo[i], inner[i] + up * y0)
	var last := pts.size() - 1
	_quad(inner[0] + up * y0, lo[0], hi[0], inner[0] + up * y1)
	_quad(lo[last], inner[last] + up * y0, inner[last] + up * y1, hi[last])


func _roof(r: Rect2, y: float, cc: Vector2, cr: float) -> void:
	# Raised spine down the middle of the roof.
	var spine_x := r.position.x + r.size.x * 0.55
	_box(Vector3(spine_x - 0.6, y, r.position.y + 0.4), Vector3(spine_x + 0.6, y + 0.22, r.end.y - 0.4), cc, cr)
	# Plates in rows, varied widths, grooves between.
	var z := r.position.y + GAP
	while z < r.end.y - 0.6:
		var d := _rng.randf_range(2.0, 4.0)
		var z1 := minf(z + d, r.end.y - GAP)
		var x := r.position.x + GAP
		while x < r.end.x - 0.6:
			var w := _rng.randf_range(1.8, 4.5)
			var x1 := minf(x + w, r.end.x - GAP)
			# Leave the spine strip clear.
			var a := x
			var b := x1
			if a < spine_x + 0.7 and b > spine_x - 0.7:
				if spine_x - 0.7 - a > 0.5:
					_box(Vector3(a, y, z), Vector3(spine_x - 0.7 - GAP, y + _rng.randf_range(0.05, 0.1), z1 - GAP), cc, cr)
				a = spine_x + 0.7 + GAP
			if b - a > 0.5:
				_box(Vector3(a, y, z), Vector3(b - GAP, y + _rng.randf_range(0.05, 0.1), z1 - GAP), cc, cr)
			x = x1 + GAP
		z = z1 + GAP


## Axis-aligned roof plate; skipped where it would poke outside the rounded corner.
func _box(a: Vector3, b: Vector3, cc: Vector2, cr: float) -> void:
	if cr > 0.0:
		for c in [Vector2(a.x, a.z), Vector2(b.x, a.z), Vector2(a.x, b.z), Vector2(b.x, b.z)]:
			if c.x < cc.x and c.y < cc.y and c.distance_to(cc) > cr - 0.1:
				return
	var p := [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z)]
	var q := [Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]
	_quad(q[0], q[1], q[2], q[3])
	for i in 4:
		var j := (i + 1) % 4
		_quad(p[i], p[j], q[j], q[i])


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		_st.add_vertex(v)


func _lengths(path: PackedVector2Array) -> PackedFloat32Array:
	var l := PackedFloat32Array([0.0])
	for i in range(1, path.size()):
		l.append(l[i - 1] + path[i].distance_to(path[i - 1]))
	return l


func _at(path: PackedVector2Array, lens: PackedFloat32Array, s: float) -> Vector2:
	for i in range(1, path.size()):
		if s <= lens[i]:
			var t := (s - lens[i - 1]) / maxf(lens[i] - lens[i - 1], 1e-5)
			return path[i - 1].lerp(path[i], t)
	return path[path.size() - 1]
