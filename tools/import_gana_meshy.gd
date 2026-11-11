extends SceneTree

## Builds characters/gana/body/gana_body.glb (the stylized Gana, generated
## and rigged in Meshy) from the downloaded GLB, keeping its mesh, rig and
## animations as they are:
## - textures resized to TEXTURE_SIZE,
## - animations renamed for the game (RENAME), any forward root motion
##   stripped,
## - the skin recoloured to SKIN (the generated skin came out pale).
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
