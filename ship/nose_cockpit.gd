class_name NoseCockpit
extends RefCounted

## The cockpit at deck level inside the fuselage's nose, with a windshield
## in the nose (replaces the old raised flight deck and its stairs).
##
## Ship space: forward is -Z, floor y = 0. From the kitchen's cockpit door
## (z -6.9) a short passage (x 2.4..5.6, z -9.95..-6.95, carved in the hull
## by kestrel_exterior.gd) opens into the nose. Inside the nose a clean
## shell ("liner", aged ivory panels) follows the fuselage's own section, LINER_INSET in from
## its skin, with a flat floor at y 0; the fuselage's internal geometry
## inside it is removed. At the front the nose is cut by the windshield
## plane (raked back WS_RAKE per metre up, its foot at y WS_Y, z WS_Z):
## above WS_Y everything in front of the plane goes, and the cut is glazed
## (three panes: two mullions), framed by the fuselage's own section on the
## plane; below WS_Y the chin stays, capped flat at WS_Y, with a dash wall
## inside. The liner, dash and glass collide.

const WS_Z := -13.4
const WS_Y := 0.95
const WS_RAKE := 0.585          # z per metre up the glass (same rake as the old canopy)
const LINER_INSET := 0.15
const CENTRE := Vector2(4.0, 1.3)   # (x, y) the sections are sampled around
const N := 40                   # samples around a section
const PASSAGE := Rect2(2.4, 0.0, 3.2, 3.0)   # x, y, w, h of the opening from the passage
const PASSAGE_Z := -9.95
const STATIONS := [-10.6, -11.3, -12.0, -12.7]
const MULLION_X := [3.45, 4.55]
## Above this the shell and the fuselage are open for the roof window.
const ROOF_CUT_Y := 1.9

var ext: Node3D
var tris := PackedVector3Array()   # the fuselage, ship space, all surfaces


## Builds the cockpit as children of `exterior` and returns the fuselage
## mesh (model frame, drawn with xf) with the nose cut for the windshield
## and its insides cleared.
func build(exterior: Node3D, fus: Mesh, xf: Transform3D) -> ArrayMesh:
	ext = exterior
	for sidx in fus.get_surface_count():
		var a := fus.surface_get_arrays(sidx)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx = a[Mesh.ARRAY_INDEX]
		if idx == null:
			for p in v:
				tris.append(xf * p)
		else:
			for i in idx:
				tris.append(xf * v[i])

	# Sections: the passage opening, the fuselage stations, the windshield.
	var rings: Array = [_rect_ring(PASSAGE, PASSAGE_Z)]
	for z in STATIONS:
		rings.append(_station_ring(z))
	var last := _front_ring()
	rings.append(last)

	_liner(rings)
	_front(last)
	_chin_cap()
	# Ribs, windows, controls, lights (ship/cockpit_fitout.gd).
	CockpitFitout.new().build(ext, rings, bool(ext.get("crashed")))

	# The fuselage, in one pass: the nose cut at the windshield, and
	# everything inside the cockpit cleared.
	var regions: Array = [[[
		[Vector3(0, 1, 0), WS_Y],
		[Vector3(0, WS_RAKE, -1), WS_RAKE * WS_Y - WS_Z],
		[Vector3(1, 0, 0), 1.0], [Vector3(-1, 0, 0), -7.5]],
		AABB(Vector3(1.0, WS_Y, -20.0), Vector3(6.5, 10.0, 20.0 + WS_Z + WS_RAKE * 10.0))]]
	regions.append_array(_inside_regions(rings))
	# The roof window (cockpit_fitout.gd frames and glazes it).
	var rx: Vector2 = CockpitFitout.ROOF_X
	var rz: Vector2 = CockpitFitout.ROOF_Z
	regions.append([[[Vector3(1, 0, 0), rx.x], [Vector3(-1, 0, 0), -rx.y], [Vector3(0, 0, 1), rz.x],
		[Vector3(0, 0, -1), -rz.y], [Vector3(0, 1, 0), ROOF_CUT_Y]],
		AABB(Vector3(rx.x, ROOF_CUT_Y, rz.x), Vector3(rx.y - rx.x, 10.0, rz.y - rz.x))])
	# The passage from the kitchen door (the fuselage crosses it; the hull
	# carves the room itself).
	var pb := AABB(Vector3(PASSAGE.position.x, 0.01, PASSAGE_Z), Vector3(PASSAGE.size.x, PASSAGE.size.y - 0.01, 3.0))
	regions.append([[[Vector3(1, 0, 0), pb.position.x], [Vector3(-1, 0, 0), -pb.end.x],
		[Vector3(0, 1, 0), pb.position.y], [Vector3(0, -1, 0), -pb.end.y],
		[Vector3(0, 0, 1), pb.position.z], [Vector3(0, 0, -1), -pb.end.z]], pb])
	return ext.call("_clip_regions", fus, xf, regions)


# ---------- sections ----------

## Where the windshield plane sits at height y (below WS_Y: the dash wall).
static func plane_z(y: float) -> float:
	return WS_Z + WS_RAKE * maxf(y - WS_Y, 0.0)


func _dir(k: int) -> Vector2:
	var a := TAU * float(k) / float(N)
	return Vector2(cos(a), sin(a))


## Distance from CENTRE along d to a convex polygon's edge.
func _hit(poly: PackedVector2Array, d: Vector2) -> float:
	var best := 1e9
	for i in poly.size():
		var a := poly[i] - CENTRE
		var b := poly[(i + 1) % poly.size()] - CENTRE
		var e := b - a
		var den := d.x * e.y - d.y * e.x
		if absf(den) < 1e-9:
			continue
		var t := (a.x * e.y - a.y * e.x) / den
		var s := (a.x * d.y - a.y * d.x) / den
		if t > 0.0 and s >= -1e-6 and s <= 1.0 + 1e-6:
			best = minf(best, t)
	return best if best < 1e8 else 1.0


## A section (convex hull of points) sampled at N angles, pulled in by
## inset, with a flat floor at y 0. As (x, y).
func _sample(hull: PackedVector2Array, inset: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in N:
		var d := _dir(k)
		var p := CENTRE + d * (_hit(hull, d) - inset)
		p.y = maxf(p.y, 0.0)
		out.append(p)
	return out


func _rect_ring(r: Rect2, z: float) -> PackedVector3Array:
	var hull := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var out := PackedVector3Array()
	for p in _sample(hull, 0.0):
		out.append(Vector3(p.x, p.y, z))
	return out


## The fuselage's outline where the plane n.p = d cuts it, as (x, y).
func _slice(n: Vector3, d: float, keep: Callable) -> PackedVector2Array:
	var out := PackedVector2Array()
	for t in range(0, tris.size(), 3):
		for e in 3:
			var a := tris[t + e]
			var b := tris[t + (e + 1) % 3]
			var fa := n.dot(a) - d
			var fb := n.dot(b) - d
			if (fa > 0.0) != (fb > 0.0):
				var p := a.lerp(b, fa / (fa - fb))
				if p.x > 1.0 and p.x < 7.5 and p.y > -0.4 and keep.call(p):
					out.append(Vector2(p.x, p.y))
	return out


func _station_ring(z: float) -> PackedVector3Array:
	var hull := Geometry2D.convex_hull(_slice(Vector3(0, 0, 1), z, func(_p: Vector3) -> bool: return true))
	var out := PackedVector3Array()
	for p in _sample(hull, LINER_INSET):
		out.append(Vector3(p.x, p.y, z))
	return out


## The fuselage's section on the windshield (above WS_Y: the raked plane;
## below: the vertical dash plane), as (x, y).
func _front_outline() -> PackedVector2Array:
	var pts := _slice(Vector3(0, -WS_RAKE, 1), WS_Z - WS_RAKE * WS_Y, func(p: Vector3) -> bool: return p.y >= WS_Y - 0.01)
	pts.append_array(_slice(Vector3(0, 0, 1), WS_Z, func(p: Vector3) -> bool: return p.y <= WS_Y + 0.01))
	return Geometry2D.convex_hull(pts)


func _front_ring() -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in _sample(_front_outline(), LINER_INSET):
		out.append(Vector3(p.x, p.y, plane_z(p.y)))
	return out


# ---------- meshes ----------

func _liner(rings: Array) -> void:
	# The user's panel-cut metal on the walls and ceiling (corridor.gdshader
	# surface 9), the deck plates underfoot (surface 1).
	var src := load("res://ship/materials/corridor_wall.tres") as ShaderMaterial
	var wall_src := panel_material()
	var floor_mat := src.duplicate() as ShaderMaterial
	floor_mat.set_shader_parameter("surface", 1)
	var sts := [SurfaceTool.new(), SurfaceTool.new()]
	for st in sts:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var col := PackedVector3Array()
	for r in rings.size() - 1:
		var a: PackedVector3Array = rings[r]
		var b: PackedVector3Array = rings[r + 1]
		var axis := Vector3(CENTRE.x, CENTRE.y, (a[0].z + b[0].z) * 0.5)
		for k in N:
			var j := (k + 1) % N
			for t in [[a[k], b[k], b[j]], [a[k], b[j], a[j]]]:
				var on_floor: bool = t[0].y < 0.01 and t[1].y < 0.01 and t[2].y < 0.01
				var c: Vector3 = (t[0] + t[1] + t[2]) / 3.0
				if c.y > ROOF_CUT_Y and c.x > CockpitFitout.ROOF_X.x and c.x < CockpitFitout.ROOF_X.y \
						and c.z > CockpitFitout.ROOF_Z.x and c.z < CockpitFitout.ROOF_Z.y:
					continue   # the roof window
				_tri(sts[1 if on_floor else 0], t, axis)
				col.append_array(PackedVector3Array(t))
	var m: ArrayMesh = null
	for st in sts:
		st.generate_normals()
		m = st.commit(m) if m else st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "CockpitLiner"
	mi.mesh = m
	mi.set_surface_override_material(0, wall_src)
	mi.set_surface_override_material(1, floor_mat)
	ext.add_child(mi)
	_body("CockpitLinerBody", col)


## The cockpit's walls, ceiling and dash: the user's panel-cut metal wall
## texture (corridor.gdshader surface 9).
static var _panel: StandardMaterial3D


static func panel_material() -> StandardMaterial3D:
	if _panel == null:
		# A standard material, projected in world space (the shell has no
		# UVs); not a corridor.gdshader surface, which is at the Mac
		# Compatibility renderer's texture limit.
		_panel = StandardMaterial3D.new()
		var tex := "res://ship/textures/interior/cockpit_panel_"
		_panel.albedo_texture = load(tex + "color.png")
		_panel.albedo_color = Color(1.15, 1.15, 1.15)
		_panel.normal_enabled = true
		_panel.normal_texture = load(tex + "nor.png")
		_panel.roughness_texture = load(tex + "rm.png")
		_panel.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		_panel.metallic = 0.4
		_panel.metallic_texture = load(tex + "rm.png")
		_panel.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		_panel.uv1_triplanar = true
		_panel.uv1_world_triplanar = true
		_panel.uv1_scale = Vector3(1.0 / 2.6, 1.0 / 1.46, 1.0 / 2.6)
		_panel.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _panel


## Adds a triangle facing the axis point (into the room).
func _tri(st: SurfaceTool, t: Array, toward: Vector3) -> void:
	var a: Vector3 = t[0]
	var b: Vector3 = t[1]
	var c: Vector3 = t[2]
	var n := (b - a).cross(c - a)
	# Godot's front faces wind clockwise: the face normal is -(b-a)x(c-a).
	if (-n).dot(toward - (a + b + c) / 3.0) < 0.0:
		var tmp := b
		b = c
		c = tmp
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _body(n: String, faces: PackedVector3Array) -> void:
	var body := StaticBody3D.new()
	body.name = n
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	ext.add_child(body)


## Front: the dash wall below WS_Y, the glass above it (with mullions and a
## sill), and the frame between the glass and the fuselage's skin.
func _front(ring: PackedVector3Array) -> void:
	var paint: Material = ext.call("_mat")
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.58, 0.56, 0.53)
	steel.metallic = 0.75
	steel.roughness = 0.32
	var behind := Vector3(CENTRE.x, CENTRE.y, WS_Z + 3.0)
	# Split the ring at WS_Y: glass outline above, dash outline below.
	var above := PackedVector3Array()
	var below := PackedVector3Array()
	for k in N:
		var a := ring[k]
		var b := ring[(k + 1) % N]
		if a.y >= WS_Y:
			above.append(a)
		if a.y <= WS_Y:
			below.append(a)
		if (a.y > WS_Y) != (b.y > WS_Y):
			var p := a.lerp(b, (WS_Y - a.y) / (b.y - a.y))
			above.append(p)
			below.append(p)
	# Dash wall (faces into the cockpit).
	_fan("Dash", below, panel_material(), behind, true)
	# Glass.
	var glass_mat := ShaderMaterial.new()
	glass_mat.shader = preload("res://ship/galley_glass.gdshader")
	var g := _fan("Windshield", above, glass_mat, behind, true)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The frame: from the glass's edge out to the skin, on the plane.
	var outer := _front_outline()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ahead := Vector3(CENTRE.x, CENTRE.y, WS_Z - 3.0)
	for k in N:
		var j := (k + 1) % N
		var i0 := ring[k]
		var i1 := ring[j]
		if i0.y < WS_Y - 0.01 or i1.y < WS_Y - 0.01:
			continue
		# Over the roof window the glass carries on up: no frame there.
		var rx: Vector2 = CockpitFitout.ROOF_X
		if i0.y > ROOF_CUT_Y and i1.y > ROOF_CUT_Y and minf(i0.x, i1.x) > rx.x - 0.1 and maxf(i0.x, i1.x) < rx.y + 0.1:
			continue
		var o0 := _on_plane(CENTRE + _dir(k) * _hit(outer, _dir(k)))
		var o1 := _on_plane(CENTRE + _dir(j) * _hit(outer, _dir(j)))
		_tri(st, [i0, o0, o1], ahead)
		_tri(st, [i0, o1, i1], ahead)
	st.generate_normals()
	var fm := MeshInstance3D.new()
	fm.name = "WindshieldFrame"
	fm.mesh = st.commit()
	fm.material_override = paint
	ext.add_child(fm)
	# Mullions and the sill: steel bars on the glass.
	var up := Vector3(0, 1, WS_RAKE).normalized()
	var top_y := 0.0
	for p in above:
		top_y = maxf(top_y, p.y)
	for x in MULLION_X:
		var y1 := _top_at(above, x)
		var a := Vector3(x, WS_Y, plane_z(WS_Y))
		var b := Vector3(x, y1, plane_z(y1))
		_bar("Mullion", a, b, Vector3(0.07, 0.0, 0.07), steel)
	var sl := _x_span(above, WS_Y + 0.01)
	_bar("WindshieldSill", Vector3(sl.x, WS_Y + 0.02, plane_z(WS_Y) + 0.02), Vector3(sl.y, WS_Y + 0.02, plane_z(WS_Y) + 0.02),
		Vector3(0.0, 0.06, 0.12), steel)
	# The glass and dash collide.
	var faces := PackedVector3Array()
	for poly in [above, below]:
		var c := Vector3.ZERO
		for p in poly:
			c += p
		c /= float(poly.size())
		for i in poly.size():
			faces.append_array(PackedVector3Array([c, poly[i], poly[(i + 1) % poly.size()]]))
	_body("WindshieldBody", faces)


func _on_plane(p: Vector2) -> Vector3:
	return Vector3(p.x, p.y, plane_z(p.y))


## Highest y of an outline at x (its top edge), on the plane.
func _top_at(poly: PackedVector3Array, x: float) -> float:
	var best := WS_Y
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if (a.x - x) * (b.x - x) <= 0.0 and absf(b.x - a.x) > 1e-5:
			best = maxf(best, lerpf(a.y, b.y, (x - a.x) / (b.x - a.x)))
	return best


## The outline's x extent at height y.
func _x_span(poly: PackedVector3Array, y: float) -> Vector2:
	var lo := 1e9
	var hi := -1e9
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if (a.y - y) * (b.y - y) <= 0.0 and absf(b.y - a.y) > 1e-5:
			var x := lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
			lo = minf(lo, x)
			hi = maxf(hi, x)
	return Vector2(lo, hi) if hi > lo else Vector2(CENTRE.x - 1.0, CENTRE.x + 1.0)


func _fan(n: String, poly: PackedVector3Array, mat: Material, toward: Vector3, _two := false) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector3.ZERO
	for p in poly:
		c += p
	c /= float(poly.size())
	for i in poly.size():
		_tri(st, [c, poly[i], poly[(i + 1) % poly.size()]], toward)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = st.commit()
	mi.material_override = mat
	ext.add_child(mi)
	return mi


func _bar(n: String, a: Vector3, b: Vector3, thick: Vector3, mat: Material) -> void:
	var len := a.distance_to(b)
	var bm := BoxMesh.new()
	var dir := (b - a).normalized()
	var mi := MeshInstance3D.new()
	mi.name = n
	if thick.x == 0.0:
		# Along x (the sill).
		bm.size = Vector3(len, thick.y, thick.z)
		mi.transform = Transform3D(Basis.IDENTITY, (a + b) * 0.5)
	else:
		bm.size = Vector3(thick.x, len, thick.z)
		var x := Vector3.RIGHT
		var z := x.cross(dir).normalized()
		mi.transform = Transform3D(Basis(x, dir, z), (a + b) * 0.5)
	mi.mesh = bm
	mi.material_override = mat
	ext.add_child(mi)


## The chin in front of the windshield, capped flat at WS_Y.
func _chin_cap() -> void:
	var pts := PackedVector2Array()
	for t in range(0, tris.size(), 3):
		for e in 3:
			var a := tris[t + e]
			var b := tris[t + (e + 1) % 3]
			if (a.y > WS_Y) != (b.y > WS_Y):
				var p := a.lerp(b, (WS_Y - a.y) / (b.y - a.y))
				if p.z < WS_Z + 0.01 and p.x > 1.0 and p.x < 7.5:
					pts.append(Vector2(p.x, p.z))
	if pts.size() < 3:
		return
	var hull := Geometry2D.convex_hull(pts)
	var poly := PackedVector3Array()
	for q in hull:
		poly.append(Vector3(q.x, WS_Y, minf(q.y, WS_Z)))
	var cap := _fan("ChinCap", poly, ext.call("_mat"), Vector3(CENTRE.x, WS_Y + 3.0, WS_Z - 1.0))
	var faces := PackedVector3Array()
	for i in range(1, poly.size() - 1):
		faces.append_array(PackedVector3Array([poly[0], poly[i], poly[i + 1]]))
	_body("ChinCapBody", faces)
	cap.name = "ChinCap"


## The cockpit's inside as convex regions for _clip_regions: each stretch
## of the liner between two sections (its side faces and its two ends),
## with its bounds.
func _inside_regions(rings: Array) -> Array:
	var out: Array = []
	for r in rings.size() - 1:
		var a: PackedVector3Array = rings[r]
		var b: PackedVector3Array = rings[r + 1]
		var planes: Array = []
		var axis := Vector3(CENTRE.x, CENTRE.y, (a[0].z + b[0].z) * 0.5)
		var bounds := AABB(a[0], Vector3.ZERO)
		for p in a:
			bounds = bounds.expand(p)
		for p in b:
			bounds = bounds.expand(p)
		for k in N:
			var j := (k + 1) % N
			var n := (a[j] - a[k]).cross(b[k] - a[k])
			if n.length() < 1e-6:
				n = (b[j] - b[k]).cross(b[k] - a[j])
			if n.length() < 1e-6:
				continue
			n = n.normalized()
			if n.dot(axis - a[k]) < 0.0:
				n = -n
			# Inside the room: n.p > n.a (a hair outside the liner too).
			planes.append([n, n.dot(a[k]) - 0.02])
		# Ends: in front of the back section, behind the front one.
		planes.append([Vector3(0, 0, -1), -a[0].z - 0.01])
		if r == rings.size() - 2:
			planes.append([Vector3(0, 0, 1), WS_Z - 0.01])
			planes.append([Vector3(0, -WS_RAKE, 1), WS_Z - WS_RAKE * WS_Y - 0.01])
		else:
			planes.append([Vector3(0, 0, 1), b[0].z - 0.01])
		out.append([planes, bounds.grow(0.05)])
	return out
