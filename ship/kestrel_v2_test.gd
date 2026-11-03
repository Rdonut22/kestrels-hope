@tool
extends Node3D

## Blockout test for the reworked Kestrel exterior (the user's sketches):
## the stripped marauder fuselage around the cockpit, kitchen and lounge on
## the starboard (+X) side, the existing hull to port (front-left corner
## rounded) clad in a plated skin (ship/hull_skin.gd), two big fan turbines
## mirrored at the back, a tilted A-shaped top wing on struts and a low swept
## wing to starboard, both built like the user's wing reference (thick
## chamfered slabs with a raised inner plate). Every part wears the same
## procedural worn paint (ship/marauder_paint.gdshader).
## The current interior (ship/ship_interior.tscn) is placed inside so the fit
## can be checked. Kestrel frame: forward is -Z, floor at y = 0.

## Fuselage size: model units -> metres.
@export var fuselage_scale := 26.0
## Fuselage centre line (x) and where its nose tip sits (z).
@export var fuselage_x := 4.75
@export var nose_z := -14.5
@export var fuselage_floor_y := -0.7
## Radius of the rounded front-left corner of the port hull.
@export var corner_radius := 3.5
@export var show_interior := true
## Hull cladding: 0 = the fuselage's own paneling copied on, 1 = plated skin.
@export_enum("Fuselage paneling", "Plated skin") var hull_style := 0
## The hinged top wing on its pylons and rams (off for now).
@export var show_top_wing := false
## Tilt of the top wing (degrees, outer tip down).
@export var wing_tilt := 16.0

# Port hull box (from tools/build_scenes.gd): x -7.7..5.9, z -9.9..9.5.
const HULL_MIN := Vector3(-7.7, -0.2, -9.9)
const HULL_MAX := Vector3(5.9, 3.2, 9.5)
# Ship centre line for mirroring the fans: halfway across hull + fuselage.
const CENTRE_X := -0.15

var _paint: Shader
var _seed := 0.0


func _ready() -> void:
	_paint = load("res://ship/marauder_paint.gdshader")
	var parts := MarauderParts.parts()

	if show_interior:
		var ship: Node3D = (load("res://ship/ship_interior.tscn") as PackedScene).instantiate()
		add_child(ship)
		var ext := ship.get_node_or_null("Exterior")
		if ext:
			ext.visible = false
		var hull := ship.get_node_or_null("Hull") as CSGCombiner3D
		if hull:
			var outer := hull.get_node_or_null("Outer") as CSGShape3D
			if outer:
				# Under the plated skin the hull is dark, showing through the
				# grooves; under the fuselage paneling it's painted like it.
				if hull_style == 1:
					outer.material = _dark_metal()
				else:
					outer.material = _mat()
				# The ceiling panels' top is level with the roof and showed
				# through outside: lift the roof 0.15 m above them.
				var box := outer as CSGBox3D
				if box:
					box.size.y += 0.15
					box.position.y += 0.075
			_round_corner(hull)

	# Plated skin over the port hull, in the fuselage's style.
	var r := corner_radius
	var path := PackedVector2Array([Vector2(2.0, HULL_MAX.z), Vector2(HULL_MIN.x, HULL_MAX.z)])
	for i in 13:
		var a := PI * 0.5 * float(i) / 12.0
		# From the port side (facing -x) round to the front (facing -z).
		path.append(Vector2(HULL_MIN.x + r - r * cos(a), HULL_MIN.z + r - r * sin(a)))
	path.append(Vector2(2.0, HULL_MIN.z))
	if hull_style == 0:
		# The fuselage's own surface copied onto the hull's walls and roof.
		var walls := FuselageCladding.walls(path, Vector2(-2.8, 0.0), -0.2, 3.35, 0.42)
		_mesh("HullWalls", walls, Transform3D.IDENTITY)
		var roof := FuselageCladding.roof(Rect2(HULL_MIN.x + r * 0.6, HULL_MIN.z + 0.2,
			2.0 - HULL_MIN.x - r * 0.6, HULL_MAX.z - HULL_MIN.z - 0.4), 3.35)
		_mesh("HullRoof", roof, Transform3D.IDENTITY)
		# A ledge along the seam between the copied bands, as on the fuselage.
		var ledge := HullSkin.new().ledge(path, Vector2(-2.8, 0.0), lerpf(-0.2, 3.35, 0.42), 0.32, 0.7)
		_mesh("HullLedge", ledge, Transform3D.IDENTITY)
	else:
		var skin := HullSkin.new().build(path, Vector2(-2.8, 0.0),
			[[-0.15, 0.6], [0.68, 2.42], [2.5, 3.32]],
			Rect2(HULL_MIN.x + 0.1, HULL_MIN.z + 0.1, 2.0 - HULL_MIN.x - 0.2, HULL_MAX.z - HULL_MIN.z - 0.2), 3.35,
			Vector2(HULL_MIN.x + r, HULL_MIN.z + r), r)
		var skin_mi := _mesh("HullSkin", skin, Transform3D.IDENTITY)
		skin_mi.material_override = null
		skin_mi.set_surface_override_material(0, _mat())
		skin_mi.set_surface_override_material(1, _dark_metal())

	# The model's nose is +Z; turn it to face -Z (forward) and scale to metres.
	var s := fuselage_scale
	var xf := Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * s),
		Vector3(fuselage_x, fuselage_floor_y, nose_z + 0.687 * s))
	_mesh("Fuselage", parts["fuselage"], xf)
	# Close the slots left where the nacelle mounts were cut away.
	for side in [-1.0, 1.0]:
		var plate := BoxMesh.new()
		plate.size = Vector3(0.004, 0.12, 0.76)
		_mesh("SidePlate", plate, xf * Transform3D(Basis.IDENTITY, Vector3(0.092 * side, 0.11, -0.08)))

	# Two big fans at the back, mirrored about the ship's centre line: one
	# under the rear of the fuselage, one under the port hull.
	var fs := 34.0
	var fan_y := 0.6
	var fan_z := 10.2
	for f in [["FanStarboard", "nacelle_rear_right", fuselage_x],
			["FanPort", "nacelle_rear_left", 2.0 * CENTRE_X - fuselage_x]]:
		var m: Mesh = parts[f[1]]
		var c := m.get_aabb().get_center()
		var b := Basis(Vector3.UP, PI).scaled(Vector3.ONE * fs)
		_mesh(f[0], m, Transform3D(b, Vector3(f[2], fan_y, fan_z) - b * c))

	if show_top_wing:
		_build_top_wing()

	# Low wings, in the style of the wing reference (the starboard one from the
	# fuselage's belly, mirrored onto the port hull): a thick swept slab, angular clipped tip with a notch in the
	# trailing edge.
	var rw := PackedVector2Array([Vector2(0, -7.0), Vector2(9.6, 5.6), Vector2(8.8, 7.6),
		Vector2(5.6, 7.2), Vector2(5.1, 8.3), Vector2(0, 7.6)])
	var rw_xf := Transform3D(Basis(Vector3.BACK, deg_to_rad(-4.0)), Vector3(fuselage_x + 2.0, 0.4, 0.0))
	_mesh("WingStarboard", _wing(rw, 0.6, 0.4, 1), rw_xf)
	# The same wing mirrored onto the port hull's side.
	var lw := PackedVector2Array()
	for i in range(rw.size() - 1, -1, -1):
		lw.append(Vector2(-rw[i].x, rw[i].y))
	var lw_xf := Transform3D(Basis(Vector3.BACK, deg_to_rad(4.0)), Vector3(HULL_MIN.x - 0.2, 0.4, 0.0))
	_mesh("WingPort", _wing(lw, 0.6, 0.4, 1), lw_xf)


## A wing like the reference: a thick slab with big chamfered edges, and on
## top a raised inner plate stepped in from the edge, split into a few large
## sections (`axis` 0: split across z, 1: split across x).
func _wing(outline: PackedVector2Array, thick: float, bevel: float, axis: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	_slab_into(st, outline, thick, bevel, 0.0)
	var inner_set := Geometry2D.offset_polygon(outline, -(bevel + 0.9), Geometry2D.JOIN_MITER)
	if inner_set.size() > 0:
		var inner: PackedVector2Array = inner_set[0]
		# Cut the inner plate into three big sections with 0.12 m gaps.
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p in inner:
			lo = lo.min(p)
			hi = hi.max(p)
		var cuts := [0.0, 0.42, 0.7, 1.0]
		for i in 3:
			var a: float = cuts[i]
			var b: float = cuts[i + 1]
			var band: PackedVector2Array
			if axis == 0:
				var z0 := lerpf(lo.y, hi.y, a) + (0.06 if i > 0 else -1.0)
				var z1 := lerpf(lo.y, hi.y, b) - (0.06 if i < 2 else -1.0)
				band = PackedVector2Array([Vector2(lo.x - 1, z0), Vector2(hi.x + 1, z0), Vector2(hi.x + 1, z1), Vector2(lo.x - 1, z1)])
			else:
				var x0 := lerpf(lo.x, hi.x, a) + (0.06 if i > 0 else -1.0)
				var x1 := lerpf(lo.x, hi.x, b) - (0.06 if i < 2 else -1.0)
				band = PackedVector2Array([Vector2(x0, lo.y - 1), Vector2(x1, lo.y - 1), Vector2(x1, hi.y + 1), Vector2(x0, hi.y + 1)])
			for piece in Geometry2D.intersect_polygons(inner, band):
				if Geometry2D.is_polygon_clockwise(piece):
					piece.reverse()
				_slab_into(st, piece, 0.16, 0.06, thick * 0.5 + 0.08)
	st.generate_normals()
	return st.commit()


## Adds a slab (outline extruded to `thick`, edges chamfered inward by
## `bevel`) centred at height y.
func _slab_into(st: SurfaceTool, outline: PackedVector2Array, thick: float, bevel: float, y: float) -> void:
	var tris := Geometry2D.triangulate_polygon(outline)
	if tris.is_empty():
		return
	var inset := Geometry2D.offset_polygon(outline, -bevel, Geometry2D.JOIN_MITER)
	var cap: PackedVector2Array = inset[0] if inset.size() > 0 else outline
	var cap_tris := Geometry2D.triangulate_polygon(cap)
	var h := thick * 0.5
	for yy in [y + h, y - h]:
		for i in range(0, cap_tris.size(), 3):
			for k in 3:
				var c := cap[cap_tris[i + k]]
				st.add_vertex(Vector3(c.x, yy, c.y))
	# Chamfer band from the outline (at mid-height) to the caps.
	var n := outline.size()
	for i in n:
		var j := (i + 1) % n
		var o0 := outline[i]
		var o1 := outline[j]
		var c0 := _nearest(cap, o0)
		var c1 := _nearest(cap, o1)
		for yy in [y + h, y - h]:
			for v in [Vector3(o0.x, y, o0.y), Vector3(o1.x, y, o1.y), Vector3(c1.x, yy, c1.y),
					Vector3(o0.x, y, o0.y), Vector3(c1.x, yy, c1.y), Vector3(c0.x, yy, c0.y)]:
				st.add_vertex(v)


## The top wing's outline (x outboard = negative, z from the front edge back).
func _top_wing(span: float, chord: float) -> ArrayMesh:
	var flat := span * 0.27
	var tip_v := chord * 0.45
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(-flat, 0)])
	for i in range(1, 13):
		var t := float(i) / 12.0
		# Concave sweep (as sketched): drops steeply from the flat front, then
		# flattens out towards the tip.
		pts.append(Vector2(-flat - (span - flat) * t, tip_v * (1.0 - pow(1.0 - t, 1.8))))
	pts.append(Vector2(-span, chord))
	pts.append(Vector2(0, chord))
	pts.reverse()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var m := _wing(pts, 0.7, 0.45, 0)
	st.append_from(m, 0, Transform3D.IDENTITY)
	# Thick rim along the trailing edge.
	_slab_into(st, PackedVector2Array([Vector2(-span + 0.2, chord - 1.1), Vector2(-0.2, chord - 1.1),
		Vector2(-0.2, chord - 0.1), Vector2(-span + 0.2, chord - 0.1)]), 1.0, 0.2, 0.0)
	# Heavy mount block at the inner front corner (the hatched strip).
	_slab_into(st, PackedVector2Array([Vector2(-1.4, 0.2), Vector2(-0.1, 0.2), Vector2(-0.1, chord * 0.22), Vector2(-1.4, chord * 0.22)]),
		1.5, 0.25, 0.25)
	st.generate_normals()
	return st.commit()


## A hydraulic ram between two points: fat cylinder at the bottom, thinner
## polished rod sliding out of it, a knuckle at each end.
func _ram(n: String, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var len := d.length()
	var basis := Basis(Quaternion(Vector3.UP, d.normalized()))
	var body := CylinderMesh.new()
	body.top_radius = 0.34
	body.bottom_radius = 0.36
	body.height = len * 0.58
	_mesh(n + "Body", body, Transform3D(basis, a + d * 0.29))
	var rod := CylinderMesh.new()
	rod.top_radius = 0.16
	rod.bottom_radius = 0.16
	rod.height = len * 0.5
	var rod_mat := StandardMaterial3D.new()
	rod_mat.albedo_color = Color(0.72, 0.74, 0.76)
	rod_mat.metallic = 0.8
	rod_mat.roughness = 0.3
	var mi := _mesh(n + "Rod", rod, Transform3D(basis, a + d * 0.72))
	mi.material_override = rod_mat
	for p in [a, b]:
		var k := SphereMesh.new()
		k.radius = 0.36
		k.height = 0.72
		_mesh(n + "Knuckle", k, Transform3D(Basis.IDENTITY, p))
		# Clevis block / base plate the knuckle sits in.
		var plate := BoxMesh.new()
		plate.size = Vector3(1.0, 0.3, 1.0)
		var up := 1.0 if p == a else -1.0
		_mesh(n + "Mount", plate, Transform3D(Basis.IDENTITY, p - Vector3(0, 0.3 * up, 0)))


func _dark_metal() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.17, 0.18, 0.2)
	m.metallic = 0.6
	m.roughness = 0.55
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## A prism: side profile (z, y) extruded across x from x0 to x1.
func _prism_x(prof: Array, x0: float, x1: float) -> ArrayMesh:
	var a: Array[Vector3] = []
	var b: Array[Vector3] = []
	for q: Vector2 in prof:
		a.append(Vector3(x0, q.y, q.x))
		b.append(Vector3(x1, q.y, q.x))
	return _prism(a, b)


## A prism: front profile (x, y) extruded along z from z0 to z1.
func _prism_z(prof: Array, z0: float, z1: float) -> ArrayMesh:
	var a: Array[Vector3] = []
	var b: Array[Vector3] = []
	for q: Vector2 in prof:
		a.append(Vector3(q.x, q.y, z0))
		b.append(Vector3(q.x, q.y, z1))
	return _prism(a, b)


func _prism(a: Array[Vector3], b: Array[Vector3]) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n := a.size()
	for i in n:
		var j := (i + 1) % n
		for v in [a[i], b[i], b[j], a[i], b[j], a[j]]:
			st.add_vertex(v)
	for ring in [a, b]:
		for i in range(1, n - 1):
			for v in [ring[0], ring[i], ring[i + 1]]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _build_top_wing() -> void:
	# Top wing (the user's sketch): straight inner edge along the hull, short
	# flat front, a concave curved leading edge sweeping back to a shorter
	# outer tip, straight trailing edge with a thick rim, and a heavy mount
	# block at the inner front corner. Tilted down to port on hydraulic rams.
	var span := 12.0
	var chord := 19.0
	var root_x := 1.6
	# Hinged along the fuselage's port shoulder, on pylons, tilted down to port.
	var hinge := Vector3(root_x + 0.3, 8.2, -8.4)
	var wing_xf := Transform3D(Basis(Vector3.BACK, deg_to_rad(wing_tilt)), hinge + Vector3(-0.3, 0.0, 0.0))
	_mesh("TopWing", _top_wing(span, chord), wing_xf)
	# Hinge barrel along the wing's root, with brackets down to the fuselage.
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.42
	barrel.bottom_radius = 0.42
	barrel.height = chord - 1.0
	_mesh("WingHinge", barrel, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), hinge + Vector3(0, 0, chord * 0.5)))
	# Pylons from the fuselage's top up to the hinge, leaning in slightly.
	var pylon_h := hinge.y - 5.7
	for k in 4:
		var bz := hinge.z + 1.5 + k * (chord - 3.0) / 3.0
		var br := BoxMesh.new()
		br.size = Vector3(0.8, pylon_h + 0.4, 0.9)
		_mesh("HingePylon", br, Transform3D(Basis(Vector3.BACK, deg_to_rad(-12.0)), Vector3(hinge.x + 0.45, hinge.y - pylon_h * 0.5, bz)))
	# Rams: from the raised deck / roof up to the wing's underside, with base
	# plates and clevis blocks.
	for rp in [[-3.6, 4.0], [-9.0, 11.0], [-3.6, 15.5], [-9.0, 16.5]]:
		var wing_pt := wing_xf * Vector3(rp[0], -0.45, rp[1])
		var base_y := 4.35 if rp[0] > -4.0 else 3.4
		var roof_pt := Vector3(wing_pt.x + 1.2, base_y + 0.15, wing_pt.z - 0.6)
		_ram("Ram", roof_pt, wing_pt)


## A worn-paint material with its own wear seed.
func _mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _paint
	_seed += 1.0
	m.set_shader_parameter("seed", _seed)
	return m


## Rounds the hull's front-left (port, forward) corner: a cutter that removes
## the corner block outside a quarter cylinder.
func _round_corner(hull: CSGCombiner3D) -> void:
	var r := corner_radius
	var cutter := CSGCombiner3D.new()
	cutter.name = "RoundedCorner"
	cutter.operation = CSGShape3D.OPERATION_SUBTRACTION
	var blk := CSGBox3D.new()
	blk.size = Vector3(r + 0.2, HULL_MAX.y - HULL_MIN.y + 0.4, r + 0.2)
	blk.position = Vector3(HULL_MIN.x + r * 0.5 - 0.1, (HULL_MIN.y + HULL_MAX.y) * 0.5, HULL_MIN.z + r * 0.5 - 0.1)
	cutter.add_child(blk)
	var cyl := CSGCylinder3D.new()
	cyl.radius = r
	cyl.height = blk.size.y + 0.2
	cyl.sides = 24
	cyl.position = Vector3(HULL_MIN.x + r, blk.position.y, HULL_MIN.z + r)
	cyl.operation = CSGShape3D.OPERATION_SUBTRACTION
	cutter.add_child(cyl)
	hull.add_child(cutter)


## Outline (x across, z along; nose at -z) of a curved "A": a pointed nose,
## two legs, and an arch cut out of the trailing edge between them.
func _a_shape(span: float, length: float, leg: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var hw := span * 0.5
	var hl := length * 0.5
	pts.append(Vector2(0.0, -hl))                       # nose
	# Leading edges curve out to the rear corners.
	for i in range(1, 7):
		var t := float(i) / 6.0
		pts.append(Vector2(hw * sin(t * PI * 0.5), -hl + length * t * t * 0.55 + length * t * 0.45))
	pts.append(Vector2(hw * (1.0 - leg * 0.9), hl))     # inner corner of right leg
	# Arch between the legs, rising to about the middle of the wing.
	var arch_w := hw * (1.0 - leg * 0.9)
	for i in range(1, 12):
		var a := PI * float(i) / 12.0
		pts.append(Vector2(arch_w * cos(a), hl - length * 0.45 * sin(a)))
	pts.append(Vector2(-arch_w, hl))
	for i in range(6, 0, -1):
		var t := float(i) / 6.0
		pts.append(Vector2(-hw * sin(t * PI * 0.5), -hl + length * t * t * 0.55 + length * t * 0.45))
	return pts


func _nearest(poly: PackedVector2Array, p: Vector2) -> Vector2:
	var best := poly[0]
	for q in poly:
		if q.distance_squared_to(p) < best.distance_squared_to(p):
			best = q
	return best


func _mesh(n: String, m: Mesh, xf: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = m
	mi.transform = xf
	mi.material_override = _mat()
	add_child(mi)
	return mi
