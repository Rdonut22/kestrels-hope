@tool
extends Node3D

## An ancient coast redwood, built procedurally (no imported assets).
##
## Anatomy, after real old-growth redwoods:
## - a huge flared base: buttress lobes running down into exposed, flattened
##   roots, an old fire scar hollowed into one side, moss on the shady foot;
## - a tall, smooth-shaded, irregular trunk: fluted, lumpy, slightly
##   wandering, in cinnamon-to-brown streaked bark (world/redwood_bark.gdshader);
## - bare for a long way up apart from dead stubs, then a narrow, ragged crown
##   of limbs that sag and turn up at the tips, in clumps with gaps between,
##   a couple of secondary trunks ("reiterations") rising off big limbs, and
##   often a dead spike top above the green;
## - foliage as flat drooping needle sprays on alpha-cut cards
##   (world/redwood_foliage.gdshader) whose normals point out of the crown,
##   so the canopy shades as soft painted masses, darker deep inside.
##
## Two surfaces (bark, foliage) with materials shared by every redwood. Branch
## tips sway in the wind, each branch to its own rhythm; the trunk barely
## moves. The origin is at ground level, centre of the trunk, +Y up. Change any
## exported value or the seed for a different tree.

@export var height := 64.0:
	set(v):
		height = v
		_queue_rebuild()
## Radius of the trunk just above the flare (m). The base flares much wider.
@export var trunk_radius := 2.6:
	set(v):
		trunk_radius = v
		_queue_rebuild()
## Widest the crown gets (m across).
@export var crown_width := 24.0:
	set(v):
		crown_width = v
		_queue_rebuild()
## Where the living crown starts, as a fraction of the height.
@export_range(0.15, 0.85) var crown_start := 0.2:
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
## How far from regular: trunk wander and lean, crown lopsidedness, gaps.
@export_range(0.0, 1.0) var irregularity := 0.6:
	set(v):
		irregularity = v
		_queue_rebuild()
## Old-growth features: fire scar, dead spike top, secondary trunks.
@export var ancient := true:
	set(v):
		ancient = v
		_queue_rebuild()
@export var tree_seed := 7:
	set(v):
		tree_seed = v
		_queue_rebuild()
## 0 = full detail; 1 = the distant version (same tree, far fewer triangles).
@export_range(0, 1) var lod := 0:
	set(v):
		lod = v
		_queue_rebuild()

const BARK_MATERIAL := "res://world/materials/redwood_bark.tres"
const LEAF_MATERIAL := "res://world/materials/redwood_foliage.tres"

const BARK := [Color(0.55, 0.25, 0.14), Color(0.64, 0.33, 0.19), Color(0.45, 0.20, 0.12), Color(0.60, 0.30, 0.18)]
const BARK_DARK := Color(0.20, 0.10, 0.07)
const CHAR := Color(0.06, 0.05, 0.045)
const MOSS := Color(0.24, 0.34, 0.11)
const DEADWOOD := Color(0.40, 0.36, 0.32)
const LIMB := Color(0.30, 0.17, 0.11)
const GREENS := [Color(0.11, 0.25, 0.10), Color(0.15, 0.31, 0.11), Color(0.21, 0.37, 0.12),
	Color(0.10, 0.23, 0.14), Color(0.17, 0.33, 0.15)]

static var _bark_mat: ShaderMaterial
static var _leaf_mat: ShaderMaterial

var _bark: SurfaceTool
var _leaf: SurfaceTool
var _bark_n := 0
var _leaf_n := 0
var _rng: RandomNumberGenerator
var _noise: FastNoiseLite
var _queued := false
var _bark_mi: MeshInstance3D
var _leaf_mi: MeshInstance3D
var _tris := 0
# Per-tree shape, rolled from the seed.
var _lean := Vector2.ZERO
var _wander := Vector2.ZERO
var _bias := Vector3.ZERO
var _buttress := []  # [angle, strength]
var _scar_a := 0.0
var _scar_h := 0.0
var _crown_top := 0.0
var _droop := 0.0  # extra sag for the low, sweeping limbs


func _ready() -> void:
	_rebuild()
	# Darken with the day-night cycle (it only collects materials at start).
	if not Engine.is_editor_hint():
		var clock := get_tree().get_first_node_in_group("day_night")
		if clock and "_tinted" in clock:
			for m in [_bark_mat, _leaf_mat]:
				if not clock._tinted.has(m):
					clock._tinted.append(m)


func _queue_rebuild() -> void:
	if not is_inside_tree() or _queued:
		return
	_queued = true
	_rebuild.call_deferred()


func triangle_count() -> int:
	return _tris


func _rebuild() -> void:
	_queued = false
	var meshes := build_meshes()
	if not _bark_mi:
		_bark_mi = MeshInstance3D.new()
		_bark_mi.name = "Bark"
		add_child(_bark_mi)
		_leaf_mi = MeshInstance3D.new()
		_leaf_mi.name = "Foliage"
		add_child(_leaf_mi)
	_bark_mi.mesh = meshes[0]
	_bark_mi.material_override = _bark_mat
	_leaf_mi.mesh = meshes[1]
	_leaf_mi.material_override = _leaf_mat


## Builds the tree from the current settings: [bark mesh, foliage mesh],
## for the shared materials (redwood_material(), as used by the forest).
func build_meshes() -> Array[ArrayMesh]:
	_ensure_materials()
	_rng = RandomNumberGenerator.new()
	_rng.seed = tree_seed
	_noise = FastNoiseLite.new()
	_noise.seed = tree_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_roll_shape()
	_bark = SurfaceTool.new()
	_bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	_leaf = SurfaceTool.new()
	_leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
	_bark_n = 0
	_leaf_n = 0
	_tris = 0
	_build_trunk()
	_build_roots()
	_build_stubs()
	_build_crown()
	return [_bark.commit(), _leaf.commit()]


## The shared bark (0) or foliage (1) material. tools/build_scenes.gd saves
## them; without the saved files (e.g. before the first build) they are made
## on the spot.
static func redwood_material(which: int) -> ShaderMaterial:
	_ensure_materials()
	return _bark_mat if which == 0 else _leaf_mat


static func make_materials() -> Array[ShaderMaterial]:
	var bark := ShaderMaterial.new()
	bark.shader = load("res://world/redwood_bark.gdshader")
	var leaf := ShaderMaterial.new()
	leaf.shader = load("res://world/redwood_foliage.gdshader")
	leaf.set_shader_parameter("spray", _make_spray_texture())
	return [bark, leaf]


static func _ensure_materials() -> void:
	if _bark_mat:
		return
	if ResourceLoader.exists(BARK_MATERIAL) and ResourceLoader.exists(LEAF_MATERIAL):
		_bark_mat = load(BARK_MATERIAL)
		_leaf_mat = load(LEAF_MATERIAL)
	else:
		var m := make_materials()
		_bark_mat = m[0]
		_leaf_mat = m[1]


func _roll_shape() -> void:
	var a := _rng.randf() * TAU
	_lean = Vector2(cos(a), sin(a)) * _rng.randf_range(0.3, 1.0) * irregularity
	_wander = Vector2(_rng.randf() * TAU, _rng.randf() * TAU)
	var b := _rng.randf() * TAU
	_bias = Vector3(cos(b), 0, sin(b))
	_buttress.clear()
	var n := 5 + _rng.randi() % 3
	var start := _rng.randf() * TAU
	for i in n:
		_buttress.append([start + TAU * (i + _rng.randf_range(-0.25, 0.25)) / n, _rng.randf_range(0.35, 0.8)])
	_scar_a = _rng.randf() * TAU
	_scar_h = _rng.randf_range(4.0, 7.5) * trunk_radius / 2.6 if ancient else 0.0
	_crown_top = height * (0.94 if ancient else 1.0)


# --- Trunk -------------------------------------------------------------------

func _spine(h: float) -> Vector3:
	var u := clampf(h / height, 0.0, 1.0)
	var w := irregularity
	var lean := _lean * u * u * height * 0.035
	var x := lean.x + sin(u * 5.0 + _wander.x) * 0.3 * w * trunk_radius * u
	var z := lean.y + cos(u * 4.0 + _wander.y) * 0.3 * w * trunk_radius * u
	return Vector3(x, h, z)


## Smooth (unbumped) trunk radius at height h.
func _base_radius(h: float) -> float:
	var hh := maxf(h, 0.0)
	var u := clampf(hh / height, 0.0, 1.0)
	return trunk_radius * (0.12 + 0.88 * pow(1.0 - u, 1.3)) + trunk_radius * 0.9 * exp(-hh / (trunk_radius * 0.9))


## Scar strength (0..1) at an angle and height: a pointed hollow up one side.
func _scar(a: float, h: float) -> float:
	if _scar_h <= 0.0 or h > _scar_h:
		return 0.0
	var w := 0.55 * pow(1.0 - maxf(h, 0.0) / _scar_h, 0.6)
	var d := absf(angle_difference(a, _scar_a))
	return smoothstep(w, w * 0.4, d)


func _trunk_radius_at(a: float, h: float) -> float:
	var hh := maxf(h, 0.0)
	var base := _base_radius(h)
	var r := base
	var low := exp(-hh / (trunk_radius * 1.4))
	for bt in _buttress:
		var c := maxf(0.0, cos(a - float(bt[0])))
		r += trunk_radius * float(bt[1]) * pow(c, 8.0) * low
	var n := _noise.get_noise_3d(cos(a) * 1.3, hh * 0.09, sin(a) * 1.3)
	r += base * (0.05 * sin(a * 11.0 + hh * 0.06 + n * 3.0) + 0.12 * n)
	r *= 1.0 - 0.42 * _scar(a, h)
	return r


func _bark_color(a: float, h: float) -> Color:
	var hh := maxf(h, 0.0)
	var stripe := _noise.get_noise_2d(a * 4.0, hh * 0.05) * 0.5 + 0.5
	var col: Color = (BARK[int(stripe * 3.99)] as Color).lerp(BARK[(int(stripe * 3.99) + 1) % 4], fposmod(stripe * 3.99, 1.0))
	# Darker, damp foot; greyer and paler high up.
	col = col.lerp(BARK_DARK, (1.0 - smoothstep(0.0, 2.5, hh)) * 0.4)
	col = col.lerp(Color(0.45, 0.33, 0.27), smoothstep(height * 0.5, height, hh) * 0.4)
	# Moss climbs the shady side of the base.
	var moss := smoothstep(0.2, 0.8, cos(a - _scar_a - PI * 0.7)) * (1.0 - smoothstep(1.0, 5.0 + stripe * 4.0, hh))
	col = col.lerp(MOSS, moss * 0.75)
	col = col.lerp(CHAR, smoothstep(0.1, 0.6, _scar(a, h)))
	if ancient and hh > _crown_top - 1.0:
		col = col.lerp(DEADWOOD, smoothstep(_crown_top - 1.0, _crown_top + 1.0, hh))
	return col


func _build_trunk() -> void:
	var sides := 32 if lod == 0 else 10
	var step := 1.0 if lod == 0 else 3.0
	var hs := PackedFloat32Array()
	var h := -1.0
	while h < height - 1.0:
		hs.append(h)
		h += (0.35 if h < 4.0 else (0.9 if h < 14.0 else 1.8)) * step
	hs.append(height - 1.0)
	hs.append(height)
	var rows := []
	var colors := []
	var uvs := []
	var centers := PackedVector3Array()
	var circ := TAU * trunk_radius
	for i in hs.size():
		var hh := hs[i]
		var c := _spine(hh)
		var row := PackedVector3Array()
		var crow := PackedColorArray()
		var urow := PackedVector2Array()
		for j in sides + 1:
			var a := TAU * j / sides
			var r := _trunk_radius_at(a, hh) if i < hs.size() - 1 else 0.03
			row.append(c + Vector3(cos(a) * r, 0, sin(a) * r))
			crow.append(_bark_color(a, hh))
			urow.append(Vector2(circ * j / sides, hh))
		rows.append(row)
		colors.append(crow)
		uvs.append(urow)
		centers.append(c)
	_grid(_bark, true, rows, centers, colors, uvs, Vector2.ZERO)


## Exposed roots: flattened limbs running out of each buttress and down into
## the ground, with a few smaller ones between.
func _build_roots() -> void:
	var list := []
	for bt in _buttress:
		list.append([float(bt[0]), float(bt[1])])
	for i in 3 + _rng.randi() % 3:
		list.append([_rng.randf() * TAU, _rng.randf_range(0.15, 0.3)])
	for rt in list:
		var a: float = rt[0]
		var s: float = rt[1]
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var length := trunk_radius * _rng.randf_range(2.0, 3.6) * (0.6 + s)
		var r0 := trunk_radius * (0.25 + 0.45 * s)
		var start := _spine(0.0) + dir * _trunk_radius_at(a, 0.6) * 0.55 + Vector3(0, 0.6 + s, 0)
		var wig := _rng.randf_range(-0.35, 0.35) * length
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		var n := 9 if lod == 0 else 4
		for k in n:
			var t := float(k) / (n - 1)
			var p := start + dir * length * t + side * wig * t * t
			p.y = lerpf(start.y, -0.35, pow(t, 0.7))
			pts.append(p)
			radii.append(lerpf(r0, 0.08, pow(t, 0.8)))
		if lod > 0 and s < 0.33:
			continue
		_tube(_bark, pts, radii, 8 if lod == 0 else 4, 0.55, LIMB.lerp(BARK_DARK, 0.5).lerp(MOSS, _rng.randf() * 0.4), Vector2.ZERO)


## Dead stubs and burls on the bare lower trunk.
func _build_stubs() -> void:
	for i in 9:
		var h := _rng.randf_range(height * 0.06, height * crown_start * 0.9)
		var a := _rng.randf() * TAU
		var dir := Vector3(cos(a), _rng.randf_range(-0.3, 0.1), sin(a)).normalized()
		var p := _spine(h) + Vector3(cos(a), 0, sin(a)) * _trunk_radius_at(a, h) * 0.85
		var length := _rng.randf_range(0.4, 1.3)
		var r0 := _rng.randf_range(0.12, 0.25) * trunk_radius / 2.6
		var pts := PackedVector3Array([p, p + dir * length * 0.5, p + dir * length])
		if lod > 0:
			continue
		_tube(_bark, pts, PackedFloat32Array([r0, r0 * 0.75, r0 * 0.4]), 5, 1.0, DEADWOOD, Vector2.ZERO)


# --- Crown -------------------------------------------------------------------

func _build_crown() -> void:
	var base := height * crown_start
	var span := _crown_top - base
	var crown_r := crown_width * 0.5
	# Branches come in loose clumps with gaps between, not even whorls.
	var clumps := PackedFloat32Array()
	for i in 9 + _rng.randi() % 4:
		clumps.append(_rng.randf())
	var count := int(125 * branch_density)
	var reiterations := 2 if ancient else 0
	for i in count:
		var u := clampf(clumps[_rng.randi() % clumps.size()] + _rng.randf_range(-0.035, 0.035) * (1.0 + irregularity), 0.0, 1.0)
		if _rng.randf() < 0.12:
			u = _rng.randf()
		var h := base + u * span
		var a := i * 2.39996 + _rng.randf_range(-0.6, 0.6)
		var dir := Vector3(cos(a), 0, sin(a))
		# Widest low down: a lush skirt sweeping out and down, narrowing upwards.
		var prof := (0.8 + 0.2 * smoothstep(0.0, 0.1, u)) * pow(1.0 - u * 0.88, 0.75)
		var length := crown_r * prof * _rng.randf_range(0.7, 1.15) * branch_length
		length *= 1.0 + 0.35 * irregularity * dir.dot(_bias)
		length = maxf(length, 1.5)
		var dead := u < 0.06 and _rng.randf() < 0.25
		_droop = (1.0 - u) * (1.0 - u) * 0.3
		var start := _spine(h) + dir * _trunk_radius_at(a, h) * 0.8
		var leader := reiterations > 0 and u > 0.25 and u < 0.6 and length > crown_r * 0.6 and not dead
		if leader:
			reiterations -= 1
		_branch(start, dir, length, 0, dead, leader, 0.0, _rng.randf())
	_build_inner_foliage(base, span)
	_build_top()


## A limb: sags out from the trunk and turns up towards the tip, with side
## twigs, all carrying needle sprays. `flex0`: how much the attachment point
## already moves (twigs inherit their limb's motion and phase).
func _branch(start: Vector3, dir: Vector3, length: float, depth: int, dead: bool, leader: bool, flex0: float, phase: float) -> void:
	var sag := _rng.randf_range(0.04, 0.14)
	var rise := _rng.randf_range(-0.12, 0.28) - _droop if depth == 0 else _rng.randf_range(-0.35, 0.05) - _droop * 0.5
	var dip := _rng.randf_range(-0.12, 0.0) if depth == 0 else -0.05
	var p0 := start
	var p1 := start + dir * length * 0.5 + Vector3(0, length * (dip - sag), 0)
	var p2 := start + dir * length + Vector3(0, length * rise, 0)
	var flex1 := minf(1.0, flex0 + length / 9.0)
	var rings := clampi(int(length / 1.4) + 3, 4, 9) if lod == 0 else 3
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var r0 := clampf(0.03 * length + 0.08, 0.1, 0.55) * trunk_radius / 2.6 if depth == 0 else clampf(0.025 * length + 0.04, 0.05, 0.18)
	var flexes := PackedFloat32Array()
	for k in rings:
		var t := float(k) / (rings - 1)
		pts.append(_bez(p0, p1, p2, t))
		radii.append(lerpf(r0, r0 * 0.18, t))
		flexes.append(lerpf(flex0, flex1, t * t))
	var col := DEADWOOD if dead else LIMB.lerp(BARK[_rng.randi() % 4], 0.3)
	# Far away the twigs vanish under their sprays.
	if lod == 0 or depth == 0:
		_tube(_bark, pts, radii, (6 if depth == 0 else 4) if lod == 0 else 3, 1.0, col, Vector2(0, phase), flexes)
	if leader:
		_leader(_bez(p0, p1, p2, 0.65), _rng.randf_range(8.0, 13.0), r0 * 0.7, lerpf(flex0, flex1, 0.42), phase)
	if dead:
		return
	if depth == 0:
		for k in 2 + _rng.randi() % 3:
			var t := _rng.randf_range(0.3, 0.85)
			var turn := _rng.randf_range(0.7, 1.4) * (1.0 if k % 2 == 0 else -1.0)
			var tdir := dir.rotated(Vector3.UP, turn)
			_branch(_bez(p0, p1, p2, t), tdir, length * _rng.randf_range(0.28, 0.5), 1, false, false, lerpf(flex0, flex1, t * t), phase)
	# Sprays along the outer part, a little past the tip.
	var spacing := 1.5 / foliage_density
	var t := 0.32 if depth == 0 else 0.15
	while t <= 1.05:
		var p := _bez(p0, p1, p2, minf(t, 1.0)) + dir * maxf(t - 1.0, 0.0) * length
		var size := _rng.randf_range(2.6, 3.8) * (1.0 if depth == 0 else 0.85)
		_cluster(p, dir, size, lerpf(flex0, flex1, minf(t, 1.0) ** 2), phase)
		t += spacing / length


## A secondary trunk rising off a big limb, with its own little crown.
func _leader(start: Vector3, rise: float, r0: float, flex0: float, phase: float) -> void:
	var lean := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * 0.15 * rise
	var p1 := start + Vector3(0, rise * 0.45, 0) + lean * 0.2
	var p2 := start + Vector3(0, rise, 0) + lean
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var flexes := PackedFloat32Array()
	for k in 7:
		var t := k / 6.0
		pts.append(_bez(start, p1, p2, t))
		radii.append(lerpf(r0, 0.05, t))
		flexes.append(lerpf(flex0, minf(1.0, flex0 + 0.4), t))
	_tube(_bark, pts, radii, 6 if lod == 0 else 3, 1.0, LIMB.lerp(BARK[1], 0.5), Vector2(0, phase), flexes)
	for i in 7:
		var t := _rng.randf_range(0.3, 0.95)
		var a := _rng.randf() * TAU
		var f := lerpf(flex0, minf(1.0, flex0 + 0.4), t)
		_branch(_bez(start, p1, p2, t), Vector3(cos(a), 0, sin(a)), _rng.randf_range(1.5, 3.5) * (1.2 - t), 1, false, false, f, phase)
	_cluster(p2 + Vector3(0, 0.6, 0), Vector3(cos(phase * TAU), 0, sin(phase * TAU)), 2.2, minf(1.0, flex0 + 0.45), phase)


## Dark sprays close in around the trunk so the crown has no hollow core.
func _build_inner_foliage(base: float, span: float) -> void:
	var h := base + span * 0.08
	while h < _crown_top - 1.5:
		var a := _rng.randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		var p := _spine(h) + dir * (_base_radius(h) + _rng.randf_range(0.8, 2.5))
		_cluster(p, dir, _rng.randf_range(2.5, 3.5), 0.15, _rng.randf())
		h += _rng.randf_range(0.8, 1.8) / foliage_density


## Narrowing tip of the crown: short upswept twigs round the top of the trunk.
func _build_top() -> void:
	var top := _crown_top
	for i in 8:
		var h := top - 6.0 + i * 0.75
		var a := i * 2.39996 + _rng.randf()
		var dir := Vector3(cos(a), 0, sin(a))
		var start := _spine(h) + dir * _base_radius(h) * 0.7
		_branch(start, (dir + Vector3(0, 0.35, 0)).normalized(), _rng.randf_range(1.5, 3.0) * (1.0 - i / 10.0), 1, false, false, 0.25, _rng.randf())
	if not ancient:
		_cluster(_spine(top) + Vector3(0, 0.5, 0), _bias, 1.8, 0.4, _rng.randf())


## A clump of 3-4 flat needle sprays, mostly level and drooping at the outer
## edge, sometimes with one hanging below like a curtain.
func _cluster(p: Vector3, out: Vector3, size: float, flex: float, phase: float) -> void:
	var q := _spine(p.y)
	var dist := Vector2(p.x - q.x, p.z - q.z).length()
	var reach := maxf(crown_width * 0.5 * pow(1.0 - clampf((p.y - height * crown_start) / maxf(_crown_top - height * crown_start, 1.0), 0.0, 1.0) * 0.85, 0.8), 2.0)
	# Ambient occlusion: deeper in the crown and lower down is darker.
	var shade := lerpf(0.5, 1.05, clampf(dist / reach, 0.0, 1.0))
	shade *= lerpf(0.8, 1.05, clampf((p.y - height * crown_start) / maxf(_crown_top - height * crown_start, 1.0), 0.0, 1.0))
	var base_yaw := atan2(out.z, out.x)
	var cards := 3 + (1 if _rng.randf() < 0.5 else 0)
	var green: Color = GREENS[_rng.randi() % GREENS.size()]
	for k in cards:
		var hang := k == cards - 1 and _rng.randf() < 0.5
		var yaw := base_yaw + _rng.randf_range(-1.2, 1.2)
		var fwd := Vector3(cos(yaw), 0, sin(yaw))
		var tilt := _rng.randf_range(0.8, 1.25) if hang else _rng.randf_range(-0.1, 0.45)
		fwd = (fwd * cos(tilt) + Vector3.DOWN * sin(tilt)).normalized()
		var side := fwd.cross(Vector3.UP).normalized().rotated(fwd, _rng.randf_range(-0.35, 0.35))
		var s := size * _rng.randf_range(0.85, 1.15)
		var c := p + Vector3(_rng.randf_range(-0.3, 0.3) * s, _rng.randf_range(-0.25, 0.1) * s, _rng.randf_range(-0.3, 0.3) * s)
		c += fwd * s * 0.2
		if hang:
			c += Vector3.DOWN * s * 0.35
		var col := green.lerp(GREENS[_rng.randi() % GREENS.size()], 0.4) * (shade * (0.85 if hang else 1.0) * _rng.randf_range(0.92, 1.08))
		col.a = 1.0
		# The distant version keeps two bigger sprays per clump.
		if lod == 0:
			_card(c, fwd * s * 0.62, side * s * 0.48, p, col, flex, phase)
		elif k < 2:
			_card(c, fwd * s * 0.8, side * s * 0.65, p, col, flex, phase)


func _card(c: Vector3, u: Vector3, v: Vector3, cluster: Vector3, col: Color, flex: float, phase: float) -> void:
	var corners := [c - u - v, c + u - v, c + u + v, c - u + v]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var outer := [0.0, 0.12, 0.12, 0.0]
	for i in 4:
		var p: Vector3 = corners[i]
		var q := _spine(p.y)
		var radial := Vector3(p.x - q.x, 0, p.z - q.z).normalized()
		var n := (radial * 0.7 + Vector3.UP * 0.6 + (p - cluster).normalized() * 0.7).normalized()
		_leaf.set_normal(n)
		_leaf.set_color(col)
		_leaf.set_uv(uvs[i])
		_leaf.set_uv2(Vector2(minf(1.0, flex + float(outer[i]) * flex), phase))
		_leaf.add_vertex(p)
	for idx in [0, 1, 2, 0, 2, 3]:
		_leaf.add_index(_leaf_n + idx)
	_leaf_n += 4
	_tris += 2


# --- Geometry helpers --------------------------------------------------------

static func _bez(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


## A tube along `pts`. `flatten` squashes it vertically (roots). Wind data:
## UV2 = (flex per ring, or data.x; data.y = phase).
func _tube(st: SurfaceTool, pts: PackedVector3Array, radii: PackedFloat32Array, sides: int, flatten: float, col: Color, data: Vector2, flexes := PackedFloat32Array()) -> void:
	var rows := []
	var colors := []
	var uvs := []
	var centers := PackedVector3Array()
	var along := 0.0
	for k in pts.size():
		var t: Vector3 = (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
		var side := t.cross(Vector3.UP)
		if side.length() < 0.1:
			side = t.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(t).normalized()
		if k > 0:
			along += pts[k].distance_to(pts[k - 1])
		var row := PackedVector3Array()
		var crow := PackedColorArray()
		var urow := PackedVector2Array()
		for j in sides + 1:
			var a := TAU * j / sides
			row.append(pts[k] + (side * cos(a) + up * sin(a) * flatten) * radii[k])
			crow.append(col)
			urow.append(Vector2(radii[k] * TAU * j / sides, along))
		rows.append(row)
		colors.append(crow)
		uvs.append(urow)
		centers.append(pts[k])
	var fl = flexes if not flexes.is_empty() else null
	_grid(st, true, rows, centers, colors, uvs, data, fl)


## Smooth-shaded quad grid (rows of rings, last column = first). Normals
## come from neighbouring vertices, pointed away from each ring's centre;
## triangles are wound clockwise when seen from outside (Godot's front).
func _grid(st: SurfaceTool, bark: bool, rows: Array, centers: PackedVector3Array, colors: Array, uvs: Array, data: Vector2, flexes = null) -> void:
	var nr := rows.size()
	var nc: int = (rows[0] as PackedVector3Array).size()
	var base := _bark_n if bark else _leaf_n
	var normals := []
	for i in nr:
		var row: PackedVector3Array = rows[i]
		var nrow := PackedVector3Array()
		for j in nc:
			var jl := j - 1 if j > 0 else nc - 2
			var jr := j + 1 if j < nc - 1 else 1
			var du: Vector3 = row[jr] - row[jl]
			var dv: Vector3 = (rows[mini(i + 1, nr - 1)] as PackedVector3Array)[j] - (rows[maxi(i - 1, 0)] as PackedVector3Array)[j]
			var n := du.cross(dv)
			var out := row[j] - centers[i]
			if n.length() < 1e-6:
				n = out if out.length() > 1e-4 else dv
			n = n.normalized()
			if n.dot(out) < 0.0:
				n = -n
			nrow.append(n)
		normals.append(nrow)
	for i in nr:
		var f: float = (flexes as PackedFloat32Array)[i] if flexes != null else data.x
		for j in nc:
			st.set_normal((normals[i] as PackedVector3Array)[j])
			st.set_color((colors[i] as PackedColorArray)[j])
			st.set_uv((uvs[i] as PackedVector2Array)[j])
			st.set_uv2(Vector2(f, data.y))
			st.add_vertex((rows[i] as PackedVector3Array)[j])
	for i in nr - 1:
		var r0: PackedVector3Array = rows[i]
		var r1: PackedVector3Array = rows[i + 1]
		for j in nc - 1:
			var a := base + i * nc + j
			var b := a + 1
			var c := a + nc + 1
			var d := a + nc
			var out: Vector3 = (normals[i] as PackedVector3Array)[j]
			var tn := (r0[j + 1] - r0[j]).cross(r1[j + 1] - r0[j])
			if tn.length() < 1e-8:
				tn = (r1[j + 1] - r0[j]).cross(r1[j] - r0[j])
			if tn.dot(out) > 0.0:
				for idx in [a, c, b, a, d, c]:
					st.add_index(idx)
			else:
				for idx in [a, b, c, a, c, d]:
					st.add_index(idx)
			_tris += 2
	if bark:
		_bark_n += nr * nc
	else:
		_leaf_n += nr * nc


## The needle-spray cutout: a fan of flat redwood fronds (a midrib with short
## needles either side, shorter towards the tip), drawn once and shared.
## R = brightness, A = coverage.
static func _make_spray_texture() -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.6, 0.6, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var centre := Vector2(size, size) * 0.5
	var fronds := 13
	for f in fronds:
		var ang := TAU * f / fronds + rng.randf_range(-0.2, 0.2)
		var length := rng.randf_range(78.0, 100.0)
		_frond(img, rng, centre + Vector2(cos(ang), sin(ang)) * rng.randf_range(2.0, 12.0), ang, length, rng.randf_range(-0.006, 0.006), 17.0)
	return ImageTexture.create_from_image(_coverage_mipmaps(img, 0.45))


## Mipmaps that keep the same share of pixels above the alpha cut as the full
## image, so distant foliage doesn't thin out to nothing.
static func _coverage_mipmaps(img: Image, cut: float) -> Image:
	var target := _coverage(img, cut, 1.0)
	var data := img.get_data()
	var level := img.duplicate() as Image
	var size := img.get_width()
	while size > 1:
		size /= 2
		level.resize(size, size, Image.INTERPOLATE_BILINEAR)
		var lo := 1.0
		var hi := 8.0
		for i in 12:
			var mid := (lo + hi) * 0.5
			if _coverage(level, cut, mid) < target:
				lo = mid
			else:
				hi = mid
		var scaled := level.duplicate() as Image
		for y in size:
			for x in size:
				var c := scaled.get_pixel(x, y)
				c.a = minf(c.a * hi, 1.0)
				scaled.set_pixel(x, y, c)
		data.append_array(scaled.get_data())
	return Image.create_from_data(img.get_width(), img.get_height(), true, Image.FORMAT_RGBA8, data)


static func _coverage(img: Image, cut: float, scale: float) -> float:
	var n := 0
	var w := img.get_width()
	for y in w:
		for x in w:
			if img.get_pixel(x, y).a * scale > cut:
				n += 1
	return float(n) / (w * w)


static func _frond(img: Image, rng: RandomNumberGenerator, start: Vector2, ang: float, length: float, curve: float, needle: float) -> void:
	var p := start
	var a := ang
	var step := 0.0
	while step < length:
		var t := step / length
		var dir := Vector2(cos(a), sin(a))
		_dot(img, p, 1.6, 0.5)
		if int(step) % 2 == 0:
			var nl := needle * (1.0 - t * 0.65)
			for s in [-1.0, 1.0]:
				var nd := dir.rotated(s * 1.0)
				var bright := rng.randf_range(0.55, 1.0) * lerpf(0.85, 1.0, t)
				for k in int(nl):
					_dot(img, p + nd * k, 1.25 * (1.0 - k / (nl + 1.0) * 0.5), bright)
		# Side shoots partway along the bigger fronds.
		if needle > 10.0 and (int(step) == int(length * 0.35) or int(step) == int(length * 0.6)):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			_frond(img, rng, p, a + side * 0.7, length * 0.4, curve, needle * 0.7)
		a += curve
		p += dir
		step += 1.0


static func _dot(img: Image, p: Vector2, r: float, bright: float) -> void:
	var w := img.get_width()
	for y in range(int(p.y - r), int(p.y + r) + 1):
		for x in range(int(p.x - r), int(p.x + r) + 1):
			if x < 0 or y < 0 or x >= w or y >= w:
				continue
			if Vector2(x + 0.5, y + 0.5).distance_to(p) <= r:
				img.set_pixel(x, y, Color(bright, bright, bright, 1.0))
