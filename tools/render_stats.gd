extends SceneTree

## Renderer statistics for a scene from fixed camera positions: draw calls,
## objects and primitives (triangles) per frame, and video memory. These
## counts don't depend on the GPU; the frame time does (under a software
## renderer it is only useful for comparing runs on the same machine).
## Informational: never fails.
##   godot --path . --script tools/render_stats.gd -- res://crash_site.tscn

const VIEWS := [
	["corridor", Vector3(-0.15, 1.6, 8.0), Vector3(-0.15, 1.3, -5.0)],
	["kitchen", Vector3(3.0, 1.6, -5.0), Vector3(5.6, 1.4, -5.0)],
	["cockpit", Vector3(4.0, 1.6, -9.0), Vector3(4.0, 1.4, -14.0)],
]
const OUTDOOR_VIEWS := [
	["outside_ship", Vector3(16, 2.5, 6), Vector3(4, 1, -2)],
	["forest_far", Vector3(-20, 3, 40), Vector3(60, 5, -60)],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	change_scene_to_file(args[0] if args.size() > 0 else "res://main.tscn")
	_go.call_deferred()


func _view(tag: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var t := Time.get_ticks_usec()
	for i in 10:
		await process_frame
	var ms := (Time.get_ticks_usec() - t) / 10000.0
	print("STAT %-14s draw_calls=%d objects=%d primitives=%d frame_ms=%.0f" % [tag,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), ms])


func _go() -> void:
	for i in 30:
		await process_frame
	var s := current_scene
	if s == null:
		print("STAT unavailable: scene did not load")
		quit()
		return
	print("STAT scene=%s nodes=%d" % [s.scene_file_path, get_node_count()])
	var p := s.find_child("Player", true, false)
	if p:
		p.process_mode = Node.PROCESS_MODE_DISABLED
	var ship: Node3D = s.find_child("ShipInterior", true, false)
	var cam := Camera3D.new()
	s.add_child(cam)
	cam.current = true
	var views: Array = VIEWS.duplicate()
	if s.scene_file_path.contains("crash"):
		views.append_array(OUTDOOR_VIEWS)
	for v in views:
		if ship:
			cam.global_position = ship.global_transform * (v[1] as Vector3)
			cam.look_at(ship.global_transform * (v[2] as Vector3))
		await _view(v[0])
	print("STAT memory video_MB=%.0f texture_MB=%.0f buffer_MB=%.0f" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0])
	quit()
