class_name ProcMesh

## Small toolkit for building low-poly meshes in code: a per-material
## triangle collector and lathe / loft / sector / box shapes. Used by the
## jack socket (mechanical_assembly.gd) and Meki's jack arm.

## Collects triangles per material and turns them into one ArrayMesh.
class Builder:
	var tools := {}
	var mats := {}

	func _st(mat: String) -> SurfaceTool:
		if not tools.has(mat):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[mat] = st
		return tools[mat]

	## Quad a-b-c-d; `out` is roughly which way it should face. The winding
	## is fixed up to suit (Godot front faces are clockwise).
	func quad(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3) -> void:
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-14:
			n = (c - a).cross(d - a)
		if n.dot(out) < 0.0:
			n = -n
			var t := b
			b = d
			d = t
		n = n.normalized()
		var st := _st(mat)
		for v in [a, c, b, a, d, c]:
			st.set_normal(n)
			st.add_vertex(v)

	func tri(mat: String, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
		var n := (b - a).cross(c - a)
		if n.dot(out) < 0.0:
			var t := b
			b = c
			c = t
			n = -n
		n = n.normalized()
		var st := _st(mat)
		for v in [a, c, b]:
			st.set_normal(n)
			st.add_vertex(v)

	func commit(material_table: Dictionary) -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for name in tools:
			var st: SurfaceTool = tools[name]
			st.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, material_table[name])
		return mesh


static func circle(segs: int, a0 := 0.0, a1 := TAU) -> Array:
	var pts := []
	var closed := is_equal_approx(a1 - a0, TAU)
	var n := segs if closed else segs + 1
	for i in n:
		var a := a0 + (a1 - a0) * i / segs
		pts.append(Vector2(cos(a), sin(a)))
	return pts


## Square with chamfered corners (c = how much of each side stays flat).
static func chamfered_square(c := 0.62) -> Array:
	return [Vector2(1, -c), Vector2(1, c), Vector2(c, 1), Vector2(-c, 1), Vector2(-1, c), Vector2(-1, -c), Vector2(-c, -1), Vector2(c, -1)]


## Sweep a profile of (radius, z) points around a cross-section (unit
## points; a circle gives a lathe). Normals face (-dz, dr) in the profile
## plane, so walk the profile with the solid on your right.
static func loft(mb: Builder, mat: String, profile: Array, section: Array, closed := true, mats := []) -> void:
	var n := section.size()
	var count := n if closed else n - 1
	for j in profile.size() - 1:
		var p0: Vector2 = profile[j]
		var p1: Vector2 = profile[j + 1]
		if p0.x <= 0.0 and p1.x <= 0.0:
			continue
		var m: String = mats[j] if j < mats.size() and mats[j] != "" else mat
		var nr := -(p1.y - p0.y)
		var nz := p1.x - p0.x
		for i in count:
			var s0: Vector2 = section[i]
			var s1: Vector2 = section[(i + 1) % n]
			var dir := ((s0 + s1) * 0.5).normalized()
			var out := Vector3(dir.x * nr, dir.y * nr, nz)
			mb.quad(m, Vector3(s0.x * p0.x, s0.y * p0.x, p0.y), Vector3(s1.x * p0.x, s1.y * p0.x, p0.y),
				Vector3(s1.x * p1.x, s1.y * p1.x, p1.y), Vector3(s0.x * p1.x, s0.y * p1.x, p1.y), out)


## Closed solid ring sector between radii, angles and depths (front face at
## z0, which is the more negative one).
static func sector(mb: Builder, mat: String, r0: float, r1: float, a0: float, a1: float, z0: float, z1: float, segs := 6) -> void:
	var prof := [Vector2(r1, z1), Vector2(r1, z0), Vector2(r0, z0), Vector2(r0, z1), Vector2(r1, z1)]
	loft(mb, mat, prof, circle(segs, a0, a1), false)
	for a in [a0, a1]:
		var d := Vector2(cos(a), sin(a))
		var out := Vector3(-d.y, d.x, 0) * (-1.0 if a == a0 else 1.0)
		var v := []
		for p: Vector2 in prof.slice(0, 4):
			v.append(Vector3(d.x * p.x, d.y * p.x, p.y))
		mb.quad(mat, v[0], v[1], v[2], v[3], out)


## Axis-aligned box from its centre and size.
static func box(mb: Builder, mat: String, c: Vector3, s: Vector3, xf := Transform3D.IDENTITY) -> void:
	var h := s * 0.5
	var p := []
	for i in 8:
		p.append(xf * (c + Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)))
	var faces := [[0, 2, 3, 1, Vector3(0, 0, -1)], [4, 5, 7, 6, Vector3(0, 0, 1)], [0, 1, 5, 4, Vector3(0, -1, 0)],
		[2, 6, 7, 3, Vector3(0, 1, 0)], [0, 4, 6, 2, Vector3(-1, 0, 0)], [1, 3, 7, 5, Vector3(1, 0, 0)]]
	for f in faces:
		mb.quad(mat, p[f[0]], p[f[1]], p[f[2]], p[f[3]], xf.basis * (f[4] as Vector3))
