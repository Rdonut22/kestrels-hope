class_name FuselageCladding
extends RefCounted

## Clads other hull sections with the marauder fuselage's own surface, so
## they share its paneling exactly: recessed hatches, panel breaks, steps,
## facets and window frames.
##
## Recessed faces (windows, hatches, vents) come out as a second surface so
## they can take the same dark material as on the fuselage.
## A patch of the fuselage (ship/marauder_parts.gd, model frame: nose +Z,
## +X to one side, bottom at y = 0) is cut out and "unrolled": its length and
## height (or length and width, for the top) become positions on the target
## surface, and how far it stands out from a reference plane becomes depth.
## Patches are tiled along the target, every other one mirrored, so the
## repeat isn't obvious.

# Side patches: the fuselage's +X side is intact above and below the slot
# where the nacelles were: its upper band and its lower band.
# [source y range, source z range]
const SIDE_BANDS := [[Vector2(0.165, 0.245), Vector2(-0.3, 0.35)],
	[Vector2(0.02, 0.095), Vector2(-0.2, 0.35)]]
const SIDE_REF_X := 0.04      # faces outside this are the side skin
# The side's depth is compressed so the copied bulge doesn't stand out too far.
const SIDE_DEPTH := 0.5
# Top patch: the cabin roof, from the rear pod to the cockpit.
const TOP_Z := Vector2(-0.15, 0.55)
const TOP_X := 0.095          # half width taken
const TOP_REF_Y := 0.19       # faces above this are the roof skin


## Wall cladding along a footprint path (x, z points); outward is away from
## `centre`. The wall from y0 to y1 gets the fuselage's upper band on its top
## part and its lower band below, split at `split` (0..1 of the height).
## `scale` = metres per model unit along the wall.
static func walls(path: PackedVector2Array, centre: Vector2, y0: float, y1: float, split := 0.5, scale := 26.0) -> ArrayMesh:
	var st := [SurfaceTool.new(), SurfaceTool.new()]
	for t in st:
		t.begin(Mesh.PRIMITIVE_TRIANGLES)
		t.set_smooth_group(-1)
	var ym := lerpf(y0, y1, split)
	_wall_band(st, path, centre, SIDE_BANDS[0][0], SIDE_BANDS[0][1], ym, y1, scale)
	_wall_band(st, path, centre, SIDE_BANDS[1][0], SIDE_BANDS[1][1], y0, ym, scale)
	return _commit2(st)


static func _wall_band(st: Array, path: PackedVector2Array, centre: Vector2,
		sy: Vector2, sz: Vector2, y0: float, y1: float, scale: float) -> void:
	var src := _triangles()
	var lens := _lengths(path)
	var total: float = lens[lens.size() - 1]
	var tile := (sz.y - sz.x) * scale
	var hs := (y1 - y0) / (sy.y - sy.x)
	var start := 0.0
	var k := 0
	while start < total:
		var mirror := k % 2 == 1
		for t in range(0, src.size(), 3):
			var c: Vector3 = (src[t] + src[t + 1] + src[t + 2]) / 3.0
			if c.x < SIDE_REF_X or c.z < sz.x or c.z > sz.y or c.y < sy.x or c.y > sy.y:
				continue
			var out: Array[Vector3] = []
			var ok := true
			for i in 3:
				var v: Vector3 = src[t + i]
				var u := (v.z - sz.x) / (sz.y - sz.x)
				if mirror:
					u = 1.0 - u
				var s := start + clampf(u, 0.0, 1.0) * tile
				if s > total + 0.01:
					ok = false
					break
				var pn := _at(path, lens, minf(s, total), centre)
				var d := maxf(v.x - SIDE_REF_X, 0.0) * scale * SIDE_DEPTH
				var p: Vector2 = pn[0] + pn[1] * d
				out.append(Vector3(p.x, y0 + (clampf(v.y, sy.x, sy.y) - sy.x) * hs, p.y))
			if ok:
				for v in out:
					st[mini(_flags[t / 3], 1)].add_vertex(v)
		start += tile
		k += 1


## Roof cladding over a rectangle (x, z) at height y: strips of the
## fuselage's top laid side by side across x, tiled along z.
static func roof(rect: Rect2, y: float, scale := 26.0) -> ArrayMesh:
	var src := _triangles()
	var strip_w := TOP_X * 2.0 * scale
	var tile := (TOP_Z.y - TOP_Z.x) * scale
	var st := [SurfaceTool.new(), SurfaceTool.new()]
	for t in st:
		t.begin(Mesh.PRIMITIVE_TRIANGLES)
		t.set_smooth_group(-1)
	var col := 0
	var x0 := rect.position.x
	while x0 < rect.end.x - 0.5:
		var z0 := rect.position.y
		var row := 0
		while z0 < rect.end.y - 0.5:
			var mirror_x := col % 2 == 1
			var mirror_z := row % 2 == 1
			for t in range(0, src.size(), 3):
				var c: Vector3 = (src[t] + src[t + 1] + src[t + 2]) / 3.0
				if c.y < TOP_REF_Y or absf(c.x) > TOP_X or c.z < TOP_Z.x or c.z > TOP_Z.y:
					continue
				var out: Array[Vector3] = []
				var ok := true
				for i in 3:
					var v: Vector3 = src[t + i]
					var u := (v.x + TOP_X) / (2.0 * TOP_X)
					var w := (v.z - TOP_Z.x) / (TOP_Z.y - TOP_Z.x)
					if mirror_x:
						u = 1.0 - u
					if mirror_z:
						w = 1.0 - w
					var px := x0 + clampf(u, 0.0, 1.0) * strip_w
					var pz := z0 + clampf(w, 0.0, 1.0) * tile
					if px > rect.end.x + 0.01 or pz > rect.end.y + 0.01:
						ok = false
						break
					out.append(Vector3(px, y + (v.y - TOP_REF_Y) * scale, pz))
				if ok:
					for v in out:
						st[mini(_flags[t / 3], 1)].add_vertex(v)
			z0 += tile
			row += 1
		x0 += strip_w
		col += 1
	return _commit2(st)


## Surface 0: skin. Surface 1: recess floors (windows, hatches, vents).
static func _commit2(st: Array) -> ArrayMesh:
	var m: ArrayMesh = null
	for t in st:
		t.generate_normals()
		m = t.commit(m) if m else t.commit()
	return m


## The fuselage as a flat triangle list (model frame), all surfaces; and
## which surface each triangle came from (0 skin, 1 recess) in _flags.
static var _flags := PackedInt32Array()


static func _triangles() -> PackedVector3Array:
	var m: Mesh = MarauderParts.parts()["fuselage"]
	var out := PackedVector3Array()
	_flags = PackedInt32Array()
	for sidx in m.get_surface_count():
		var a := m.surface_get_arrays(sidx)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx = a[Mesh.ARRAY_INDEX]
		if idx == null:
			out.append_array(v)
			for i in v.size() / 3:
				_flags.append(sidx)
		else:
			for i in idx:
				out.append(v[i])
			for i in idx.size() / 3:
				_flags.append(sidx)
	return out


static func _lengths(path: PackedVector2Array) -> PackedFloat32Array:
	var l := PackedFloat32Array([0.0])
	for i in range(1, path.size()):
		l.append(l[i - 1] + path[i].distance_to(path[i - 1]))
	return l


## Point and outward normal at distance s along the path.
static func _at(path: PackedVector2Array, lens: PackedFloat32Array, s: float, centre: Vector2) -> Array:
	for i in range(1, path.size()):
		if s <= lens[i] or i == path.size() - 1:
			var t := clampf((s - lens[i - 1]) / maxf(lens[i] - lens[i - 1], 1e-5), 0.0, 1.0)
			var p := path[i - 1].lerp(path[i], t)
			var d := (path[i] - path[i - 1]).normalized()
			var n := Vector2(-d.y, d.x)
			if n.dot(p - centre) < 0.0:
				n = -n
			return [p, n]
	return [path[0], Vector2.LEFT]
