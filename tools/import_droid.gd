extends SceneTree

## Builds characters/droid/droid.glb (the farming droid) from the download:
## - orange and yellow paint recoloured to the model's own light grey,
##   keeping its shading and wear,
## - reduced from ~380k to about TRIANGLES triangles,
## - split into Body and the four wheel pods (rotated by droid.gd), with
##   their pivots at each wheel's centre,
## - origin at the ground under its middle, front facing -Z.
##   godot --path . -s tools/import_droid.gd
## The sources (res://character/gana_src/droid/, git-ignored) must be
## imported first.

## Pre-reduced in Blender to ~24k triangles (decimate); textures recoloured
## separately (orange/yellow -> grey) into character/gana_src/droid/droid_{albedo,normal,orm}.png.
const SRC := "res://character/gana_src/droid/droid_low.glb"
const OUT := "res://characters/droid/droid.glb"
const TRIANGLES := 24000
const TEXTURE_SIZE := 1024
## The model's light grey plating (sampled from its armour).
const GREY := Color(0.62, 0.6, 0.57)


func _initialize() -> void:
	var src: Node3D = (load(SRC) as PackedScene).instantiate()
	var mi: MeshInstance3D = src.find_children("*", "MeshInstance3D", true, false)[0]
	var arrays := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for p in v:
		lo = lo.min(p)
		hi = hi.max(p)
	print("bounds ", lo, " .. ", hi)
	# Model faces +X (its hose and lamp at -X are the back). Put the ground
	# under the middle at the origin and turn it so the front is -Z.
	var centre := Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
	var turn := Basis(Vector3.UP, -PI / 2)
	for i in v.size():
		v[i] = turn * (v[i] - centre)
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in n.size():
		n[i] = turn * n[i]
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	if arrays[Mesh.ARRAY_TANGENT] != null:
		arrays[Mesh.ARRAY_TANGENT] = null
	var mat := StandardMaterial3D.new()
	mat.resource_name = "Droid"
	mat.albedo_texture = _png("albedo")
	mat.normal_enabled = true
	mat.normal_texture = _png("normal")
	var orm := _png("orm")
	mat.roughness_texture = orm
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.metallic_texture = orm
	mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	mat.metallic = 1.0
	mat.roughness = 1.0
	# Wheels: the four pods below the axle line, out at the sides
	# (after the turn: sides are +-X, front -Z).
	var root := Node3D.new()
	root.name = "Droid"
	var wheel_y := -0.3 - lo.y
	var parts := {"Body": PackedInt32Array()}
	var pods := {}
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t in range(0, idx.size(), 3):
		var c := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
		var key := "Body"
		if c.y < wheel_y and absf(c.x) > 0.2:
			key = "Wheel%s%s" % ["L" if c.x < 0.0 else "R", "F" if c.z < 0.0 else "B"]
		if not parts.has(key):
			parts[key] = PackedInt32Array()
		parts[key].append_array([idx[t], idx[t + 1], idx[t + 2]])
	for key in parts:
		var sub := _compact(arrays, parts[key])
		var sv: PackedVector3Array = sub[Mesh.ARRAY_VERTEX]
		var pivot := Vector3.ZERO
		if key != "Body":
			var a := Vector3(INF, INF, INF)
			var b := -a
			for p in sv:
				a = a.min(p)
				b = b.max(p)
			pivot = (a + b) * 0.5
			for i in sv.size():
				sv[i] -= pivot
			sub[Mesh.ARRAY_VERTEX] = sv
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sub)
		am.surface_set_material(0, mat)
		var part := MeshInstance3D.new()
		part.name = key
		part.mesh = am
		part.position = pivot
		root.add_child(part)
		part.owner = root
		print("%s: %d triangles, pivot %s" % [key, (sub[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3, pivot])
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(OUT))
	print("wrote %s: %s" % [OUT, error_string(err)])
	root.free()
	src.free()
	quit(0 if err == OK else 1)


func _png(n: String) -> Texture2D:
	return ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://character/gana_src/droid/droid_%s.png" % n)))


## Keeps only the vertices `idx` uses (all per-vertex arrays), renumbered.
func _compact(arrays: Array, idx: PackedInt32Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n := verts.size()
	var remap := PackedInt32Array()
	remap.resize(n)
	remap.fill(-1)
	var order := PackedInt32Array()
	var new_idx := PackedInt32Array()
	new_idx.resize(idx.size())
	for i in idx.size():
		var vi := idx[i]
		if remap[vi] < 0:
			remap[vi] = order.size()
			order.append(vi)
		new_idx[i] = remap[vi]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	for a in Mesh.ARRAY_MAX:
		var arr = arrays[a]
		if arr == null or a == Mesh.ARRAY_INDEX:
			continue
		var per: int = arr.size() / n
		var dst = arr.duplicate()
		dst.resize(order.size() * per)
		for j in order.size():
			for c in per:
				dst[j * per + c] = arr[order[j] * per + c]
		out[a] = dst
	out[Mesh.ARRAY_INDEX] = new_idx
	return out
