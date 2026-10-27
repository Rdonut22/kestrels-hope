extends SceneTree
var fails := 0
var steps := 0
var played := 0
func _check(c: bool, w: String) -> void:
	print(("PASS " if c else "FAIL ") + w)
	if not c: fails += 1
func _initialize() -> void:
	change_scene_to_file("res://crash_site.tscn")
	_run.call_deferred()
func _walk(secs: float) -> void:
	Input.action_press("move_forward")
	for i in int(secs * 60): await physics_frame
	Input.action_release("move_forward")
	for i in 10: await physics_frame
func _run() -> void:
	for i in 40: await physics_frame
	var player: CharacterBody3D = current_scene.get_node("Player")
	var ship: Node3D = current_scene.get_node("Ship")
	player.mesh.footstep.connect(func(): steps += 1)
	player._steps.finished.connect(func(): pass)
	var orig: Callable = player._on_footstep
	player.mesh.footstep.connect(func():
		if player._steps.has_stream_playback(): played += 1)
	# Inside the ship (metal floor): footsteps detected, no grass sound.
	player.global_position = ship.to_global(Vector3(-0.15, 1.1, 6.0))
	player.pivot.rotation.y = 0.0
	await _walk(2.0)
	var inside_steps := steps
	var inside_played := played
	_check(inside_steps >= 4, "footsteps detected while running inside (%d)" % inside_steps)
	_check(inside_played == 0, "no grass sound on the ship floor")
	# Outside on grass.
	steps = 0
	played = 0
	player.global_position = Vector3(18, 1.0, 2)
	player.pivot.rotation.y = -PI / 2
	await _walk(3.0)
	_check(steps >= 6, "footsteps detected outside (%d)" % steps)
	_check(played >= steps - 1, "grass sound plays on each step (%d of %d)" % [played, steps])
	print("FAILS: ", fails)
	quit()
