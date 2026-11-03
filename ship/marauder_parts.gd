class_name MarauderParts
extends RefCounted

## Splits the "marauder" ship model (ship/models/marauder/marauder.obj, one
## welded mesh) into reusable parts: the central fuselage (nose, raised
## cabin, rear pod, antennas) and its four engine nacelles with their fans.
##
## Model frame: nose towards +Z, centred on x = 0, bottom at y = 0, about
## 1.19 units long. Faces are assigned by their centre: anything further than
## FUSELAGE_HALF_WIDTH from the centre line belongs to a nacelle.

const MODEL := "res://ship/models/marauder/marauder.obj"
const FUSELAGE_HALF_WIDTH := 0.098
## Nacelles in front of this z are the front pair, behind it the rear pair.
const NACELLE_SPLIT_Z := -0.15

## Cockpit canopy region (model frame) whose faces become glass.
const CANOPY_Z := Vector2(0.44, 0.62)
const CANOPY_Y := Vector2(0.115, 0.25)

static var _cache := {}


## Returns {"fuselage", "nacelle_front_left", "nacelle_front_right",
## "nacelle_rear_left", "nacelle_rear_right"} -> ArrayMesh (model frame).
## The fuselage has three surfaces: 0 = outer skin, 1 = recess floors
## (windows, hatches, vents), 2 = the cockpit canopy.
static func parts() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var src: Mesh = load(MODEL)
	var a := src.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var idx = a[Mesh.ARRAY_INDEX]
	var n_tris: int = (idx.size() if idx != null else v.size()) / 3
	var names := ["fuselage", "nacelle_front_left", "nacelle_front_right", "nacelle_rear_left", "nacelle_rear_right"]
	var tools := {}
	for n in names:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[n] = st
	for t in n_tris:
		var ids := [t * 3, t * 3 + 1, t * 3 + 2]
		if idx != null:
			ids = [idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]]
		var c: Vector3 = (v[ids[0]] + v[ids[1]] + v[ids[2]]) / 3.0
		var part := "fuselage"
		if absf(c.x) >= FUSELAGE_HALF_WIDTH:
			# Model's +x is the ship's left (nose is +Z, up is +Y).
			part = "nacelle_%s_%s" % ["front" if c.z > NACELLE_SPLIT_Z else "rear", "left" if c.x > 0.0 else "right"]
		var st: SurfaceTool = tools[part]
		for i in ids:
			st.set_normal(nrm[i])
			st.add_vertex(v[i])
	for n in names:
		_cache[n] = (tools[n] as SurfaceTool).commit()
	_cache["fuselage"] = _split_recesses(_cache["fuselage"])
	return _cache


## True when, looking out from bin b in all four directions (up to 6 bins),
## there's surface standing above `level`: the face sits in an inset.
static func _enclosed(grid: Dictionary, b: Vector2i, level: float) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var found := false
		for k in range(1, 7):
			if grid.get(b + d * k, -1.0) > level:
				found = true
				break
		if not found:
			return false
	return true


## Splits a mesh into surface 0 (outer skin) and surface 1 (recess floors:
## the window, hatch and vent insets), found by comparing each outward-facing
## face with the outermost surface around it.
static func _split_recesses(m: Mesh) -> ArrayMesh:
	var a := m.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var cell := 0.008
	var side_max := {}   # (z, y) -> outermost |x|
	var top_max := {}    # (x, z) -> highest y
	for p in v:
		var ks := Vector2i(floori(p.z / cell), floori(p.y / cell))
		side_max[ks] = maxf(side_max.get(ks, 0.0), absf(p.x))
		var kt := Vector2i(floori(p.x / cell), floori(p.z / cell))
		top_max[kt] = maxf(top_max.get(kt, -1.0), p.y)
	var st := [SurfaceTool.new(), SurfaceTool.new(), SurfaceTool.new()]
	for t in st:
		t.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, v.size(), 3):
		var c := (v[i] + v[i + 1] + v[i + 2]) / 3.0
		var n := (v[i + 1] - v[i]).cross(v[i + 2] - v[i]).normalized()
		var recess := false
		if absf(n.x) > 0.8 and absf(c.x) > 0.03:
			var b := Vector2i(floori(c.z / cell), floori(c.y / cell))
			recess = _enclosed(side_max, b, absf(c.x) + 0.0025)
		elif n.y > 0.8:
			var b := Vector2i(floori(c.x / cell), floori(c.z / cell))
			recess = _enclosed(top_max, b, c.y + 0.0025)
		# The cockpit canopy: the band of faces around the top of the nose,
		# except the flat roof.
		var k := 1 if recess else 0
		# Glass only on faces looking forward or up (a windshield), not the
		# nose's sides. (The model's winding makes n point inward.)
		if c.z > CANOPY_Z.x and c.z < CANOPY_Z.y and c.y > CANOPY_Y.x and c.y < CANOPY_Y.y and n.y < 0.9 \
				and absf(n.x) < 0.85 and (-n.z > 0.12 or -n.y > 0.15):
			k = 2
		for j in 3:
			st[k].set_normal(nrm[i + j])
			st[k].add_vertex(v[i + j])
	var out: ArrayMesh = st[0].commit()
	st[1].commit(out)
	return st[2].commit(out)

