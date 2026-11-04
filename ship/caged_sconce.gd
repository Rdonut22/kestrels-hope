@tool
class_name CagedSconce
extends Node3D

## An industrial caged wall sconce (after the user's industrial_caged_sconce
## reference textures): a yellow-painted round wall plate, a steel arm and
## housing, a glass tube with a domed end glowing warm orange, a steel bar
## cage with yellow bands.
##
## Frame: the wall is the XY plane at z = 0, the lamp stands out along +Z,
## +Y up. To mount it on a wall whose surface faces +X, rotate it by +PI/2
## about Y (-PI/2 for a wall facing -X).
##
## Built at runtime; children have no owner, so a saved scene holds only the
## root and its exported values.
##
## With `follow_power`, the lamp glows dimly on emergency power and comes
## up to full brightness when the ship's power is restored.

@export var glow_color := Color(1.0, 0.55, 0.22)
@export var light_energy := 0.9
@export var light_range := 2.3
@export var lit := true
@export var follow_power := true

const PAINT := Color(0.78, 0.6, 0.08)
const STEEL := Color(0.46, 0.47, 0.49)
const EMERGENCY := 0.3   # brightness on emergency power

const ARM_Y := 0.08      # height of the arm above the lamp's origin
const OUT := 0.13        # how far the lamp's axis stands off the wall
const GLASS_R := 0.042
const CAGE_R := 0.056

static var _mats := {}
static var _unit_cyl: CylinderMesh

var _light: OmniLight3D
var _glass_mat: StandardMaterial3D


func _ready() -> void:
	for c in get_children():
		c.free()
	_build()
	if lit and follow_power and not Engine.is_editor_hint():
		var gs: Node = Game.state()
		if not gs.power_restored:
			_set_level(EMERGENCY)
			gs.power_restored_changed.connect(func(_on: bool) -> void:
				create_tween().tween_method(_set_level, EMERGENCY, 1.0, 0.6), CONNECT_ONE_SHOT)


func _set_level(k: float) -> void:
	_light.light_energy = light_energy * k
	_set_glass(k)


## Glass colour for a brightness level k (0 = dead, 1 = full power).
func _set_glass(k: float) -> void:
	var hot := glow_color.lerp(Color(1.0, 0.85, 0.6), 0.35)
	_glass_mat.albedo_color = Color(0.22, 0.2, 0.18).lerp(hot, clampf(k * 1.3, 0.0, 1.0))


# ---------- materials ----------

static func _mat(key: String, color: Color, rough: float, metal: float) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		_mats[key] = m
	return _mats[key]


func _paint() -> StandardMaterial3D:
	return _mat("paint", PAINT, 0.6, 0.1)


func _steel() -> StandardMaterial3D:
	return _mat("steel", STEEL, 0.4, 0.65)


# ---------- geometry ----------

func _build() -> void:
	_wall_plate()
	_arm_and_housing()
	_glass()
	_cage()
	_light = OmniLight3D.new()
	_light.name = "Glow"
	_light.position = Vector3(0, -0.02, OUT)
	_light.light_color = glow_color
	_light.light_energy = light_energy if lit else 0.0
	_light.omni_range = light_range
	_light.omni_attenuation = 1.5
	add_child(_light)


func _wall_plate() -> void:
	# Round plate, flat against the wall, and a hex nut where the arm meets it.
	_cyl("WallPlate", Vector3(0, ARM_Y, 0.0), Vector3(0, ARM_Y, 0.018), 0.07, _paint(), 24)
	_cyl("PlateRim", Vector3(0, ARM_Y, 0.018), Vector3(0, ARM_Y, 0.024), 0.05, _steel(), 24)
	_cyl("Nut", Vector3(0, ARM_Y, 0.024), Vector3(0, ARM_Y, 0.04), 0.028, _steel(), 6)


func _arm_and_housing() -> void:
	_cyl("Arm", Vector3(0, ARM_Y, 0.04), Vector3(0, ARM_Y, OUT - 0.04), 0.017, _steel(), 12)
	# Housing over the glass: a steel collar, a yellow cap on top.
	_cyl("Housing", Vector3(0, 0.055, OUT), Vector3(0, 0.105, OUT), 0.06, _steel(), 20)
	_cyl("Cap", Vector3(0, 0.105, OUT), Vector3(0, 0.118, OUT), 0.066, _paint(), 20)
	_cyl("CapBoss", Vector3(0, 0.118, OUT), Vector3(0, 0.13, OUT), 0.022, _steel(), 6)


func _glass() -> void:
	# Unshaded: the lamp's own light sits inside the glass and would wash it
	# out; the glass just shows its glow colour.
	_glass_mat = StandardMaterial3D.new()
	_glass_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_set_glass(1.0 if lit else 0.0)
	_cyl("Glass", Vector3(0, -0.085, OUT), Vector3(0, 0.055, OUT), GLASS_R, _glass_mat, 20)
	var dome := SphereMesh.new()
	dome.radius = GLASS_R
	dome.height = GLASS_R * 2.0
	dome.radial_segments = 20
	dome.rings = 8
	var mi := MeshInstance3D.new()
	mi.name = "GlassDome"
	mi.mesh = dome
	mi.material_override = _glass_mat
	mi.position = Vector3(0, -0.085, OUT)
	add_child(mi)


func _cage() -> void:
	# Six bars from the housing down past the glass, bending in under the
	# dome to a small bottom ring; two yellow bands around the middle.
	var top_y := 0.055
	var bend_y := -0.085
	var bottom_y := -0.14
	var foot_r := 0.018
	for k in 6:
		var a := TAU * float(k) / 6.0 + PI / 6.0
		var d := Vector3(cos(a), 0, sin(a))
		var c := Vector3(0, 0, OUT)
		var p0 := c + d * CAGE_R + Vector3(0, top_y, 0)
		var p1 := c + d * CAGE_R + Vector3(0, bend_y, 0)
		var p2 := c + d * foot_r + Vector3(0, bottom_y, 0)
		_bar("Bar%d" % k, p0, p1, 0.0042)
		_bar("BarFoot%d" % k, p1, p2, 0.0042)
	_ring("Band0", Vector3(0, -0.005, OUT), CAGE_R, 0.007, _paint())
	_ring("Band1", Vector3(0, -0.07, OUT), CAGE_R, 0.007, _paint())
	_ring("FootRing", Vector3(0, bottom_y, OUT), foot_r, 0.005, _steel())


## A cylinder between two points (its own mesh: few of these per lamp).
func _cyl(n: String, a: Vector3, b: Vector3, r: float, mat: Material, segs: int) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = a.distance_to(b)
	c.radial_segments = segs
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = c
	mi.material_override = mat
	mi.transform = _along(a, b, 1.0)
	add_child(mi)
	return mi


## A thin cage bar: one shared unit cylinder, scaled to length.
func _bar(n: String, a: Vector3, b: Vector3, r: float) -> void:
	if _unit_cyl == null:
		_unit_cyl = CylinderMesh.new()
		_unit_cyl.top_radius = 1.0
		_unit_cyl.bottom_radius = 1.0
		_unit_cyl.height = 1.0
		_unit_cyl.radial_segments = 6
		_unit_cyl.rings = 1
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = _unit_cyl
	mi.material_override = _steel()
	var t := _along(a, b, a.distance_to(b))
	t.basis = t.basis * Basis.from_scale(Vector3(r, 1.0, r))
	mi.transform = t
	add_child(mi)


func _ring(n: String, centre: Vector3, r: float, thick: float, mat: Material) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = r - thick
	tm.outer_radius = r + thick
	tm.rings = 24
	tm.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = tm
	mi.material_override = mat
	mi.position = centre
	add_child(mi)


## Transform putting a Y-axis mesh's centre midway between a and b, its Y
## along a->b, scaled by `len` along Y.
func _along(a: Vector3, b: Vector3, len: float) -> Transform3D:
	var y := (b - a).normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x, y * len, z), (a + b) * 0.5)
