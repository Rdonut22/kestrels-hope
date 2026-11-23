extends SceneTree

## Checks the greenhouse interior's collision (world/greenhouse.gd): the
## ground floor and the open hole, a continuous walkable ramp up the stairs,
## nothing in the way along the stairs at body height, the walkway round
## the hole, and the railings at its edge. Then walks Gana up the stairs.
##   godot --path . -s tools/greenhouse_walk_check.gd

var fails := 0


func _check(c: bool, w: String) -> void:
	print(("PASS " if c else "FAIL ") + w)
	if not c:
		fails += 1


func _initialize() -> void:
	change_scene_to_file("res://crash_site.tscn")
	_run.call_deferred()


func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, exclude := []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = exclude
	return space.intersect_ray(q)


func _run() -> void:
	for i in 10:
		await physics_frame
	var scene := current_scene
	var gh := scene.get_node("CrashSite/Ruins/Greenhouse")
	var inner := gh.get_node("Interior") as Node3D
	var L: Dictionary = gh.get("_L")
	var space := inner.get_world_3d().direct_space_state
	var player: CharacterBody3D = scene.get_node("Player")
	var ex := [player.get_rid()]
	var to_w := func(p: Vector3) -> Vector3: return inner.to_global(p)
	var floor_y: float = L["floor_y"]
	# Ground floor and the hole above it.
	# (Sampled all over: the inner arcade's arches and rib stumps below the
	# cut catch the odd ray.)
	var h: Dictionary
	var through := 0
	var rays := 0
	for r in [2.0, 9.5, 12.0, 15.0]:   # (the inner arcade stands at 4.5-7.5 m)
		for k in 24:
			var a := TAU * k / 24.0
			h = _ray(space, to_w.call(Vector3(r * cos(a), 30, r * sin(a))), to_w.call(Vector3(r * cos(a), -2, r * sin(a))), ex)
			rays += 1
			if h and absf(inner.to_local(h["position"]).y - floor_y) < 0.8:
				through += 1
	_check(through >= rays * 0.9, "down through the hole to the ground floor (%d of %d rays)" % [through, rays])
	# Walkway.
	var ok := 0
	var tot := 0
	var n0: float = L["notch"]["from"]
	var n1: float = L["notch"]["to"]
	for k in 36:
		var a := TAU * k / 36.0
		var am := fposmod(a, TAU)
		if am > fposmod(n0, TAU) - 0.05 and am < fposmod(n1, TAU) + 0.05:
			continue
		tot += 1
		var p := Vector3(19.5 * cos(a), 25, 19.5 * sin(a))
		h = _ray(space, to_w.call(p), to_w.call(p - Vector3(0, 12, 0)), ex)
		if h and absf(inner.to_local(h["position"]).y - 18.05) < 0.9:
			ok += 1
	_check(ok >= tot - 2, "the walkway is walkable all round (%d of %d)" % [ok, tot])
	# Stairs: continuous ramp, rising steadily, and clear at body height.
	var s: Dictionary = L["stair"]
	var a0: float = s["start"]
	var a1: float = s["end"]
	var rm: float = float(s["r_outer"]) - float(s["width"]) * 0.5
	var bad := 0
	var blocked := 0
	var last := -1.0
	for i in 60:
		var a := lerpf(a0, a1, (i + 0.5) / 60.0)
		var p := Vector3(rm * cos(a), 40, rm * sin(a))
		var expect := lerpf(float(s["y0"]), float(s["y1"]), (i + 0.5) / 60.0)
		h = _ray(space, to_w.call(Vector3(p.x, expect + 1.0, p.z)), to_w.call(Vector3(p.x, expect - 1.0, p.z)), ex)
		var got: float = inner.to_local(h["position"]).y if h else -99.0
		if absf(got - expect) > 0.6:
			bad += 1
		# Body height, along the flight to the next sample.
		var a2 := lerpf(a0, a1, (i + 1.5) / 60.0)
		var e2 := lerpf(float(s["y0"]), float(s["y1"]), (i + 1.5) / 60.0)
		for dh in [0.5, 1.2, 1.8]:
			var c1 := Vector3(rm * cos(a), expect + dh, rm * sin(a))
			var c2 := Vector3(rm * cos(a2), e2 + dh, rm * sin(a2))
			if i < 59 and _ray(space, to_w.call(c1), to_w.call(c2), ex):
				blocked += 1
	_check(bad == 0, "a continuous ramp under the steps (%d of 60 samples off)" % bad)
	_check(blocked == 0, "nothing in the way up the stairs at body height (%d hits)" % blocked)
	# Railing round the hole.
	var a := fposmod(n1 + 0.6, TAU)
	h = _ray(space, to_w.call(Vector3(18.5 * cos(a), 18.6, 18.5 * sin(a))), to_w.call(Vector3(14.0 * cos(a), 18.6, 14.0 * sin(a))), ex)
	_check(not h.is_empty(), "the railing stops a walk off the walkway into the hole")
	# Walk Gana up: put him at the foot of the stairs and steer him along
	# the flight.
	player.global_position = to_w.call(Vector3(rm * cos(a0 - 0.05), floor_y + 1.1, rm * sin(a0 - 0.05)))
	var top_y := -99.0
	for f in 60 * 40:
		var lp: Vector3 = inner.to_local(player.global_position)
		var ang := atan2(lp.z, lp.x)
		if ang < 0.0:
			ang += TAU
		# Tangent (anticlockwise) plus a pull back to the middle radius.
		var r := Vector2(lp.x, lp.z).length()
		var tdir := Vector3(-sin(ang), 0, cos(ang)) + Vector3(cos(ang), 0, sin(ang)) * clampf((rm - r) * 0.8, -0.5, 0.5)
		var wdir: Vector3 = (inner.global_basis * tdir)
		wdir.y = 0
		player.velocity.x = wdir.normalized().x * 4.0
		player.velocity.z = wdir.normalized().z * 4.0
		player.velocity.y -= 9.8 / 60.0
		player.move_and_slide()
		await physics_frame
		top_y = maxf(top_y, inner.to_local(player.global_position).y)
		if ang > a1 + 0.02:
			break
	_check(top_y > 18.0, "Gana walks up the stairs to the walkway (highest %.1f m)" % top_y)
	print("FAILS: %d" % fails)
	quit(1 if fails else 0)
