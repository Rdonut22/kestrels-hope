extends Node

## Keeps the crash site's drawing cost down without changing how it looks.
##
## 1. Trees cast their sun shadows from their simpler distant trunks. The
##    full trunks have ten times the triangles, and the sun draws its casters
##    up to four times (once per shadow cascade); a trunk's shadow looks the
##    same either way.
##
## 2. Past the fog's end (90 m on the ground) everything comes out the flat
##    fog colour, so a far tree is only its outline. Trees beyond `cut` are
##    drawn as one fog-coloured cut-out each (world/tree_impostor.gdshader)
##    instead of their 6,000-triangle distant models; the forest's outline
##    against the sky and the mountains stays as it was.
##
## 3. The meadow's flowers and shrubs, the farm droid and the wreck's insides
##    aren't drawn past `cut` either (the hull is, for its outline). Anything
##    that cast a sun shadow out there still does, from a shadow-only copy.
##
## `cut` follows the fog in use: the title screen (fog to 360 m) and anything
## without depth fog get everything drawn as built.
##
## Built by tools/build_scenes.gd into crash_site.tscn as "RenderBudget".

## Extra metres drawn past the fog's end (crowns reach well past their trunk).
@export var margin := 25.0
## Drawn only within the cut, relative to the scene root.
@export var cut_roots: PackedStringArray = ["CrashSite/EastForest", "CrashSite/Redwoods",
	"CrashSite/Flowers", "CrashSite/Shrubs", "FarmDroid", "Ship"]
## Left drawn at any distance (the wreck's hull keeps its outline).
@export var keep: PackedStringArray = ["KestrelExterior"]
## Trees drawn as cut-outs beyond the cut: [path, drawn out to (0 = no end)].
const FORESTS := [["CrashSite/EastForest", 440.0], ["CrashSite/Redwoods", 0.0]]
const BAND := "CrashSite/FarForest"
## Size of each tree's outline texture.
const MASK_SIZE := 512

var _items: Array[GeometryInstance3D] = []
var _orig_end := PackedFloat32Array()
var _twins: Array[GeometryInstance3D] = []   # shadow-only copies past the cut
var _twin_end := PackedFloat32Array()
var _band: Array[MultiMeshInstance3D] = []
var _band_xf := []  # per band multimesh: [positions, transforms] in the band's frame
var _near: Array[MultiMeshInstance3D] = []  # the band's trees within the cut
var _band_at := Vector3(INF, INF, INF)
## How far the camera moves before the band's near trees are re-picked.
const BAND_REFRESH := 12.0
var _impostors: Array[MultiMeshInstance3D] = []
var _impostor_mats: Array[ShaderMaterial] = []
var _cut := -1.0
var _ready_done := false
var _t := 0.0


func _ready() -> void:
	var root := get_parent()
	for path in ["CrashSite/EastForest", "CrashSite/Redwoods"]:
		var r := root.get_node_or_null(path)
		if r:
			for tree in r.get_children():
				_shadow_from_far(tree)
	for path in cut_roots:
		var r := root.get_node_or_null(path)
		if r:
			_collect(r)
	var band := root.get_node_or_null(BAND)
	if band:
		for c in band.get_children():
			var mmi := c as MultiMeshInstance3D
			if mmi == null or mmi.multimesh == null:
				continue
			var pos := PackedVector3Array()
			var xfs := []
			for i in mmi.multimesh.instance_count:
				var xf := mmi.transform * mmi.multimesh.get_instance_transform(i)
				pos.append(xf.origin)
				xfs.append(xf)
			_band.append(mmi)
			_band_xf.append([pos, xfs])
			var near := MultiMeshInstance3D.new()
			near.name = String(mmi.name) + "Near"
			near.material_override = mmi.material_override
			near.cast_shadow = mmi.cast_shadow
			near.visible = false
			var nmm := MultiMesh.new()
			nmm.transform_format = MultiMesh.TRANSFORM_3D
			nmm.mesh = mmi.multimesh.mesh
			near.multimesh = nmm
			band.add_child.call_deferred(near)
			_near.append(near)
	await _build_impostors(root)
	_ready_done = true
	_update()


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.25 or not _ready_done:
		return
	_t = 0.0
	_update()


## The distance to stop drawing at (INF when the fog doesn't hide everything
## past its end).
func cut_distance() -> float:
	var env := _environment()
	if env == null or not env.fog_enabled or env.fog_mode != Environment.FOG_MODE_DEPTH or env.fog_density < 0.99:
		return INF
	return env.fog_depth_end + margin


func _environment() -> Environment:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.environment:
		return cam.environment
	var w := get_viewport().find_world_3d()
	return w.environment if w else null


# ------------------------------------------------------------------ shadows

## The tree's full trunk stops casting; a shadow-only copy of its distant
## trunk casts in its place, over the same distances.
func _shadow_from_far(tree: Node) -> void:
	var near := tree.get_node_or_null("Bark") as MeshInstance3D
	var far := tree.get_node_or_null("BarkFar") as MeshInstance3D
	if near == null or far == null or near.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		return
	var sh := MeshInstance3D.new()
	sh.name = "BarkShadow"
	sh.mesh = far.mesh
	sh.material_override = far.material_override
	sh.transform = far.transform
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	sh.visibility_range_begin = near.visibility_range_begin
	sh.visibility_range_end = near.visibility_range_end
	sh.visibility_range_end_margin = near.visibility_range_end_margin
	near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree.add_child(sh)


## Everything under `n` gets its drawing ended at the cut; those that cast a
## shadow past it get a shadow-only copy for the rest of their range.
func _collect(n: Node) -> void:
	if n.name in keep:
		return
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		_items.append(g)
		_orig_end.append(g.visibility_range_end)
		var casts := g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if casts and (g is MeshInstance3D or g is MultiMeshInstance3D):
			var twin := g.duplicate(0) as GeometryInstance3D
			for c in twin.get_children():
				twin.remove_child(c)
				c.free()
			twin.name = String(g.name) + "CutShadow"
			twin.set_script(null)
			twin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			twin.visible = false
			g.add_sibling.call_deferred(twin)
			_twins.append(twin)
			_twin_end.append(g.visibility_range_end)
	for c in n.get_children():
		_collect(c)


# ------------------------------------------------------------------ the cut

func _update() -> void:
	var cut := cut_distance()
	if cut != _cut:
		_apply_cut(cut)
	if not is_inf(cut):
		_refresh_band()


func _apply_cut(cut: float) -> void:
	_cut = cut
	_band_at = Vector3(INF, INF, INF)
	var off := is_inf(cut)
	for i in _items.size():
		var g := _items[i]
		if not is_instance_valid(g):
			continue
		var orig := _orig_end[i]
		if off:
			g.visibility_range_end = orig
		else:
			g.visibility_range_end = cut if orig <= 0.0 else minf(orig, cut)
	for i in _twins.size():
		var tw := _twins[i]
		if not is_instance_valid(tw):
			continue
		var end := _twin_end[i]
		tw.visible = not off and (end <= 0.0 or end > cut)
		tw.visibility_range_begin = 0.0 if off else cut
		tw.visibility_range_begin_margin = 0.0
	for i in _band.size():
		_band[i].visible = off
		_near[i].visible = not off
	for m in _impostors:
		m.visible = not off
	for mat in _impostor_mats:
		# A little inside the cut, so the cut-outs overlap the real trees
		# (both the fog colour there) rather than leave a gap.
		mat.set_shader_parameter("near_cut", 0.0 if off else cut - margin * 0.6)


## The band's trees within reach of the camera, drawn in full.
func _refresh_band() -> void:
	if _near.is_empty() or not _near[0].is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := (_near[0].get_parent() as Node3D).to_local(cam.global_position)
	if eye.distance_to(_band_at) < BAND_REFRESH:
		return
	_band_at = eye
	var reach := _cut + BAND_REFRESH
	var reach2 := reach * reach
	for i in _band.size():
		var pos: PackedVector3Array = _band_xf[i][0]
		var xfs: Array = _band_xf[i][1]
		var keep_xf := []
		for j in pos.size():
			var d := pos[j] - eye
			if d.x * d.x + d.z * d.z < reach2:
				keep_xf.append(xfs[j])
		var mm := _near[i].multimesh
		mm.instance_count = keep_xf.size()
		for j in keep_xf.size():
			mm.set_instance_transform(j, keep_xf[j])


# ------------------------------------------------------------------ cut-outs

## One fog-coloured cut-out per tree, per kind: the outline is rendered once
## from the kind's distant model.
func _build_impostors(root: Node) -> void:
	# Each tree's kind is its distant trunk's mesh.
	var kinds := {}   # bark mesh -> {foliage, bark_mat, foliage_mat, groups: {far_end: [Transform3D]}}
	for f in FORESTS:
		var r := root.get_node_or_null(f[0])
		if r == null:
			continue
		for tree in r.get_children():
			var bark := tree.get_node_or_null("BarkFar") as MeshInstance3D
			var fol := tree.get_node_or_null("FoliageFar") as MeshInstance3D
			if fol == null:
				fol = tree.get_node_or_null("Foliage") as MeshInstance3D
			if bark == null or fol == null:
				continue
			_add_instance(kinds, bark.mesh, fol.mesh, bark.material_override, fol.material_override, float(f[1]),
				(bark as Node3D).global_transform)
	# The band beyond the walls: a multimesh per kind and part (K<k>_Bark,
	# K<k>_Foliage), the same meshes as the distant trees.
	var band := root.get_node_or_null(BAND)
	if band:
		for c in band.get_children():
			var mmi := c as MultiMeshInstance3D
			if mmi == null or not String(mmi.name).ends_with("_Bark") or String(mmi.name).ends_with("Near"):
				continue
			var fol := band.get_node_or_null(String(mmi.name).replace("_Bark", "_Foliage")) as MultiMeshInstance3D
			if fol == null:
				continue
			for i in mmi.multimesh.instance_count:
				_add_instance(kinds, mmi.multimesh.mesh, fol.multimesh.mesh, mmi.material_override, fol.material_override, 0.0,
					mmi.global_transform * mmi.multimesh.get_instance_transform(i))
	if kinds.is_empty():
		return
	var shader := load("res://world/tree_impostor.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for bark_mesh in kinds:
		var k: Dictionary = kinds[bark_mesh]
		var aabb: AABB = (bark_mesh as Mesh).get_aabb().merge((k["foliage"] as Mesh).get_aabb())
		var half_w := maxf(maxf(absf(aabb.position.x), absf(aabb.end.x)), maxf(absf(aabb.position.z), absf(aabb.end.z)))
		var side := maxf(half_w * 2.0, aabb.size.y)
		var cy := aabb.position.y + aabb.size.y * 0.5
		var mask: Texture2D = await _render_mask(bark_mesh, k["foliage"], k["bark_mat"], k["foliage_mat"], side, cy)
		for far_end in k["groups"]:
			var xfs: Array = k["groups"][far_end]
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("mask", mask)
			mat.set_shader_parameter("half_side", side * 0.5)
			mat.set_shader_parameter("centre_y", cy)
			mat.set_shader_parameter("far_cut", float(far_end))
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = quad
			mm.instance_count = xfs.size()
			for i in xfs.size():
				mm.set_instance_transform(i, xfs[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "TreeCutouts"
			mmi.multimesh = mm
			mmi.material_override = mat
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# The quads are stretched into place in the shader.
			mmi.custom_aabb = AABB(Vector3(-5000, -500, -5000), Vector3(10000, 1500, 10000))
			mmi.visible = false
			add_child(mmi)
			_impostors.append(mmi)
			_impostor_mats.append(mat)


func _add_instance(kinds: Dictionary, bark: Mesh, foliage: Mesh, bark_mat: Material, fol_mat: Material, far_end: float, xf: Transform3D) -> void:
	if not kinds.has(bark):
		kinds[bark] = {"foliage": foliage, "bark_mat": bark_mat, "foliage_mat": fol_mat, "groups": {}}
	var groups: Dictionary = kinds[bark]["groups"]
	if not groups.has(far_end):
		groups[far_end] = []
	(groups[far_end] as Array).append(xf)


## The kind's outline from the side, as an alpha mask (`side` metres square,
## centred `cy` up the trunk).
func _render_mask(bark: Mesh, foliage: Mesh, bark_mat: Material, fol_mat: Material, side: float, cy: float) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(MASK_SIZE, MASK_SIZE)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	for part in [[bark, bark_mat], [foliage, fol_mat]]:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.material_override = part[1]
		vp.add_child(mi)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = side
	cam.near = 0.1
	cam.far = side * 4.0
	cam.position = Vector3(0.0, cy, side * 2.0)
	vp.add_child(cam)
	cam.current = true
	add_child(vp)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
