extends SceneTree

## Builds character/gana/gana.glb (Gana's body) from the Mixamo FBX
## downloads: one FBX per animation, each with the same mesh, skeleton and
## embedded textures. Keeps the mesh, skeleton and textures once (textures
## resized), takes each file's animation, strips the forward root motion so
## the controller moves the character, and writes one GLB.
##
##   godot --path . -s tools/import_gana.gd -- <dir with the imported FBX>
##   (the FBX must be inside the project and imported first, e.g. copy them
##   to res://character/gana_src/ and run godot --headless --import; don't
##   commit them: they're ~25 MB each.)
##
## Animation files expected in the folder: idle.fbx -> "Idle",
## walk.fbx -> "Walk", and optionally run.fbx -> "Run", interact.fbx ->
## "Interact".

const OUT := "res://character/gana/gana.glb"
const TEXTURE_SIZE := 1024
## Mixamo's export is ~1.98 m tall; Gana is 1.80 m.
const BODY_SCALE := 0.91
const ANIMS := {"idle": "Idle", "walk": "Walk", "run": "Run", "interact": "Interact"}
## Material name in the FBX -> index of its embedded texture (<file>_<i>.png).
const TEXTURES := {"head": 0, "body": 1, "hand": 2, "boot": 3}
const ROUGHNESS := {"head": 0.62, "body": 0.72, "hand": 0.6, "boot": 0.66}
## The download is ~310k triangles (114k of them boots); reduce each part to
## about this many triangles. The face keeps the most.
const TRIANGLES := {"head": 14000, "body": 30000, "hand": 5000, "boot": 7000}


func _initialize() -> void:
	var dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "res://character/gana_src"
	var base: Node3D = null
	var lib := AnimationLibrary.new()
	for file in ANIMS:
		var path := "%s/%s.fbx" % [dir, file]
		if not ResourceLoader.exists(path):
			continue
		var scene: Node3D = (load(path) as PackedScene).instantiate()
		var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var anim := _pick_animation(ap)
		anim = anim.duplicate(true)
		_strip_root_motion(anim)
		_center_facing(anim)
		anim.loop_mode = Animation.LOOP_NONE if file == "interact" else Animation.LOOP_LINEAR
		lib.add_animation(ANIMS[file], anim)
		print("animation %s: %.2f s, %d tracks" % [ANIMS[file], anim.length, anim.get_track_count()])
		if base == null:
			base = scene
			_prepare_materials(base, dir, file)
			for mi: MeshInstance3D in base.find_children("*", "MeshInstance3D", true, false):
				_reduce(mi)
		else:
			scene.free()
	if base == null:
		push_error("no FBX found in " + dir)
		quit(1)
		return
	# Replace the FBX's own animations with ours.
	var player: AnimationPlayer = base.find_children("*", "AnimationPlayer", true, false)[0]
	for l in player.get_animation_library_list():
		player.remove_animation_library(l)
	player.add_animation_library("", lib)
	base.scale = Vector3.ONE * BODY_SCALE
	base.name = "Gana"
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(base, state)
	if err == OK:
		err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(OUT))
	print("wrote %s: %s" % [OUT, error_string(err)])
	base.free()
	quit(0 if err == OK else 1)


## The Mixamo take (the FBX also carries a one-frame "Take 001" bind pose).
func _pick_animation(ap: AnimationPlayer) -> Animation:
	var best: Animation = null
	for n in ap.get_animation_list():
		var a := ap.get_animation(n)
		if best == null or a.length > best.length or n.contains("mixamo"):
			best = a
			if n.contains("mixamo"):
				break
	return best


## Removes the hips' steady drift across the ground over the clip (keeps
## the bob and sway), so walking happens in place.
func _strip_root_motion(anim: Animation) -> void:
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D or not String(anim.track_get_path(t)).ends_with("Hips"):
			continue
		var n := anim.track_get_key_count(t)
		if n < 2:
			return
		var first: Vector3 = anim.track_get_key_value(t, 0)
		var last: Vector3 = anim.track_get_key_value(t, n - 1)
		var drift := Vector3(last.x - first.x, 0.0, last.z - first.z)
		var t0 := anim.track_get_key_time(t, 0)
		var t1 := anim.track_get_key_time(t, n - 1)
		for k in n:
			var f := (anim.track_get_key_time(t, k) - t0) / maxf(t1 - t0, 0.0001)
			var v: Vector3 = anim.track_get_key_value(t, k)
			anim.track_set_key_value(t, k, v - drift * f)
		print("  stripped root motion: %.2f m over %.2f s" % [drift.length(), t1 - t0])
		return


## The FBX importer extracts the embedded textures but leaves the
## materials without them: put them back (resized) with sensible PBR values.
func _prepare_materials(scene: Node3D, dir: String, file: String) -> void:
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		for s in mesh.get_surface_count():
			var old := mesh.surface_get_material(s)
			var key := old.resource_name.to_lower() if old else ""
			var m := StandardMaterial3D.new()
			m.resource_name = key.capitalize()
			m.roughness = ROUGHNESS.get(key, 0.7)
			m.metallic = 0.0
			if TEXTURES.has(key):
				var img := Image.load_from_file(ProjectSettings.globalize_path("%s/%s_%d.png" % [dir, file, TEXTURES[key]]))
				if img:
					img.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
					m.albedo_texture = ImageTexture.create_from_image(img)
			mesh.surface_set_material(s, m)
			mi.set_surface_override_material(s, null)


## Simplifies each surface (meshoptimizer, via ImporterMesh's LOD
## generator) to about TRIANGLES[material] and drops the unused vertices.
func _reduce(mi: MeshInstance3D) -> void:
	var src := mi.mesh as ArrayMesh
	var out := ArrayMesh.new()
	var before := 0
	var after := 0
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var mat := src.surface_get_material(s)
		var key := mat.resource_name.to_lower() if mat else ""
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		before += idx.size() / 3
		var want: int = TRIANGLES.get(key, idx.size() / 3) * 3
		if idx.size() > want:
			var im := ImporterMesh.new()
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
			im.generate_lods(60.0, 25.0, [])
			for l in im.get_surface_lod_count(0):
				var li := im.get_surface_lod_indices(0, l)
				idx = li
				if li.size() <= want:
					break
		arrays = _compact(arrays, idx)
		after += idx.size() / 3
		var flags := src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, mat)
		print("  %s: %d -> %d triangles" % [key, (src.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3, idx.size() / 3])
	out.resource_name = src.resource_name
	mi.mesh = out
	print("mesh %s: %d -> %d triangles" % [mi.name, before, after])


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
		var v := idx[i]
		if remap[v] < 0:
			remap[v] = order.size()
			order.append(v)
		new_idx[i] = remap[v]
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


## Turns the whole clip so the hips face forward on average. (Mixamo's idle
## looks around, ending up ~40 degrees to one side; a constant turn keeps
## the feet planted.)
func _center_facing(anim: Animation) -> void:
	var rot := -1
	var pos := -1
	for t in anim.get_track_count():
		if String(anim.track_get_path(t)).ends_with("Hips"):
			if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				rot = t
			elif anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
				pos = t
	if rot < 0:
		return
	var sum := Vector2.ZERO
	for k in anim.track_get_key_count(rot):
		var fwd := Basis(anim.track_get_key_value(rot, k) as Quaternion) * Vector3.BACK
		sum += Vector2(fwd.x, fwd.z)
	var mean := atan2(sum.x, sum.y)
	if absf(mean) < deg_to_rad(3.0):
		return
	var fix := Quaternion(Vector3.UP, -mean)
	for k in anim.track_get_key_count(rot):
		anim.track_set_key_value(rot, k, fix * (anim.track_get_key_value(rot, k) as Quaternion))
	if pos >= 0:
		for k in anim.track_get_key_count(pos):
			anim.track_set_key_value(pos, k, fix * (anim.track_get_key_value(pos, k) as Vector3))
	print("  centred facing: turned %.0f degrees" % rad_to_deg(-mean))
