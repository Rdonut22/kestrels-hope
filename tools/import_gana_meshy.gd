extends SceneTree

## Builds characters/gana/body/gana_body.glb (the stylized Gana from the
## character sheet, generated in Meshy and rigged with Mixamo) from the
## downloaded GLB(s):
## - keeps the mesh (already ~10k triangles), skeleton and textures
##   (resized to TEXTURE_SIZE),
## - cuts out the generated right hand (it came out malformed); the
##   mechanical hand is built on the finger bones at runtime instead
##   (character/gana/robot_arm.gd, hand only),
## - renames the animations it needs and strips any forward root motion,
## - adds animations from extra files (idle, interact) when present.
##
##   godot --path . -s tools/import_gana_meshy.gd -- [source dir]
## The source GLB/FBX files must be inside the project and imported first
## (copy them to res://character/gana_src/meshy/ and run --import); don't
## commit them.

const OUT := "res://characters/gana/body/gana_body.glb"
const MAIN := "all.glb"
const TEXTURE_SIZE := 1024
## Animation in the main file -> name used by the game.
const RENAME := {"Walking": "Walk", "Running": "Run", "Regular_Jump": "Jump"}
## Extra files (any one animation each) -> name.
const EXTRA := {"idle": "Idle", "interact": "Interact"}
const REMOVED_BONES := ["mixamorig_RightHand"]


func _initialize() -> void:
	var dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "res://character/gana_src/meshy"
	var base: Node3D = (load(dir + "/" + MAIN) as PackedScene).instantiate()
	var player: AnimationPlayer = base.find_children("*", "AnimationPlayer", true, false)[0]
	var skel: Skeleton3D = base.find_children("*", "Skeleton3D", true, false)[0]
	var skel_path := String(player.get_node(player.root_node).get_path_to(skel))
	var lib := AnimationLibrary.new()
	for src in RENAME:
		if player.has_animation(src):
			var a := player.get_animation(src).duplicate(true) as Animation
			_strip_root_motion(a)
			a.loop_mode = Animation.LOOP_NONE if RENAME[src] == "Jump" else Animation.LOOP_LINEAR
			lib.add_animation(RENAME[src], a)
			print("animation %s <- %s (%.2f s)" % [RENAME[src], src, a.length])
	for file in EXTRA:
		for ext in ["glb", "fbx"]:
			var path := "%s/%s.%s" % [dir, file, ext]
			if not ResourceLoader.exists(path):
				continue
			var scene: Node = (load(path) as PackedScene).instantiate()
			var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
			var a := _longest(ap).duplicate(true) as Animation
			_retarget(a, skel_path)
			_strip_root_motion(a)
			a.loop_mode = Animation.LOOP_LINEAR if file == "idle" else Animation.LOOP_NONE
			lib.add_animation(EXTRA[file], a)
			print("animation %s <- %s" % [EXTRA[file], path])
			scene.free()
	if not lib.has_animation("Idle"):
		# Stand-in until a real idle is supplied: the standing pose at the
		# start of the jump, held.
		lib.add_animation("Idle", _held_pose(lib.get_animation("Jump"), 0.0))
		print("animation Idle <- held standing pose (stand-in: add idle.glb)")
	for l in player.get_animation_library_list():
		player.remove_animation_library(l)
	player.add_animation_library("", lib)
	for mi: MeshInstance3D in base.find_children("*", "MeshInstance3D", true, false):
		_cut(mi)
		_materials(mi, dir)
	base.name = "GanaBody"
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(base, state)
	if err == OK:
		err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(OUT))
	print("wrote %s: %s" % [OUT, error_string(err)])
	base.free()
	quit(0 if err == OK else 1)


func _longest(ap: AnimationPlayer) -> Animation:
	var best: Animation = null
	for n in ap.get_animation_list():
		var a := ap.get_animation(n)
		if best == null or a.length > best.length:
			best = a
	return best


## Point an animation from another file at this skeleton (same bone names).
func _retarget(a: Animation, skel_path: String) -> void:
	for t in a.get_track_count():
		var p := String(a.track_get_path(t))
		var i := p.find(":")
		if i >= 0:
			a.track_set_path(t, NodePath(skel_path + p.substr(i)))


## One frame of `src`, held for a second (looping).
func _held_pose(src: Animation, time: float) -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	for t in src.get_track_count():
		var type := src.track_get_type(t)
		if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var n := a.add_track(type)
		a.track_set_path(n, src.track_get_path(t))
		var k := src.track_find_key(t, time, Animation.FIND_MODE_NEAREST)
		a.track_insert_key(n, 0.0, src.track_get_key_value(t, maxi(k, 0)))
	return a


## Removes the hips' steady drift across the ground over the clip.
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
		if drift.length() < 0.02:
			return
		var t0 := anim.track_get_key_time(t, 0)
		var t1 := anim.track_get_key_time(t, n - 1)
		for k in n:
			var f := (anim.track_get_key_time(t, k) - t0) / maxf(t1 - t0, 0.0001)
			anim.track_set_key_value(t, k, (anim.track_get_key_value(t, k) as Vector3) - drift * f)
		print("  stripped root motion: %.2f m" % drift.length())
		return


## Resized textures on a plain material (albedo, normal, roughness).
func _materials(mi: MeshInstance3D, dir: String) -> void:
	var stem := dir + "/" + MAIN.get_basename()
	var m := StandardMaterial3D.new()
	m.resource_name = "Gana"
	m.albedo_texture = _tex(stem + "_texture_0.png")
	var nrm := _tex(stem + "_normal.png")
	if nrm:
		m.normal_enabled = true
		m.normal_texture = nrm
		m.normal_scale = 0.6
	var mr := _tex(stem + "_texture_0_metallic_roughness.png")
	if mr:
		m.roughness_texture = mr
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.roughness = 1.0
	m.metallic = 0.0
	for s in mi.mesh.get_surface_count():
		mi.mesh.surface_set_material(s, m)
		mi.set_surface_override_material(s, null)


func _tex(path: String) -> Texture2D:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		return null
	img.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


## Removes triangles skinned mostly to REMOVED_BONES or their children.
func _cut(mi: MeshInstance3D) -> void:
	var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	if skel == null or mi.skin == null:
		return
	var gone := {}
	for i in skel.get_bone_count():
		var b := i
		while b >= 0:
			if skel.get_bone_name(b) in REMOVED_BONES:
				gone[i] = true
				break
			b = skel.get_bone_parent(b)
	var bind_gone := []
	for i in mi.skin.get_bind_count():
		var bone := mi.skin.get_bind_bone(i)
		if bone < 0:
			bone = skel.find_bone(mi.skin.get_bind_name(i))
		bind_gone.append(gone.has(bone))
	var src := mi.mesh as ArrayMesh
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var nv := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var per: int = bones.size() / nv
		var w_gone := PackedFloat32Array()
		w_gone.resize(nv)
		for v in nv:
			var w := 0.0
			for c in per:
				var bi: int = bones[v * per + c]
				if bi < bind_gone.size() and bind_gone[bi]:
					w += weights[v * per + c]
			w_gone[v] = w
		var keep := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			if (w_gone[idx[t]] + w_gone[idx[t + 1]] + w_gone[idx[t + 2]]) / 3.0 < 0.5:
				keep.append_array([idx[t], idx[t + 1], idx[t + 2]])
		print("  cut right hand: %d -> %d triangles" % [idx.size() / 3, keep.size() / 3])
		arrays = _compact(arrays, keep)
		var flags := src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))
	mi.mesh = out


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
