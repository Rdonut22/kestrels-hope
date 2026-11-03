extends SceneTree

## Measures the cost of the cloud bake: average frame time in the cloud test
## scene with the clouds refreshing normally, and with them switched off.
##   godot --path . -s tools/cloud_bench.gd

func _initialize() -> void:
	change_scene_to_file("res://world/clouds/cloud_test.tscn")
	_run.call_deferred()


func _avg_ms(frames: int) -> float:
	var t := Time.get_ticks_usec()
	for i in frames:
		await process_frame
	return (Time.get_ticks_usec() - t) / 1000.0 / frames


func _run() -> void:
	for i in 10:
		await process_frame
	var c: SkyClouds = current_scene.get_node("SkyClouds")
	for q in [SkyClouds.Quality.LOW, SkyClouds.Quality.MEDIUM, SkyClouds.Quality.HIGH]:
		c.quality = q
		for i in 6:
			await process_frame
		print("quality %d: %.1f ms/frame" % [q, await _avg_ms(40)])
	c.enabled = false
	for i in 4:
		await process_frame
	print("clouds off: %.1f ms/frame" % [await _avg_ms(40)])
	c.queue_free()
	for i in 4:
		await process_frame
	print("no cloud node: %.1f ms/frame" % [await _avg_ms(40)])
	quit()
