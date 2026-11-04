@tool
class_name GalleyWindows
extends Node3D

## Panoramic windows for the galley (kitchen). Above the window sill the
## galley is pushed out to the fuselage's skin, so its outer wall and sloped
## upper glass are flush with the rest of the ship; below the sill the old
## wall stays, and the extra depth is a deep steel window counter.
##
## Ship space (the parent ship scene's frame): forward is -Z, starboard +X,
## floor y = 0. The kitchen is x 2.4..5.6, z -6.8..-3.4. The fuselage's
## starboard side there is near vertical at x ~7.0 up to y 2.1, then curves
## in toward the roof (ship/kestrel_exterior.gd clips the fuselage skin
## away over the bay, GALLEY_CUT, and closes its cut ends).
##
## At runtime this adds to the parent's Hull (CSGCombiner3D):
##   - GalleyBay: solid out to the skin line (BAY_OUTLINE),
##   - GalleyRoom: the room carved out of it above the sill (ROOM_OUTLINE),
##   - GalleyPane*: real openings through its outer wall and sloped top.
## And as its own children: the glass (with collision), brushed-steel
## bezels around each opening, and the steel window counter.
## Nothing is given an owner, so a saved scene holds only this node.
##
## Each pane is laid out in a frame (u along the ship's z, v up the wall or
## the slope, w into the room); w = 0 is the interior surface.

@export var restyle_walls := true   # aged ivory painted panels in the kitchen

const Z_RANGE := Vector2(-6.8, -3.4)
const SILL_Y := 0.95
const WALL_IN := 6.78        # the bay's outer wall: inner face
const WALL_OUT := 7.03       # outer face, on the fuselage's skin
# Exterior slope line in (x, y), along the skin: from the top of the wall
# to where the fuselage carries on above the bay.
const EXT0 := Vector2(7.03, 2.12)
const EXT1 := Vector2(6.3, 3.25)
const SLOPE_T := 0.2
const CEIL_Y := 3.0
const CORNER_R := 0.07
const BEZEL_W := 0.055
const BEZEL_D := 0.035
# The bay's solid in (x, y): just inside the fuselage's curve below the
# sill, on its skin above.
const BAY_OUTLINE := [Vector2(5.62, -0.2), Vector2(5.9, -0.2), Vector2(6.2, 0.2), Vector2(6.55, 0.55),
	Vector2(6.98, 0.85), Vector2(WALL_OUT, 0.85), EXT0, EXT1, Vector2(5.62, 3.25)]

# Vertical panes, (u = ship z, v = height): three trapezoids split by two
# angled mullions.
const WALL_PANES := [
	[Vector2(-6.62, 0.98), Vector2(-5.6, 0.98), Vector2(-5.8, 2.0), Vector2(-6.62, 2.0)],
	[Vector2(-5.44, 0.98), Vector2(-4.76, 0.98), Vector2(-4.56, 2.0), Vector2(-5.64, 2.0)],
	[Vector2(-4.6, 0.98), Vector2(-3.58, 0.98), Vector2(-3.58, 2.0), Vector2(-4.4, 2.0)]]
# Sloped panes, (u = ship z, v = distance up the slope from its foot on the
# inner line): the mullions carry on from the wall and splay further.
const SLOPE_PANES := [
	[Vector2(-6.62, 0.27), Vector2(-5.8, 0.27), Vector2(-5.95, 1.08), Vector2(-6.62, 1.08)],
	[Vector2(-5.64, 0.27), Vector2(-4.56, 0.27), Vector2(-4.41, 1.08), Vector2(-5.79, 1.08)],
	[Vector2(-4.4, 0.27), Vector2(-3.58, 0.27), Vector2(-3.58, 1.08), Vector2(-4.25, 1.08)]]

const IVORY := Color("C5B9A5")

var _glass: ShaderMaterial
var _steel: StandardMaterial3D
var _charcoal: StandardMaterial3D


func _ready() -> void:
	for c in get_children():
		c.free()
	_materials()
	# After the exterior has repainted the hull (its _ready runs first only
	# if it comes earlier in the tree).
	_build.call_deferred()


func _materials() -> void:
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


func _build() -> void:
	var ship := get_parent()
	var hull := ship.get_node_or_null("Hull") as CSGCombiner3D if ship else null
	if hull == null:
		return
	var to_hull: Transform3D = hull.transform.affine_inverse() * transform
	var outer := hull.get_node_or_null("Outer") as CSGShape3D
	var paint: Material = outer.material if outer else _charcoal

	# 1. The bay's solid, out to the fuselage's skin.
	var bay := _prism("GalleyBay", PackedVector2Array(BAY_OUTLINE), paint)
	bay.transform = to_hull * bay.transform
	hull.add_child(bay)

	# 2. The room above the sill: out to the bay's wall, up its slope to
	# the ceiling.
	var n := _slope_out()
	var in0 := EXT0 - n * SLOPE_T
	var in1 := EXT1 - n * SLOPE_T
	var wall_top := in0.y + (in1.y - in0.y) * (WALL_IN - in0.x) / (in1.x - in0.x)
	var room := _prism("GalleyRoom", PackedVector2Array([Vector2(5.5, SILL_Y), Vector2(WALL_IN, SILL_Y),
		Vector2(WALL_IN, wall_top), Vector2(_line_x(in0, in1, CEIL_Y), CEIL_Y), Vector2(5.5, CEIL_Y)]), _charcoal)
	room.operation = CSGShape3D.OPERATION_SUBTRACTION
	room.transform = to_hull * room.transform
	hull.add_child(room)

	# 3. The openings, and their glass and bezels.
	for i in WALL_PANES.size():
		_pane("Wall%d" % i, _wall_frame(), WALL_PANES[i], WALL_OUT - WALL_IN, hull, to_hull)
	for i in SLOPE_PANES.size():
		_pane("Slope%d" % i, _slope_frame(), SLOPE_PANES[i], SLOPE_T, hull, to_hull)

	# The deep window counter: brushed steel, over the old wall's top.
	var counter := MeshInstance3D.new()
	counter.name = "WindowCounter"
	var cb := BoxMesh.new()
	cb.size = Vector3(WALL_IN - 5.52, 0.04, Z_RANGE.y - Z_RANGE.x - 0.04)
	counter.mesh = cb
	counter.material_override = _steel
	counter.position = Vector3((WALL_IN + 5.52) * 0.5, SILL_Y + 0.02, (Z_RANGE.x + Z_RANGE.y) * 0.5)
	add_child(counter)
	var lip := MeshInstance3D.new()
	lip.name = "CounterLip"
	var lb := BoxMesh.new()
	lb.size = Vector3(0.05, 0.09, Z_RANGE.y - Z_RANGE.x - 0.04)
	lip.mesh = lb
	lip.material_override = _steel
	lip.position = Vector3(5.53, SILL_Y - 0.005, (Z_RANGE.x + Z_RANGE.y) * 0.5)
	add_child(lip)

	if restyle_walls:
		var kitchen := hull.get_node_or_null("Kitchen") as CSGShape3D
		var wall_mat := load("res://ship/materials/corridor_wall.tres") as ShaderMaterial
		if kitchen and wall_mat:
			var m := wall_mat.duplicate() as ShaderMaterial
			m.set_shader_parameter("surface", 3)
			m.set_shader_parameter("panel_color", IVORY)
			kitchen.material = m
			(hull.get_node("GalleyRoom") as CSGShape3D).material = m


# ---------- frames ----------

## Outward normal of the slope, in (x, y).
func _slope_out() -> Vector2:
	var d := (EXT1 - EXT0).normalized()
	return Vector2(d.y, -d.x)


## The wall's frame: u = ship z, v = y, w into the room; origin on the
## wall's interior face.
func _wall_frame() -> Transform3D:
	return Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)), Vector3(WALL_IN, 0, 0))


## The slope's frame: u = ship z, v up the slope, w into the room; origin at
## the foot of the slope's inner line.
func _slope_frame() -> Transform3D:
	var d := (EXT1 - EXT0).normalized()
	var n := _slope_out()
	var o := EXT0 - n * SLOPE_T
	return Transform3D(Basis(Vector3(0, 0, 1), Vector3(d.x, d.y, 0), Vector3(-n.x, -n.y, 0)), Vector3(o.x, o.y, 0))


## x where the line through a and b reaches height y.
func _line_x(a: Vector2, b: Vector2, y: float) -> float:
	return a.x + (b.x - a.x) * (y - a.y) / (b.y - a.y)


# ---------- one pane ----------

func _pane(n: String, frame: Transform3D, quad: Array, thick: float, hull: Node, to_hull: Transform3D) -> void:
	var poly := _fillet(_ccw(PackedVector2Array(quad)), CORNER_R, 4)
	# The opening: from just inside the room out past the exterior surface.
	var cut := CSGPolygon3D.new()
	cut.name = "GalleyPane" + n
	cut.polygon = poly
	cut.depth = thick + 0.4
	cut.material = _charcoal
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut.transform = to_hull * frame * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.15))
	hull.add_child(cut)

	# Glass, mid-thickness, with collision.
	var gm := MeshInstance3D.new()
	gm.name = "Glass" + n
	gm.mesh = _flat(poly, -thick * 0.5)
	gm.material_override = _glass
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gm.transform = frame
	add_child(gm)
	var body := StaticBody3D.new()
	body.name = "GlassBody" + n
	var shape := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for p in poly:
		pts.append(Vector3(p.x, p.y, -thick * 0.5 - 0.02))
		pts.append(Vector3(p.x, p.y, -thick * 0.5 + 0.02))
	shape.points = pts
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.transform = frame
	add_child(body)

	# Brushed-steel bezel around the opening on the interior surface.
	var bz := MeshInstance3D.new()
	bz.name = "Bezel" + n
	bz.mesh = _bezel(poly, _fillet(_ccw(_offset(PackedVector2Array(quad), BEZEL_W)), CORNER_R + BEZEL_W, 4))
	bz.material_override = _steel
	bz.transform = frame
	add_child(bz)


# ---------- 2D helpers ----------

func _ccw(p: PackedVector2Array) -> PackedVector2Array:
	var a := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		a += p[i].x * q.y - q.x * p[i].y
	if a < 0.0:
		p.reverse()
	return p


## A convex polygon grown outward by d (edges pushed out, corners met).
func _offset(p: PackedVector2Array, d: float) -> PackedVector2Array:
	p = _ccw(p)
	var out := PackedVector2Array()
	var k := p.size()
	for i in k:
		var a := p[(i - 1 + k) % k]
		var b := p[i]
		var c := p[(i + 1) % k]
		var e0 := (b - a).normalized()
		var e1 := (c - b).normalized()
		var n0 := Vector2(e0.y, -e0.x)
		var n1 := Vector2(e1.y, -e1.x)
		var bis := (n0 + n1).normalized()
		out.append(b + bis * d / maxf(bis.dot(n0), 0.2))
	return out


## Rounds each corner of a convex CCW polygon with radius r (segs + 1
## points per corner, so polygons with the same corners match up).
func _fillet(p: PackedVector2Array, r: float, segs: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var k := p.size()
	for i in k:
		var v := p[i]
		var a := (p[(i - 1 + k) % k] - v)
		var b := (p[(i + 1) % k] - v)
		var la := a.length()
		var lb := b.length()
		a /= la
		b /= lb
		var half := acos(clampf(a.dot(b), -1.0, 1.0)) * 0.5
		var t := minf(r / tan(half), minf(la, lb) * 0.45)
		var rr := t * tan(half)
		var c := v + (a + b).normalized() * sqrt(t * t + rr * rr)
		var s := v + a * t
		var e := v + b * t
		var a0 := (s - c).angle()
		var a1 := (e - c).angle()
		var da := wrapf(a1 - a0, -PI, PI)
		for j in segs + 1:
			out.append(c + Vector2.from_angle(a0 + da * float(j) / float(segs)) * rr)
	return out


# ---------- meshes ----------

## A flat polygon at depth w (a fan; the panes are convex).
func _flat(p: PackedVector2Array, w: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3(0, 0, 1))
	var c := Vector2.ZERO
	for q in p:
		c += q
	c /= float(p.size())
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		# Clockwise seen from +w (the room): Godot's front faces.
		st.add_vertex(Vector3(c.x, c.y, w))
		st.add_vertex(Vector3(b.x, b.y, w))
		st.add_vertex(Vector3(a.x, a.y, w))
	return st.commit()


## A bezel ring between the opening (inner) and a larger outline (outer),
## standing BEZEL_D proud of the surface, with its outer edge and inner
## lip closed.
func _bezel(inner: PackedVector2Array, outer: PackedVector2Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var k := inner.size()
	var f := BEZEL_D
	for i in k:
		var j := (i + 1) % k
		var i0 := Vector3(inner[i].x, inner[i].y, f)
		var i1 := Vector3(inner[j].x, inner[j].y, f)
		var o0 := Vector3(outer[i].x, outer[i].y, f)
		var o1 := Vector3(outer[j].x, outer[j].y, f)
		_quad(st, i0, o0, o1, i1)                                     # face
		_quad(st, o0, o0 - Vector3(0, 0, f), o1 - Vector3(0, 0, f), o1)   # outer edge
		_quad(st, i1, i1 - Vector3(0, 0, f + 0.02), i0 - Vector3(0, 0, f + 0.02), i0)  # inner lip
	st.generate_normals()
	return st.commit()


## A quad a-b-c-d; the winding is set so it faces away from the polygon's
## inside for edges, and toward +w for the face (CCW outlines).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)


## A prism along the kitchen's length from an (x, y) outline.
func _prism(n: String, outline: PackedVector2Array, mat: Material) -> CSGPolygon3D:
	var p := CSGPolygon3D.new()
	p.name = n
	p.polygon = outline
	p.depth = Z_RANGE.y - Z_RANGE.x
	p.material = mat
	# CSGPolygon3D extrudes toward -Z from its origin.
	p.position.z = Z_RANGE.y
	return p
