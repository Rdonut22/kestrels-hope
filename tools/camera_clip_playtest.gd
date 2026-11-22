extends SceneTree

## Spins the third-person camera all the way round (and up and down) in the
## ship's tightest spots and counts views where a wall (anything solid, or
## any big model) sits between Gana's head and the camera: the camera has
## gone through it.
##   godot --path . --script tools/camera_clip_playtest.gd

const SPOTS := {
	"quarters": Vector3(-0.6, 1.1, -7.6), "quarters_pods": Vector3(-1.9, 1.1, -7.9),
	"bathroom": Vector3(-4.3, 1.1, -3.0), "engineering": Vector3(-4.6, 1.1, 1.6),
	"kitchen": Vector3(4.3, 1.1, -5.0), "passage": Vector3(4.0, 1.1, -8.8),
	"cockpit": Vector3(4.0, 1.1, -11.0), "cockpit_left": Vector3(3.1, 1.1, -10.6),
	"corridor_ramp": Vector3(-0.2, 1.1, 8.3), "gunner": Vector3(-4.8, 1.1, 5.0),
}
var fails := 0


func _initialize() -> void:
	change_scene_to_file("res://main.tscn")
	_run.call_deferred()


func _run() -> void:
	for i in 25:
		await process_frame
	var scene := current_scene
	var player: CharacterBody3D = scene.get_node("Player")
	var ship: Node3D = scene.get_node("ShipInterior")
	var pivot: Node3D = player.get_node("CameraPivot")
	var cam: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")
	var space := player.get_world_3d().direct_space_state
	# Test against what you see, not just what's solid: every visible mesh
	# of the ship gets a throwaway collider on layer 20 (bit 19).
	const SEEN := 1 << 19
	for mi: MeshInstance3D in ship.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null or mi.mesh.get_faces().size() == 0:
			continue
		var gi := mi as GeometryInstance3D
		if gi.transparency > 0.0:
			continue
		var body := StaticBody3D.new()
		body.collision_layer = SEEN
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		var faces := mi.mesh.get_faces()
		var xf := mi.global_transform
		for i in faces.size():
			faces[i] = xf * faces[i]
		shape.set_faces(faces)
		cs.shape = shape
		body.add_child(cs)
		root.add_child(body)
		body.set_meta("mesh", mi)
	for i in 3:
		await physics_frame
	var total := 0
	var bad := 0
	for spot in SPOTS:
		player.global_position = ship.to_global(SPOTS[spot])
		player.velocity = Vector3.ZERO
		for i in 4:
			await physics_frame
		var clipped := 0
		var n := 0
		for pitch in [-40.0, -10.0, 20.0]:
			for k in 24:
				pivot.rotation = Vector3(deg_to_rad(pitch), TAU * k / 24.0, 0)
				await physics_frame
				await process_frame
				var head := pivot.global_position
				var q := PhysicsRayQueryParameters3D.create(head, cam.global_position, SEEN, [player.get_rid()])
				var hit := space.intersect_ray(q)
				if hit:
					clipped += 1
					if OS.get_environment("CLIP_DEBUG") != "":
						var col: Node = hit.collider
						col = col.get_meta("mesh") if col.has_meta("mesh") else col
						print("   hit %s at %.2f m of %.2f (arm %.2f)" % [ship.get_path_to(col), head.distance_to(hit.position),
							head.distance_to(cam.global_position), player.get("spring_arm").get_hit_length()])
				n += 1
		total += n
		bad += clipped
		print("%-14s %2d of %d views through a wall" % [spot, clipped, n])
	print("%s camera clipping: %d of %d views" % ["PASS" if bad == 0 else "FAIL", bad, total])
	print("FAILS: %d" % (0 if bad == 0 else 1))
	quit(1 if bad else 0)
