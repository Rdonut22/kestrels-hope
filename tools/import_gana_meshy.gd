extends SceneTree

## Builds characters/gana/body/gana_body.glb (the stylized Gana, generated
## and rigged in Meshy) from the downloaded GLB, keeping its mesh, rig and
## animations as they are:
## - textures resized to TEXTURE_SIZE,
## - animations renamed for the game (RENAME), any forward root motion
##   stripped,
## - the skin recoloured to SKIN (the generated skin came out pale),
## - the generated right forearm and hand cut out: Gana's mechanical arm
##   with the wrist terminal is built on those bones at runtime
##   (character/gana/robot_arm.gd).
##
##   godot --path . -s tools/import_gana_meshy.gd -- [source GLB]
## The source must be inside the project and imported first (copy it to
## res://character/gana_src/, which is git-ignored, and run --import).

const SRC := "res://character/gana_src/meshy2/all.glb"
const OUT := "res://characters/gana/body/gana_body.glb"
const TEXTURE_SIZE := 1024
## Animation in the download -> name used by the game. Others keep their
## names.
const RENAME := {"Idle_3": "Idle", "Walking": "Walk", "walking_2": "QuickWalk", "Running": "Run",
	"Regular_Jump": "Jump", "Male_Bend_Over_Pick_Up": "PickUp", "Catching_Breath": "CatchBreath",
	"Jump_Over_Obstacle_2": "Vault", "Jump_and_Grab_Wall": "JumpGrab", "climbing_up_wall": "ClimbUp"}
const LOOPS := ["Idle", "Walk", "QuickWalk", "Run"]
## Skin colour (the sheet's).
const SKIN := Color("A6794A")
## The generated skin's base colour (its lit tone); texels near this hue
## are recoloured, keeping their light and shade.
const SKIN_SRC := Color(0.906, 0.664, 0.482)
const REMOVED_BONES := ["mixamorig_RightForeArm"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var src: String = args[0] if args.size() > 0 else SRC
	var base: Node3D = (load(src) as PackedScene).instantiate()
	var player: AnimationPlayer = base.find_children("*", "AnimationPlayer", true, false)[0]
	var lib := AnimationLibrary.new()
	for n in player.get_animation_list():
		if n == "RESET":
			continue
		var a := player.get_animation(n).duplicate(true) as Animation
		var name: String = RENAME.get(n, n)
		_strip_root_motion(a)
		a.loop_mode = Animation.LOOP_LINEAR if name in LOOPS else Animation.LOOP_NONE
		lib.add_animation(name, a)
		print("animation %s <- %s (%.2f s)" % [name, n, a.length])
	for l in player.get_animation_library_list():
		player.remove_animation_library(l)
	player.add_animation_library("", lib)
	for mi: MeshInstance3D in base.find_children("*", "MeshInstance3D", true, false):
		_materials(mi, src)
		_clean_weights(mi)
		_separate_limbs(mi)
		_cut(mi)
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
		if drift.length() < 2.0:  # this rig's units are centimetres
			return
		var t0 := anim.track_get_key_time(t, 0)
		var t1 := anim.track_get_key_time(t, n - 1)
		for k in n:
			var f := (anim.track_get_key_time(t, k) - t0) / maxf(t1 - t0, 0.0001)
			anim.track_set_key_value(t, k, (anim.track_get_key_value(t, k) as Vector3) - drift * f)
		print("  stripped root motion: %.2f" % drift.length())
		return


func _materials(mi: MeshInstance3D, src: String) -> void:
	var stem := src.get_basename()
	var m := StandardMaterial3D.new()
	m.resource_name = "Gana"
	var albedo := _img(stem + "_texture_0.png")
	if albedo:
		_recolour_skin(albedo, mi)
		m.albedo_texture = ImageTexture.create_from_image(albedo)
	var mr := _img(stem + "_texture_0_metallic_roughness.png")
	if mr:
		m.roughness_texture = ImageTexture.create_from_image(mr)
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.roughness = 1.0
	m.metallic = 0.0
	for s in mi.mesh.get_surface_count():
		mi.mesh.surface_set_material(s, m)
		mi.set_surface_override_material(s, null)


func _img(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img:
		img.convert(Image.FORMAT_RGB8)
		img.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
	return img


## Recolours skin texels: only on the triangles of the head, neck and the
## (natural) left arm, and only texels near the generated skin's hue.
func _recolour_skin(img: Image, mi: MeshInstance3D) -> void:
	var a := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var w := img.get_width()
	var h := img.get_height()
	var scale := Vector3(SKIN.r / SKIN_SRC.r, SKIN.g / SKIN_SRC.g, SKIN.b / SKIN_SRC.b)
	var done := {}
	for t in range(0, idx.size(), 3):
		var c := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
		# Head and neck, or the left forearm/hand (+X is his left here).
		if not (c.y > 1.32 or (c.x > 0.15 and c.y < 1.2)):
			continue
		var u0 := uv[idx[t]] * Vector2(w, h)
		var u1 := uv[idx[t + 1]] * Vector2(w, h)
		var u2 := uv[idx[t + 2]] * Vector2(w, h)
		var lo := u0.min(u1).min(u2).floor() - Vector2.ONE * 2
		var hi := u0.max(u1).max(u2).ceil() + Vector2.ONE * 2
		for py in range(maxi(int(lo.y), 0), mini(int(hi.y), h - 1) + 1):
			for px in range(maxi(int(lo.x), 0), mini(int(hi.x), w - 1) + 1):
				var key := py * w + px
				if done.has(key):
					continue
				done[key] = true
				var col := img.get_pixel(px, py)
				if _is_skin(col):
					img.set_pixel(px, py, Color(col.r * scale.x, col.g * scale.y, col.b * scale.z))


static func _is_skin(c: Color) -> bool:
	var hd := absf(c.h - SKIN_SRC.h)
	return hd < 0.035 and c.s > 0.4 and c.s < 0.68 and c.v > 0.45


## The generated skinning gives some vertices weight on bones far away
## from them (part of the left arm follows the spine, so the arm stretches
## into a spike when it lifts). Influences from bones whose segment is
## more than FAR_BONE metres from the vertex are dropped (when a nearer one
## remains) and the rest renormalised.
const FAR_BONE := 0.28


func _clean_weights(mi: MeshInstance3D) -> void:
	var skin := mi.skin
	if skin == null:
		return
	# Each bind's segment in mesh space: its origin to its child's.
	var seg_a := []
	var seg_b := []
	var origins := []
	for i in skin.get_bind_count():
		origins.append(skin.get_bind_pose(i).affine_inverse().origin)
	var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	for i in skin.get_bind_count():
		var a: Vector3 = origins[i]
		var b := a
		if skel:
			var bone := skin.get_bind_bone(i)
			if bone < 0:
				bone = skel.find_bone(skin.get_bind_name(i))
			for j in skin.get_bind_count():
				var bj := skin.get_bind_bone(j)
				if bj < 0:
					bj = skel.find_bone(skin.get_bind_name(j))
				if bj >= 0 and skel.get_bone_parent(bj) == bone:
					b = origins[j]
					break
		seg_a.append(a)
		seg_b.append(b)
	var src := mi.mesh as ArrayMesh
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size() / v.size()
		var fixed := 0
		for i in v.size():
			var near := []
			var total := 0.0
			for c in per:
				var bi: int = bones[i * per + c]
				var w: float = weights[i * per + c]
				var d := 0.0
				if w > 0.0 and bi < seg_a.size():
					var q := Geometry3D.get_closest_point_to_segment(v[i], seg_a[bi], seg_b[bi])
					d = q.distance_to(v[i])
				near.append(d <= FAR_BONE)
				if d <= FAR_BONE:
					total += w
			if total <= 0.0:
				continue
			var changed := false
			for c in per:
				if not near[c] and weights[i * per + c] > 0.0:
					weights[i * per + c] = 0.0
					changed = true
			if changed:
				for c in per:
					weights[i * per + c] = weights[i * per + c] / total
				fixed += 1
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		var flags := src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))
		print("  skin weights: dropped far-away bones on %d vertices" % fixed)
	mi.mesh = out


## The auto-rig let the hands (which hang by the thighs) take weight from
## the leg bones, and the thighs from the hands, so a lifted arm drags a
## spike of skin along. Each vertex keeps only the bones of its own limb
## (plus the core next to it): arms never follow legs or the other arm,
## legs never follow arms or the other leg.
## Small loose pieces of the hands left on the legs once the bridges are
## cut: islands under STRAY_TRIS triangles, owned by a leg, outside the
## thigh (beside where the hands hang).
const STRAY_TRIS := 80


func _drop_strays(idx: PackedInt32Array, v: PackedVector3Array, own_of: Array) -> PackedInt32Array:
	var parent := {}
	var find := func(a: int) -> int:
		while parent.get(a, a) != a:
			parent[a] = parent.get(parent[a], parent[a])
			a = parent[a]
		return a
	for t in range(0, idx.size(), 3):
		for k in [1, 2]:
			var ra: int = find.call(idx[t])
			var rb: int = find.call(idx[t + k])
			if ra != rb:
				parent[ra] = rb
	var count := {}
	var centre := {}
	var leg := {}
	for t in range(0, idx.size(), 3):
		var r: int = find.call(idx[t])
		count[r] = count.get(r, 0) + 1
		centre[r] = centre.get(r, Vector3.ZERO) + v[idx[t]]
		if String(own_of[idx[t]]).ends_with("Leg"):
			leg[r] = leg.get(r, 0) + 1
	var out := PackedInt32Array()
	var dropped := 0
	for t in range(0, idx.size(), 3):
		var r: int = find.call(idx[t])
		var c: Vector3 = centre[r] / count[r]
		if count[r] < STRAY_TRIS and leg.get(r, 0) * 2 > count[r] and absf(c.x) > 0.25 and c.y > 0.75:
			dropped += 1
			continue
		out.append_array([idx[t], idx[t + 1], idx[t + 2]])
	print("  removed %d stray triangles" % dropped)
	return out


static func _limb(bone: String) -> String:
	for side in ["Left", "Right"]:
		for part in ["Shoulder", "Arm", "ForeArm", "Hand"]:
			if bone.ends_with(side + part) or bone.contains(side + "Hand"):
				return side + "Arm"
		for part in ["UpLeg", "Leg", "Foot", "ToeBase"]:
			if bone.ends_with(side + part):
				return side + "Leg"
	return "Core"


## Height (rest pose, metres) above which the torso may still bend with
## the upper arms (the armpits); below it the jacket ignores the arms.
const ARMPIT_Y := 1.2


static func _allowed(own: String, other: String, bone: String, y: float) -> bool:
	if own == other:
		return true
	if own.ends_with("Arm"):
		# An arm may still bend with the chest and neck, not the hips.
		return other == "Core" and (bone.ends_with("Spine2") or bone.ends_with("Neck"))
	if own.ends_with("Leg"):
		return other == "Core" and (bone.ends_with("Hips") or bone.ends_with("Spine"))
	# Core vertices may follow the tops of the limbs (the upper arms only at
	# the armpits).
	return bone.ends_with("Shoulder") or bone.ends_with("UpLeg") or (bone.ends_with("Arm") and y > ARMPIT_Y)


func _separate_limbs(mi: MeshInstance3D) -> void:
	var skin := mi.skin
	var names := []
	var limbs := []
	for i in skin.get_bind_count():
		names.append(skin.get_bind_name(i))
		limbs.append(_limb(skin.get_bind_name(i)))
	var src := mi.mesh as ArrayMesh
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size() / v.size()
		var fixed := 0
		for i in v.size():
			var sums := {}
			for c in per:
				var bi: int = bones[i * per + c]
				var w: float = weights[i * per + c]
				if w > 0.0:
					sums[limbs[bi]] = sums.get(limbs[bi], 0.0) + w
			var own := ""
			var best := -1.0
			for k in sums:
				if sums[k] > best:
					best = sums[k]
					own = k
			var total := 0.0
			var drop := []
			for c in per:
				var bi: int = bones[i * per + c]
				var w: float = weights[i * per + c]
				if w <= 0.0:
					continue
				if _allowed(own, limbs[bi], names[bi], v[i].y):
					total += w
				else:
					drop.append(c)
			if drop.is_empty() or total <= 0.0:
				continue
			for c in drop:
				weights[i * per + c] = 0.0
			for c in per:
				weights[i * per + c] = weights[i * per + c] / total
			fixed += 1
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		# The generated mesh joins the hanging hands to the thighs and the
		# lower arms to the jacket sides: those triangles would stretch
		# into blades whenever an arm lifts, so they go.
		var own_of := []
		own_of.resize(v.size())
		for i in v.size():
			var sums := {}
			for c in per:
				var w: float = weights[i * per + c]
				if w > 0.0:
					var l: String = limbs[bones[i * per + c]]
					sums[l] = sums.get(l, 0.0) + w
			var best := -1.0
			for k in sums:
				if sums[k] > best:
					best = sums[k]
					own_of[i] = k
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var keep := PackedInt32Array()
		var bridges := 0
		for t in range(0, idx.size(), 3):
			var ls := {}
			var low := true
			for k in 3:
				ls[own_of[idx[t + k]]] = true
				if v[idx[t + k]].y > ARMPIT_Y:
					low = false
			var arm := ls.has("LeftArm") or ls.has("RightArm")
			var bridge := arm and ls.size() > 1 and (ls.has("LeftLeg") or ls.has("RightLeg") or (ls.has("LeftArm") and ls.has("RightArm")) or (ls.has("Core") and low))
			if bridge:
				bridges += 1
			else:
				keep.append_array([idx[t], idx[t + 1], idx[t + 2]])
		keep = _drop_strays(keep, v, own_of)
		arrays = _compact(arrays, keep)
		var flags := src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))
		print("  skin weights: separated the limbs on %d vertices, removed %d bridging triangles" % [fixed, bridges])
	mi.mesh = out


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
			if (w_gone[idx[t]] + w_gone[idx[t + 1]] + w_gone[idx[t + 2]]) / 3.0 < 0.25:
				keep.append_array([idx[t], idx[t + 1], idx[t + 2]])
		print("  cut right forearm and hand: %d -> %d triangles" % [idx.size() / 3, keep.size() / 3])
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
