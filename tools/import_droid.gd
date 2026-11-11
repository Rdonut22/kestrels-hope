extends SceneTree

## Builds characters/droid/droid.glb (the farming droid) from the download:
## - orange and yellow paint recoloured to the model's own light grey,
##   keeping its shading and wear,
## - reduced from ~380k to about TRIANGLES triangles,
## - split into Base (wheel bogies) and Head (everything above them, which
##   droid.gd turns left and right),
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
	# The front is the planter arm reaching out at -X (the head's lit
	# visor faces +X; droid.gd turns the head round to face forward). Put
	# the ground under the middle at the origin and turn it so the front
	# is -Z.
	var orig := v.duplicate()
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
	# Two parts, classified in the model's own coordinates: the Base (the
	# wheel bogies and the frame under them) and the Head: everything
	# above the bogies (armour, planter arm, tank, hoses), which turns
	# about a vertical axis through the middle of the bogies.
	var root := Node3D.new()
	root.name = "Droid"
	var parts := {"Base": PackedInt32Array(), "Head": PackedInt32Array(), "Eyes": PackedInt32Array()}
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# The eyes: the model's own pair of round lights on the front face,
	# under the armour (around x -0.25, y -0.09); they keep the model's
	# yellow and glow (their own surface, original texture).
	var orig_img := _orig_albedo()
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var w := orig_img.get_width()
	for t in range(0, idx.size(), 3):
		var c := (orig[idx[t]] + orig[idx[t + 1]] + orig[idx[t + 2]]) / 3.0
		var upper := c.y > -0.22 or c.x < -0.42 or (c.y > -0.32 and absf(c.z) < 0.2)
		var key := "Head" if upper else "Base"
		if upper and c.x < -0.2 and c.x > -0.32 and c.y > -0.16 and c.y < -0.02 and absf(c.z) < 0.12:
			var u := (uv[idx[t]] + uv[idx[t + 1]] + uv[idx[t + 2]]) / 3.0
			var col := orig_img.get_pixel(clampi(int(u.x * w), 0, w - 1), clampi(int(u.y * w), 0, w - 1))
			if col.s > 0.3 and col.v > 0.45 and col.h > 0.05 and col.h < 0.18:
				key = "Eyes"
		parts[key].append_array([idx[t], idx[t + 1], idx[t + 2]])
	var eye_mat := StandardMaterial3D.new()
	eye_mat.resource_name = "DroidEyes"
	var orig_tex := ImageTexture.create_from_image(orig_img)
	eye_mat.albedo_texture = orig_tex
	eye_mat.emission_enabled = true
	eye_mat.emission_texture = orig_tex
	eye_mat.emission_energy_multiplier = 1.5
	# Pivot: model (0.29, -0.25, 0), moved and turned like the vertices.
	var head_pivot := turn * (Vector3(0.29, -0.25, 0.0) - centre)
	for key in ["Base", "Head"]:
		var sub := _compact(arrays, parts[key])
		var pivot := head_pivot if key == "Head" else Vector3.ZERO
		var sv: PackedVector3Array = sub[Mesh.ARRAY_VERTEX]
		for i2 in sv.size():
			sv[i2] -= pivot
		sub[Mesh.ARRAY_VERTEX] = sv
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sub)
		am.surface_set_material(0, mat)
		if key == "Head" and not parts["Eyes"].is_empty():
			var es := _compact(arrays, parts["Eyes"])
			var ev: PackedVector3Array = es[Mesh.ARRAY_VERTEX]
			for i2 in ev.size():
				ev[i2] -= pivot
			es[Mesh.ARRAY_VERTEX] = ev
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, es)
			am.surface_set_material(1, eye_mat)
			print("eyes: %d triangles" % (parts["Eyes"].size() / 3))
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


func _orig_albedo() -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://character/gana_src/droid/droid_0.png"))
	img.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
	return img


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
