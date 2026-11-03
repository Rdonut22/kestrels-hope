extends SceneTree

## Renders world/clouds/cloud_test.tscn from a few views and times of day.
## Run without --headless under xvfb-run:
##   godot --path . -s tools/cloud_shots.gd -- <out_dir> [views] [hours]
## views: comma list of azimuth:pitch (degrees), hours: comma list.

var out := "user://cloud_shots/"
var views := ["15:14", "70:12", "150:10", "-110:12"]
var hours := ["11"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		views = Array(args[1].split(","))
	if args.size() > 2:
		hours = Array(args[2].split(","))
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://world/clouds/cloud_test.tscn")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(3)
	var scene := current_scene
	var clock: Node = scene.get_node("DayNight")
	var clouds: SkyClouds = scene.get_node("SkyClouds")
	var cam: Camera3D = scene.get_node("Camera3D")
	clock.set_process(false)
	for h in hours:
		clock.set_hour(float(h))
		clouds.redraw()
		var t0 := Time.get_ticks_msec()
		await _frames(4)
		print("bake + frames ms: ", Time.get_ticks_msec() - t0)
		var pano: SubViewport = clouds.get_node("CloudPanorama0")
		pano.get_texture().get_image().save_png(out.path_join("pano_h%s.png" % h))
		for v in views:
			var p: PackedStringArray = v.split(":")
			cam.rotation = Vector3(deg_to_rad(float(p[1])), -deg_to_rad(float(p[0])), 0.0)
			await _frames(2)
			var t := Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			print("frame us ", Time.get_ticks_usec() - t)
			get_root().get_texture().get_image().save_png(out.path_join("h%s_az%s_p%s.png" % [h, p[0], p[1]]))
	quit()
