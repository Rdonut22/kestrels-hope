@tool
class_name CorridorDressing
extends Node3D

## The corridor's (central deck's) interior design, added to the ship scenes
## by tools/build_scenes.gd: floor and ceiling finishes, recessed wall panel
## framing, door surrounds, a vent, a cable channel, a maintenance hatch, a
## utility locker, floor access panels, a walnut handrail and accent, labels,
## and recessed light fixtures. Purely visual: no collision, so movement,
## doors and interactions are untouched.
##
## The wall finish itself is the corridor_wall material on the hull's "Deck"
## room (ship/materials/corridor_wall.tres, ship/corridor.gdshader). Floor
## and ceiling here use the same material with another `surface`.
##
## crashed: day one after the crash: the fixtures are dark, the hatch hangs
## open on its hinge and the replacement panel is missing.
##
## Corridor frame (ship space): x -2.3..2.0, z -5.6..9.2, floor 0, ceiling ~3.

@export var crashed := false

const X_L := -2.3
const X_R := 2.0
const Z_F := -5.6
const Z_A := 9.2
# Solid stretches of each wall (between doorways and other openings), z ranges.
const LEFT_SPANS := [[-5.55, -4.25], [-1.75, -0.8], [3.0, 9.15]]
const RIGHT_SPANS := [[-3.75, -0.45], [2.45, 6.5]]
# Doorways [wall x, centre z, half width] for the surrounds and hand wear.
const DOORS := [[X_L, -3.0, 1.156]]  # (engineering is an open padded doorway now)
# Luminous ceiling panels in a few places only (z ranges; beams at z -1.6,
# 3.2, 5.4, 8.9): by the quarters, at the lounge entrance, near the ramp.
# Between them the ceiling is dark rusted steel with pipe runs.
const CEILING_PANELS := [[-4.7, -2.5], [-0.2, 2.4], [5.9, 7.9]]
const PANEL_W := 1.5

const GUNMETAL := Color(0.27, 0.28, 0.3)  # gunmetal structure
const IVORY := Color("C5B9A5")
const ALUMINIUM := Color("8E958F")    # brushed steel
const WALNUT := Color("957456")
const LIGHT := Color("F0D6AD")
const AMBER := Color("E6B978")
const CYAN := Color("A4C6C4")
const RED := Color("A8493D")
const OLIVE := Color("6B725D")

var _wall: ShaderMaterial
var _mats := {}


func _ready() -> void:
	_wall = load("res://ship/materials/corridor_wall.tres")
	_floor_and_ceiling()
	_panel_framing()
	_door_surrounds()
	_utilities()
	_walnut()
	_labels()
	_fixtures()
	_niche_and_storage()
	_tool_cart()
	_rug()
	_mat_edge()
	_sconces()


# ---------- materials ----------

func _surface(kind: int, color := Color(0, 0, 0, 0)) -> ShaderMaterial:
	var m := _wall.duplicate() as ShaderMaterial
	m.set_shader_parameter("surface", kind)
	if color.a > 0.0:
		m.set_shader_parameter("panel_color", color)
	return m


func _std(key: String, color: Color, rough: float, metal: float, emit := 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


func _gunmetal() -> Material:
	if not _mats.has("worn_dark"):
		_mats["worn_dark"] = _surface(7)
	return _mats["worn_dark"]


func _alu() -> StandardMaterial3D:
	return _std("alu", ALUMINIUM, 0.35, 0.85)


# ---------- helpers ----------

func _box(n: String, center: Vector3, size: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = center
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## A box against a side wall: z0..z1 along it, y0..y1, standing `depth` out
## from the wall surface.
func _on_wall(n: String, wall_x: float, z0: float, z1: float, y0: float, y1: float, depth: float, mat: Material) -> MeshInstance3D:
	var inward := 1.0 if wall_x < 0.0 else -1.0
	return _box(n, Vector3(wall_x + inward * depth * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5),
		Vector3(depth, y1 - y0, z1 - z0), mat)


# ---------- floor & ceiling ----------

func _floor_and_ceiling() -> void:
	# Thin finishes over the shared ship floor / ceiling, corridor only.
	# Built in ship coordinates (identity transform) for the shader.
	_slab("CorridorFloor", Rect2(X_L, Z_F, X_R - X_L, Z_A - Z_F), 0.022, 1.0, _surface(1))
	_slab("CorridorCeiling", Rect2(X_L, Z_F, X_R - X_L, Z_A - Z_F), 2.975, -1.0, _surface(2))
	# Floor access panels: framed in aluminium, ribbed (shutter normal) inside.
	for z in [3.9, 7.6]:
		_box("FloorHatchFrame%d" % int(z * 10), Vector3(-0.15, 0.026, z), Vector3(1.0, 0.008, 0.8), _alu())
		var inner := _surface(1)
		inner.set_shader_parameter("shutter_tile", 0.45)
		inner.set_shader_parameter("floor_color", Color(0.13, 0.14, 0.14))
		_slab("FloorHatch%d" % int(z * 10), Rect2(-0.6, z - 0.35, 0.9, 0.7), 0.031, 1.0, inner)


## A horizontal quad (as a mesh in ship space) facing up (dir 1) or down (-1).
func _slab(n: String, r: Rect2, y: float, dir: float, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3(0, dir, 0))
	var a := Vector3(r.position.x, y, r.position.y)
	var b := Vector3(r.end.x, y, r.position.y)
	var c := Vector3(r.end.x, y, r.end.y)
	var d := Vector3(r.position.x, y, r.end.y)
	var tris := [a, b, c, a, c, d] if dir > 0.0 else [a, c, b, a, d, c]
	for v in tris:
		st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------- walls ----------

## Large recessed wall panels: each solid wall stretch is divided into a
## few broad ivory panels (about 1.8-2.4 m) by a frame that stands slightly
## proud in a darker ivory, so the panels read as set in. A curved cove
## softens the wall-to-ceiling joint.
func _panel_framing() -> void:
	var frame := _surface(7)
	var cove := _surface(7)
	for side in [[X_L, LEFT_SPANS], [X_R, RIGHT_SPANS]]:
		var wx: float = side[0]
		for sp in side[1]:
			var z0: float = sp[0]
			var z1: float = sp[1]
			var tag := "%s%d" % ["L" if wx < 0.0 else "R", int(z0 * 10)]
			_on_wall("Kick" + tag, wx, z0, z1, 0.0, 0.12, 0.025, _surface(7))
			# Frame: top and bottom rails, then a stile between panels.
			_on_wall("ChairRail" + tag, wx, z0, z1, 1.0, 1.06, 0.03, _gunmetal())
			_on_wall("FrameHigh" + tag, wx, z0, z1, 2.28, 2.34, 0.02, frame)
			var count := maxi(1, int(round((z1 - z0) / 2.1)))
			for k in range(1, count):
				var z := z0 + (z1 - z0) * float(k) / float(count)
				_on_wall("Stile%s_%d" % [tag, k], wx, z - 0.035, z + 0.035, 1.06, 2.28, 0.02, frame)
			# Cove: a soft curved strip along the top of the wall.
			_cove("Cove" + tag, wx, z0, z1, cove)


## A quarter-round cove along a wall's top edge (radius 0.22 m), from z0 to z1.
func _cove(n: String, wx: float, z0: float, z1: float, mat: Material) -> void:
	var inward := 1.0 if wx < 0.0 else -1.0
	var r := 0.22
	var top := 2.97
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 6
	for i in segs:
		var a0 := PI * 0.5 * float(i) / segs
		var a1 := PI * 0.5 * float(i + 1) / segs
		# Centre of the arc at (wall + r, top - r); arc from the wall up to the ceiling.
		var p0 := Vector2(wx + inward * (r - r * cos(a0)), top - r + r * sin(a0))
		var p1 := Vector2(wx + inward * (r - r * cos(a1)), top - r + r * sin(a1))
		var n0 := Vector3(inward * cos(a0), -sin(a0), 0)
		var n1 := Vector3(inward * cos(a1), -sin(a1), 0)
		var q := [[p0, n0, z0], [p1, n1, z0], [p1, n1, z1], [p0, n0, z1]]
		var order := [0, 1, 2, 0, 2, 3] if inward < 0.0 else [0, 2, 1, 0, 3, 2]
		for k in order:
			var e: Array = q[k]
			st.set_normal(e[1])
			st.add_vertex(Vector3(e[0].x, e[0].y, e[2]))
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


## Gunmetal surrounds on the corridor side of the side doors, so the existing
## sci-fi doors sit in the same architecture: jambs, a header with the door
## track, and a small control plate with a lamp beside each.
func _door_surrounds() -> void:
	var g := _gunmetal()
	for i in DOORS.size():
		var wx: float = DOORS[i][0]
		var zc: float = DOORS[i][1]
		var hw: float = DOORS[i][2]
		var t := "Door%d" % i
		_on_wall(t + "JambA", wx, zc - hw - 0.14, zc - hw, 0.0, 2.3, 0.07, g)
		_on_wall(t + "JambB", wx, zc + hw, zc + hw + 0.14, 0.0, 2.3, 0.07, g)
		_on_wall(t + "Header", wx, zc - hw - 0.14, zc + hw + 0.14, 2.2, 2.38, 0.08, g)
		_on_wall(t + "Track", wx, zc - hw, zc + hw, 2.24, 2.3, 0.1, _alu())
		# Control plate on the aft jamb with a status lamp.
		var plate := _on_wall(t + "Control", wx, zc + hw + 0.18, zc + hw + 0.34, 1.1, 1.34, 0.03, _alu())
		var lamp := _box(t + "Lamp", plate.position + Vector3(0.018 if wx < 0.0 else -0.018, 0.07, 0.0),
			Vector3(0.012, 0.03, 0.03), _std("cyan", CYAN, 0.3, 0.0, 1.4))


## A ventilation grille and a recessed cable channel up in the gunmetal band,
## a maintenance hatch and a utility locker in the olive band, and one
## replacement panel in slightly mismatched paint.
func _utilities() -> void:
	var g := _gunmetal()
	var dark := _std("recess", Color(0.08, 0.085, 0.09), 0.8, 0.3)
	# Vent grille (left wall, over the gunner stretch).
	_on_wall("VentRecess", X_L, 4.6, 5.6, 2.45, 2.75, 0.01, dark)
	for k in 6:
		var y := 2.48 + k * 0.045
		_on_wall("VentSlat%d" % k, X_L, 4.62, 5.58, y, y + 0.02, 0.04, _alu())
	# Recessed cable channel along the right wall's upper band, with a
	# hinged cover strip and two bundled cables visible at its open end.
	_on_wall("CableChannel", X_R, 2.6, 6.4, 2.48, 2.62, 0.012, dark)
	_on_wall("CableCover", X_R, 2.6, 5.6, 2.47, 2.63, 0.035, g)
	for k in 2:
		var c := CylinderMesh.new()
		c.top_radius = 0.018
		c.bottom_radius = 0.018
		c.height = 0.8
		var mi := MeshInstance3D.new()
		mi.name = "Cable%d" % k
		mi.mesh = c
		mi.material_override = _std("cable_" + str(k), [Color(0.12, 0.12, 0.12), RED.darkened(0.3)][k], 0.7, 0.0)
		mi.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(X_R - 0.03, 2.52 + k * 0.05, 6.0))
		add_child(mi)
	# Maintenance hatch (left wall, olive band): its own olive plate, a darker
	# seam, an aluminium pull and a stencilled label.
	var hatch_z := 6.6
	_on_wall("HatchSeam", X_L, hatch_z - 0.42, hatch_z + 0.42, 0.18, 0.8, 0.012, dark)
	var hatch := _on_wall("Hatch", X_L, hatch_z - 0.4, hatch_z + 0.4, 0.2, 0.78, 0.03, _surface(7))
	if crashed:
		# Shaken loose in the crash: hangs open from its bottom hinge.
		hatch.rotation = Vector3(0, 0, -0.5)
		hatch.position += Vector3(0.12, -0.12, 0)
	_on_wall("HatchPull", X_L, hatch_z - 0.12, hatch_z + 0.12, 0.66, 0.7, 0.05, _alu())
	# Utility locker (right wall): a steel-blue housing with an amber
	# indicator and a small cyan readout.
	_on_wall("LockerBody", X_R, 3.0, 3.9, 1.1, 2.1, 0.06, _surface(5))
	_on_wall("LockerHandle", X_R, 3.78, 3.83, 1.35, 1.65, 0.09, _alu())
	_on_wall("LockerLamp", X_R, 3.1, 3.14, 1.9, 1.94, 0.07, _std("amber", AMBER, 0.3, 0.0, 2.2 if not crashed else 0.0))
	_on_wall("LockerReadout", X_R, 3.2, 3.5, 1.82, 1.96, 0.065, _std("cyan_screen", CYAN, 0.3, 0.0, 0.9 if not crashed else 0.0))
	# One replacement panel in a slightly different off-white, between two
	# mullions on the right wall; missing after the crash.
	if not crashed:
		# A newer replacement panel: same dark paint, less worn.
		var rp := _surface(7)
		rp.set_shader_parameter("dark_paint", Color(0.26, 0.255, 0.24))
		_on_wall("ReplacementPanel", X_R, -2.55, -1.55, 1.06, 2.26, 0.012, rp)
	else:
		_on_wall("MissingPanel", X_R, -2.55, -1.55, 1.06, 2.26, 0.008, _surface(6))


## Walnut: one narrow handrail on aluminium brackets along the long left
## wall, and a small inset accent beside the lounge entrance.
func _walnut() -> void:
	var wood := _std("walnut", WALNUT.darkened(0.15), 0.75, 0.0)
	var z0 := 2.6
	var z1 := 8.8
	_on_wall("Handrail", X_L, z0, z1, 1.18, 1.24, 0.0001, wood).position.x = X_L + 0.1
	for k in 5:
		var z := z0 + 0.2 + (z1 - z0 - 0.4) * float(k) / 4.0
		_on_wall("RailBracket%d" % k, X_L, z - 0.02, z + 0.02, 1.16, 1.22, 0.1, _alu())
	# Accent beside the lounge entrance (right wall, aft side of the opening).
	_on_wall("WalnutAccent", X_R, 2.5, 2.62, 0.95, 2.33, 0.02, wood)


## Small identification plates (stencil-style text) where crew would look.
func _labels() -> void:
	var font_col := Color(0.12, 0.12, 0.11)
	var plates := [
		[X_L, -0.95, 1.55, "DECK B  ·  FR 07"],
		[X_L, 6.6, 0.88, "SVC ACCESS  B-3"],
		[X_R, 3.45, 2.15, "STOWAGE 2"],
		[X_L, 5.1, 2.82, "AIR RETURN"],
	]
	for p in plates:
		var wx: float = p[0]
		var inward := 1.0 if wx < 0.0 else -1.0
		var pl := _on_wall("LabelPlate", wx, p[1] - 0.22, p[1] + 0.22, p[2] - 0.035, p[2] + 0.035, 0.012,
			_std("label", Color(0.78, 0.76, 0.68), 0.6, 0.0))
		var l := Label3D.new()
		l.text = p[3]
		l.font_size = 22
		l.pixel_size = 0.0022
		l.modulate = font_col
		l.outline_size = 0
		l.shaded = true
		l.double_sided = false
		l.position = Vector3(wx + inward * 0.014, p[2], p[1])
		l.rotation.y = PI * 0.5 * inward
		add_child(l)


## Broad luminous ceiling panels between the beams: a charcoal recess
## frame and a soft ivory diffuser (dark after the crash, but for one dim
## panel near the quarters).
func _fixtures() -> void:
	var lit := _std("diffuser", LIGHT.lightened(0.3), 0.5, 0.0, 0.85)
	var dark := _std("diffuser_dark", Color(0.3, 0.29, 0.27), 0.6, 0.0)
	var dim := _std("diffuser_dim", LIGHT, 0.5, 0.0, 0.25)
	for i in CEILING_PANELS.size():
		var z0: float = CEILING_PANELS[i][0]
		var z1: float = CEILING_PANELS[i][1]
		var zc := (z0 + z1) * 0.5
		var len := z1 - z0
		_box("PanelRecess%d" % i, Vector3(-0.15, 2.968, zc), Vector3(PANEL_W + 0.16, 0.012, len + 0.16), _gunmetal())
		var mat: Material = lit
		if crashed:
			mat = dim if i == 0 else dark
		_box("LightPanel%d" % i, Vector3(-0.15, 2.958, zc), Vector3(PANEL_W, 0.012, len), mat)
	_ceiling_pipes()


## Pipe runs along the ceiling either side of the light panels: two dark
## steel lines and a thinner brushed one, on clamp brackets.
func _ceiling_pipes() -> void:
	var dark_pipe := _std("pipe_dark", Color(0.17, 0.165, 0.16), 0.5, 0.7)
	var runs := [[-1.35, 2.8, 0.075, dark_pipe], [-1.6, 2.83, 0.05, _alu()], [1.05, 2.8, 0.085, dark_pipe]]
	var z0 := Z_F + 0.1
	var z1 := Z_A - 0.15
	for i in runs.size():
		var r: Array = runs[i]
		var c := CylinderMesh.new()
		c.top_radius = r[2]
		c.bottom_radius = r[2]
		c.height = z1 - z0
		c.radial_segments = 12
		var mi := MeshInstance3D.new()
		mi.name = "CeilingPipe%d" % i
		mi.mesh = c
		mi.material_override = r[3]
		mi.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(r[0], r[1], (z0 + z1) * 0.5))
		add_child(mi)
	# Clamp brackets hanging from the ceiling every ~1.8 m.
	var z := z0 + 0.6
	var k := 0
	while z < z1:
		for x in [-1.47, 1.05]:
			_box("PipeHanger%d_%d" % [k, int(x * 10)], Vector3(x, 2.9, z), Vector3(0.36 if x < 0.0 else 0.22, 0.03, 0.06), _gunmetal())
			_box("PipeHangerRod%d_%d" % [k, int(x * 10)], Vector3(x, 2.94, z), Vector3(0.02, 0.07, 0.02), _gunmetal())
		z += 1.8
		k += 1


## A personal niche near the quarters (left wall, forward stretch): a small
## recess with a walnut shelf, a mug, a framed photo and a tin.
## Beside it, built-in storage: two flush ivory cabinet doors with steel pulls.
func _niche_and_storage() -> void:
	var recess := _std("niche_back", IVORY.darkened(0.35), 0.7, 0.0)
	var zc := -4.9
	_on_wall("NicheBack", X_L, zc - 0.45, zc + 0.45, 1.25, 1.75, 0.005, recess)
	_on_wall("NicheFrame", X_L, zc - 0.5, zc + 0.5, 1.2, 1.24, 0.05, _gunmetal())
	_on_wall("NicheFrameTop", X_L, zc - 0.5, zc + 0.5, 1.76, 1.8, 0.05, _gunmetal())
	var shelf := _std("walnut", WALNUT.darkened(0.15), 0.75, 0.0)
	_on_wall("NicheShelf", X_L, zc - 0.45, zc + 0.45, 1.24, 1.27, 0.16, shelf)
	if not crashed:
		var mug := CylinderMesh.new()
		mug.top_radius = 0.035
		mug.bottom_radius = 0.032
		mug.height = 0.09
		var mm := MeshInstance3D.new()
		mm.name = "NicheMug"
		mm.mesh = mug
		mm.material_override = _std("mug", Color(0.55, 0.62, 0.6), 0.5, 0.0)
		mm.position = Vector3(X_L + 0.09, 1.315, zc - 0.22)
		add_child(mm)
		var photo := _box("NichePhoto", Vector3(X_L + 0.04, 1.36, zc + 0.05), Vector3(0.015, 0.18, 0.13), _std("photo_frame", Color(0.2, 0.19, 0.17), 0.6, 0.2))
		photo.rotation.z = -0.12
		_box("NicheTin", Vector3(X_L + 0.08, 1.31, zc + 0.3), Vector3(0.08, 0.08, 0.08), _std("tin", OLIVE.darkened(0.1), 0.5, 0.4))
	# Built-in storage on the right wall, forward stretch (near the quarters).
	for k in 2:
		var z0 := -3.65 + k * 0.56
		_on_wall("CabinetDoor%d" % k, X_R, z0, z0 + 0.53, 0.15, 0.95, 0.03, _surface(5))
		_on_wall("CabinetPull%d" % k, X_R, z0 + 0.4, z0 + 0.44, 0.7, 0.87, 0.05, _alu())


## The tool cart against the right wall, mid-corridor, aft of the locker.
## Rolled askew and away from the wall after the crash.
func _tool_cart() -> void:
	var cart := ToolCart.new()
	cart.name = "ToolCart"
	add_child(cart)
	if crashed:
		cart.position = Vector3(1.1, 0.0, 5.6)
		cart.rotation.y = PI + 0.5
	else:
		cart.position = Vector3(X_R - 0.3, 0.0, 5.3)
		cart.rotation.y = PI


## A big rug at the lounge entrance (ship/models/rug/rug.fbx, about
## 2.2 x 3.5 m here), its long side running from the corridor into the
## lounge doorway. Kicked askew after the crash.
func _rug() -> void:
	var scene: PackedScene = load("res://ship/models/rug/rug.fbx")
	var rug: Node3D = scene.instantiate()
	rug.name = "LoungeRug"
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ship/rug.gdshader")
	for n in rug.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = mat
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rug)
	rug.scale = Vector3.ONE * 1.6
	# The model's long side runs along its z: turn it to run along x.
	rug.rotation.y = PI * 0.5 + (0.22 if crashed else 0.0)
	rug.position = Vector3(0.55, 0.02, 1.4 + (0.3 if crashed else 0.0))


## Rubber mats over the aft third (from the boarding ramp in): separate
## mats laid in a grid, a uniform inch (2.54 cm) apart, with an aluminium
## transition strip where they start.
const MAT_GAP := 0.0254
const MAT_Z := Vector2(4.34, 9.15)
const MAT_COLS := 4
const MAT_ROWS := 5


func _mat_edge() -> void:
	_box("MatEdge", Vector3((X_L + X_R) * 0.5, 0.028, MAT_Z.x - 0.03), Vector3(X_R - X_L - 0.06, 0.012, 0.05), _alu())
	var rubber := _surface(4)
	var x0 := X_L + 0.06
	var x1 := X_R - 0.06
	var w := (x1 - x0 - MAT_GAP * (MAT_COLS - 1)) / MAT_COLS
	var d := (MAT_Z.y - MAT_Z.x - MAT_GAP * (MAT_ROWS - 1)) / MAT_ROWS
	for c in MAT_COLS:
		for r in MAT_ROWS:
			var cx := x0 + w * 0.5 + c * (w + MAT_GAP)
			var cz := MAT_Z.x + d * 0.5 + r * (d + MAT_GAP)
			# Raised over the floor rails so they read as loose mats.
			var m := _box("RubberMat%d_%d" % [c, r], Vector3(cx, 0.044, cz), Vector3(w, 0.02, d), rubber)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if crashed and (c + r) % 3 == 0:
				# Shifted in the crash.
				m.position += Vector3(0.04 * (c - 1.5), 0.0, 0.05)
				m.rotation.y = 0.05 * (r - 2)


## Industrial caged sconces (ship/caged_sconce.gd) on both walls, in the dark
## stretches between the ceiling panels, glowing warm orange. Dead after
## the crash. [wall x, z]
const SCONCES := [[X_L, -1.0], [X_L, 2.72], [X_L, 7.6], [X_R, -1.0], [X_R, 4.45]]
const SCONCE_Y := 1.95


func _sconces() -> void:
	var script: Script = load("res://ship/caged_sconce.gd")
	for i in SCONCES.size():
		var wx: float = SCONCES[i][0]
		var lamp := Node3D.new()
		lamp.set_script(script)
		lamp.name = "Sconce%d" % i
		lamp.set("lit", not crashed)
		lamp.position = Vector3(wx, SCONCE_Y, SCONCES[i][1])
		lamp.rotation.y = PI * 0.5 if wx < 0.0 else -PI * 0.5
		add_child(lamp)
