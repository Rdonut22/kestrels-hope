@tool
extends Node3D

## Blockout test for the reworked Kestrel exterior (the user's sketches):
## the stripped marauder fuselage around the cockpit, kitchen and lounge on
## the starboard (+X) side, the existing hull to port (front-left corner
## rounded), two big fan turbines mirrored at the back, a tilted A-shaped top
## wing on struts and a low swept wing to starboard. Every part wears the same
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
				outer.material = _mat()
				# The ceiling panels' top is level with the roof and showed
				# through outside: lift the roof 0.15 m above them.
				var box := outer as CSGBox3D
				if box:
					box.size.y += 0.15
					box.position.y += 0.075
			_round_corner(hull)

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

	# Top wing on struts: a curved "A" seen from above (pointed nose, two legs
	# with an arch cut out between them at the back), tilted to rise towards
	# the fuselage and overhanging the port side.
	var tilt := deg_to_rad(7.0)
	var wing_xf := Transform3D(Basis(Vector3.BACK, tilt), Vector3(-4.6, 4.75, 1.0))
	_mesh("TopWing", _slab(_a_shape(14.5, 19.0, 0.42), 0.5), wing_xf)
	for p in [Vector3(-8.5, 0, 6.5), Vector3(-1.0, 0, 6.5), Vector3(-4.6, 0, -4.0)]:
		# Struts from the hull roof (y = 3.2) up to the wing's underside.
		var under := (wing_xf * Vector3(p.x - wing_xf.origin.x, 0, 0)).y - 0.25
		# (the roof is now at y = 3.35)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.18
		cm.bottom_radius = 0.26
		cm.height = maxf(under - 3.35, 0.3)
		_mesh("Strut", cm, Transform3D(Basis.IDENTITY, Vector3(p.x, 3.35 + cm.height * 0.5, p.z)))

	# Low starboard wing from the fuselage's belly: swept, tapering to a point.
	var rw := PackedVector2Array([Vector2(0, -6.5), Vector2(0, 7.5), Vector2(7.5, 8.5), Vector2(8.5, 6.8)])
	var rw_xf := Transform3D(Basis(Vector3.BACK, deg_to_rad(-4.0)), Vector3(fuselage_x + 2.0, 0.4, 0.0))
	_mesh("WingStarboard", _slab(rw, 0.35), rw_xf)


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


## Extrudes an outline (x, z) into a flat-shaded slab of the given thickness,
## its top and bottom edges slightly bevelled inward.
func _slab(outline: PackedVector2Array, thick: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var tris := Geometry2D.triangulate_polygon(outline)
	var inset := Geometry2D.offset_polygon(outline, -minf(thick * 0.6, 0.3))
	var cap: PackedVector2Array = inset[0] if inset.size() > 0 else outline
	var cap_tris := Geometry2D.triangulate_polygon(cap)
	var h := thick * 0.5
	for y in [h, -h]:
		for i in range(0, cap_tris.size(), 3):
			var a := cap[cap_tris[i]]
			var b := cap[cap_tris[i + 1]]
			var c := cap[cap_tris[i + 2]]
			var tri := [Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y)]
			if y < 0.0:
				tri.reverse()
			for v in tri:
				st.add_vertex(v)
	# Side band: from the outline at mid-height to the inset caps above/below.
	var n := outline.size()
	var m := cap.size()
	for i in n:
		var j := (i + 1) % n
		var o0 := outline[i]
		var o1 := outline[j]
		# Nearest cap points for a simple bevel band.
		var c0 := _nearest(cap, o0)
		var c1 := _nearest(cap, o1)
		for y in [h, -h]:
			var quad := [Vector3(o0.x, 0, o0.y), Vector3(o1.x, 0, o1.y), Vector3(c1.x, y, c1.y), Vector3(c0.x, y, c0.y)]
			var t1 := [quad[0], quad[1], quad[2]]
			var t2 := [quad[0], quad[2], quad[3]]
			if y < 0.0:
				t1.reverse()
				t2.reverse()
			for v in t1 + t2:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


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
