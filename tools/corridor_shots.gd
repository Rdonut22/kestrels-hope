extends SceneTree

## Renders the ship's corridor (the central deck) from player height.
##   godot --path . --script tools/corridor_shots.gd -- <out_dir> [scene]
## scene: res://main.tscn (default, the ship in space) or res://crash_site.tscn.
## Set POWER=1 in the environment to render with the ship's power restored.

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
	if OS.get_environment("POWER") == "1":
		Game.state().power_restored = true
		await create_timer(4.0).timeout
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
		["8_entrance", Vector3(-0.15, 1.7, 2.5), Vector3(-0.15, 0.0, 8.5)], ["9_mats", Vector3(-0.15, 1.3, 5.0), Vector3(-0.15, 0.0, 6.6)], ["a_quarters", Vector3(1.3, 1.6, -6.2), Vector3(-2.0, 0.3, -8.8)], ["b_kitchen", Vector3(4.0, 1.6, -3.6), Vector3(3.5, 0.2, -6.5)], ["c_ceiling", Vector3(-0.15, 1.5, 7.5), Vector3(-0.15, 3.0, 2.0)], ["d_up", Vector3(-0.15, 1.8, 4.3), Vector3(-0.1, 3.0, 4.31)], ["e_sconce", Vector3(-1.2, 1.85, 2.2), Vector3(-2.2, 1.93, 2.72)], ["f_sconces", Vector3(0.5, 1.6, -3.5), Vector3(-0.3, 1.5, 3.0)],
		["g_engineering", Vector3(1.2, 1.6, 3.6), Vector3(-2.3, 1.1, 1.0)], ["h_fore", Vector3(0.3, 1.7, 3.6), Vector3(-0.3, 1.1, -3.5)],
		["i_from_fore", Vector3(-0.3, 1.6, -4.4), Vector3(-0.1, 1.1, 1.0)], ["j_eng_inside", Vector3(-5.2, 1.5, 2.6), Vector3(-2.3, 1.0, 0.8)],
		["k_eng_close", Vector3(0.6, 1.4, 1.1), Vector3(-2.4, 1.1, 1.1)], ["l_bulk_close", Vector3(0.4, 1.3, 1.0), Vector3(-0.2, 1.2, -1.4)],
		["m_board", Vector3(0.1, 1.55, 1.3), Vector3(1.4, 1.5, -1.2)], ["n_board_up", Vector3(0.6, 1.2, 0.2), Vector3(1.4, 2.7, -1.2)],
		["o_cockpit", Vector3(4.0, 1.65, -8.6), Vector3(4.0, 1.2, -13.0)], ["p_cockpit_side", Vector3(5.0, 1.6, -12.4), Vector3(2.6, 1.4, -10.0)],
		["q_cockpit_up", Vector3(4.0, 1.2, -11.0), Vector3(3.0, 2.6, -11.8)]]
	# VIEWS=g,h renders only the views whose names start with those letters.
	var only := OS.get_environment("VIEWS").split(",", false)
	for v in views:
		if not only.is_empty() and not (v[0] as String).substr(0, 1) in only:
			continue
		cam.position = v[1]
		cam.look_at(ship.to_global(v[2]))
		await _frames(8)
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(out.path_join(v[0] + ".png"))
	quit()
