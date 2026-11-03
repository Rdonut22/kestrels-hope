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

## Fuselage size: model units -> metres (across / along, and up).
@export var fuselage_scale := 30.0
@export var fuselage_scale_y := 30.0
## Fuselage placement: centred on the cockpit / kitchen (x 4.0). Its hollow
## nose is the cockpit: a flight deck FLIGHT_DECK_Y above the main deck,
## under the model's own canopy, up a few steps from the kitchen door.
@export var fuselage_x := 4.0
@export var nose_z := -16.21
@export var fuselage_floor_y := -2.0
## Radius of the rounded front-left corner of the port hull.
@export var corner_radius := 3.5
@export var show_interior := true
## Window frame bars on the canopy and the porthole frames (off for now).
@export var show_window_frames := false
## Hull cladding: 0 = the fuselage's own paneling copied on, 1 = plated skin.
@export_enum("Fuselage paneling", "Plated skin") var hull_style := 0
## The hinged top wing on its pylons and rams (off for now).
@export var show_top_wing := false
## Angle (degrees) the port split wings open up / down.
@export var port_split := 22.0
## Tilt of the top wing (degrees, outer tip down).
@export var wing_tilt := 16.0

# Port hull box (from tools/build_scenes.gd): x -7.7..5.9, z -9.9..9.5.
const HULL_MIN := Vector3(-7.7, -0.2, -9.9)
const HULL_MAX := Vector3(5.9, 3.2, 9.5)
# Ship centre line for mirroring the fans: halfway across hull + fuselage.
const CENTRE_X := -0.15
# The flight deck (the old cockpit, raised into the fuselage's nose).
const FLIGHT_DECK_Y := 1.35
const DECK_Z := Vector2(-8.8, -13.3)      # back edge, front edge
const STAIR_Z := Vector2(-7.05, -8.8)
# Everything of the old cockpit that moves up onto the flight deck.
const COCKPIT_NODES := ["CockpitFurniture", "ConsoleScreenLeft", "ConsoleScreenRight", "PilotChair",
	"CopilotChair", "CockpitPanel", "Lights/Cockpit", "Lights/CanopyFill", "Interactables/ShipComputer",
	"Interactables/PilotSeat", "FlexHoses/CockpitHoses", "Clutter/BarrelC"]
# Interior rooms (tools/build_scenes.gd), floor 0 to ceiling 3: exterior
# geometry poking into them is removed. [x0, x1, z0, z1]
const ROOMS := [[2.4, 5.6, -6.8, -3.4], [-2.3, 2.0, -5.6, 9.2],
	[-2.6, 1.8, -9.6, -5.9], [-6.0, -2.6, -4.4, -1.6], [-6.3, -2.6, -1.3, 3.4], [-7.4, -2.6, 3.7, 7.3]]
# The round lounge: centre (x, z) and radius, on the starboard half.
const LOUNGE := Vector3(2.4, 1.6, 4.75)
# The one porthole with a room behind it: the gunner's station (y, z).
const GUNNER_WINDOW := Vector2(2.0, 5.5)

var _paint: Shader
var _plating: Texture2D = preload("res://ship/textures/hull_plating.png")
var _grime: Texture2D = preload("res://ship/textures/hull_grime.png")
# Venator colour tiles: greys for the hull, red for the wings' tops.
var _colors: Array[Texture2D] = [preload("res://ship/textures/hull_color_1026.png"),
	preload("res://ship/textures/hull_color_1038.png"), preload("res://ship/textures/hull_color_1039.png")]
var _red: Texture2D = preload("res://ship/textures/hull_color_1004_red.png")
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
			_raise_cockpit(ship, hull)
			# The lounge's round outer wall shows through the fuselage's
			# window cut-out: paint it like the hull.
			var lounge_outer := hull.get_node_or_null("LoungeOuter") as CSGShape3D
			if lounge_outer:
				lounge_outer.material = _mat()
			# The gunner's station is against the port wall: a real window
			# through to it (glass and frame added with the portholes).
			var gw := CSGBox3D.new()
			gw.name = "Window_Gunner"
			gw.size = Vector3(1.0, 0.62, 1.12)
			gw.position = Vector3(HULL_MIN.x + 0.2, GUNNER_WINDOW.x, GUNNER_WINDOW.y)
			gw.operation = CSGShape3D.OPERATION_SUBTRACTION
			hull.add_child(gw)

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
		walls = _cut(walls, Transform3D.IDENTITY, [AABB(Vector3(HULL_MIN.x - 2.0, GUNNER_WINDOW.x - 0.31,
			GUNNER_WINDOW.y - 0.56), Vector3(2.4, 0.62, 1.12))])
		_two_tone(_mesh("HullWalls", walls, Transform3D.IDENTITY))
		var roof := FuselageCladding.roof(Rect2(HULL_MIN.x + r * 0.6, HULL_MIN.z + 0.2,
			2.0 - HULL_MIN.x - r * 0.6, HULL_MAX.z - HULL_MIN.z - 0.4), 3.35)
		_two_tone(_mesh("HullRoof", roof, Transform3D.IDENTITY))
		_details(walls, roof)
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
	var xf := Transform3D(Basis(Vector3.UP, PI).scaled(Vector3(s, fuselage_scale_y, s)),
		Vector3(fuselage_x, fuselage_floor_y, nose_z + 0.687 * s))
	# Window openings: where the lounge's curved window band runs along the
	# starboard side, the fuselage skin is cut away so it shows (and the
	# lounge looks out).
	var fus := _cut(parts["fuselage"], xf, [AABB(Vector3(5.4, 0.85, -2.6), Vector3(3.0, 1.85, 8.4))])
	var fus_mi := _mesh("Fuselage", fus, xf)
	_two_tone(fus_mi)
	# You walk around inside its nose now.
	fus_mi.create_trimesh_collision()
	if show_interior:
		_flight_deck()
	# Close the slots left where the nacelle mounts were cut away.
	# (in world space; the starboard one leaves a gap for the lounge window).
	var plate_c := xf * Vector3(0.0, 0.11, -0.08)
	var half_len := 0.38 * s
	for side in [-1.0, 1.0]:
		var px: float = fuselage_x + 0.092 * s * side
		var z0: float = plate_c.z - half_len
		var z1: float = plate_c.z + half_len
		var spans := [[z0, z1]] if side < 0.0 else [[z0, -2.6], [5.8, z1]]
		for sp in spans:
			var plate := BoxMesh.new()
			plate.size = Vector3(0.12, 0.12 * fuselage_scale_y, sp[1] - sp[0])
			_mesh("SidePlate", plate, Transform3D(Basis.IDENTITY, Vector3(px, plate_c.y, (sp[0] + sp[1]) * 0.5)))

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
	# fuselage's belly; mirrored copies split top and bottom on the port hull): a thick swept slab, angular clipped tip with a notch in the
	# trailing edge.
	var rw := PackedVector2Array([Vector2(0, -7.0), Vector2(9.6, 5.6), Vector2(8.8, 7.6),
		Vector2(5.6, 7.2), Vector2(5.1, 8.3), Vector2(0, 7.6)])
	var rw_xf := Transform3D(Basis(Vector3.BACK, deg_to_rad(-4.0)), Vector3(fuselage_x + 2.0, 0.4, 0.0))
	_red_paint(_mesh("WingStarboard", _wing(rw, 0.6, 0.4, 1), rw_xf))
	# The same wing mirrored onto the port hull's side.
	var lw := PackedVector2Array()
	for i in range(rw.size() - 1, -1, -1):
		lw.append(Vector2(-rw[i].x, rw[i].y))
	# Port side: a split pair (the user's sketch), one off the top edge angled
	# up and out, one off the bottom edge angled down and out, each held off
	# the hull by two short struts.
	for w in [["WingPortUpper", 3.7, -port_split], ["WingPortLower", -0.5, port_split]]:
		var wxf := Transform3D(Basis(Vector3.BACK, deg_to_rad(w[2])), Vector3(HULL_MIN.x - 1.0, w[1], 0.0))
		_red_paint(_mesh(w[0], _wing(lw, 0.6, 0.4, 1), wxf))
		for sz in [-2.5, 4.5]:
			var on_wing: Vector3 = wxf * Vector3(-0.9, 0.0, sz)
			var on_hull := Vector3(HULL_MIN.x + 0.2, w[1], sz)
			var strut := CylinderMesh.new()
			strut.top_radius = 0.22
			strut.bottom_radius = 0.22
			strut.height = on_wing.distance_to(on_hull) + 0.4
			var dir := (on_wing - on_hull).normalized()
			_mesh(w[0] + "Strut", strut, Transform3D(Basis(Quaternion(Vector3.UP, dir)), (on_wing + on_hull) * 0.5))
	# Nav lights: red on the port wing tips, green on the starboard one.
	_nav_light(_find("WingPortUpper"), Color(1.0, 0.15, 0.1))
	_nav_light(_find("WingPortLower"), Color(1.0, 0.15, 0.1))
	_nav_light(_find("WingStarboard"), Color(0.2, 1.0, 0.35))


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


## Windows and components on the port hull: a row of framed portholes set
## into the wall, and on the roof a sensor dome, antenna masts, a dish, vent
## boxes and pipe runs. Each sits on the clad surface (found from its mesh).
func _details(walls: Mesh, roof: Mesh) -> void:
	var wv := _verts(walls)
	var rv := _verts(roof)
	var glass := _clear_glass()
	# Portholes along the straight port wall, upper band.
	# Only the gunner's station is against the wall, so it gets the one real
	# window; the rest along the wall are blanked off with cover plates.
	var zs := [-4.5, -1.9, 0.7, 3.0, GUNNER_WINDOW.y, 8.0]
	for z in zs:
		var y := 2.35 if z != GUNNER_WINDOW.y else GUNNER_WINDOW.x
		var out_x := HULL_MIN.x
		for v in wv:
			if absf(v.z - z) < 0.7 and absf(v.y - y) < 0.5:
				out_x = minf(out_x, v.x)
		_porthole(Vector3(out_x, y, z), glass if z == GUNNER_WINDOW.y else null)
	# Roof components.
	var dark := _dark_metal()
	var dome := SphereMesh.new()
	dome.radius = 0.9
	dome.height = 1.0
	dome.is_hemisphere = true
	_place_on_roof(rv, "SensorDome", dome, Vector3(-5.2, 0, 5.5), 0.0)
	for a in [[-6.6, -3.0, 3.2], [-6.2, -2.2, 2.2], [-1.2, 7.8, 2.6]]:
		var mast := CylinderMesh.new()
		mast.top_radius = 0.04
		mast.bottom_radius = 0.09
		mast.height = a[2]
		_place_on_roof(rv, "Antenna", mast, Vector3(a[0], 0, a[1]), a[2] * 0.5)
		var tip := SphereMesh.new()
		tip.radius = 0.1
		tip.height = 0.2
		_place_on_roof(rv, "AntennaTip", tip, Vector3(a[0], 0, a[1]), a[2])
	var dish := CylinderMesh.new()
	dish.top_radius = 1.0
	dish.bottom_radius = 0.25
	dish.height = 0.35
	var dmi := _place_on_roof(rv, "Dish", dish, Vector3(-3.0, 0, -5.5), 0.6)
	dmi.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(30.0), 0.0)
	for vb in [Vector3(-6.0, 0, 0.5), Vector3(-0.5, 0, -2.5)]:
		var box := BoxMesh.new()
		box.size = Vector3(1.4, 0.6, 2.2)
		_place_on_roof(rv, "VentBox", box, vb, 0.3)
		for k in 5:
			var slat := BoxMesh.new()
			slat.size = Vector3(1.2, 0.06, 0.12)
			var sm := _place_on_roof(rv, "VentSlat", slat, vb + Vector3(0, 0, -0.8 + k * 0.4), 0.63)
			sm.material_override = dark
	for px in [-7.0, -6.6]:
		var pipe := CylinderMesh.new()
		pipe.top_radius = 0.12
		pipe.bottom_radius = 0.12
		pipe.height = 12.0
		var pmi := _place_on_roof(rv, "Pipe", pipe, Vector3(px, 0, 1.5), 0.12)
		pmi.rotation = Vector3(PI * 0.5, 0, 0)
		pmi.material_override = dark


## A porthole on the port wall (facing -x): a chamfered dark-metal frame
## standing out of the hull, the glass set back inside it, a centre bar and
## four bolts.
func _porthole(at: Vector3, glass: Material) -> void:
	# The frame's well runs back to the hull wall (through the cladding).
	var well_back := HULL_MIN.x - at.x + 0.05
	var w := 1.3
	var h := 0.8
	var t := 0.05
	var frame_mat := _frame_metal()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var outer := PackedVector2Array([Vector2(-w * 0.5, -h * 0.5 + 0.12), Vector2(-w * 0.5 + 0.12, -h * 0.5),
		Vector2(w * 0.5 - 0.12, -h * 0.5), Vector2(w * 0.5, -h * 0.5 + 0.12), Vector2(w * 0.5, h * 0.5 - 0.12),
		Vector2(w * 0.5 - 0.12, h * 0.5), Vector2(-w * 0.5 + 0.12, h * 0.5), Vector2(-w * 0.5, h * 0.5 - 0.12)])
	var inner := Geometry2D.offset_polygon(outer, -t, Geometry2D.JOIN_MITER)[0]
	# Frame ring: front face (bevelled inward), outer and inner sides.
	var n := outer.size()
	for i in n:
		var j := (i + 1) % n
		var o0 := outer[i]
		var o1 := outer[j]
		var i0 := _nearest(inner, o0)
		var i1 := _nearest(inner, o1)
		var face := [Vector3(-0.2, o0.y, o0.x), Vector3(-0.2, o1.y, o1.x), Vector3(-0.26, i1.y, i1.x), Vector3(-0.26, i0.y, i0.x)]
		var side := [Vector3(0.0, o0.y, o0.x), Vector3(0.0, o1.y, o1.x), Vector3(-0.2, o1.y, o1.x), Vector3(-0.2, o0.y, o0.x)]
		var well := [Vector3(-0.26, i0.y, i0.x), Vector3(-0.26, i1.y, i1.x), Vector3(well_back, i1.y, i1.x), Vector3(well_back, i0.y, i0.x)]
		for q in [face, side, well]:
			for v in [q[0], q[1], q[2], q[0], q[2], q[3]]:
				st.add_vertex(v)
	st.generate_normals()
	var fm := MeshInstance3D.new()
	fm.name = "PortholeFrame"
	fm.mesh = st.commit()
	fm.material_override = frame_mat
	fm.position = at
	fm.visible = show_window_frames
	add_child(fm)
	# Glass, set back in the frame.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in inner:
		lo = lo.min(p)
		hi = hi.max(p)
	var pane := QuadMesh.new()
	pane.size = Vector2(hi.x - lo.x, hi.y - lo.y)
	var pm := MeshInstance3D.new()
	pm.name = "PortholeGlass" if glass else "PortholeCover"
	pm.mesh = pane
	if glass:
		pm.material_override = glass
	else:
		# Blanked off: a painted cover plate.
		var cover := BoxMesh.new()
		cover.size = Vector3(0.06, hi.y - lo.y, hi.x - lo.x)
		pm.mesh = cover
		pm.material_override = _mat()
	pm.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5) if glass else Basis.IDENTITY, at + Vector3(-0.09, 0, 0))
	add_child(pm)
	# Centre bar and bolts.
	var bar := BoxMesh.new()
	bar.size = Vector3(0.03, hi.y - lo.y, 0.03)
	var bm := MeshInstance3D.new()
	bm.mesh = bar
	bm.material_override = frame_mat
	bm.position = at + Vector3(-0.12, 0, 0)
	bm.visible = show_window_frames
	add_child(bm)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var bolt := CylinderMesh.new()
		bolt.top_radius = 0.035
		bolt.bottom_radius = 0.035
		bolt.height = 0.05
		var b := MeshInstance3D.new()
		b.mesh = bolt
		b.material_override = frame_mat
		b.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), at + Vector3(-0.23, c.y * (h * 0.5 - 0.07), c.x * (w * 0.5 - 0.07)))
		b.visible = show_window_frames
		add_child(b)


func _verts(m: Mesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in m.get_surface_count():
		out.append_array(m.surface_get_arrays(i)[Mesh.ARRAY_VERTEX])
	return out


## Places a mesh on the clad roof at (x, z): its base on the highest roof
## point there, lifted by `lift`.
func _place_on_roof(rv: PackedVector3Array, n: String, m: Mesh, at: Vector3, lift: float) -> MeshInstance3D:
	var top := 3.35
	for v in rv:
		if absf(v.x - at.x) < 0.8 and absf(v.z - at.z) < 0.8:
			top = maxf(top, v.y)
	return _mesh(n, m, Transform3D(Basis.IDENTITY, Vector3(at.x, top + lift, at.z)))


func _find(n: String) -> MeshInstance3D:
	return get_node_or_null(n) as MeshInstance3D


## A small glowing light at the outermost point of a wing.
func _nav_light(wing: MeshInstance3D, col: Color) -> void:
	if not wing:
		return
	var far := Vector3.ZERO
	var best := -1.0
	for v in _verts(wing.mesh):
		var wv: Vector3 = wing.transform * v
		var d := absf(wv.x)
		if d > best:
			best = d
			far = wv
	var bulb := SphereMesh.new()
	bulb.radius = 0.18
	bulb.height = 0.36
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 3.0
	var mi := _mesh("NavLight", bulb, Transform3D(Basis.IDENTITY, far))
	mi.material_override = m


## Paint on surface 0, glass on surface 1 (the recessed windows / hatches)
## and on surface 2 (the cockpit canopy, with frame bars).
func _two_tone(mi: MeshInstance3D) -> void:
	if mi.mesh.get_surface_count() < 2:
		return
	var paint := mi.material_override
	mi.material_override = null
	mi.set_surface_override_material(0, paint)
	mi.set_surface_override_material(1, _window_glass())
	if mi.mesh.get_surface_count() > 2:
		var canopy := _clear_glass()
		canopy.set_shader_parameter("mullion_spacing", Vector2(0.045, 0.055))
		# Thin metal frame bars.
		canopy.set_shader_parameter("mullion_width", 0.045)
		if not show_window_frames:
			canopy.set_shader_parameter("mullion_spacing", Vector2.ZERO)
		canopy.set_shader_parameter("interior_glow", 0.15)
		mi.set_surface_override_material(2, canopy)


func _window_glass() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://ship/window_glass.gdshader")
	return m


## Glass you can see through (canopy, real windows).
func _clear_glass() -> ShaderMaterial:
	var m := _window_glass()
	m.shader = preload("res://ship/window_glass_clear.gdshader")
	return m


## Bare brushed steel for window frames.
func _frame_metal() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.61, 0.63)
	m.metallic = 0.9
	m.roughness = 0.35
	m.metallic_specular = 0.6
	m.anisotropy_enabled = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


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


## The old cockpit goes: its box walls, nose, floor and glass canopy are
## removed (the fuselage's hollow nose replaces them) and everything in it
## moves up onto the flight deck.
func _raise_cockpit(ship: Node3D, hull: CSGCombiner3D) -> void:
	for n in ["NoseLower", "CockpitNose", "FloorNose", "Cockpit", "CanopyRearFrame", "CockpitHullBevel"]:
		var c := hull.get_node_or_null(n)
		if c:
			c.free()
	# The hull box's forward end beside the kitchen (z -9.9..-7.05) opens up.
	var open := CSGBox3D.new()
	open.name = "CockpitOpen"
	open.size = Vector3(4.0, 3.8, 2.9)
	open.position = Vector3(4.0, 1.6, -8.5)
	open.operation = CSGShape3D.OPERATION_SUBTRACTION
	hull.add_child(open)
	var canopy := ship.get_node_or_null("Canopy")
	if canopy:
		canopy.free()
	for path in COCKPIT_NODES:
		var nd := ship.get_node_or_null(path) as Node3D
		if nd:
			nd.position.y += FLIGHT_DECK_Y
	# The computer bench stood where the stairs go: move it beside them.
	var bench := ship.get_node_or_null("CockpitFurniture/ComputerBench") as Node3D
	var comp := ship.get_node_or_null("Interactables/ShipComputer") as Node3D
	for nd in [bench, comp]:
		if nd:
			nd.position.z -= 1.4


## The flight deck floor inside the fuselage's nose and the steps up to it
## from the kitchen door, painted and with collision.
func _flight_deck() -> void:
	var body := StaticBody3D.new()
	body.name = "FlightDeck"
	add_child(body)
	var deck_mat := _dark_metal()
	deck_mat.albedo_color = Color(0.36, 0.36, 0.37)
	# Floor: tapers with the nose.
	var hw_back := 2.2
	var hw_front := 1.6
	var y := FLIGHT_DECK_Y
	var pts := PackedVector2Array([Vector2(fuselage_x - hw_back, DECK_Z.x), Vector2(fuselage_x + hw_back, DECK_Z.x),
		Vector2(fuselage_x + hw_front, DECK_Z.y), Vector2(fuselage_x - hw_front, DECK_Z.y)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	_slab_into(st, pts, 0.2, 0.02, y - 0.1)
	st.generate_normals()
	var fm := MeshInstance3D.new()
	fm.name = "DeckFloor"
	fm.mesh = st.commit()
	fm.material_override = deck_mat
	body.add_child(fm)
	var fc := CollisionShape3D.new()
	fc.shape = fm.mesh.create_convex_shape()
	body.add_child(fc)
	# Steps from the kitchen door (floor 0) up to the deck.
	var n := 6
	var run := (STAIR_Z.x - STAIR_Z.y) / n
	for i in n:
		var top := y * float(i + 1) / n
		var b := BoxMesh.new()
		b.size = Vector3(2.0, top, run)
		var mi := MeshInstance3D.new()
		mi.name = "Step%d" % i
		mi.mesh = b
		mi.material_override = deck_mat
		mi.position = Vector3(fuselage_x, top * 0.5, STAIR_Z.x - run * (i + 0.5))
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = b.size
		cs.shape = bs
		cs.position = mi.position
		body.add_child(cs)


## A copy of a mesh without the triangles whose centre (in world space,
## via xf) falls inside any of the boxes. Keeps the surfaces.
func _cut(m: Mesh, xf: Transform3D, boxes: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	for sidx in m.get_surface_count():
		var a := m.surface_get_arrays(sidx)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nrm = a[Mesh.ARRAY_NORMAL]
		var idx = a[Mesh.ARRAY_INDEX]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n: int = (idx.size() if idx != null else v.size()) / 3
		for t in n:
			var ids := [t * 3, t * 3 + 1, t * 3 + 2]
			if idx != null:
				ids = [idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]]
			var c: Vector3 = xf * ((v[ids[0]] + v[ids[1]] + v[ids[2]]) / 3.0)
			var inside := _in_room(c)
			for b: AABB in boxes:
				if b.has_point(c):
					inside = true
					break
			if inside:
				continue
			for i in ids:
				if nrm != null:
					st.set_normal(nrm[i])
				st.add_vertex(v[i])
		st.commit(out)
	return out


func _overlaps_rooms(bb: AABB) -> bool:
	if bb.end.y < 0.0 or bb.position.y > 3.1:
		return false
	for r in ROOMS + [[LOUNGE.x, LOUNGE.x + LOUNGE.z, LOUNGE.y - LOUNGE.z, LOUNGE.y + LOUNGE.z]]:
		if bb.end.x > r[0] and bb.position.x < r[1] and bb.end.z > r[2] and bb.position.z < r[3]:
			return true
	return false


## True for a point inside one of the interior rooms (with a small margin).
func _in_room(p: Vector3) -> bool:
	# Margin covers the rooms' walls (0.3 m) too.
	if not show_interior or p.y < -0.05 or p.y > 3.15:
		return false
	for i in ROOMS.size():
		var r: Array = ROOMS[i]
		# Cockpit / kitchen sit snug in the fuselage: no wall margin there.
		var m := 0.05 if i < 1 else 0.3
		if p.x > r[0] - m and p.x < r[1] + m and p.z > r[2] - m and p.z < r[3] + m:
			return true
	if p.x > LOUNGE.x and Vector2(p.x - LOUNGE.x, p.z - LOUNGE.y).length() < LOUNGE.z + 0.05:
		return true
	return false


## Venator red on a part (the wings).
func _red_paint(mi: MeshInstance3D) -> void:
	var m := mi.material_override as ShaderMaterial
	if m:
		m.set_shader_parameter("hull_color", _red)


## A worn-paint material with its own wear seed.
func _mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _paint
	_seed += 1.0
	m.set_shader_parameter("seed", _seed)
	m.set_shader_parameter("plating", _plating)
	m.set_shader_parameter("grime_map", _grime)
	# Venator colours instead of the white / blue paint.
	m.set_shader_parameter("use_hull_color", true)
	m.set_shader_parameter("hull_color", _colors[int(_seed) % _colors.size()])
	m.set_shader_parameter("grime_strength", 0.2)
	m.set_shader_parameter("plating_tone", 0.2)
	m.set_shader_parameter("rust", 0.3)
	m.set_shader_parameter("streaks", 0.4)
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
	# Nothing of the outside may show inside a room.
	if show_interior and m is ArrayMesh or m is PrimitiveMesh:
		var bb := xf * m.get_aabb()
		if _overlaps_rooms(bb):
			m = _cut(m, xf, [])
	mi.mesh = m
	mi.transform = xf
	mi.material_override = _mat()
	add_child(mi)
	return mi
