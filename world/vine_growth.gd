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


## Traces a vine over the hull: a main strand with a few branches, young
## sprigs standing off the surface, and a shoot lifting from each tip.
func _vine(start: Vector3, normal: Vector3, dir: Vector3, length: float, sprout: float, rate: float, branchiness: float) -> Dictionary:
	var main := _crawl(start, normal, dir, length, 0.0, 1.0)
	var strands := [main]
	var mp: PackedVector3Array = main["points"]
	var mn: PackedVector3Array = main["normals"]
	var k := 6
	while k < mp.size() - 6:
		if _rng.randf() < branchiness * 0.12:
			var side := (mp[k + 1] - mp[k]).cross(mn[k]).normalized() * (1.0 if _rng.randf() < 0.5 else -1.0)
			strands.append(_crawl(mp[k], mn[k], (side + Vector3(0, _rng.randf_range(-0.6, 0.5), 0)).normalized(), length * _rng.randf_range(0.2, 0.45), k * step, 0.6))
			k += 8
		k += 1
	for si in strands.size():
		var s: Dictionary = strands[si]
		var pts: PackedVector3Array = s["points"]
		if pts.size() < 4:
			continue
		var nrm: PackedVector3Array = s["normals"]
		var hang: PackedFloat32Array = s["hang"]
		var start_d: float = s["start"]
		# Sprigs: short young stems leaning out from the surface.
		var d := _rng.randf_range(0.5, 1.0)
		while d < (pts.size() - 3) * step:
			var i := int(d / step)
			if hang[i] < 0.5:
				var t := (pts[i + 1] - pts[i]).normalized()
				var side := t.cross(nrm[i]).normalized() * (1.0 if _rng.randf() < 0.5 else -1.0)
				strands.append(_sprig(pts[i], nrm[i], (side * 0.7 + nrm[i] * 0.6 + t * 0.3).normalized(), _rng.randf_range(0.15, 0.35), start_d + i * step))
			d += _rng.randf_range(0.7, 1.4)
		# The growing tip lifts away from the surface, reaching.
		var e := pts.size() - 1
		if hang[e] < 0.5:
			var tdir := (pts[e] - pts[e - 1]).normalized()
			strands.append(_sprig(pts[e], nrm[e], (tdir + nrm[e] * 0.5).normalized(), _rng.randf_range(0.12, 0.25), start_d + e * step))
	return {"strands": strands, "sprout": sprout, "rate": rate}


## A short free-standing stem from p heading along dir, drooping a little
## under its own weight.
func _sprig(p: Vector3, n: Vector3, dir: Vector3, length: float, start: float) -> Dictionary:
	var pts := PackedVector3Array([p])
	var nrm := PackedVector3Array([n])
	var hang := PackedFloat32Array([0.0])
	var q := p
	var dd := dir
	var seg := 0.05
	for i in int(length / seg):
		dd = (dd + Vector3(0, -0.12, 0) + Vector3(_rng.randf_range(-0.15, 0.15), _rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.15, 0.15))).normalized()
		q += dd * seg
		pts.append(q)
		nrm.append(n)
		hang.append(0.6)
	return {"points": pts, "normals": nrm, "start": start, "hang": hang, "free": true, "seg": seg, "width": 0.35}


## Walks a strand across the ship's surface from p (with surface normal n),
## heading roughly along dir and winding: the turn rate itself drifts, so the
## path curves and recurves instead of zig-zagging. Over an edge it wraps
## round onto the next face, or, if there's nothing there, hangs straight
## down. Points are on the surface; the mesh lifts the stem onto it.
## `start` is how far along the vine the strand begins (for branches).
func _crawl(p: Vector3, n: Vector3, dir: Vector3, length: float, start: float, width: float) -> Dictionary:
	var pts := PackedVector3Array([p])
	var nrm := PackedVector3Array([n])
	var hang := PackedFloat32Array([0.0])
	var bias := dir.normalized()
	var hanging := false
	var turn := 0.0
	var steps := int(length / step)
	for i in steps:
		if hanging:
			p += Vector3(_rng.randf_range(-0.015, 0.015), -step, _rng.randf_range(-0.015, 0.015))
			if p.y < _ground_y + 0.15:
				break
			pts.append(p)
			nrm.append(n)
			hang.append(minf(1.0, hang[hang.size() - 1] + 0.08))
			continue
		turn = clampf(turn * 0.85 + _rng.randf_range(-0.12, 0.12), -0.35, 0.35)
		bias = (Basis(n, turn) * bias).normalized()
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
		# A jump across a gap would leave a stem bridging thin air: stop.
		if hp.distance_to(p) > step * 1.8 or hp.y > _hi.y + 0.5:
			break
		n = hit["normal"]
		p = hp
		pts.append(p)
		nrm.append(n)
		hang.append(0.0)
	_smooth(pts, nrm, hang)
	return {"points": pts, "normals": nrm, "start": start, "hang": hang, "width": width}


## Rounds off the strand's kinks, but only where neighbouring points lie on
## the same face (smoothing across an edge would cut into the hull).
static func _smooth(pts: PackedVector3Array, nrm: PackedVector3Array, hang: PackedFloat32Array) -> void:
	for pass_i in 2:
		var src := pts.duplicate()
		for i in range(1, pts.size() - 1):
			if hang[i] > 0.0 or nrm[i - 1].dot(nrm[i]) < 0.95 or nrm[i + 1].dot(nrm[i]) < 0.95:
				continue
			var avg := (src[i - 1] + src[i] * 2.0 + src[i + 1]) * 0.25
			# Keep it on the face: drop what moved along the normal.
			pts[i] = avg - nrm[i] * (avg - src[i]).dot(nrm[i])


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
	var normals := PackedVector3Array()
	for s in g["strands"]:
		_strand_mesh(st, s, sprout, rate)
		all.append_array(s["points"])
		normals.append_array(s["normals"])
	if g.has("rosette"):
		_rosette(st, g["rosette"], g["size"], sprout, rate)
	var mesh := st.commit()
	if mesh.get_surface_count() == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = id
	mi.mesh = mesh
	mi.material_override = material
	# Leaves shadow the hull and each other: the ivy sits on the ship.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# The shader moves vertices; keep it from being culled while growing.
	mi.extra_cull_margin = 1.0
	add_child(mi)
	var local := PackedVector3Array()
	for p in all:
		local.append(to_local(p))
	_groups[id] = {"mesh": mi, "points": local, "normals": normals, "sprout": sprout, "rate": rate}


## A strand's stem (a tapering tube resting on the surface, greener towards
## the young tip) and its leaves, alternating at irregular intervals, larger
## and darker where the stem is old, small and fresh near the tip.
func _strand_mesh(st: SurfaceTool, s: Dictionary, sprout: float, rate: float) -> void:
	var pts: PackedVector3Array = s["points"]
	var nrm: PackedVector3Array = s["normals"]
	var hang: PackedFloat32Array = s["hang"]
	if pts.size() < 2:
		return
	var start: float = s["start"]
	var seg: float = s.get("seg", step)
	var width: float = s.get("width", 1.0)
	var free: bool = s.get("free", false)
	var total := (pts.size() - 1) * seg
	var sides := 5
	var radius := func(i: int) -> float:
		var left := total - i * seg
		var r := lerpf(0.005, 0.022 * width, clampf(left / 2.5, 0.0, 1.0))
		# Hanging shoots are young and thin.
		return minf(r, 0.01) if hang[i] > 0.0 else r
	var centre := func(i: int) -> Vector3:
		# Lift onto the surface by the stem's radius; free stems as they are.
		var c := pts[i] if free or hang[i] > 0.0 else pts[i] + nrm[i] * (float(radius.call(i)) * 0.9 + 0.004)
		return to_local(c)
	var next_leaf := _rng.randf_range(0.04, 0.12)
	var leaf_side := 1.0 if _rng.randf() < 0.5 else -1.0
	for i in pts.size() - 1:
		var a: Vector3 = centre.call(i)
		var b: Vector3 = centre.call(i + 1)
		var d0 := start + i * seg
		var d1 := d0 + seg
		var axis := (b - a).normalized()
		var na := (to_local(pts[i] + nrm[i]) - to_local(pts[i])).normalized()
		var side := axis.cross(na).normalized()
		if side.length() < 0.5:
			side = axis.cross(Vector3.FORWARD).normalized()
		var up := side.cross(axis).normalized()
		var r0: float = radius.call(i)
		var r1: float = radius.call(i + 1)
		var young0 := 1.0 - clampf((total - i * seg) / 1.2, 0.0, 1.0)
		var young1 := 1.0 - clampf((total - (i + 1) * seg) / 1.2, 0.0, 1.0)
		for k in sides:
			var t0 := TAU * k / sides
			var t1 := TAU * (k + 1) / sides
			var o00 := (side * cos(t0) + up * sin(t0)) * r0
			var o01 := (side * cos(t1) + up * sin(t1)) * r0
			var o10 := (side * cos(t0) + up * sin(t0)) * r1
			var o11 := (side * cos(t1) + up * sin(t1)) * r1
			for v in [[a + o00, a, d0, 0, young0], [b + o10, b, d1, 0, young1], [b + o11, b, d1, 1, young1],
					[a + o00, a, d0, 0, young0], [b + o11, b, d1, 1, young1], [a + o01, a, d0, 1, young0]]:
				var vp: Vector3 = v[0]
				var cen: Vector3 = v[1]
				st.set_color(Color(1.0, 1.0, 1.0).lerp(Color(0.75, 1.15, 0.6), float(v[4])))
				st.set_normal((vp - cen).normalized())
				st.set_uv(Vector2((float(v[3]) + k) / sides, float(v[2]) * 0.6))
				st.set_custom(0, Color(v[2], sprout, rate, 0.0))
				st.set_custom(1, Color(cen.x, cen.y, cen.z, hang[mini(i, hang.size() - 1)]))
				st.add_vertex(vp)
		# Leaves at irregular spacing.
		var along := i * seg
		while next_leaf <= along + seg:
			var f := (next_leaf - along) / seg
			var at := a.lerp(b, f)
			var age := clampf((total - next_leaf) / 1.5, 0.0, 1.0)  # 0 at the tip
			leaf_side = -leaf_side
			var size := lerpf(0.09, 0.27, age) * _rng.randf_range(0.8, 1.15) * (0.75 if free else 1.0)
			# Held out to the side on a stalk, blade roughly along the surface,
			# tipped up a little and turned at random.
			var world_up := to_local(pts[i] + Vector3.UP) - to_local(pts[i])
			var lateral := side * leaf_side
			var outward := (lateral + axis * _rng.randf_range(-0.3, 0.6) + (world_up - na * world_up.dot(na)) * 0.35).normalized()
			outward = Basis(na, _rng.randf_range(-0.5, 0.5)) * outward
			var face := (na + world_up * 0.25 + Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.1, 0.25), _rng.randf_range(-0.25, 0.25))).normalized()
			if hang[mini(i, hang.size() - 1)] > 0.0:
				face = (lateral * 0.6 + Vector3(0, 0.4, 0) + axis * 0.2).normalized()
			_leaf(st, at, outward, face, size, start + next_leaf, sprout, rate, hang[mini(i, hang.size() - 1)], age)
			next_leaf += _rng.randf_range(0.11, 0.2) * lerpf(0.75, 1.0, age)


## One ivy leaf: a short stalk from the stem, then a blade of 3 x 4 vertices
## that folds along its midrib, cups slightly, droops towards its tip and
## twists, so no two read alike. Tinted by age (fresh yellow-green to deep
## green, the odd bronzed one) and a little at random.
func _leaf(st: SurfaceTool, at: Vector3, out: Vector3, face: Vector3, size: float, dist: float, sprout: float, rate: float, sway: float, age: float) -> void:
	var f := (out - face * out.dot(face)).normalized()
	var w := f.cross(face).normalized()
	var u := w.cross(f).normalized()
	var stalk_len := size * _rng.randf_range(0.18, 0.4)
	var base := at + f * stalk_len + u * (size * _rng.randf_range(0.12, 0.3))
	var length := size
	var width := size * _rng.randf_range(0.9, 1.1)
	var fold := _rng.randf_range(0.12, 0.3)
	var droop := _rng.randf_range(0.05, 0.25)
	var twist := _rng.randf_range(-0.25, 0.25)
	var tone := Color(0.84, 0.9, 0.84).lerp(Color(1.08, 1.1, 0.82), 1.0 - age)
	if _rng.randf() < 0.03 and age > 0.6:
		tone = Color(0.96, 0.88, 0.7)
	tone = tone * _rng.randf_range(0.88, 1.08)
	tone.a = 1.0
	var grid := []
	for vi in 4:
		var v := vi / 3.0
		var row := []
		for si in 3:
			var s := si - 1.0
			# The blade is widest a third of the way up; the tip narrows.
			var half := width * 0.5 * (0.85 + 0.6 * v - 0.9 * v * v)
			var p := base + f * (v * length) + w * (s * half)
			p += u * (absf(s) * half * fold - v * v * length * droop + s * v * length * twist)
			row.append(p)
		grid.append(row)
	var norm := func(vi: int, si: int) -> Vector3:
		var dv: Vector3 = grid[mini(vi + 1, 3)][si] - grid[maxi(vi - 1, 0)][si]
		var ds: Vector3 = grid[vi][mini(si + 1, 2)] - grid[vi][maxi(si - 1, 0)]
		var n := ds.cross(dv).normalized()
		return n if n.dot(u) > 0.0 else -n
	var uv := func(vi: int, si: int) -> Vector2:
		return Vector2(si * 0.5, 0.97 - vi / 3.0 * 0.97)
	for vi in 3:
		for si in 2:
			var quad := [[vi, si], [vi, si + 1], [vi + 1, si + 1], [vi + 1, si]]
			for q in [0, 1, 2, 0, 2, 3]:
				var c: Array = quad[q]
				st.set_color(tone)
				st.set_normal(norm.call(c[0], c[1]))
				st.set_uv(uv.call(c[0], c[1]))
				st.set_custom(0, Color(dist, sprout, rate, 1.0))
				st.set_custom(1, Color(at.x, at.y, at.z, sway + 0.3))
				st.add_vertex(grid[c[0]][c[1]])
	# The stalk: a thin green strip from the stem to the blade (drawn with
	# the leaf texture's green midrib).
	var sw := w * 0.005
	var stalk := [at - sw, at + sw, base + sw, base - sw]
	for q in [0, 1, 2, 0, 2, 3]:
		st.set_color(tone * 0.8)
		st.set_normal(u)
		st.set_uv(Vector2(0.5, 0.62))
		st.set_custom(0, Color(dist, sprout, rate, 1.0))
		st.set_custom(1, Color(at.x, at.y, at.z, sway + 0.3))
		st.add_vertex(stalk[q])


## A small ground plant: a rosette of ivy-type leaves on short stalks rising
## from the ground, fresh in the middle, older and lower round the outside.
func _rosette(st: SurfaceTool, base_w: Vector3, size: float, sprout: float, rate: float) -> void:
	var base := to_local(base_w)
	var count := 5 + _rng.randi() % 4
	for k in count:
		var a := TAU * k / count + _rng.randf_range(-0.3, 0.3)
		var inner := float(k % 3 == 0)
		var out := Vector3(cos(a), lerpf(0.45, 1.3, inner) + _rng.randf_range(-0.1, 0.1), sin(a)).normalized()
		var face := (Vector3.UP * 1.2 + Vector3(cos(a), 0, sin(a)) * lerpf(0.5, 0.1, inner)).normalized()
		_leaf(st, base, out, face, _rng.randf_range(0.2, 0.32) * size * lerpf(1.0, 0.7, inner), 0.0, sprout, rate, 0.2, 1.0 - inner * 0.8)
