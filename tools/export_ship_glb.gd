extends SceneTree

## Exports the Kestrel (ship/kestrel_v2_test.tscn, built at runtime) as a
## GLB for viewing outside Godot:
##   godot --path . -s tools/export_ship_glb.gd -- <out.glb>
## glTF can't hold Godot shaders, so materials are approximated: the worn
## hull paint (ship/marauder_paint.gdshader) becomes its colour tile with
## box-projected UVs, other shader materials a flat colour from their
## parameters. A preview, not the game's look.

const PAINT := "res://ship/marauder_paint.gdshader"

var _mats := {}


func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://kestrel.glb"
	var ship: Node3D = (load("res://ship/kestrel_v2_test.tscn") as PackedScene).instantiate()
	get_root().add_child(ship)
	_go.call_deferred(ship, out)


func _go(ship: Node3D, out: String) -> void:
	for i in 5:
		await process_frame
	var root := Node3D.new()
	root.name = "Kestrel"
	var n := 0
	var tris := 0
	for mi: MeshInstance3D in ship.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree() or not _outside(ship, mi):
			continue
		var m := _convert(mi) as ArrayMesh
		if m == null:
			continue
		var copy := MeshInstance3D.new()
		copy.name = "%s_%d" % [mi.name, n]
		copy.mesh = m
		copy.transform = mi.global_transform
		root.add_child(copy)
		n += 1
		for s in m.get_surface_count():
			tris += m.surface_get_array_len(s) / 3 if m.surface_get_array_index_len(s) == 0 else m.surface_get_array_index_len(s) / 3
	for mm: MultiMeshInstance3D in ship.find_children("*", "MultiMeshInstance3D", true, false):
		if mm.multimesh == null or mm.multimesh.mesh == null or not mm.is_visible_in_tree() or not _outside(ship, mm):
			continue
		for k in mm.multimesh.visible_instance_count if mm.multimesh.visible_instance_count >= 0 else mm.multimesh.instance_count:
			var copy := MeshInstance3D.new()
			copy.mesh = _plain(mm.multimesh.mesh, mm.material_override)
			copy.transform = mm.global_transform * mm.multimesh.get_instance_transform(k)
			root.add_child(copy)
	print("meshes %d, triangles %d" % [n, tris])
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, out)
	print("wrote %s: %s" % [out, error_string(err)])
	quit()


## The exterior only: everything KestrelExterior built, plus the interior's
## big shell pieces (hull, canopy, windows); not the furniture inside.
func _outside(ship: Node, n: Node3D) -> bool:
	var p := n.get_parent()
	while p and p != ship:
		if p.name == "KestrelExterior":
			return true
		p = p.get_parent()
	if not n is GeometryInstance3D:
		return false
	var box := (n as GeometryInstance3D).get_aabb()
	var size := (n.global_transform.basis * box.size).abs()
	return maxf(size.x, maxf(size.y, size.z)) > 4.0


func _mat_of(mi: MeshInstance3D, s: int) -> Material:
	if mi.material_override:
		return mi.material_override
	var m := mi.get_surface_override_material(s)
	return m if m else mi.mesh.surface_get_material(s)


func _convert(mi: MeshInstance3D) -> Mesh:
	var src := mi.mesh
	var out := ArrayMesh.new()
	var b := mi.global_transform.basis
	var sc := Vector3(b.x.length(), b.y.length(), b.z.length())
	for s in src.get_surface_count():
		if src is ArrayMesh and (src as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var mat := _mat_of(mi, s)
		var arrays := src.surface_get_arrays(s)
		if mat is ShaderMaterial and (mat as ShaderMaterial).shader and (mat as ShaderMaterial).shader.resource_path == PAINT:
			arrays = _paint_uvs(arrays, sc, mat)
		var keep := []
		keep.resize(Mesh.ARRAY_MAX)
		for a in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX, Mesh.ARRAY_COLOR]:
			keep[a] = arrays[a]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, keep)
		out.surface_set_material(out.get_surface_count() - 1, _standard(mat))
	return out if out.get_surface_count() > 0 else null


func _plain(src: Mesh, over: Material) -> Mesh:
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var keep := []
		keep.resize(Mesh.ARRAY_MAX)
		for a in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
			keep[a] = arrays[a]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, keep)
		out.surface_set_material(s, _standard(over if over else src.surface_get_material(s)))
	return out


## Unshares the vertices and gives each triangle the paint shader's
## projection for its main axis (uv in metres / color_size).
func _paint_uvs(arrays: Array, sc: Vector3, mat: ShaderMaterial) -> Array:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nr = arrays[Mesh.ARRAY_NORMAL]
	var idx = arrays[Mesh.ARRAY_INDEX]
	if idx == null or (idx as PackedInt32Array).is_empty():
		idx = PackedInt32Array(range(v.size()))
	var size: float = mat.get_shader_parameter("color_size") if mat.get_shader_parameter("color_size") != null else 8.0
	var seed: float = mat.get_shader_parameter("seed") if mat.get_shader_parameter("seed") != null else 0.0
	var off := Vector2(0.13, 0.71) + Vector2.ONE * seed * 0.41
	var pv := PackedVector3Array()
	var pn := PackedVector3Array()
	var puv := PackedVector2Array()
	var pidx := PackedInt32Array()
	var seen := {}
	for t in range(0, idx.size(), 3):
		var a: Vector3 = v[idx[t]] * sc
		var bb: Vector3 = v[idx[t + 1]] * sc
		var c: Vector3 = v[idx[t + 2]] * sc
		var fn := (bb - a).cross(c - a).abs()
		for k in 3:
			var i: int = idx[t + k]
			var p: Vector3 = v[i] * sc
			var uv: Vector2
			if fn.x >= fn.y and fn.x >= fn.z:
				uv = Vector2(p.z, -p.y)
			elif fn.z >= fn.y:
				uv = Vector2(p.x, -p.y)
			else:
				uv = Vector2(p.x, p.z) + Vector2(31, 17)
			var key := [i, (uv * 1000.0).round()]
			if not seen.has(key):
				seen[key] = pv.size()
				pv.append(v[i])
				pn.append(nr[i] if nr != null else Vector3.UP)
				puv.append(uv / size + off)
			pidx.append(seen[key])
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = pv
	out[Mesh.ARRAY_NORMAL] = pn
	out[Mesh.ARRAY_TEX_UV] = puv
	out[Mesh.ARRAY_INDEX] = pidx
	return out


func _standard(mat: Material) -> Material:
	if mat == null:
		return null
	if _mats.has(mat):
		return _mats[mat]
	var out: StandardMaterial3D
	if mat is StandardMaterial3D:
		out = (mat as StandardMaterial3D).duplicate()
		out.uv1_triplanar = false
	elif mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		out = StandardMaterial3D.new()
		out.roughness = 0.7
		out.cull_mode = BaseMaterial3D.CULL_DISABLED
		if sm.shader and sm.shader.resource_path == PAINT:
			var tex = sm.get_shader_parameter("hull_color")
			if sm.get_shader_parameter("use_hull_color") and tex is Texture2D:
				if not _mats.has(tex):
					var img := (tex as Texture2D).get_image()
					img.decompress()
					img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
					_mats[tex] = ImageTexture.create_from_image(img)
				out.albedo_texture = _mats[tex]
				out.albedo_color = Color(0.92, 0.92, 0.92)
				out.texture_repeat = true
			else:
				var w = sm.get_shader_parameter("paint_white")
				out.albedo_color = _col(w, Color(0.74, 0.73, 0.69))
			out.metallic = 0.2
		else:
			var c: Color = Color(0.5, 0.5, 0.52)
			for p in ["base_color", "albedo", "color", "albedo_color", "tint", "paint_white"]:
				var val = sm.get_shader_parameter(p)
				if val != null:
					c = _col(val, c)
					break
			out.albedo_color = c
			for p in ["emission", "glow_color", "emission_color"]:
				var e = sm.get_shader_parameter(p)
				if e != null:
					out.emission_enabled = true
					out.emission = _col(e, Color.BLACK)
					break
	else:
		out = StandardMaterial3D.new()
	_mats[mat] = out
	return out


static func _col(val, fallback: Color) -> Color:
	if val is Color:
		return val
	if val is Vector3:
		return Color(val.x, val.y, val.z)
	if val is Vector4:
		return Color(val.x, val.y, val.z, val.w)
	return fallback
