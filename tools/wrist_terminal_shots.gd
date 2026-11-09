extends SceneTree

## Renders the wrist terminal preview from each preset view.
##   godot --path . -s tools/wrist_terminal_shots.gd -- <out_dir> [port_open]
## (Run with a display or under xvfb-run, not --headless.)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://wrist_terminal_shots"
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 960)
	var scene: Node3D = (load("res://characters/gana/wrist_terminal/wrist_terminal_preview.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	_go.call_deferred(scene, out)


func _go(scene: Node3D, out: String) -> void:
	for i in 5:
		await process_frame
	var term := scene.get_node("WristTerminal")
	for i in scene.PRESETS.size():
		term.port_cover_open = 1.0 if i == 5 else 0.0
		scene.apply_preset(i)
		for f in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%02d.png" % [out, i + 1])
	print("WRIST SHOTS DONE")
	quit()
