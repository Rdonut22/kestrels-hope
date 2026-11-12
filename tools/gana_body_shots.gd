extends SceneTree

## Renders the stylized Gana preview: every view at rest, the hand
## close-ups, and frames of walk, run and jump.
##   godot --path . -s tools/gana_body_shots.gd -- <out_dir>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://gana_body_shots"
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(800, 1000)
	var scene: Node3D = (load("res://characters/gana/body/gana_body_preview.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	_go.call_deferred(scene, out)


func _snap(path: String) -> void:
	for f in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func _go(scene: Node3D, out: String) -> void:
	for i in 6:
		await process_frame
	for i in scene.PRESETS.size():
		scene.apply_preset(i)
		await _snap("%s/view_%02d.png" % [out, i + 1])
	scene.apply_preset(0)
	for a in ["Idle", "Walk", "Run", "Jump", "PickUp", "JumpGrab", "ClimbUp"]:
		scene.play(a)
		scene.anim.play(a, 0.0)
		var len: float = scene.anim.get_animation(a).length
		for f in 4:
			scene.anim.seek(len * f / 4.0, true)
			scene.anim.pause()
			await _snap("%s/%s_%d.png" % [out, a.to_lower(), f])
	print("GANA BODY SHOTS DONE")
	quit()
