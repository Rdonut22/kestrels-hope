class_name CockpitFitout
extends RefCounted

## Fits out the cockpit in the nose (ship/nose_cockpit.gd builds its shell)
## after the approved narrow-cockpit concept: dark steel ribs arching over
## the tunnel, a heavy frame round the windshield, a roof window, a small
## pedestal between the seats with three short levers in slots, the pilot's
## yoke and instrument binnacle, the co-pilot's navigation display, floor
## grates, warm amber practical lights, a bronze grab rail and pipe runs.
##
## Ship space: forward is -Z, floor y 0. The seats stay where they are
## (pilot x 3.3, co-pilot x 4.7, z -11.8: tools/build_scenes.gd, moved
## forward by kestrel_exterior.gd). Every part is its own child of
## "CockpitFitout" so each can be edited or hidden on its own.

const RIB_DEPTH := 0.1      # how far a rib stands in from the shell
const RIB_WIDTH := 0.16     # along the tunnel
const RIB_CHAMFER := 0.025
## The roof window between these stations (its middle rib splits it in two).
const ROOF_Z := Vector2(-12.7, -11.3)
const ROOF_X := Vector2(3.45, 4.55)
## The pedestal between the seats and its three lever slots.
const PEDESTAL := Vector3(4.0, 0.0, -12.3)       # floor centre
const PEDESTAL_SIZE := Vector3(0.65, 0.48, 0.8)  # the console's body (w, h, depth)
## The user's console model and how big it stands: 0.42 takes it to about
## 0.65 m wide, 0.8 m deep, 0.71 m to the lever tips (between the seats).
const CONSOLE_PATH := "res://ship/models/center_console/center_console.glb"
const CONSOLE_SCALE := 0.42
const CONSOLE_HALF := Vector3(0.776, 0.846, 0.952)  # the model's half size
const SLOT_X := [-0.085, 0.0, 0.085]
const SLOT_LEN := 0.34
const LEVER_TRAVEL := 0.12  # each way from the slot's middle
## Seats and their screens.
const PILOT_X := 3.3
const COPILOT_X := 4.7
const DASH_FRONT_Z := -12.7   # the dash console's face toward the seats
const DASH_TOP := 0.62       # the lowered dash block the dashboard unit sits on
## The user's dashboard unit (Meshy, decimated): radar screen in front of
## the pilot, terrain map in front of the co-pilot. 1.37 takes its 1.9
## model units to about 2.6 m across.
const DASHBOARD_PATH := "res://ship/models/dashboard/dashboard.glb"
const DASHBOARD_SCALE := 1.37
const DASHBOARD_HALF := Vector3(0.95, 0.255, 0.24)  # the model's half size
const DASHBOARD_Z := -12.86   # its centre, along the tunnel
## The user's under-dash unit (Meshy, decimated) fills the space under the
## dashboard: from the dash wall (z -13.4) to the dash face, floor to
## DASH_TOP, stretched a little to fit (x 1.47, y 1.58, z 1.3).
## The user's canopy frame (Meshy, decimated): turned to face forward, its
## raked front at the windshield's foot, stretched to the windshield's
## width and up to the roof window.
const CANOPY_PATH := "res://ship/models/canopy/canopy.glb"
const CANOPY_SCALE := Vector3(1.53, 1.94, 1.47)
const CANOPY_HALF := Vector3(0.951, 0.447, 0.714)
## The user's flight yoke (Meshy, decimated): 0.21 takes its 1.9 model
## units to about 0.4 m across the grips. Its display faces the pilot (+Z).
const YOKE_PATH := "res://ship/models/yoke/yoke.glb"
const YOKE_SCALE := 0.21
const YOKE_HALF := Vector3(0.952, 0.669, 0.343)
const YOKE_Y := 0.86
const YOKE_Z := -12.3     # its centre: pushed out ahead of the dash face
const UNDER_DASH_PATH := "res://ship/models/under_dash/under_dash.glb"
const UNDER_DASH_SCALE := Vector3(1.47, 1.58, 1.3)
const UNDER_DASH_MIN := Vector3(-0.952, -0.197, -0.258)   # the model's bounds
const UNDER_DASH_MAX := Vector3(0.951, 0.196, 0.284)

var ext: Node3D
var root: Node3D
var mats := {}
var crashed := false


func build(exterior: Node3D, rings: Array, is_crashed: bool) -> void:
	ext = exterior
	crashed = is_crashed
	root = Node3D.new()
	root.name = "CockpitFitout"
	ext.add_child(root)
	_materials()
	_ribs(rings)
	_windshield_frame(rings[rings.size() - 1])
	_roof_window(rings)
	_canopy()
	_pedestal()
	_yoke()
	_screens()
	_dashboard()
	_lights(rings)
	_rail_and_pipes(rings)
	_hooks()
	# Plates, hatches, consoles, floor and light (ship/cockpit_detail.gd).
	CockpitDetail.new().build(self, rings)


# ---------- materials ----------

func _materials() -> void:
	# Structural framing (ribs, window frames): clean, smooth, shiny metal
	# in the colour of the user's reference photo.
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.61, 0.58, 0.59)
	# Only part metallic: the cockpit has little bright to reflect, and a
	# fully metallic surface would read dark instead of silver.
	steel.metallic = 0.35
	steel.roughness = 0.22
	steel.metallic_specular = 0.8
	mats["steel"] = steel
	var steel_edge := steel.duplicate() as StandardMaterial3D
	steel_edge.albedo_color = Color(0.32, 0.31, 0.29)
	steel_edge.roughness = 0.35
	mats["steel_edge"] = steel_edge
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.55, 0.38, 0.2)
	bronze.metallic = 0.85
	bronze.roughness = 0.38
	mats["bronze"] = bronze
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.78, 0.78, 0.76)
	chrome.metallic = 1.0
	chrome.roughness = 0.15
	mats["chrome"] = chrome
	var cable_red := StandardMaterial3D.new()
	cable_red.albedo_color = Color(0.35, 0.08, 0.06)
	cable_red.roughness = 0.6
	mats["cable_red"] = cable_red
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.06, 0.06, 0.06)
	rubber.roughness = 0.8
	mats["rubber"] = rubber
	# Aged ivory housings: the corridor shader's painted panel (surface 3).
	var ivory := (load("res://ship/materials/corridor_wall.tres") as ShaderMaterial).duplicate() as ShaderMaterial
	ivory.set_shader_parameter("surface", 3)
	ivory.set_shader_parameter("panel_color", Color("B9AE98"))
	mats["ivory"] = ivory
	var slot := StandardMaterial3D.new()
	slot.albedo_color = Color(0.02, 0.02, 0.02)
	slot.roughness = 0.9
	mats["slot"] = slot
	var amber := StandardMaterial3D.new()
	amber.albedo_color = Color(1.0, 0.62, 0.25)
	amber.emission_enabled = true
	amber.emission = Color(1.0, 0.55, 0.2)
	amber.emission_energy_multiplier = 0.0 if crashed else 1.6
	mats["amber"] = amber
	var grate := ShaderMaterial.new()
	grate.shader = load("res://ship/grate.gdshader")
	grate.set_shader_parameter("color", Color(0.3, 0.25, 0.19))
	grate.set_shader_parameter("slat_spacing", 0.05)
	mats["grate"] = grate
	var glass := ShaderMaterial.new()
	glass.shader = load("res://ship/galley_glass.gdshader")
	mats["glass"] = glass


func _part(name: String) -> Node3D:
	var n := Node3D.new()
	n.name = name
	root.add_child(n)
	return n


func _mesh(parent: Node, name: String, mesh: Mesh, xf := Transform3D.IDENTITY, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.transform = xf
	if mat:
		mi.material_override = mat
	parent.add_child(mi)
	return mi


func _box(parent: Node, name: String, centre: Vector3, size: Vector3, mat: Material, basis := Basis()) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mesh(parent, name, bm, Transform3D(basis, centre), mat)


func _cyl(parent: Node, name: String, a: Vector3, b: Vector3, r: float, mat: Material, sides := 16) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = a.distance_to(b)
	cm.radial_segments = sides
	cm.rings = 1
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var bas := Basis(side, up, side.cross(up))
	return _mesh(parent, name, cm, Transform3D(bas, (a + b) / 2.0), mat)


# ---------- the shell's structure ----------

## The part of a ring above the floor, in order round the arch.
static func arch(ring: PackedVector3Array) -> PackedVector3Array:
	var n := ring.size()
	var start := 0
	for k in n:
		if ring[k].y <= 0.02 and ring[(k + 1) % n].y > 0.02:
			start = (k + 1) % n
			break
	var out := PackedVector3Array()
	for i in n:
		var p := ring[(start + i) % n]
		if p.y <= 0.02:
			break
		out.append(p)
	return out


## Inward direction (toward the tunnel's axis) at a ring point.
static func inward(p: Vector3) -> Vector3:
	var d := Vector2(NoseCockpit.CENTRE.x - p.x, NoseCockpit.CENTRE.y - p.y)
	return Vector3(d.x, d.y, 0.0).normalized()


## Sweeps a chamfered rectangular section along an arch: `depth` inward
## from the shell, `width` along the arch's normal `along` (the tunnel axis,
## or the windshield plane's normal).
func _sweep_frame(mb: ProcMesh.Builder, mat: String, pts: PackedVector3Array, ins: Array, along: Vector3, depth: float, width: float, cham: float) -> void:
	var prof := [Vector2(0.0, -width / 2), Vector2(depth - cham, -width / 2), Vector2(depth, -width / 2 + cham),
		Vector2(depth, width / 2 - cham), Vector2(depth - cham, width / 2), Vector2(0.0, width / 2)]
	var at := func(i: int, j: int) -> Vector3:
		var p: Vector2 = prof[j]
		return pts[i] + (ins[i] as Vector3) * p.x + along * p.y
	for i in pts.size() - 1:
		for j in prof.size() - 1:
			var a: Vector3 = at.call(i, j)
			var b: Vector3 = at.call(i, j + 1)
			var c: Vector3 = at.call(i + 1, j + 1)
			var d: Vector3 = at.call(i + 1, j)
			var mid: Vector2 = ((prof[j] as Vector2) + (prof[j + 1] as Vector2)) / 2.0
			var out: Vector3 = (ins[i] as Vector3) * (mid.x - depth * 0.5) + along * mid.y
			mb.quad(mat, a, b, c, d, out)
	# Feet: close both ends.
	for i in [0, pts.size() - 1]:
		var cap := []
		for j in prof.size():
			cap.append(at.call(i, j))
		var tan := (pts[1] - pts[0]) if i == 0 else (pts[i] - pts[i - 1])
		var out: Vector3 = -tan if i == 0 else tan
		for j in range(1, prof.size() - 1):
			mb.tri(mat, cap[0], cap[j], cap[j + 1], out)


func _ribs(rings: Array) -> void:
	var node := _part("Ribs")
	var mb := ProcMesh.Builder.new()
	# One at every fuselage station but the last (its top would stand
	# outside the raked windshield; the windshield frame is the front rib).
	for r in range(1, rings.size() - 2):
		var pts := arch(rings[r])
		if pts.size() < 3:
			continue
		var ins := []
		for p in pts:
			ins.append(inward(p))
		_sweep_frame(mb, "steel", pts, ins, Vector3(0, 0, 1), RIB_DEPTH, RIB_WIDTH, RIB_CHAMFER)
		# A darker base plate at each foot.
		for p in [pts[0], pts[pts.size() - 1]]:
			ProcMesh.box(mb, "steel_edge", Vector3(p.x, 0.06, p.z) + inward(p) * 0.06, Vector3(0.16, 0.12, 0.22))
	_mesh(node, "RibMesh", mb.commit(mats))
	# The passage mouth: a heavier portal frame.
	var mouth := arch(rings[0])
	if mouth.size() > 2:
		var ins := []
		for p in mouth:
			ins.append(inward(p))
		var mb2 := ProcMesh.Builder.new()
		_sweep_frame(mb2, "steel", mouth, ins, Vector3(0, 0, 1), 0.14, 0.22, 0.035)
		_mesh(node, "PortalFrame", mb2.commit(mats))


func _windshield_frame(front: PackedVector3Array) -> void:
	var node := _part("WindshieldFrame")
	var pts := PackedVector3Array()
	for p in front:
		if p.y >= NoseCockpit.WS_Y - 0.01:
			pts.append(p)
	# Order round from one side to the other (the ring wraps through k = 0).
	var arc := PackedVector3Array()
	var n := front.size()
	var start := 0
	for k in n:
		if front[k].y < NoseCockpit.WS_Y - 0.01 and front[(k + 1) % n].y >= NoseCockpit.WS_Y - 0.01:
			start = (k + 1) % n
	for i in n:
		var p := front[(start + i) % n]
		if p.y < NoseCockpit.WS_Y - 0.01:
			break
		arc.append(p)
	if arc.size() < 3:
		return
	var plane_n := Vector3(0, -NoseCockpit.WS_RAKE, 1).normalized()  # into the cabin, off the glass
	var ins := []
	for p in arc:
		var d := inward(p)
		ins.append((d - plane_n * d.dot(plane_n)).normalized())
	var mb := ProcMesh.Builder.new()
	_sweep_frame(mb, "steel", arc, ins, plane_n, 0.16, 0.14, 0.03)
	# A thick sill along the bottom of the glass.
	var l := arc[arc.size() - 1]
	var r := arc[0]
	var y := NoseCockpit.WS_Y + 0.04
	ProcMesh.box(mb, "steel", Vector3((l.x + r.x) / 2.0, y, NoseCockpit.plane_z(y) + 0.07), Vector3(absf(l.x - r.x), 0.08, 0.16))
	# Mullion covers: chunky bars over the steel ones.
	var up := Vector3(0, 1, NoseCockpit.WS_RAKE).normalized()
	for x in NoseCockpit.MULLION_X:
		var top := 0.0
		for p in arc:
			if absf(p.x - x) < 0.35:
				top = maxf(top, p.y)
		var y0 := NoseCockpit.WS_Y
		var y1 := top - 0.1
		var a := Vector3(x, y0, NoseCockpit.plane_z(y0))
		var b := Vector3(x, y1, NoseCockpit.plane_z(y1))
		var len := a.distance_to(b)
		var bas := Basis(Vector3.RIGHT, up, Vector3.RIGHT.cross(up))
		ProcMesh.box(mb, "steel", Vector3.ZERO, Vector3(0.11, len, 0.09), Transform3D(bas, (a + b) / 2.0 + plane_n * 0.05))
	_mesh(node, "Frame", mb.commit(mats))


## Where the shell's ceiling is at (x, z): the highest arch point near x
## on the nearest ring.
static func ceiling_at(rings: Array, x: float, z: float) -> float:
	var best := 1e9
	var ring: PackedVector3Array = rings[0]
	for r in rings:
		var rr: PackedVector3Array = r
		if absf(rr[0].z - z) < best:
			best = absf(rr[0].z - z)
			ring = rr
	var top := 0.0
	var near := 1e9
	for p in ring:
		if p.y > 1.3 and absf(p.x - x) < near:
			near = absf(p.x - x)
			top = p.y
	return top


## Roof window: two panes between the forward stations, either side of the
## middle rib, in a deep steel frame. (nose_cockpit.gd leaves the shell and
## the fuselage open here.)
func _roof_window(rings: Array) -> void:
	var node := _part("RoofWindow")
	var mb := ProcMesh.Builder.new()
	var y := 10.0
	for x in [ROOF_X.x, (ROOF_X.x + ROOF_X.y) / 2.0, ROOF_X.y]:
		for z in [-12.0, ROOF_Z.y]:
			y = minf(y, ceiling_at(rings, x, z))
	y -= 0.02
	# It runs forward to meet the top of the windshield, so the glass is
	# continuous over the front.
	var front := NoseCockpit.plane_z(y + 0.12)
	var cx := (ROOF_X.x + ROOF_X.y) / 2.0
	var cz := (front + ROOF_Z.y) / 2.0
	var w := ROOF_X.y - ROOF_X.x
	var d := ROOF_Z.y - front
	var g := QuadMesh.new()
	g.size = Vector2(w, d)
	g.orientation = PlaneMesh.FACE_Y
	var gm := _mesh(node, "Glass", g, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(cx, y + 0.12, cz)), mats["glass"])
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var g2 := _mesh(node, "GlassTop", g, Transform3D(Basis(), Vector3(cx, y + 0.12, cz)), mats["glass"])
	g2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The frame: a deep box round the opening, from the shell up to the
	# glass, and a bar down the middle.
	var t := 0.12
	ProcMesh.box(mb, "steel", Vector3(cx, y + 0.04, ROOF_Z.y + t / 2 - 0.06), Vector3(w + 2 * t, 0.2, t))
	ProcMesh.box(mb, "steel", Vector3(ROOF_X.x - t / 2 + 0.06, y + 0.04, cz + t / 2), Vector3(t, 0.2, d + t))
	ProcMesh.box(mb, "steel", Vector3(ROOF_X.y + t / 2 - 0.06, y + 0.04, cz + t / 2), Vector3(t, 0.2, d + t))
	# A cross bar over the rib between the two panes.
	ProcMesh.box(mb, "steel", Vector3(cx, y + 0.05, -12.0), Vector3(w, 0.16, 0.1))
	_mesh(node, "Frame", mb.commit(mats))


## The canopy frame takes over from the built window frames (the glass
## stays).
func _canopy() -> void:
	var node := _part("Canopy")
	var c: Node3D = (load(CANOPY_PATH) as PackedScene).instantiate()
	c.name = "Frame"
	c.rotation.y = PI
	c.scale = CANOPY_SCALE
	c.position = Vector3(4.0, NoseCockpit.WS_Y + CANOPY_HALF.y * CANOPY_SCALE.y,
		NoseCockpit.WS_Z + CANOPY_HALF.z * CANOPY_SCALE.z)
	node.add_child(c)
	for path in ["WindshieldFrame", "RoofWindow/Frame"]:
		var old := root.get_node_or_null(path) as Node3D
		if old:
			old.visible = false
	# The shell's own steel window posts and sill (nose_cockpit.gd): the
	# canopy has its own.
	for n in ext.get_children():
		if n is Node3D and (String(n.name).contains("Mullion") or String(n.name).contains("WindshieldSill")):
			(n as Node3D).visible = false


# ---------- controls ----------

## The low pedestal between the seats: ivory housing, dark top plate with
## three slots running front to back, amber lamps at their heads.
func _pedestal() -> void:
	var node := _part("Pedestal")
	var s := PEDESTAL_SIZE
	var c := PEDESTAL
	var body := StaticBody3D.new()
	body.name = "Collision"
	node.add_child(body)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = s
	cs.shape = shape
	cs.position = c + Vector3(0, s.y / 2, 0)
	body.add_child(cs)
	# The user's control console (Meshy, decimated): its tall end against
	# the dash, its three levers leaning back toward the seats. Stands on
	# the floor; the model is centred on its origin.
	var console: Node3D = (load(CONSOLE_PATH) as PackedScene).instantiate()
	console.name = "Console"
	console.scale = Vector3.ONE * CONSOLE_SCALE
	console.position = c + Vector3(0, CONSOLE_HALF.y * CONSOLE_SCALE, 0)
	node.add_child(console)


## The pedestal top: tilted up toward the dash.
static func _top_basis() -> Basis:
	return Basis(Vector3.RIGHT, -0.12)


static func top_centre() -> Vector3:
	return PEDESTAL + Vector3(0, PEDESTAL_SIZE.y + 0.005, 0)


## Where lever i sits; t -1 (pulled back, toward the seats) .. 1 (pushed
## forward).
static func lever_transform(i: int, t: float) -> Transform3D:
	var top := _top_basis()
	return Transform3D(top, top_centre() + top * Vector3(SLOT_X[i], 0.012, -t * LEVER_TRAVEL))


## A short chunky lever handle like a compact hilt: machined rings, a
## knurled grip, a bronze pommel and an amber emitter cap. Origin at the
## slot, handle standing up out of it.
static func make_lever(m: Dictionary) -> Node3D:
	var lever := Node3D.new()
	var parts := [
		[0.0, 0.03, 0.009, "steel"],      # stem in the slot
		[0.03, 0.04, 0.022, "bronze"],    # lower ring
		[0.04, 0.1, 0.019, "rubber"],     # grip
		[0.1, 0.112, 0.022, "bronze"],    # upper ring
		[0.112, 0.135, 0.02, "steel_edge"],
		[0.135, 0.142, 0.016, "amber"],   # emitter cap
	]
	for p in parts:
		var cm := CylinderMesh.new()
		cm.top_radius = p[2]
		cm.bottom_radius = p[2]
		cm.height = p[1] - p[0]
		cm.radial_segments = 14
		cm.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = m[p[3]]
		mi.position.y = (p[0] + p[1]) / 2.0
		lever.add_child(mi)
	# Knurling: thin raised bands on the grip.
	for k in 5:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.0185
		tm.outer_radius = 0.0215
		tm.rings = 12
		tm.ring_segments = 4
		var mi := MeshInstance3D.new()
		mi.mesh = tm
		mi.material_override = m["steel_edge"]
		mi.position.y = 0.05 + k * 0.012
		lever.add_child(mi)
	return lever


## The pilot's yoke: the user's flight yoke model (Meshy, decimated),
## pushed out from the under-dash toward the pilot on a hydraulic cylinder
## (a dark barrel, a polished piston rod, a collar where it meets the
## yoke), with a few wires drooping from its back into the dash.
func _yoke() -> void:
	var node := _part("Yoke")
	var y := YOKE_Y
	var back := YOKE_Z - YOKE_HALF.z * YOKE_SCALE     # the yoke's rear face
	var dash := DASH_FRONT_Z + 0.02
	var unit: Node3D = (load(YOKE_PATH) as PackedScene).instantiate()
	unit.name = "Unit"
	unit.scale = Vector3.ONE * YOKE_SCALE
	unit.position = Vector3(PILOT_X, y, YOKE_Z)
	node.add_child(unit)
	# Hydraulic cylinder: mounting flange on the dash, barrel, gland, rod.
	var mid := lerpf(dash, back, 0.55)
	_cyl(node, "Flange", Vector3(PILOT_X, y, dash - 0.01), Vector3(PILOT_X, y, dash + 0.015), 0.06, mats["steel_edge"], 16)
	_cyl(node, "Barrel", Vector3(PILOT_X, y, dash), Vector3(PILOT_X, y, mid), 0.038, mats["rubber"], 18)
	_cyl(node, "BarrelBand", Vector3(PILOT_X, y, lerpf(dash, mid, 0.5) - 0.01), Vector3(PILOT_X, y, lerpf(dash, mid, 0.5) + 0.01), 0.041, mats["bronze"], 18)
	_cyl(node, "Gland", Vector3(PILOT_X, y, mid - 0.01), Vector3(PILOT_X, y, mid + 0.015), 0.043, mats["steel_edge"], 18)
	_cyl(node, "Rod", Vector3(PILOT_X, y, mid), Vector3(PILOT_X, y, back + 0.01), 0.018, mats["chrome"], 14)
	_cyl(node, "RodEnd", Vector3(PILOT_X, y, back - 0.015), Vector3(PILOT_X, y, back + 0.012), 0.03, mats["steel_edge"], 14)
	# A hydraulic line from the barrel's top back into the dash.
	_wire(node, "HydraulicLine", [Vector3(PILOT_X + 0.03, y + 0.04, mid - 0.03), Vector3(PILOT_X + 0.05, y + 0.07, lerpf(dash, mid, 0.4)),
		Vector3(PILOT_X + 0.06, y + 0.05, dash + 0.005)], 0.008, mats["bronze"])
	# Wires from the yoke's back, sagging down into the under-dash.
	var cols := [mats["rubber"], mats["cable_red"], mats["rubber"]]
	for k in 3:
		var x := PILOT_X - 0.06 + k * 0.06
		var start := Vector3(x, y - 0.05, back + 0.005)
		var end := Vector3(x * 0.6 + PILOT_X * 0.4, y - 0.2 - k * 0.02, dash + 0.005)
		var sag := (start + end) / 2.0 + Vector3(0, -0.1 - k * 0.02, 0)
		_wire(node, "Wire%d" % k, [start, start.lerp(sag, 0.6), sag, sag.lerp(end, 0.5), end], 0.009, cols[k])


## A cable through the given points, as short straight pieces.
func _wire(parent: Node, name: String, pts: Array, r: float, mat: Material) -> void:
	for i in pts.size() - 1:
		_cyl(parent, "%s_%d" % [name, i], pts[i], pts[i + 1], r, mat, 8)


func _display(mode: int, aspect: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://ship/cockpit_display.gdshader")
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("aspect", aspect)
	m.set_shader_parameter("brightness", 0.0 if crashed else 0.9)
	m.set_shader_parameter("ink", Color(0.35, 0.85, 0.65) if mode != 1 else Color(0.35, 0.8, 0.9))
	return m


## Clears the dash for the stations (cockpit_detail.gd builds them): the
## overhead console moves out of the roof window, the old flat screens go.
func _screens() -> void:
	# The overhead console hung where the roof window is now: move it back
	# a bay, between the ribs.
	var canopy := ext.get_parent().get_node_or_null("Canopy") as Node3D if ext.get_parent() else null
	if canopy:
		for n in ["OverheadPost", "OverheadConsole", "OverheadScreen"]:
			var part := canopy.get_node_or_null(n) as Node3D
			if part:
				part.position.z += 0.62
	# The old flat amber screens lay under the new binnacles.
	var ship := ext.get_parent()
	if ship:
		for n in ["ConsoleScreenLeft", "ConsoleScreenRight"]:
			var old := ship.get_node_or_null(n) as Node3D
			if old:
				old.visible = false


## The dashboard: the old dash block drops to DASH_TOP and the user's
## dashboard unit (screens, gauges, buttons) sits on it across the cockpit.
func _dashboard() -> void:
	var ship := ext.get_parent()
	var block := ship.get_node_or_null("CockpitFurniture/Console") as CSGBox3D if ship else null
	if block:
		# The under-dash unit takes its place (a hidden CSG child drops out
		# of the combiner, collision included: a box stands in for that).
		block.visible = false
	var node := _part("Dashboard")
	var body := StaticBody3D.new()
	body.name = "Collision"
	node.add_child(body)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.8, DASH_TOP, 0.7)
	cs.shape = shape
	cs.position = Vector3(4.0, DASH_TOP / 2.0, -13.05)
	body.add_child(cs)
	var under: Node3D = (load(UNDER_DASH_PATH) as PackedScene).instantiate()
	under.name = "UnderDash"
	under.scale = UNDER_DASH_SCALE
	under.position = Vector3(4.0, -UNDER_DASH_MIN.y * UNDER_DASH_SCALE.y, -13.4 - UNDER_DASH_MIN.z * UNDER_DASH_SCALE.z)
	node.add_child(under)
	var unit: Node3D = (load(DASHBOARD_PATH) as PackedScene).instantiate()
	unit.name = "Unit"
	unit.scale = Vector3.ONE * DASHBOARD_SCALE
	unit.position = Vector3(4.0, DASH_TOP + DASHBOARD_HALF.y * DASHBOARD_SCALE - 0.02, DASHBOARD_Z)
	node.add_child(unit)


# ---------- floor, light, rail ----------

func _lights(rings: Array) -> void:
	var node := _part("Lights")
	# Amber recess strips in the ceiling between the ribs, and low strips
	# along both walls just above the floor.
	for r in range(1, rings.size() - 2):
		var za: float = (rings[r] as PackedVector3Array)[0].z
		var zb: float = (rings[r + 1] as PackedVector3Array)[0].z
		var zc := (za + zb) / 2.0
		if zc < ROOF_Z.y and zc > ROOF_Z.x:
			continue
		var y := ceiling_at(rings, 4.0, zc) - 0.02
		_box(node, "CeilingRecess%d" % r, Vector3(4.0, y, zc), Vector3(0.5, 0.02, 0.1), mats["slot"])
		_box(node, "CeilingStrip%d" % r, Vector3(4.0, y - 0.012, zc), Vector3(0.42, 0.01, 0.05), mats["amber"])
	var floor_y := 0.04
	for side in [-1.0, 1.0]:
		var x := 0.0
		for p in (rings[2] as PackedVector3Array):
			if p.y < 0.05 and (p.x - 4.0) * side > (x - 4.0) * side:
				x = p.x
		x -= side * 0.04
		_box(node, "FloorStrip%d" % int(side), Vector3(x, floor_y, -11.35), Vector3(0.025, 0.02, 2.4), mats["amber"])
	if not crashed:
		for z in [-10.6, -12.2]:
			var l := OmniLight3D.new()
			l.name = "Amber%d" % int(-z * 10)
			l.light_color = Color(1.0, 0.68, 0.35)
			l.light_energy = 0.45
			l.omni_range = 2.4
			l.position = Vector3(4.0, ceiling_at(rings, 4.0, z) - 0.25, z)
			node.add_child(l)
		var low := OmniLight3D.new()
		low.name = "AmberLow"
		low.light_color = Color(1.0, 0.6, 0.3)
		low.light_energy = 0.25
		low.omni_range = 1.8
		low.position = Vector3(4.0, 0.25, -11.2)
		node.add_child(low)


func _rail_and_pipes(rings: Array) -> void:
	var node := _part("RailAndPipes")
	# Wall x at a height on a ring, on one side.
	var wall_x := func(ring: PackedVector3Array, y: float, side: float) -> float:
		var best := 1e9
		var bx := 4.0
		for p in ring:
			if (p.x - 4.0) * side > 0.0 and absf(p.y - y) < best:
				best = absf(p.y - y)
				bx = p.x
		return bx
	# Bronze grab rail on the pilot's side wall, on stand-off brackets.
	var za: float = (rings[1] as PackedVector3Array)[0].z
	var zb: float = (rings[3] as PackedVector3Array)[0].z
	var xa: float = wall_x.call(rings[1], 1.15, -1.0) + 0.16
	var xb: float = wall_x.call(rings[3], 1.15, -1.0) + 0.16
	_cyl(node, "GrabRail", Vector3(xa, 1.15, za - 0.15), Vector3(xb, 1.15, zb + 0.15), 0.018, mats["bronze"])
	for t in [0.0, 1.0]:
		var p := Vector3(lerpf(xa, xb, t), 1.15, lerpf(za - 0.15, zb + 0.15, t))
		_cyl(node, "RailBracket%d" % int(t), p, p - Vector3(0.16, 0, 0), 0.012, mats["steel"])
	# Two pipes along the co-pilot's upper wall, through the ribs.
	for k in 2:
		var y := 1.85 + k * 0.1
		var x0: float = wall_x.call(rings[1], y, 1.0) - 0.15 - k * 0.03
		var x1: float = wall_x.call(rings[rings.size() - 2], y, 1.0) - 0.15 - k * 0.03
		var z0: float = (rings[0] as PackedVector3Array)[0].z
		var z1: float = (rings[rings.size() - 2] as PackedVector3Array)[0].z
		_cyl(node, "Pipe%d" % k, Vector3(x0, y, z0), Vector3(x1, y, z1), 0.03 - k * 0.008, mats["bronze"] if k == 0 else mats["steel_edge"])


# ---------- interaction hooks ----------

func _hooks() -> void:
	var node := _part("Hooks")
	var script: Script = load("res://interactables/cockpit_hook.gd")
	var add := func(id: String, pos: Vector3, prompt: String, rng: float) -> void:
		var h := Node3D.new()
		h.set_script(script)
		h.name = id.to_pascal_case()
		h.set("hook_id", id)
		h.set("prompt", prompt)
		h.set("interact_range", rng)
		h.position = pos
		node.add_child(h)
	add.call("copilot_seat", Vector3(COPILOT_X, 0.0, -11.8), "Sit in the co-pilot seat", 1.2)
	add.call("pilot_instruments", Vector3(PILOT_X - 0.08, DASH_TOP + 0.35, DASHBOARD_Z), "Pilot instruments", 1.4)
	add.call("copilot_display", Vector3(COPILOT_X - 0.08, DASH_TOP + 0.35, DASHBOARD_Z), "Navigation display", 1.4)
	for i in SLOT_X.size():
		add.call("lever_%d" % i, lever_transform(i, 0.0).origin, "Lever %d" % (i + 1), 1.0)
