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
const LEFT_SPANS := [[-5.55, -4.25], [-1.75, -0.15], [2.35, 9.15]]
const RIGHT_SPANS := [[-3.75, -0.45], [2.45, 6.5]]
# Doorways [wall x, centre z, half width] for the surrounds and hand wear.
const DOORS := [[X_L, -3.0, 1.156], [X_L, 1.1, 1.156]]
# Light pools down the corridor (z), recessed in the ceiling.
const FIXTURES := [-3.4, -0.8, 1.8, 4.4, 6.9]

const GUNMETAL := Color("343A3B")
const ALUMINIUM := Color("929A98")
const WALNUT := Color("805638")
const AMBER := Color("E6B978")
const CYAN := Color("A4C6C4")
const RED := Color("A8493D")
const STEEL_BLUE := Color("354B5A")
const OLIVE := Color("52634D")

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
	_tool_cart()


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


func _gunmetal() -> StandardMaterial3D:
	return _std("gunmetal", GUNMETAL, 0.5, 0.6)


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

## Rails along the panel band edges and mullions between panels, standing
## proud of the wall so the off-white and olive panels read as recessed.
func _panel_framing() -> void:
	var g := _gunmetal()
	for side in [[X_L, LEFT_SPANS], [X_R, RIGHT_SPANS]]:
		var wx: float = side[0]
		for sp in side[1]:
			var z0: float = sp[0]
			var z1: float = sp[1]
			var tag := "%s%d" % ["L" if wx < 0.0 else "R", int(z0 * 10)]
			_on_wall("RailLow" + tag, wx, z0, z1, 0.85, 0.95, 0.045, g)
			_on_wall("RailHigh" + tag, wx, z0, z1, 2.33, 2.4, 0.045, g)
			_on_wall("Kick" + tag, wx, z0, z1, 0.0, 0.12, 0.03, g)
			# Mullions every ~1.2 m between the rails.
			var count := int(floor((z1 - z0) / 1.2))
			for k in range(1, count + 1):
				var z := z0 + (z1 - z0) * float(k) / float(count + 1)
				_on_wall("Mullion%s_%d" % [tag, k], wx, z - 0.025, z + 0.025, 0.95, 2.33, 0.03, g)


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
	var hatch := _on_wall("Hatch", X_L, hatch_z - 0.4, hatch_z + 0.4, 0.2, 0.78, 0.03, _surface(3, OLIVE))
	if crashed:
		# Shaken loose in the crash: hangs open from its bottom hinge.
		hatch.rotation = Vector3(0, 0, -0.5)
		hatch.position += Vector3(0.12, -0.12, 0)
	_on_wall("HatchPull", X_L, hatch_z - 0.12, hatch_z + 0.12, 0.66, 0.7, 0.05, _alu())
	# Utility locker (right wall): a steel-blue housing with an amber
	# indicator and a small cyan readout.
	_on_wall("LockerBody", X_R, 3.0, 3.9, 0.95, 2.05, 0.06, _std("steel_blue", STEEL_BLUE, 0.55, 0.4))
	_on_wall("LockerHandle", X_R, 3.78, 3.83, 1.35, 1.65, 0.09, _alu())
	_on_wall("LockerLamp", X_R, 3.1, 3.14, 1.9, 1.94, 0.07, _std("amber", AMBER, 0.3, 0.0, 2.2 if not crashed else 0.0))
	_on_wall("LockerReadout", X_R, 3.2, 3.5, 1.82, 1.96, 0.065, _std("cyan_screen", CYAN, 0.3, 0.0, 0.9 if not crashed else 0.0))
	# One replacement panel in a slightly different off-white, between two
	# mullions on the right wall; missing after the crash.
	if not crashed:
		_on_wall("ReplacementPanel", X_R, -2.55, -1.55, 0.98, 2.3, 0.012, _surface(3, Color("BDB59B")))
	else:
		_on_wall("MissingPanel", X_R, -2.55, -1.55, 0.98, 2.3, 0.008, dark)


## Walnut: one narrow handrail on aluminium brackets along the long left
## wall, and a small inset accent beside the lounge entrance.
func _walnut() -> void:
	var wood := _std("walnut", WALNUT.darkened(0.15), 0.75, 0.0)
	var z0 := 2.6
	var z1 := 8.8
	_on_wall("Handrail", X_L, z0, z1, 0.98, 1.04, 0.0001, wood).position.x = X_L + 0.1
	for k in 5:
		var z := z0 + 0.2 + (z1 - z0 - 0.4) * float(k) / 4.0
		_on_wall("RailBracket%d" % k, X_L, z - 0.02, z + 0.02, 0.96, 1.02, 0.1, _alu())
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


## Recessed fixtures in the ceiling over each light pool: a gunmetal trim
## ring and a warm diffuser (dark after the crash).
func _fixtures() -> void:
	var diffuser := _std("diffuser", Color(1.0, 0.93, 0.82), 0.4, 0.0, 1.6 if not crashed else 0.0)
	if crashed:
		diffuser.albedo_color = Color(0.25, 0.25, 0.24)
	for z in FIXTURES:
		_box("FixtureTrim%d" % int(z * 10), Vector3(-0.15, 2.965, z), Vector3(0.62, 0.02, 0.62), _gunmetal())
		_box("FixtureLens%d" % int(z * 10), Vector3(-0.15, 2.955, z), Vector3(0.5, 0.02, 0.5), diffuser)


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
