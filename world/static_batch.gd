extends Node

## Joins its parent's fixed meshes into a few big ones, so the scene draws in
## a few hundred calls instead of thousands (the ship's interior is ~2,500
## small pieces; on a Mac each draw call costs the CPU 20-40 µs). Nothing
## looks different: the pieces keep their materials and places, and only
## pieces that never change are joined.
##
## Once the scene has built itself (a couple of frames in), the meshes are
## grouped by material, shadow setting, render layers and vertex format, and
## by CELL-sized block of space (so blocks out of view are still skipped),
## then each group becomes one mesh under "StaticBatch". The originals stay
## in the tree (scripts and saves still find them) with their mesh moved to
## the meta "batched_mesh".
##
## Left alone (drawn as before):
## - anything an interactable outlines (its _targets()), and anything under
##   a node with a script other than the builders in BUILDERS (doors, the
##   reactor, terminals...), under a light (power-switched fixtures), or in
##   a day/night group;
## - anything marked with the meta "batch_keep" (moving parts, screens);
## - transparent materials (their sorting would change), shaders that use
##   an object's own position, skinned meshes, meshes with a per-instance
##   transparency or overlay. Shaders that read a piece's local position
##   or normal are joined only where the piece's frame is the root's own
##   (then its local coordinates don't change).
##
## Pieces are only joined with ones of the same draw distance (visibility
## range), and each joined mesh keeps following one of its pieces' range and
## visibility, which world/render_budget.gd changes as the fog does.

## Scripts that only build geometry when the scene loads.
const BUILDERS := ["corridor_dressing.gd", "caged_sconce.gd", "kestrel_exterior.gd", "galley_windows.gd",
	"tool_cart.gd", "room_floors.gd", "round_window.gd"]
const CELL := 12.0
## Frames to wait for the builders (they build in _ready or deferred), and
## then for what's added later (world/render_budget.gd's shadow twins):
## a second pass joins those.
const SETTLE_FRAMES := 3
const LATE_FRAMES := 60

var merged := 0        # pieces joined
var meshes_made := 0
var _follow := []      # [joined mesh, one of its pieces]


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	var root := get_parent() as Node3D
	if root:
		batch(root)
		for i in LATE_FRAMES:
			await get_tree().process_frame
		batch(root)


func batch(root: Node3D) -> void:
	var keep := _kept(root)
	var to_root := root.global_transform.affine_inverse()
	var groups := {}   # key -> [material, cast_shadow, layers, [[mesh, surface, transform]...]]
	var joined: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not _mergeable(mi, root, keep):
			continue
		var xf := to_root * mi.global_transform
		var c := xf * mi.get_aabb().get_center()
		var cell := Vector3i(floori(c.x / CELL), floori(c.y / CELL), floori(c.z / CELL))
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			var fmt := _format(mi.mesh, s)
			var key := [mat.get_instance_id(), mi.cast_shadow, mi.layers, fmt, cell,
				mi.visibility_range_begin, mi.visibility_range_end, mi.visibility_range_begin_margin,
				mi.visibility_range_end_margin, mi.visibility_range_fade_mode]
			if not groups.has(key):
				groups[key] = [mat, mi.cast_shadow, mi.layers, [], mi]
			groups[key][3].append([mi.mesh, s, xf])
		joined.append(mi)
	if joined.is_empty():
		return
	var holder := Node3D.new()
	holder.name = "StaticBatch" if not root.has_node("StaticBatch") else "StaticBatchLate"
	root.add_child(holder)
	for key in groups:
		var g: Array = groups[key]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: Array in g[3]:
			st.append_from(part[0], part[1], part[2])
		var mesh := st.commit()
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		mesh.surface_set_material(0, g[0])
		var out := MeshInstance3D.new()
		out.mesh = mesh
		out.cast_shadow = g[1]
		out.layers = g[2]
		holder.add_child(out)
		_follow.append([out, g[4]])
		_copy_range(out, g[4])
		meshes_made += 1
	for mi in joined:
		mi.set_meta("batched_mesh", mi.mesh)
		mi.mesh = null
	merged += joined.size()
	print("StaticBatch: %d pieces joined into %d meshes" % [merged, meshes_made])


func _process(_delta: float) -> void:
	for f: Array in _follow:
		if is_instance_valid(f[1]):
			_copy_range(f[0], f[1])


func _copy_range(out: MeshInstance3D, piece: MeshInstance3D) -> void:
	out.visible = piece.visible
	out.visibility_range_begin = piece.visibility_range_begin
	out.visibility_range_end = piece.visibility_range_end
	out.visibility_range_begin_margin = piece.visibility_range_begin_margin
	out.visibility_range_end_margin = piece.visibility_range_end_margin
	out.visibility_range_fade_mode = piece.visibility_range_fade_mode


## Which vertex data a surface has (pieces are only joined with alike ones).
func _format(mesh: Mesh, s: int) -> int:
	var arrays := mesh.surface_get_arrays(s)
	var f := 0
	for i in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		if arrays[i] != null:
			f |= 1 << i
	return f


## Nodes whose meshes must stay as they are.
func _kept(root: Node) -> Dictionary:
	var keep := {}
	for n in get_tree().get_nodes_in_group("interactables"):
		if not root.is_ancestor_of(n):
			continue
		keep[n] = true
		if n.has_method("_targets"):
			for t: Node in n.call("_targets"):
				keep[t] = true
	return keep


func _mergeable(mi: MeshInstance3D, root: Node3D, keep: Dictionary) -> bool:
	return _why_not(mi, root, keep) == ""


## Why a mesh can't be joined ("" if it can).
func _why_not(mi: MeshInstance3D, root: Node3D, keep: Dictionary) -> String:
	if mi.mesh == null or mi.has_meta("batched_mesh"):
		return "no mesh"
	if not mi.is_visible_in_tree():
		return "hidden"
	if mi.skin != null:
		return "skinned"
	if mi.transparency > 0.0 or mi.material_overlay:
		return "transparency/overlay"
	if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).get_blend_shape_count() > 0:
		return "blend shapes"
	var n: Node = mi
	while n and n != root:
		if keep.has(n):
			return "outlined by an interactable"
		if n.has_meta("batch_keep"):
			return "kept (batch_keep)"
		if n is Light3D:
			return "under a light"
		if n.is_in_group("night_only") or n.is_in_group("day_only") or n.is_in_group("night_glow"):
			return "day/night group"
		if n.get_script() and not ((n.get_script() as Script).resource_path.get_file() in BUILDERS):
			return "script " + (n.get_script() as Script).resource_path.get_file()
		n = n.get_parent()
	for s in mi.mesh.get_surface_count():
		if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return "not triangles"
		var mat := mi.get_active_material(s)
		if mat == null:
			return "no material"
		if not _solid(mat, _in_root_frame(mi, root)):
			return "material " + mat.get_class() + (" " + (mat as ShaderMaterial).shader.resource_path.get_file() if mat is ShaderMaterial and (mat as ShaderMaterial).shader else "")
	return ""


## Shaders that read a piece's own (local) position or normal: joined, the
## pieces share one local frame, so their patterns would shift.
static var _local_use: RegEx


## A piece placed at its root's own origin and orientation.
func _in_root_frame(mi: MeshInstance3D, root: Node3D) -> bool:
	var xf := root.global_transform.affine_inverse() * mi.global_transform
	return xf.is_equal_approx(Transform3D.IDENTITY)


## Opaque, and not depending on its object's own position or frame
## (`same_frame`: the piece's frame is the root's, so local use is fine).
func _solid(mat: Material, same_frame := false) -> bool:
	if mat.next_pass:
		return false
	if mat is BaseMaterial3D:
		var b := mat as BaseMaterial3D
		if not same_frame and ((b.uv1_triplanar and not b.uv1_world_triplanar) or (b.uv2_triplanar and not b.uv2_world_triplanar)):
			return false
		return b.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and b.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED
	if mat is ShaderMaterial:
		var sh := (mat as ShaderMaterial).shader
		if sh == null:
			return false
		var code := sh.code
		for bad in ["ALPHA", "MODEL_MATRIX[3]", "NODE_POSITION", "INSTANCE_CUSTOM", "INSTANCE_ID", "blend_", "depth_draw_never"]:
			if code.contains(bad):
				return false
		if _local_use == null:
			_local_use = RegEx.create_from_string("=\\s*(VERTEX|NORMAL|TANGENT|BINORMAL)\\b")
		return same_frame or _local_use.search(code) == null
	return false
