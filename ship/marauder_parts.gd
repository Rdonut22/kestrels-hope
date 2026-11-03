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

static var _cache := {}


## Returns {"fuselage", "nacelle_front_left", "nacelle_front_right",
## "nacelle_rear_left", "nacelle_rear_right"} -> ArrayMesh (model frame).
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
	return _cache
