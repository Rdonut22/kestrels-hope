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
##   godot --path . -s tools/import_gana_meshy.gd -- [source dir] [shoulder drop deg] [output]
## The source GLB/FBX files must be inside the project and imported first
## (copy them to res://character/gana_src/meshy/ and run --import); don't
## commit them.

const OUT := "res://characters/gana/body/gana_body.glb"
const MAIN := "all.glb"
const TEXTURE_SIZE := 1024
## Animation in the main file -> name used by the game.
const RENAME := {"Idle_3": "Idle", "Walking": "Walk", "Quick_Walk": "QuickWalk", "Running": "Run", "Regular_Jump": "Jump",
	"Male_Bend_Over_Pick_Up": "PickUp"}
## Looping animations (the rest play once).
const LOOPS := ["Idle", "Walk", "QuickWalk", "Run"]
## The generated rig holds the shoulders high (a shrug); every animation
## gets each shoulder turned down by this much.
const SHOULDER_DROP_DEG := 16.0
var _drop_deg := SHOULDER_DROP_DEG
## Extra files (any one animation each) -> name.
const EXTRA := {"idle": "Idle", "interact": "Interact"}
const REMOVED_BONES := ["mixamorig_RightHand"]
## Skin colour the generated (pale) skin is shifted to, like the sheet.
const SKIN := Color("A6794A")
## Face landmarks in the rest pose (metres; he faces +Z here): the face's
## middle, and the heights of the chin, mouth, nose and hairline.
const FACE_X := -0.025
const CHIN_Y := 1.432
const MOUTH_Y := 1.468
const BROW_Y := 1.565
const HAIRLINE_Y := 1.6


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "res://character/gana_src/meshy"
	if args.size() > 1:
		_drop_deg = float(args[1])
	var out: String = args[2] if args.size() > 2 else OUT
	var base: Node3D = (load(dir + "/" + MAIN) as PackedScene).instantiate()
	var player: AnimationPlayer = base.find_children("*", "AnimationPlayer", true, false)[0]
	var skel: Skeleton3D = base.find_children("*", "Skeleton3D", true, false)[0]
	var skel_path := String(player.get_node(player.root_node).get_path_to(skel))
	var lib := AnimationLibrary.new()
	for src in RENAME:
		if player.has_animation(src):
			var a := player.get_animation(src).duplicate(true) as Animation
			_strip_root_motion(a)
			_drop_shoulders(a, skel)
			a.loop_mode = Animation.LOOP_LINEAR if RENAME[src] in LOOPS else Animation.LOOP_NONE
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
			_drop_shoulders(a, skel)
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
		_reshape_face(mi)
	base.name = "GanaBody"
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(base, state)
	if err == OK:
		err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(out))
	print("wrote %s: %s" % [out, error_string(err)])
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


## Turns both shoulder bones down by SHOULDER_DROP_DEG in every key (about
## the axis that swings the arm towards the ground at rest), and the upper
## arms back by the same amount.
func _drop_shoulders(a: Animation, skel: Skeleton3D) -> void:
	for side in ["Left", "Right"]:
		var sh := skel.find_bone("mixamorig_%sShoulder" % side)
		var arm := skel.find_bone("mixamorig_%sArm" % side)
		if sh < 0 or arm < 0:
			continue
		var rest := skel.get_bone_global_rest(sh)
		var d := (skel.get_bone_global_rest(arm).origin - rest.origin).normalized()
		var axis := rest.basis.inverse() * Vector3.DOWN.cross(d).normalized()
		var fix := Quaternion(axis.normalized(), deg_to_rad(_drop_deg))
		var path := ":mixamorig_%sShoulder" % side
		var found := false
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_ROTATION_3D and String(a.track_get_path(t)).ends_with(path):
				found = true
				for k in a.track_get_key_count(t):
					a.track_set_key_value(t, k, (a.track_get_key_value(t, k) as Quaternion) * fix)
		if not found:
			continue
		# Counter-turn the upper arm so the arm still hangs the same way:
		# only the shoulder joint drops.
		var arm_path := ":mixamorig_%sArm" % side
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_ROTATION_3D and String(a.track_get_path(t)).ends_with(arm_path):
				for k in a.track_get_key_count(t):
					a.track_set_key_value(t, k, fix.inverse() * (a.track_get_key_value(t, k) as Quaternion))


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
	var albedo := Image.load_from_file(ProjectSettings.globalize_path(stem + "_texture_0.png"))
	albedo.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
	_paint_skin(albedo, mi)
	m.albedo_texture = ImageTexture.create_from_image(albedo)
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


## Moves the face's vertices (GanaEyes.reshape_face). After the painting,
## which places features by the original positions; the paint moves with
## the surface.
func _reshape_face(mi: MeshInstance3D) -> void:
	var src := mi.mesh as ArrayMesh
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var moved := 0
		for i in v.size():
			var q := GanaEyes.reshape_face(v[i])
			if q != v[i]:
				v[i] = q
				moved += 1
		arrays[Mesh.ARRAY_VERTEX] = v
		var flags := src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))
		print("  reshaped the face: %d vertices moved" % moved)
	mi.mesh = out


# ----------------------------------------------------------- face painting

## Repaints the skin on the texture: warmer, deeper skin on the face, neck
## and left forearm/hand, the painted eye blobs covered (the glowing eyes
## are gana_eyes.gd), and soft painted features placed by where each texel
## sits on the face in 3D: mouth, goatee, and shadow under the fringe and
## along the jaw. (No nose, like the sheet.)
func _paint_skin(img: Image, mi: MeshInstance3D) -> void:
	var a := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var w := img.get_width()
	var h := img.get_height()
	var done := {}
	var painted := 0
	for t in range(0, idx.size(), 3):
		var p0 := v[idx[t]]
		var p1 := v[idx[t + 1]]
		var p2 := v[idx[t + 2]]
		var c := (p0 + p1 + p2) / 3.0
		var head := c.y > 1.39 and c.y < 1.7
		var left_arm := c.x > 0.18 and c.y > 0.7 and c.y < 1.2
		if not head and not left_arm:
			continue
		var u0 := uv[idx[t]] * Vector2(w, h)
		var u1 := uv[idx[t + 1]] * Vector2(w, h)
		var u2 := uv[idx[t + 2]] * Vector2(w, h)
		var lo := u0.min(u1).min(u2).floor() - Vector2.ONE
		var hi := u0.max(u1).max(u2).ceil() + Vector2.ONE
		var den := (u1.y - u2.y) * (u0.x - u2.x) + (u2.x - u1.x) * (u0.y - u2.y)
		if absf(den) < 1e-9:
			continue
		for py in range(maxi(int(lo.y), 0), mini(int(hi.y), h - 1) + 1):
			for px in range(maxi(int(lo.x), 0), mini(int(hi.x), w - 1) + 1):
				var q := Vector2(px + 0.5, py + 0.5)
				var b0 := ((u1.y - u2.y) * (q.x - u2.x) + (u2.x - u1.x) * (q.y - u2.y)) / den
				var b1 := ((u2.y - u0.y) * (q.x - u2.x) + (u0.x - u2.x) * (q.y - u2.y)) / den
				var b2 := 1.0 - b0 - b1
				# A little slack so the island edges are covered too.
				if b0 < -0.08 or b1 < -0.08 or b2 < -0.08:
					continue
				var key := py * w + px
				if done.has(key):
					continue
				var col := img.get_pixel(px, py)
				var out: Variant = _skin_texel(col, p0 * b0 + p1 * b1 + p2 * b2, head)
				if out != null:
					img.set_pixel(px, py, out)
					done[key] = true
					painted += 1
	print("  painted %d skin texels" % painted)


## New colour for one texel at 3D point p, or null to leave it.
func _skin_texel(col: Color, p: Vector3, head: bool) -> Variant:
	var bright := (col.r + col.g + col.b) / 3.0
	# The painted eyes (and their soft edges) are covered with skin; the
	# glowing eyes are separate meshes (gana_eyes.gd).
	var eye := head and p.z > 0.08 and _near_eye(p, 0.032)
	var skinlike := col.r > 0.5 and col.r > col.g and col.g > col.b and col.r - col.b > 0.18 and col.r - col.b < 0.45 and bright < 0.8
	if eye:
		return SKIN.darkened(0.04)
	if not skinlike:
		return null
	# Keep the painted light and shade, at the new colour.
	var shade := clampf(bright / 0.54, 0.75, 1.15)
	var out := Color(SKIN.r * shade, SKIN.g * shade, SKIN.b * shade)
	if eye:
		out = SKIN
	if not head:
		return out
	var lx := p.x - FACE_X
	var front := smoothstep(0.07, 0.11, p.z)
	var dark := 0.0
	# Shadow under the fringe, deepening up to the hairline.
	dark = maxf(dark, smoothstep(BROW_Y, HAIRLINE_Y, p.y) * 0.32)
	# Sides of the face and along the jaw.
	dark = maxf(dark, smoothstep(0.045, 0.085, absf(lx)) * 0.2)
	dark = maxf(dark, (1.0 - smoothstep(CHIN_Y, CHIN_Y + 0.03, p.y)) * smoothstep(0.02, 0.05, absf(lx)) * 0.28)
	out = out.darkened(dark)
	# Mouth: a short flat line.
	var my := MOUTH_Y
	var mouth := (1.0 - smoothstep(0.0028, 0.0048, absf(p.y - my))) * (1.0 - smoothstep(0.01, 0.014, absf(lx)))
	out = out.lerp(Color(0.23, 0.13, 0.09), mouth * front * 0.85)
	# Goatee: a tuft on the chin, narrowing downwards.
	var gy := clampf((p.y - (CHIN_Y - 0.004)) / 0.026, 0.0, 1.0)
	var gw := lerpf(0.003, 0.008, gy)
	var goatee := (1.0 - smoothstep(gw, gw + 0.003, absf(lx))) * (1.0 - smoothstep(0.017, 0.024, p.y - CHIN_Y)) * smoothstep(-0.01, -0.002, p.y - CHIN_Y)
	out = out.lerp(Color(0.2, 0.13, 0.09), goatee * front)
	return out


## True within r of one of the painted eyes (positions as gana_eyes.gd).
static func _near_eye(p: Vector3, r: float) -> bool:
	for e in GanaEyes.EYES:
		if p.distance_to(e[0]) < r:
			return true
	return false


## 1 inside an ellipse (radii r), fading to 0 just outside.
static func _ellipse(d: Vector2, r: Vector2) -> float:
	var k := (d / r).length()
	return 1.0 - smoothstep(0.7, 1.15, k)


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
