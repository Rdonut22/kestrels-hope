extends Node3D

## The ruined greenhouse in the east forest (tools/build_scenes.gd
## _build_greenhouse).
##
## The model (world/models/greenhouse) has a great round hole cut through
## the ceiling between the ground floor and the glass dome, and a stairwell
## notch along the inner wall (tools/greenhouse_interior.py, which also
## measured the numbers in interior.json). Built here, at run time:
##
##   - the cut's stone faces: the hole's rim, the stairwell's sides, the
##     caps on the inner arcade where the cut leaves it;
##   - a staircase of cantilevered stone steps round the inner wall from
##     the ground floor up to the upper floor, the walkway round the hole;
##   - iron railings along the stairs and round the walkway's edge;
##   - light shafts where the sun gets through the dome's missing glass,
##     following the sun through the day (world/day_night.gd), with dust;
##   - butterflies in the ground floor.
##
## The model's own material is replaced by a sharper one (the colour
## texture sharpened and lossless, anisotropic filtering).
##
## Interior coordinates: the model's frame in metres, heights from its
## lowest point (the Interior node undoes the model's scale and offset).

const MATERIAL := preload("res://world/models/greenhouse/greenhouse_material.tres")
const LAYOUT := "res://world/models/greenhouse/interior.json"
const STONE := preload("res://world/models/greenhouse/greenhouse_stone.png")

## How many light shafts (the largest gaps in the glass), how wide they
## look relative to their gap, and how bright.
@export var shaft_count := 9
@export var shaft_width := 0.75
@export_range(0.0, 1.0) var shaft_strength := 0.16
@export var butterfly_count := 14
const RAIL_HEIGHT := 1.05
const STAIR_THICK := 0.32

var _L: Dictionary
var _interior: Node3D
var _stone: StandardMaterial3D
var _iron: StandardMaterial3D
var _shafts: Array = []   # [MeshInstance3D, CPUParticles3D, gap point, outward normal, size]
var _shaft_mat: ShaderMaterial
var _clock: Node
var _t := 0.0


func _ready() -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = MATERIAL
	var f := FileAccess.open(LAYOUT, FileAccess.READ)
	if f == null:
		return
	_L = JSON.parse_string(f.get_as_text())
	var sc: float = _L["scale"]
	_interior = Node3D.new()
	_interior.name = "Interior"
	_interior.scale = Vector3.ONE / sc
	_interior.position = Vector3(0, float(_L["y0"]) / sc, 0)
	add_child(_interior)
	_make_materials()
	_build_cut_faces()
	_build_stairs()
	_build_railings()
	_build_shafts()
	_build_butterflies()


# ------------------------------------------------------------------ helpers

static func _polar(r: float, a: float, y: float) -> Vector3:
	return Vector3(r * cos(a), y, r * sin(a))


func _make_materials() -> void:
	_stone = StandardMaterial3D.new()
	_stone.albedo_texture = STONE
	_stone.albedo_color = Color(0.92, 0.9, 0.86)
	_stone.roughness = 0.9
	_stone.uv1_triplanar = true
	_stone.uv1_world_triplanar = true
	_stone.uv1_scale = Vector3.ONE / 5.0
	_stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_stone.cull_mode = BaseMaterial3D.CULL_DISABLED
	_iron = StandardMaterial3D.new()
	_iron.albedo_color = Color(0.16, 0.12, 0.09)
	_iron.metallic = 0.6
	_iron.roughness = 0.55


func _mesh_node(st: SurfaceTool, name: String, mat: Material) -> MeshInstance3D:
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = st.commit()
	mi.material_override = mat
	_interior.add_child(mi)
	return mi


## A quad, both sides drawn by the material (cull disabled).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for p in [a, b, c, a, c, d]:
		st.add_vertex(p)


## A solid of trimesh faces for collision (both sides).
func _collider(faces: PackedVector3Array, name: String) -> void:
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var body := StaticBody3D.new()
	body.name = name
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	_interior.add_child(body)


static func _face_quad(f: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	f.append_array(PackedVector3Array([a, b, c, a, c, d]))


# ------------------------------------------------------------------ cut faces

## Close the cut: the hole's rim (a stone band from the slab's underside to
## its top), the stairwell's sides and outer face, caps on the arcade.
func _build_cut_faces() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hole: Dictionary = _L["hole"]
	var R: float = hole["radius"]
	var rim: Array = hole["rim"]
	var n0: float = _L["notch"]["from"]
	var n1: float = _L["notch"]["to"]
	var n := rim.size()
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		if _in_notch(a0, n0, n1) and _in_notch(a1, n0, n1):
			continue
		var r0: Variant = rim[k]
		var r1: Variant = rim[(k + 1) % n]
		if r0 == null or r1 == null:
			continue
		_quad(st, _polar(R, a0, r0[0]), _polar(R, a1, r1[0]), _polar(R, a1, r1[1]), _polar(R, a0, r0[1]))
	# The stairwell's two sides (radial faces) and its outer face.
	var edges: Array = _L["notch"]["edges"]
	for side in 2:
		var a: float = [n0, n1][side]
		var row: Array = edges[side]
		for i in row.size() - 1:
			var p: Array = row[i]
			var q: Array = row[i + 1]
			if p[1] == null or q[1] == null:
				continue
			_quad(st, _polar(p[0], a, p[1]), _polar(q[0], a, q[1]), _polar(q[0], a, q[2]), _polar(p[0], a, p[2]))
	var rw: float = _L["notch"]["r_wall"]
	var y_low: float = float(hole["y_cut"]) - 1.5
	var steps := 24
	for i in steps:
		var a0 := lerpf(n0, n1, float(i) / steps)
		var a1 := lerpf(n0, n1, float(i + 1) / steps)
		_quad(st, _polar(rw, a0, y_low), _polar(rw, a1, y_low), _polar(rw, a1, 18.05), _polar(rw, a0, 18.05))
	# Caps where the cut crosses the inner arcade.
	var cop: Array = _L["coping"]
	var y: float = hole["y_cut"]
	for k in cop.size():
		var c0: Variant = cop[k]
		var c1: Variant = cop[(k + 1) % cop.size()]
		if c0 == null or c1 == null:
			continue
		var a0 := TAU * k / cop.size()
		var a1 := TAU * (k + 1) / cop.size()
		_quad(st, _polar(c0[0], a0, y), _polar(c1[0], a1, y), _polar(c1[1], a1, y), _polar(c0[1], a0, y))
	var mi := _mesh_node(st, "CutFaces", _stone)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static func _in_notch(a: float, n0: float, n1: float) -> bool:
	a = fposmod(a, TAU)
	return a > fposmod(n0, TAU) and a < fposmod(n1, TAU)


# ------------------------------------------------------------------ stairs

func _stair_y(a: float) -> float:
	var s: Dictionary = _L["stair"]
	return lerpf(s["y0"], s["y1"], (a - float(s["start"])) / (float(s["end"]) - float(s["start"])))


## Cantilevered stone steps round the inner wall, anticlockwise from the
## ground floor to the upper floor, and a landing onto the walkway. Walked
## on as a smooth ramp (the player has no step-up).
func _build_stairs() -> void:
	var s: Dictionary = _L["stair"]
	var a0: float = s["start"]
	var a1: float = s["end"]
	var steps: int = s["steps"]
	var ro: float = s["r_outer"]
	var w: float = s["width"]
	var ri := ro - w
	var y0: float = s["y0"]
	var y1: float = s["y1"]
	var rise := (y1 - y0) / steps
	var da := (a1 - a0) / steps
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = steps + 1
	var rm := (ro + ri) * 0.5
	for k in steps:
		var a := a0 + (k + 0.5) * da
		var top := y0 + (k + 1) * rise
		# Each step a slab: radial width, tangential tread (a little overlap),
		# its top at the step's height.
		var basis := Basis(Vector3.UP, -a)   # local X radial, Z tangential
		var tread := rm * da * 1.06
		var b := basis.scaled(Vector3(w + 0.3, STAIR_THICK, tread))
		mm.set_instance_transform(k, Transform3D(b, _polar(rm + 0.15, a, top - STAIR_THICK * 0.5)))
	# The landing: from the top step to the walkway's edge.
	var n1: float = _L["notch"]["to"]
	var la := (a1 + n1) * 0.5 + 0.004
	var lb := Basis(Vector3.UP, -la).scaled(Vector3(w + 0.4, STAIR_THICK, rm * (n1 - a1 + 0.02)))
	mm.set_instance_transform(steps, Transform3D(lb, _polar(rm + 0.2, la, y1 - STAIR_THICK * 0.5)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Stairs"
	mmi.multimesh = mm
	mmi.material_override = _stone
	_interior.add_child(mmi)
	# Under the steps, a solid stone flight (its soffit and open side), so
	# it reads as one cantilevered stair rather than loose slabs.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var depth := 0.55
	var seg_n := 80
	for i in seg_n:
		var b0 := lerpf(a0, a1, float(i) / seg_n)
		var b1 := lerpf(a0, a1, float(i + 1) / seg_n)
		var t0 := y0 + (b0 - a0) / da * rise
		var t1 := y0 + (b1 - a0) / da * rise
		# Soffit, sloping with the flight a little under the steps' backs.
		var u0 := maxf(t0 - depth, y0 - 0.05)
		var u1 := maxf(t1 - depth, y0 - 0.05)
		_quad(st, _polar(ri, b0, u0), _polar(ro + 0.3, b0, u0), _polar(ro + 0.3, b1, u1), _polar(ri, b1, u1))
		# The open side, from the soffit up to the steps' noses.
		_quad(st, _polar(ri, b0, u0), _polar(ri, b1, u1), _polar(ri, b1, t1 + rise - STAIR_THICK), _polar(ri, b0, t0 + rise - STAIR_THICK))
	_mesh_node(st, "Flight", _stone)
	# The ramp they're walked on: one tread before the first step at floor
	# level up to the top step, then level onto the walkway.
	var faces := PackedVector3Array()
	var seg := 96
	var start := a0 - da
	for i in seg:
		var t0 := float(i) / seg
		var t1 := float(i + 1) / seg
		var b0 := lerpf(start, a1, t0)
		var b1 := lerpf(start, a1, t1)
		var h0 := lerpf(y0, y1, t0)
		var h1 := lerpf(y0, y1, t1)
		_face_quad(faces, _polar(ri, b0, h0), _polar(ro, b0, h0), _polar(ro, b1, h1), _polar(ri, b1, h1))
	_face_quad(faces, _polar(ri, a1, y1), _polar(ro, a1, y1), _polar(ro, n1 + 0.02, y1), _polar(ri, n1 + 0.02, y1))
	_collider(faces, "StairRamp")


# ------------------------------------------------------------------ railings

## Iron railings: up the stairs' open side, round the walkway's edge over
## the hole, and across the stairwell's two ends. Each also a low wall for
## collision.
func _build_railings() -> void:
	var s: Dictionary = _L["stair"]
	var a0: float = s["start"]
	var a1: float = s["end"]
	var ri: float = float(s["r_outer"]) - float(s["width"]) + 0.08
	var n0: float = _L["notch"]["from"]
	var n1: float = _L["notch"]["to"]
	var R: float = float(_L["hole"]["radius"]) - 0.25
	var rw: float = _L["notch"]["r_wall"]
	var walk_y := 18.05
	var runs := []   # each: an Array of [Vector3 foot]
	# Up the stairs.
	var stair := []
	var n := 48
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		stair.append(_polar(ri, a, _stair_y(a)))
	runs.append(stair)
	# Round the hole's edge, from the stairwell's top end round to its
	# bottom end.
	var arc := []
	var span := fposmod(n0 - n1, TAU)
	n = 120
	for i in n + 1:
		arc.append(_polar(R, n1 + span * i / n, walk_y))
	runs.append(arc)
	# Across the stairwell's lower end (a drop to the stairs below), and its
	# upper end from the hole to the stairs' rail.
	runs.append([_polar(R, n0, walk_y), _polar(rw, n0, walk_y)])
	runs.append([_polar(R, n1, walk_y), _polar(ri, n1, walk_y)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for run in runs:
		var pts: Array = run
		var since := 99.0
		for i in pts.size():
			var p: Vector3 = pts[i]
			if i > 0:
				var q: Vector3 = pts[i - 1]
				since += p.distance_to(q)
				# Top rail and a lower rail, square bars.
				for h in [RAIL_HEIGHT, RAIL_HEIGHT * 0.45]:
					_bar(st, q + Vector3.UP * h, p + Vector3.UP * h, 0.05)
				_face_quad(faces, q, p, p + Vector3.UP * (RAIL_HEIGHT + 0.1), q + Vector3.UP * (RAIL_HEIGHT + 0.1))
			# Posts every 1.6 m and at the ends.
			if since >= 1.6 or i == 0 or i == pts.size() - 1:
				_bar(st, p, p + Vector3.UP * (RAIL_HEIGHT + 0.06), 0.045)
				since = 0.0
	var mi := _mesh_node(st, "Railings", _iron)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_collider(faces, "RailCollision")


## A square bar from a to b (thickness t).
static func _bar(st: SurfaceTool, a: Vector3, b: Vector3, t: float) -> void:
	var d := (b - a)
	if d.length() < 0.001:
		return
	d = d.normalized()
	var side := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized() * t * 0.5
	var up := side.cross(d).normalized() * t * 0.5
	var c := [side + up, -side + up, -side - up, side - up]
	for i in 4:
		var p0: Vector3 = c[i]
		var p1: Vector3 = c[(i + 1) % 4]
		_quad(st, a + p0, b + p0, b + p1, a + p1)


# ------------------------------------------------------------------ light

## Shafts of light through the largest gaps in the dome's glass. Each runs
## from its gap away from the sun until it meets something (a physics ray,
## redone every second as the sun moves), and fades out at night or when
## its gap faces away from the sun. Dust drifts in each.
func _build_shafts() -> void:
	_shaft_mat = ShaderMaterial.new()
	_shaft_mat.shader = load("res://world/light_shaft.gdshader")
	var gaps: Array = _L.get("gaps", [])
	var dust_mesh := QuadMesh.new()
	dust_mesh.size = Vector2(0.035, 0.035)
	var dust_mat := StandardMaterial3D.new()
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust_mat.albedo_color = Color(1.0, 0.92, 0.75, 0.55)
	dust_mesh.material = dust_mat
	for i in mini(shaft_count, gaps.size()):
		var g: Dictionary = gaps[i]
		var p := Vector3(g["p"][0], g["p"][1], g["p"][2])
		var nrm := Vector3(g["n"][0], g["n"][1], g["n"][2])
		var size: float = g["size"]
		var mi := MeshInstance3D.new()
		mi.name = "Shaft%d" % i
		var cyl := CylinderMesh.new()
		cyl.top_radius = size * shaft_width * 0.5
		cyl.bottom_radius = size * shaft_width * 0.5
		cyl.height = 1.0
		cyl.radial_segments = 14
		cyl.cap_top = false
		cyl.cap_bottom = false
		mi.mesh = cyl
		mi.material_override = _shaft_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 260.0
		_interior.add_child(mi)
		var dust := CPUParticles3D.new()
		dust.name = "Dust%d" % i
		dust.mesh = dust_mesh
		dust.amount = 36
		dust.lifetime = 9.0
		dust.preprocess = 9.0
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		dust.direction = Vector3(0, 1, 0)
		dust.spread = 180.0
		dust.gravity = Vector3(0, -0.015, 0)
		dust.initial_velocity_min = 0.02
		dust.initial_velocity_max = 0.08
		dust.visibility_range_end = 120.0
		_interior.add_child(dust)
		_shafts.append([mi, dust, p, nrm, size])
	_update_shafts.call_deferred()


func _sun_dir() -> Vector3:
	# Towards the sun (world/day_night.gd's path), in the interior's frame.
	if _clock == null:
		_clock = get_tree().get_first_node_in_group("day_night")
	var hour: float = _clock.get("hour") if _clock else 10.0
	var a := (hour - 6.0) / 12.0 * PI
	var w := Vector3(cos(a), sin(a) * 0.9, 0.3).normalized()
	return (_interior.global_basis.inverse() * w).normalized()


func _update_shafts() -> void:
	if _shafts.is_empty() or not is_inside_tree():
		return
	var sun := _sun_dir()
	var day := smoothstep(0.05, 0.3, sun.y)
	_shaft_mat.set_shader_parameter("strength", shaft_strength * day)
	var space := get_world_3d().direct_space_state
	var to_world := _interior.global_transform
	var sc: float = _L["scale"]
	for s in _shafts:
		var mi: MeshInstance3D = s[0]
		var dust: CPUParticles3D = s[1]
		var p: Vector3 = s[2]
		var nrm: Vector3 = s[3]
		var size: float = s[4]
		var facing := clampf((nrm.dot(sun) - 0.05) / 0.3, 0.0, 1.0)
		var on := day * facing > 0.02
		mi.visible = on
		dust.emitting = on
		dust.visible = on
		if not on:
			continue
		# From the gap down along the sunlight until it lands.
		var down := -sun
		var start := p - nrm * 0.6
		var length := 42.0
		var q := PhysicsRayQueryParameters3D.create(to_world * start, to_world * (start + down * length))
		var hit := space.intersect_ray(q)
		if hit:
			length = maxf(2.0, (to_world.affine_inverse() * (hit["position"] as Vector3)).distance_to(start))
		var mid := start + down * length * 0.5
		var y := down
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(y).normalized()
		mi.transform = Transform3D(Basis(x, y * length, z), mid)
		mi.set_instance_shader_parameter("fade", facing)
		dust.transform = Transform3D(Basis(x, y, z), mid)
		var rad := size * shaft_width * 0.45
		dust.emission_box_extents = Vector3(rad, length * 0.45, rad)


func _process(delta: float) -> void:
	_t += delta
	if _t > 1.0:
		_t = 0.0
		_update_shafts()


# ------------------------------------------------------------------ butterflies

func _build_butterflies() -> void:
	var mesh: Mesh = load("res://world/models/butterfly.res")
	if mesh == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4555
	var R: float = float(_L["hole"]["radius"]) - 3.0
	var floor_y: float = _L["floor_y"]
	for k in butterfly_count:
		var fly := Node3D.new()
		fly.set_script(load("res://world/butterfly.gd"))
		fly.add_to_group("night_glow", true)
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * R
		fly.name = "Butterfly%d" % k
		fly.set("wander", 3.5)
		fly.position = _polar(r, a, floor_y + rng.randf_range(0.8, 4.0))
		_interior.add_child(fly)
		var body := MeshInstance3D.new()
		body.mesh = mesh
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * 0.2), Vector3.ZERO)
		body.visibility_range_end = 90.0
		fly.add_child(body)
