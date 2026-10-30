@tool
extends Node3D

## A giant low-poly redwood, built procedurally into a single mesh with one
## material (world/redwood.gdshader), so whole forests stay cheap.
##
## Anatomy, after real old-growth redwoods: a huge flared base with roots
## spreading into the ground; a tall, straight, fluted trunk in warm red-brown
## stripes, bare for the lower part apart from the odd burl and broken stub;
## then a narrow, irregular crown of short drooping branches with twigs,
## carrying flattened low-poly needle sprays in several greens, up to an
## uneven spire. Branch tips sway in the wind (each to its own rhythm), the
## trunk barely moves.
##
## The origin is at ground level, at the centre of the trunk. Change any
## exported value (or the seed) to get a different tree.

@export var height := 48.0:
	set(v):
		height = v
		_queue_rebuild()
## Radius of the trunk above the flare (m). The base flares out wider.
@export var trunk_radius := 2.0:
	set(v):
		trunk_radius = v
		_queue_rebuild()
## Widest the crown gets (m across).
@export var crown_width := 17.0:
	set(v):
		crown_width = v
		_queue_rebuild()
## Where the crown starts, as a fraction of the height (redwoods stay bare
## a long way up).
@export_range(0.2, 0.8) var crown_start := 0.4:
	set(v):
		crown_start = v
		_queue_rebuild()
@export_range(0.3, 2.0) var branch_density := 1.0:
	set(v):
		branch_density = v
		_queue_rebuild()
@export_range(0.5, 1.5) var branch_length := 1.0:
	set(v):
		branch_length = v
		_queue_rebuild()
@export_range(0.3, 2.0) var foliage_density := 1.0:
	set(v):
		foliage_density = v
		_queue_rebuild()
## How far from perfectly regular: trunk curve, crown lean, spacing.
@export_range(0.0, 1.0) var irregularity := 0.5:
	set(v):
		irregularity = v
		_queue_rebuild()
@export var tree_seed := 7:
	set(v):
		tree_seed = v
		_queue_rebuild()

const BARK := [Color(0.30, 0.10, 0.05), Color(0.38, 0.14, 0.07), Color(0.24, 0.08, 0.04),
	Color(0.46, 0.19, 0.10), Color(0.34, 0.12, 0.06)]
const GROOVE := Color(0.12, 0.05, 0.03)
const GREENS := [Color(0.03, 0.10, 0.04), Color(0.06, 0.18, 0.06), Color(0.14, 0.28, 0.08),
	Color(0.05, 0.15, 0.08), Color(0.09, 0.22, 0.07)]

var _st: SurfaceTool
var _rng: RandomNumberGenerator
var _queued := false
var _phase := Vector2.ZERO  # interleaved [flex, phase] for the next triangles
var _mi: MeshInstance3D
var _mat: ShaderMaterial
var _tris := 0


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _queued:
		return
	_queued = true
	_rebuild.call_deferred()


## Triangle count of the current mesh (for checking budgets).
func triangle_count() -> int:
	return _tris


func _rebuild() -> void:
	_queued = false
	if _mi:
		_mi.queue_free()
	_rng = RandomNumberGenerator.new()
	_rng.seed = tree_seed
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tris = 0
	_build_trunk()
	_build_roots()
	_build_trunk_details()
	_build_crown()
	_mi = MeshInstance3D.new()
	_mi.name = "Mesh"
	_mi.mesh = _st.commit()
	if not _mat:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://world/redwood.gdshader")
	_mat.set_shader_parameter("tree_height", height)
	_mi.material_override = _mat
	add_child(_mi)


# ---------- shape ----------

## Centre of the trunk at height h: mostly straight, a gentle wander.
func _spine(h: float) -> Vector3:
	var a := irregularity * height * 0.012
	var u := h / height
	return Vector3(sin(u * 2.3 + tree_seed) * a * u, h, cos(u * 1.7 + tree_seed * 0.7) * a * u)


## Trunk radius at height h: big flare at the foot, steady taper above.
func _radius(h: float) -> float:
	var u := clampf(h / height, 0.0, 1.0)
	var r := trunk_radius * (0.1 + 0.9 * pow(1.0 - u, 1.15))
	return r + trunk_radius * 0.75 * exp(-h / (trunk_radius * 1.2))


func _build_trunk() -> void:
	var segs := 18
	# Fluting: each column of facets has its own ridge depth and colour, so
	# the bark reads as long vertical streaks.
	var ridge := []
	var stripe := []
	for k in segs:
		ridge.append(_rng.randf())
		stripe.append(_rng.randi() % BARK.size())
	var hs: Array[float] = [0.0, 0.35, 0.8, 1.4, 2.2, 3.2, 4.5]
	var h := 6.0
	while h < height * 0.96:
		hs.append(h)
		h += lerpf(2.2, 4.0, h / height)
	hs.append(height * 0.96)
	var rings := []
	for i in hs.size():
		var hh: float = hs[i]
		var c := _spine(hh)
		var r := _radius(hh)
		var ring := []
		for k in segs:
			var a := TAU * k / segs + hh * 0.012
			var depth: float = 1.0 - 0.24 * (0.4 + 0.6 * irregularity) * float(ridge[k]) * (0.6 + 0.4 * sin(hh * 0.3 + k))
			if hh < 2.5:
				# Buttress lobes at the foot.
				depth *= 1.0 + 0.25 * maxf(0.0, sin(a * 3.0 + tree_seed)) * (1.0 - hh / 2.5)
			ring.append(c + Vector3(cos(a), 0.0, sin(a)) * r * depth)
		rings.append(ring)
	_phase = Vector2.ZERO
	for i in rings.size() - 1:
		var hh: float = hs[i]
		for k in segs:
			var k2 := (k + 1) % segs
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i][k2]
			var c: Vector3 = rings[i + 1][k2]
			var d: Vector3 = rings[i + 1][k]
			var out := ((a + b) * 0.5 - _spine(hh)).normalized()
			var col: Color = BARK[(stripe[k] + (1 if _rng.randf() < 0.15 else 0)) % BARK.size()]
			if float(ridge[k]) > 0.6:
				col = col.lerp(GROOVE, 0.7)
			col = col.darkened(0.25 * (1.0 - clampf(hh / 3.0, 0.0, 1.0)))  # damp, dark foot
			col = col.lightened(_rng.randf_range(-0.04, 0.05))
			_quad(a, b, c, d, out, col)


func _build_roots() -> void:
	var n := 6 + _rng.randi() % 3
	for i in n:
		var a := TAU * i / n + _rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(a), 0.0, sin(a))
		var start := out * _radius(1.0) * 0.6 + Vector3(0, 1.6, 0)
		var reach := trunk_radius * _rng.randf_range(1.6, 2.6)
		var end := out * (trunk_radius + reach) + Vector3(0, -0.35, 0)
		var mid := out * (trunk_radius + reach * 0.45) + Vector3(0, 0.35, 0)
		_limb([start, mid, end], trunk_radius * _rng.randf_range(0.35, 0.5), 0.08, 5, BARK[2].darkened(0.15), 0.0, 0.0, 1.4)


func _build_trunk_details() -> void:
	# Burls: lumpy growths low on the trunk.
	for i in 3:
		var h := _rng.randf_range(3.0, height * crown_start * 0.7)
		var a := _rng.randf() * TAU
		var out := Vector3(cos(a), 0.0, sin(a))
		var p := _spine(h) + out * _radius(h) * 0.92
		var s := trunk_radius * _rng.randf_range(0.18, 0.32)
		_blob(p, Vector3(s, s * 1.3, s), Basis.looking_at(out), BARK[0].darkened(0.1), 0.0, 0.0, 0.3)
	# Broken stubs of old lower branches.
	for i in 5:
		var h := _rng.randf_range(height * 0.2, height * crown_start)
		var a := _rng.randf() * TAU
		var out := Vector3(cos(a), _rng.randf_range(-0.3, 0.1), sin(a)).normalized()
		var p := _spine(h) + Vector3(out.x, 0, out.z).normalized() * _radius(h) * 0.85
		var len := _rng.randf_range(0.6, 1.6)
		_limb([p, p + out * len * 0.5, p + out * len], _rng.randf_range(0.12, 0.22), 0.07, 5, BARK[3].darkened(0.1), 0.0, 0.0, 1.0)


func _build_crown() -> void:
	var top := height * 0.95
	var base := height * crown_start
	var count := int(52 * branch_density)
	var bias := _rng.randf() * TAU  # the side the crown leans toward
	var golden := 2.39996
	var a := _rng.randf() * TAU
	for i in count:
		var u := (float(i) + _rng.randf_range(-0.4, 0.4) * irregularity) / count
		u = clampf(u, 0.0, 1.0)
		var h := lerpf(base, top, u)
		a += golden + _rng.randf_range(-0.6, 0.6) * irregularity
		var out := Vector3(cos(a), 0.0, sin(a))
		# Long-ish and drooping low in the crown, short near the top.
		var prof := 0.18 + 0.82 * pow(1.0 - u, 0.75)
		var length := crown_width * 0.5 * prof * branch_length * _rng.randf_range(0.75, 1.15)
		length *= 1.0 + 0.3 * irregularity * cos(a - bias)
		_branch(_spine(h) + out * _radius(h) * 0.85, out, length, u)
	# Inner foliage close to the trunk fills the crown so it isn't see-through.
	var inner := int(34 * foliage_density)
	for i in inner:
		var h := lerpf(base + 2.0, top - 2.0, _rng.randf())
		var b := _rng.randf() * TAU
		var p := _spine(h) + Vector3(cos(b), 0, sin(b)) * (_radius(h) + 1.2)
		_spray(p, Vector3(cos(b), 0, sin(b)), _rng.randf_range(2.4, 3.6), GREENS[_rng.randi() % 2], 0.15, _rng.randf())
	# The spire: tight sprays up the last stretch of trunk.
	var tip := 9
	for i in tip:
		var f := float(i) / tip
		var h := lerpf(top - 4.0, height * 1.01, f)
		var b := _rng.randf() * TAU
		var p := _spine(h) + Vector3(cos(b), 0, sin(b)) * _rng.randf_range(0.0, 0.6)
		_spray(p, Vector3(cos(b), 0.5, sin(b)).normalized(), lerpf(3.2, 1.4, f), GREENS[1 + i % 3], 0.4 + f * 0.4, _rng.randf())


func _branch(start: Vector3, out: Vector3, length: float, u: float) -> void:
	var phase := _rng.randf()
	var droop := length * lerpf(0.4, 0.12, u) * _rng.randf_range(0.7, 1.3)
	var rise := length * lerpf(0.06, 0.2, u)
	var mid := start + out * length * 0.5 + Vector3(0, rise, 0)
	var end := start + out * length + Vector3(0, rise - droop, 0)
	var r0 := clampf(trunk_radius * 0.11 * sqrt(length / 5.0), 0.1, 0.42)
	var flex_tip := clampf(length / 6.5, 0.35, 1.0)
	_limb([start, mid, end], r0, 0.04, 5, BARK[1].darkened(0.05), 0.0, phase, 1.0, flex_tip)
	# Twigs off the main branch.
	var twigs := 2 + _rng.randi() % 3
	for t in twigs:
		var f := _rng.randf_range(0.35, 0.85)
		var p := _bez(start, mid, end, f)
		var side := out.rotated(Vector3.UP, _rng.randf_range(0.6, 1.2) * (1.0 if t % 2 else -1.0))
		var tl := length * _rng.randf_range(0.28, 0.42)
		var te := p + side * tl + Vector3(0, -tl * 0.25, 0)
		_limb([p, (p + te) * 0.5 + Vector3(0, 0.15, 0), te], r0 * 0.35, 0.02, 3, BARK[1], flex_tip * f, phase, 1.0, flex_tip * minf(f + 0.3, 1.0))
		_spray(te, side, _rng.randf_range(2.0, 3.0) * sqrt(length / 5.0 + 0.4), GREENS[_rng.randi() % GREENS.size()], flex_tip * minf(f + 0.3, 1.0), phase)
	# Needle sprays hanging along the outer part of the branch.
	var n := maxi(3, int(length / 0.55 * foliage_density))
	for s in n:
		var f := lerpf(0.3, 1.05, float(s) / maxf(n - 1, 1))
		var p := _bez(start, mid, end, minf(f, 1.0)) + Vector3(0, -0.2, 0)
		if f > 1.0:
			p += out * (f - 1.0) * length
		var size := lerpf(1.8, 2.9, _rng.randf()) * lerpf(0.75, 1.0, sqrt(length / 6.0))
		var shade: Color = GREENS[_rng.randi() % GREENS.size()]
		if f > 0.85 and _rng.randf() < 0.5:
			shade = GREENS[2]  # sunlit tips
		_spray(p, out, size, shade, flex_tip * minf(f, 1.0), phase)
		# A second, darker layer hanging underneath gives the sprays depth.
		if _rng.randf() < 0.6:
			_spray(p + Vector3(0, -size * 0.3, 0) + out.rotated(Vector3.UP, 1.4) * _rng.randf_range(-0.6, 0.6), out, size * 0.8, shade.darkened(0.3), flex_tip * minf(f, 1.0), phase)


func _bez(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


# ---------- pieces ----------

## A tapered limb along a 3-point curve (roots, branches, twigs, stubs).
## Flex runs from flex0 at the base to flex1 at the tip.
func _limb(pts: Array, r0: float, r1: float, sides: int, col: Color, flex0: float, phase: float, flatten := 1.0, flex1 := -1.0) -> void:
	if flex1 < 0.0:
		flex1 = flex0
	var steps := 4
	var rings := []
	var flexes := []
	for i in steps + 1:
		var t := float(i) / steps
		var c := _bez(pts[0], pts[1], pts[2], t)
		var tan := (_bez(pts[0], pts[1], pts[2], minf(t + 0.05, 1.0)) - _bez(pts[0], pts[1], pts[2], maxf(t - 0.05, 0.0))).normalized()
		var side := tan.cross(Vector3.UP)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		side = side.normalized()
		var up := side.cross(tan).normalized()
		var r := lerpf(r0, r1, t)
		var ring := []
		for k in sides:
			var a := TAU * k / sides
			ring.append(c + (side * cos(a) * flatten + up * sin(a)) * r)
		rings.append(ring)
		flexes.append(lerpf(flex0, flex1, t))
	for i in steps:
		for k in sides:
			var k2 := (k + 1) % sides
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i][k2]
			var c: Vector3 = rings[i + 1][k2]
			var d: Vector3 = rings[i + 1][k]
			var centre := _bez(pts[0], pts[1], pts[2], (i + 0.5) / steps)
			_phase = Vector2(flexes[i], phase)
			_quad(a, b, c, d, ((a + b + c + d) * 0.25 - centre).normalized(), col.lightened(_rng.randf_range(-0.05, 0.05)))


## A flattened, irregular low-poly needle spray, hanging a little at the
## edges, long axis along `along`.
func _spray(p: Vector3, along: Vector3, size: float, shade: Color, flex: float, phase: float) -> void:
	var flat := Vector3(along.x, 0, along.z)
	if flat.length() < 0.01:
		flat = Vector3.FORWARD
	var basis := Basis.looking_at(flat.normalized())
	basis = basis.rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
	var scale := Vector3(size * _rng.randf_range(0.7, 0.95), size * _rng.randf_range(0.28, 0.38), size * _rng.randf_range(1.05, 1.35))
	_blob(p, scale, basis, shade, flex, phase, 0.28, true)


## Jittered icosahedron: the building block for sprays and burls.
func _blob(p: Vector3, scale: Vector3, basis: Basis, col: Color, flex: float, phase: float, jitter: float, droop := false) -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
		[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var pts := []
	for q: Vector3 in v:
		var n := q.normalized()
		n *= 1.0 + _rng.randf_range(-jitter, jitter)
		if droop and n.y < 0.0:
			n.y *= 1.8  # needles hang: a deeper, pointed underside
		pts.append(p + basis * (n * scale * 0.5))
	_phase = Vector2(flex, phase)
	for f in faces:
		var a: Vector3 = pts[f[0]]
		var b: Vector3 = pts[f[1]]
		var c: Vector3 = pts[f[2]]
		var out := ((a + b + c) / 3.0 - p).normalized()
		_tri(a, b, c, out, col.lightened(_rng.randf_range(-0.06, 0.07)))


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, col: Color) -> void:
	_tri(a, b, c, out, col)
	_tri(a, c, d, out, col)


## Flat-shaded triangle facing `out` (Godot front faces wind clockwise).
func _tri(a: Vector3, b: Vector3, c: Vector3, out: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.dot(out) > 0.0:
		var tmp := b
		b = c
		c = tmp
		n = -n
	var normal := -n.normalized()
	for q in [a, b, c]:
		_st.set_color(col)
		_st.set_normal(normal)
		_st.set_uv(_phase)
		_st.add_vertex(q)
	_tris += 1
