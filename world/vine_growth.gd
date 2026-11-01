extends Node3D

## Nature reclaiming the wreck: ivy and small plants that spread over the
## crashed ship as in-game days pass (GameState.day plus the hour).
##
## The growth is laid out once, when the scene starts, from a fixed seed: vines
## start at the hull's foot, under its edges and inside the breach, and creep
## over the ship's real surfaces (traced with physics rays against the ship's
## collision), climbing, spreading sideways, wrapping over edges and hanging
## down where the hull falls away; small leafy plants come up round the wreck.
## The same seed and ship give the same layout every time, so a loaded game
## shows exactly the growth it was saved with. Each vine has a day it sprouts
## and a speed; the shader (world/vine.gdshader) grows it along its length from
## the current age, so growth is smooth and cumulative, never rebuilt or
## duplicated. Outside sprouts first; inside the ship only after many days.
##
## Every vine (with its branches) and every plant is a group with a stable id
## ("v12", "p3") and its own mesh. cut(id) drops it and records the id in
## GameState.cut_vines, so cleared parts stay clear after saving; the rest
## keeps growing. group_near() finds the group closest to a point, for a
## future cutting tool.

signal vine_cut(id: String)

@export var ship_path := NodePath("../Ship")
@export var seed := 1977
@export var outside_vines := 48
@export var inside_vines := 8
@export var plants := 60
@export var step := 0.16

const LEAF_TEXTURE := "res://world/textures/ivy/ivy_leaf.png"
const STEM_TEXTURE := "res://world/textures/ivy/ivy_stem.png"

var material: ShaderMaterial
var _ship: Node3D
var _space: PhysicsDirectSpaceState3D
var _rng := RandomNumberGenerator.new()
var _lo := Vector3.ZERO
var _hi := Vector3.ZERO
var _ground_y := -0.5
var _groups := {}  # id -> {mesh: MeshInstance3D, points: PackedVector3Array}
var _clock: Node


func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://world/vine.gdshader")
	material.set_shader_parameter("leaf_texture", load(LEAF_TEXTURE))
	material.set_shader_parameter("stem_texture", load(STEM_TEXTURE))
	_clock = get_tree().get_first_node_in_group("day_night")
	if _clock and "_tinted" in _clock:
		_clock._tinted.append(material)
	_update_age()
	_build.call_deferred()


func _process(_delta: float) -> void:
	_update_age()


## In-game days since the crash (day 1 starts at 0).
func age() -> float:
	var hour: float = _clock.get("hour") if _clock else 9.0
	return float(Game.state().day - 1) + hour / 24.0


func _update_age() -> void:
	material.set_shader_parameter("age", age())


## Ids of all growth groups that are still standing.
func group_ids() -> Array:
	return _groups.keys()


## The id of the standing group with a stem or leaf nearest `point` (world
## space), within `radius` metres, or "".
func group_near(point: Vector3, radius := 1.5) -> String:
	var best := ""
	var best_d := radius
	var grown := age()
	for id: String in _groups:
		var g: Dictionary = _groups[id]
		var pts: PackedVector3Array = g["points"]
		var shown := int(maxf(grown - float(g["sprout"]), 0.0) * float(g["rate"]) / step)
		for i in mini(pts.size(), shown + 1):
			var d := point.distance_to(global_transform * pts[i])
			if d < best_d:
				best_d = d
				best = id
	return best


## Cuts a group back: it drops away and stays gone (saved in GameState).
func cut(id: String) -> void:
	if not _groups.has(id):
		return
	var mi: MeshInstance3D = _groups[id]["mesh"]
	_groups.erase(id)
	var gs := Game.state()
	if not id in gs.cut_vines:
		gs.cut_vines.append(id)
		gs.vines_changed.emit()
	vine_cut.emit(id)
	var tw := create_tween().set_parallel()
	tw.tween_property(mi, "position", mi.position + Vector3(0, -1.2, 0), 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.6, 0.8)
	tw.chain().tween_callback(mi.queue_free)


# --- Layout -----------------------------------------------------------------

func _build() -> void:
	_ship = get_node_or_null(ship_path)
	if _ship == null:
		return
	# The physics shapes need a frame to be in the space.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_space = get_world_3d().direct_space_state
	_lo = Vector3(INF, INF, INF)
	_hi = -_lo
	for mi: MeshInstance3D in _ship.find_children("*", "MeshInstance3D", true, false):
		if mi.is_visible_in_tree():
			var ab := mi.global_transform * mi.get_aabb()
			_lo = _lo.min(ab.position)
			_hi = _hi.max(ab.end)
	_ground_y = _lo.y
	_rng.seed = seed
	var cut: Array = Game.state().cut_vines
	var n := 0
	for i in outside_vines:
		var g := _outside_vine(i)
		_add_group("v%d" % n, g, cut)
		n += 1
	for i in inside_vines:
		var g := _inside_vine()
		_add_group("v%d" % n, g, cut)
		n += 1
	for i in plants:
		_add_group("p%d" % i, _plant(i), cut)


## A vine starting at the foot of the hull, or (later ones) under an edge
## higher up, then climbing and spreading; sometimes branching.
func _outside_vine(i: int) -> Dictionary:
	var c := (_lo + _hi) * 0.5
	var high := i >= outside_vines * 0.6
	for attempt in 12:
		var a := _rng.randf() * TAU
		var y := _ground_y + (_rng.randf_range(0.05, 0.5) if not high else _rng.randf_range(1.2, 3.2))
		var dir := Vector3(cos(a), 0, sin(a))
		var from := Vector3(c.x, y, c.z) + dir * 30.0
		var hit := _ray(from, Vector3(c.x, y, c.z))
		if hit.is_empty() or (hit["normal"] as Vector3).y > 0.6 or _inside(hit["position"], hit["normal"]):
			continue
		var climb := Vector3.UP.lerp(Vector3(-dir.z, 0, dir.x) * (1.0 if _rng.randf() < 0.5 else -1.0), _rng.randf_range(0.1, 0.6))
		var length := _rng.randf_range(4.0, 11.0) if not high else _rng.randf_range(3.0, 7.0)
		var sprout := _rng.randf_range(0.4, 3.0) if not high else _rng.randf_range(2.5, 6.0)
		return _vine(hit["position"], hit["normal"], climb, length, sprout, _rng.randf_range(1.0, 2.2), 0.35 if not high else 0.7)
	return {}


## A vine that has found its way in: starting on the floor or walls inside
## the hull, only after many days.
func _inside_vine() -> Dictionary:
	for attempt in 20:
		var p := Vector3(_rng.randf_range(_lo.x, _hi.x), _hi.y + 1.0, _rng.randf_range(_lo.z, _hi.z))
		# Down through the roof: the second surface below is inside.
		var roof := _ray(p, p - Vector3(0, 10, 0))
		if roof.is_empty():
			continue
		var floor_hit := _ray((roof["position"] as Vector3) - Vector3(0, 0.3, 0), (roof["position"] as Vector3) - Vector3(0, 10, 0))
		if floor_hit.is_empty() or (floor_hit["normal"] as Vector3).y < 0.6:
			continue
		var a := _rng.randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		return _vine(floor_hit["position"], floor_hit["normal"], dir, _rng.randf_range(2.0, 5.0), _rng.randf_range(7.0, 13.0), _rng.randf_range(0.5, 0.9), 0.5)
	return {}


## A small leafy plant near the wreck: a short stem with a rosette.
func _plant(i: int) -> Dictionary:
	var c := (_lo + _hi) * 0.5
	for attempt in 12:
		var a := _rng.randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		var hull := _ray(Vector3(c.x, _ground_y + 0.3, c.z) + dir * 30.0, Vector3(c.x, _ground_y + 0.3, c.z))
		if hull.is_empty():
			continue
		var at: Vector3 = hull["position"] + dir * _rng.randf_range(0.3, 3.5)
		var g := _ray(at + Vector3(0, 2, 0), at - Vector3(0, 3, 0), true)
		if g.is_empty():
			continue
		var base: Vector3 = g["position"]
		var sprout := _rng.randf_range(-0.6, 0.3) if i < 10 else _rng.randf_range(0.3, 9.0)
		var pts := PackedVector3Array([base, base + Vector3(0, 0.08, 0)])
		return {"strands": [{"points": pts, "normals": PackedVector3Array([Vector3.UP, Vector3.UP]), "start": 0.0, "hang": PackedFloat32Array([0, 0])}],
			"sprout": sprout, "rate": 0.3, "rosette": base, "size": _rng.randf_range(0.7, 1.3)}
	return {}


## Traces a vine over the hull: main strand plus a few branches.
func _vine(start: Vector3, normal: Vector3, dir: Vector3, length: float, sprout: float, rate: float, branchiness: float) -> Dictionary:
	var main := _crawl(start, normal, dir, length, 0.0)
	var strands := [main]
	var mp: PackedVector3Array = main["points"]
	var k := 6
	while k < mp.size() - 6:
		if _rng.randf() < branchiness * 0.12:
			var mn: PackedVector3Array = main["normals"]
			var side := (mp[k + 1] - mp[k]).cross(mn[k]).normalized() * (1.0 if _rng.randf() < 0.5 else -1.0)
			strands.append(_crawl(mp[k], mn[k], (side + Vector3(0, _rng.randf_range(-0.6, 0.5), 0)).normalized(), length * _rng.randf_range(0.2, 0.45), k * step))
			k += 8
		k += 1
	return {"strands": strands, "sprout": sprout, "rate": rate}


## Walks a strand across the ship's surface from p (with surface normal n),
## heading roughly along dir and wandering. Over an edge it wraps round onto
## the next face, or, if there's nothing there, hangs straight down.
## `start` is how far along the vine the strand begins (for branches).
func _crawl(p: Vector3, n: Vector3, dir: Vector3, length: float, start: float) -> Dictionary:
	var pts := PackedVector3Array([p + n * 0.03])
	var nrm := PackedVector3Array([n])
	var hang := PackedFloat32Array([0.0])
	var bias := dir.normalized()
	var hanging := false
	var steps := int(length / step)
	for i in steps:
		if hanging:
			p += Vector3(_rng.randf_range(-0.02, 0.02), -step, _rng.randf_range(-0.02, 0.02))
			if p.y < _ground_y + 0.15:
				break
			pts.append(p)
			nrm.append(n)
			hang.append(minf(1.0, hang[hang.size() - 1] + 0.08))
			continue
		var wander := Basis(n, _rng.randf_range(-0.5, 0.5))
		bias = (wander * bias).normalized()
		var t := bias - n * bias.dot(n)
		if t.length() < 0.05:
			t = n.cross(Vector3.RIGHT)
		t = t.normalized()
		var guess := p + t * step
		# A wall in the way (inside corner): climb onto it.
		var ahead := _ray(p + n * 0.05, guess + n * 0.05)
		var hit := ahead if not ahead.is_empty() else _ray(guess + n * 0.35, guess - n * 0.45)
		if hit.is_empty():
			# Over an edge: wrap round onto the face beyond...
			var round := _ray(guess - n * 0.3, guess - n * 0.3 - t * 0.6)
			if not round.is_empty():
				hit = round
				bias = -n
			else:
				hanging = true
				continue
		var hp: Vector3 = hit["position"]
		if hp.distance_to(p) > step * 4.0 or hp.y > _hi.y + 0.5:
			break
		n = hit["normal"]
		p = hp
		pts.append(p + n * 0.03)
		nrm.append(n)
		hang.append(0.0)
	return {"points": pts, "normals": nrm, "start": start, "hang": hang}


## True if a hull point is inside the ship: roofed over and walled in.
func _inside(p: Vector3, n: Vector3) -> bool:
	var q := p + n * 0.1
	if _ray(q, q + Vector3(0, 8, 0)).is_empty():
		return false
	var walls := 0
	for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		if not _ray(q, q + d * 15.0).is_empty():
			walls += 1
	return walls >= 3


## Ray against the ship only (or, with ground, the ground too); {} if none.
func _ray(from: Vector3, to: Vector3, ground := false) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var exclude: Array[RID] = []
	for i in 6:
		q.exclude = exclude
		var r := _space.intersect_ray(q)
		if r.is_empty():
			return {}
		var col: Node = r["collider"]
		if _ship.is_ancestor_of(col) or (ground and col.is_in_group("grass_surface")):
			if ground and _ship.is_ancestor_of(col):
				return {}
			return r
		exclude.append(r["rid"])
	return {}


# --- Meshes -----------------------------------------------------------------

func _add_group(id: String, g: Dictionary, cut: Array) -> void:
	if g.is_empty() or id in cut:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var sprout: float = g["sprout"]
	var rate: float = g["rate"]
	var all := PackedVector3Array()
	for s in g["strands"]:
		_strand_mesh(st, s, sprout, rate)
		all.append_array(s["points"])
	if g.has("rosette"):
		_rosette(st, g["rosette"], g["size"], sprout, rate)
	var mesh := st.commit()
	if mesh.get_surface_count() == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = id
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader moves vertices; keep it from being culled while growing.
	mi.extra_cull_margin = 1.0
	add_child(mi)
	var local := PackedVector3Array()
	for p in all:
		local.append(to_local(p))
	_groups[id] = {"mesh": mi, "points": local, "sprout": sprout, "rate": rate}


func _strand_mesh(st: SurfaceTool, s: Dictionary, sprout: float, rate: float) -> void:
	var pts: PackedVector3Array = s["points"]
	var nrm: PackedVector3Array = s["normals"]
	var hang: PackedFloat32Array = s["hang"]
	if pts.size() < 2:
		return
	var start: float = s["start"]
	var sides := 4
	var leaf_side := 1.0
	for i in pts.size() - 1:
		var a := to_local(pts[i])
		var b := to_local(pts[i + 1])
		var d0 := start + i * step
		var d1 := d0 + step
		var axis := (b - a).normalized()
		var na := to_local(pts[i] + nrm[i]) - to_local(pts[i])
		var side := axis.cross(na).normalized()
		var up := side.cross(axis).normalized()
		var r0 := lerpf(0.032, 0.012, clampf(float(i) / pts.size(), 0.0, 1.0))
		var r1 := lerpf(0.032, 0.012, clampf(float(i + 1) / pts.size(), 0.0, 1.0))
		for k in sides:
			var t0 := TAU * k / sides
			var t1 := TAU * (k + 1) / sides
			var o00 := (side * cos(t0) + up * sin(t0)) * r0
			var o01 := (side * cos(t1) + up * sin(t1)) * r0
			var o10 := (side * cos(t0) + up * sin(t0)) * r1
			var o11 := (side * cos(t1) + up * sin(t1)) * r1
			for v in [[a + o00, a, d0, 0], [b + o10, b, d1, 0], [b + o11, b, d1, 1], [a + o00, a, d0, 0], [b + o11, b, d1, 1], [a + o01, a, d0, 1]]:
				var vp: Vector3 = v[0]
				var cen: Vector3 = v[1]
				st.set_color(Color(1, 1, 1))
				st.set_normal((vp - cen).normalized())
				st.set_uv(Vector2(float(v[3]) * 0.25 + k * 0.25, float(v[2]) * 0.5))
				st.set_custom(0, Color(v[2], sprout, rate, 0.0))
				st.set_custom(1, Color(cen.x, cen.y, cen.z, hang[mini(i, hang.size() - 1)]))
				st.add_vertex(vp)
		# Leaves along the stem, alternating sides, lying against the hull
		# (or turned outward where the vine hangs free).
		for extra in (2 if _rng.randf() < 0.55 else 1):
			leaf_side = -leaf_side
			var size := _rng.randf_range(0.2, 0.36) * (1.0 - 0.35 * float(i) / pts.size())
			var lean := na.normalized() * 0.4 + side * leaf_side + axis * _rng.randf_range(-0.2, 0.5)
			_leaf(st, a, lean.normalized(), na.normalized(), size, d0, sprout, rate, hang[mini(i, hang.size() - 1)])


## One ivy leaf card growing out of `at`, pointing along `out`, facing `face`.
func _leaf(st: SurfaceTool, at: Vector3, out: Vector3, face: Vector3, size: float, dist: float, sprout: float, rate: float, sway: float) -> void:
	var w := out.cross(face).normalized() * size * 0.5
	var stalk := at + out * size * 0.15 + face * 0.015
	var tip := stalk + out * size
	var quad := [stalk - w, stalk + w, tip + w, tip - w]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	var shade := Color(1, 1, 1) * _rng.randf_range(0.8, 1.1)
	shade.a = 1.0
	var n := (face + out * 0.2).normalized()
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_color(shade)
		st.set_normal(n)
		st.set_uv(uvs[k])
		st.set_custom(0, Color(dist, sprout, rate, 1.0))
		st.set_custom(1, Color(at.x, at.y, at.z, sway + 0.3))
		st.add_vertex(quad[k])


## A rosette of leaves rising from the ground (a small plant).
func _rosette(st: SurfaceTool, base_w: Vector3, size: float, sprout: float, rate: float) -> void:
	var base := to_local(base_w)
	var count := 5 + _rng.randi() % 4
	for k in count:
		var a := TAU * k / count + _rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), _rng.randf_range(0.5, 1.2), sin(a)).normalized()
		var face := (Vector3.UP - out * out.y).normalized().lerp(Vector3.UP, 0.5).normalized()
		_leaf(st, base, out, face, _rng.randf_range(0.22, 0.36) * size, 0.0, sprout, rate, 0.2)
