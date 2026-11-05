@tool
class_name RoundWindow
extends Node3D

## A big round window through a forward-facing (-Z) hull wall: a real round
## opening in the parent's Hull (CSG), a deep round housing standing out
## through the exterior cladding, clear glass with collision, and a
## brushed-steel bezel on the inside.
##
## Ship space (the parent ship scene's frame): forward is -Z. The wall's
## interior face is at `wall_in_z`, the hull's exterior face at
## `wall_out_z`; outside that, ship/kestrel_exterior.gd's cladding (HullWalls,
## HullLedge) stands up to about a metre proud. The cladding inside the
## housing is clipped away (stepped boxes, all inside the housing's rim),
## and the housing's front sits just beyond the deepest cladding there.
##
## Built at runtime; nothing gets an owner, so a saved scene holds only this
## node and its exported values.

@export var centre := Vector2(-0.4, 1.5)   # (x, y) of the window's axis
@export var radius := 1.25                 # clear opening
@export var rim := 0.32                    # housing ring width outside the opening
@export var wall_in_z := -9.6
@export var wall_out_z := -9.9
@export var glass_inset := 0.25            # glass, back from the housing's front
@export var segments := 56

const BEZEL_W := 0.1
const BEZEL_D := 0.05
const CLAD_NODES := ["HullWalls", "HullLedge"]

var _glass: ShaderMaterial
var _steel: StandardMaterial3D
var _charcoal: StandardMaterial3D


func _ready() -> void:
	for c in get_children():
		c.free()
	_glass = ShaderMaterial.new()
	_glass.shader = preload("res://ship/galley_glass.gdshader")
	_steel = StandardMaterial3D.new()
	_steel.albedo_color = Color(0.58, 0.56, 0.53)
	_steel.metallic = 0.75
	_steel.roughness = 0.32
	_charcoal = StandardMaterial3D.new()
	_charcoal.albedo_color = Color(0.13, 0.13, 0.135)
	_charcoal.metallic = 0.5
	_charcoal.roughness = 0.4
	for m in [_steel, _charcoal]:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# After the exterior has built (and painted) the hull and its cladding.
	_build.call_deferred()


func _build() -> void:
	var ship := get_parent()
	var hull := ship.get_node_or_null("Hull") as CSGCombiner3D if ship else null
	if hull == null:
		return
	var outer := hull.get_node_or_null("Outer") as CSGShape3D
	var paint: Material = outer.material if outer else _charcoal

	# 1. The opening through the hull.
	var cut := CSGCylinder3D.new()
	cut.name = "RoundWindowCut"
	cut.radius = radius
	cut.height = (wall_in_z - wall_out_z) + 0.3
	cut.sides = segments
	cut.material = _charcoal
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut.transform = hull.transform.affine_inverse() * transform * Transform3D(
		Basis(Vector3.RIGHT, PI * 0.5), Vector3(centre.x, centre.y, (wall_in_z + wall_out_z) * 0.5))
	hull.add_child(cut)

	# 2. Clear the cladding inside the housing, and find how far it stands
	# out there.
	var front_z := wall_out_z - 0.15
	var ext := ship.get_node_or_null("KestrelExterior")
	var r_out := radius + rim
	for n in CLAD_NODES:
		var mi := ext.get_node_or_null(n) as MeshInstance3D if ext else null
		if mi == null or mi.mesh == null:
			continue
		front_z = minf(front_z, _deepest(mi, r_out) - 0.05)
		var mats := []
		for s in mi.get_surface_override_material_count():
			mats.append(mi.get_surface_override_material(s))
		var m: Mesh = mi.mesh
		for b in _clip_boxes():
			m = ext.call("_clip_out", m, mi.transform, b)
		mi.mesh = m
		for s in mini(mats.size(), mi.get_surface_override_material_count()):
			mi.set_surface_override_material(s, mats[s])

	# 3. The housing: painted like the hull outside, dark inside its bore.
	var housing := MeshInstance3D.new()
	housing.name = "Housing"
	housing.mesh = _housing(front_z)
	housing.set_surface_override_material(0, paint)
	housing.set_surface_override_material(1, _steel)
	add_child(housing)
	var hb := StaticBody3D.new()
	hb.name = "HousingBody"
	var hcs := CollisionShape3D.new()
	var hshape := housing.mesh.create_trimesh_shape()
	hshape.backface_collision = true
	hcs.shape = hshape
	hb.add_child(hcs)
	add_child(hb)

	# 4. Glass, with collision.
	var gz := front_z + glass_inset
	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	glass.mesh = _disc(radius, gz)
	glass.material_override = _glass
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	var gb := StaticBody3D.new()
	gb.name = "GlassBody"
	var gcs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 0.04
	gcs.shape = cyl
	gcs.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(centre.x, centre.y, gz))
	gb.add_child(gcs)
	add_child(gb)

	# 5. The brushed-steel bezel on the interior wall.
	var bezel := MeshInstance3D.new()
	bezel.name = "Bezel"
	bezel.mesh = _bezel()
	bezel.material_override = _steel
	add_child(bezel)


## Stepped boxes covering the opening, every corner inside the housing's
## rim (so no clipped edge shows outside it).
func _clip_boxes() -> Array:
	var r := radius + 0.02
	var out := []
	for k in [[1.0, 0.42], [0.86, 0.72], [0.42, 1.0]]:
		var hx: float = r * k[0]
		var hy: float = r * k[1]
		out.append(AABB(Vector3(centre.x - hx, centre.y - hy, wall_out_z - 3.0), Vector3(hx * 2.0, hy * 2.0, 3.0 + 0.05)))
	return out


## The most negative z of the mesh's vertices within distance r of the axis.
func _deepest(mi: MeshInstance3D, r: float) -> float:
	var z := wall_out_z
	for s in mi.mesh.get_surface_count():
		var v: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for p in v:
			var q: Vector3 = mi.transform * p
			if Vector2(q.x, q.y).distance_to(centre) < r and q.z < wall_out_z:
				z = minf(z, q.z)
	return z


func _ring_point(r: float, i: int, z: float) -> Vector3:
	var a := TAU * float(i) / float(segments)
	return Vector3(centre.x + cos(a) * r, centre.y + sin(a) * r, z)


## Surface 0: outer drum and front face. Surface 1: the bore (steel).
func _housing(front_z: float) -> ArrayMesh:
	var r0 := radius
	var r1 := radius + rim
	var back := wall_out_z + 0.02
	var sts := [SurfaceTool.new(), SurfaceTool.new()]
	for st in sts:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var j := i + 1
		# Front face (faces -Z).
		_quad(sts[0], _ring_point(r0, i, front_z), _ring_point(r1, i, front_z), _ring_point(r1, j, front_z), _ring_point(r0, j, front_z))
		# Outer drum (faces outward).
		_quad(sts[0], _ring_point(r1, i, front_z), _ring_point(r1, i, back), _ring_point(r1, j, back), _ring_point(r1, j, front_z))
		# Bore (faces the axis), from the hull's exterior face out (the
		# hull's own cut lines it inside the wall).
		_quad(sts[1], _ring_point(r0, j, front_z), _ring_point(r0, j, back), _ring_point(r0, i, back), _ring_point(r0, i, front_z))
	var m: ArrayMesh = null
	for st in sts:
		st.generate_normals()
		m = st.commit(m) if m else st.commit()
	return m


func _disc(r: float, z: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector3(centre.x, centre.y, z)
	for i in segments:
		st.add_vertex(c)
		st.add_vertex(_ring_point(r, i, z))
		st.add_vertex(_ring_point(r, i + 1, z))
	st.generate_normals()
	return st.commit()


func _bezel() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r0 := radius
	var r1 := radius + BEZEL_W
	var f := wall_in_z + BEZEL_D
	for i in segments:
		var j := i + 1
		_quad(st, _ring_point(r0, j, f), _ring_point(r1, j, f), _ring_point(r1, i, f), _ring_point(r0, i, f))
		_quad(st, _ring_point(r1, j, f), _ring_point(r1, j, wall_in_z), _ring_point(r1, i, wall_in_z), _ring_point(r1, i, f))
		_quad(st, _ring_point(r0, i, f), _ring_point(r0, i, wall_in_z - 0.03), _ring_point(r0, j, wall_in_z - 0.03), _ring_point(r0, j, f))
	st.generate_normals()
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)
