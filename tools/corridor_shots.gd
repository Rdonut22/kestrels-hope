extends SceneTree

## Renders the ship's corridor (the central deck) from player height.
##   godot --path . --script tools/corridor_shots.gd -- <out_dir> [scene]
## scene: res://main.tscn (default, the ship in space) or res://crash_site.tscn.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://corridor_shots"
	var scene: String = args[1] if args.size() > 1 else "res://main.tscn"
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file(scene)
	_run.call_deferred(out)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run(out: String) -> void:
	await _frames(20)
	var scene := current_scene
	var player: Node = scene.get_node_or_null("Player")
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED
	var hud := scene.get_node_or_null("HUD")
	if hud:
		hud.visible = false
	var ship: Node3D = scene.get_node_or_null("ShipInterior")
	if ship == null:
		ship = scene.get_node("Ship/ShipCrashed") if scene.has_node("Ship/ShipCrashed") else scene.get_node("Ship").get_child(0)
	var cam := Camera3D.new()
	cam.fov = 70
	ship.add_child(cam)
	cam.current = true
	# Ship-local views: [name, eye, look-at].
	var views := [["1_fore", Vector3(-0.15, 1.6, 8.0), Vector3(-0.15, 1.3, -5.0)],
		["2_aft", Vector3(-0.15, 1.6, -5.0), Vector3(-0.15, 1.3, 8.0)],
		["3_left_wall", Vector3(1.2, 1.5, 4.5), Vector3(-2.3, 1.2, 1.5)],
		["4_right_wall", Vector3(-1.5, 1.5, 0.0), Vector3(2.0, 1.2, 4.0)],
		["5_cart", Vector3(0.0, 1.3, 3.8), Vector3(1.7, 0.6, 5.3)],
		["6_handrail", Vector3(1.0, 1.4, 3.0), Vector3(-2.3, 0.9, 6.5)],
		["7_rug", Vector3(-1.8, 2.0, -1.4), Vector3(1.0, 0.0, 1.6)],
		["8_entrance", Vector3(-0.15, 1.7, 2.5), Vector3(-0.15, 0.0, 8.5)], ["9_mats", Vector3(-0.15, 1.3, 5.0), Vector3(-0.15, 0.0, 6.6)], ["a_quarters", Vector3(1.3, 1.6, -6.2), Vector3(-2.0, 0.3, -8.8)], ["b_kitchen", Vector3(4.0, 1.6, -3.6), Vector3(3.5, 0.2, -6.5)]]
	for v in views:
		cam.position = v[1]
		cam.look_at(ship.to_global(v[2]))
		await _frames(8)
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(out.path_join(v[0] + ".png"))
	quit()
