extends SceneTree

var mats := {}
var scene_root: Node
var crashed := false


func _init() -> void:
	_make_materials()
	_build_hud()
	_build_ship()
	crashed = true
	_build_ship()
	crashed = false
	_build_character()
	_update_main()
	_build_crash_site()
	print("BUILD DONE")
	quit()


# ---------- materials ----------

func _mat(name: String, color: Color, rough := 0.8, metal := 0.0, emit := 0.0, alpha := 1.0) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = alpha
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var path := "res://ship/materials/%s.tres" % name
	ResourceSaver.save(m, path)
	m.take_over_path(path)
	mats[name] = m


func _shader_mat(name: String, shader: String, params: Dictionary) -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://ship/%s.gdshader" % shader)
	for key in params:
		m.set_shader_parameter(key, params[key])
	var path := "res://ship/materials/%s.tres" % name
	ResourceSaver.save(m, path)
	m.take_over_path(path)
	mats[name] = m


# Palette: blue-grey painted metal, gunmetal floors, cream seats,
# worn leather, copper pipes, cool strip lights with warm accents.
func _make_materials() -> void:
	_shader_mat("hull_outer", "worn", {"base_color": Color(0.66, 0.65, 0.62), "chip_color": Color(0.3, 0.29, 0.28),
		"grime": 0.55, "chips": 0.35, "scratches": 0.6, "fade": 0.4, "noise_scale": 1.6,
		"metallic_amount": 0.55, "roughness_amount": 0.5})
	_mat("stripe", Color(0.66, 0.3, 0.14), 0.6, 0.2)
	_mat("thruster_glow", Color(0.35, 0.7, 1.0), 0.3, 0.0, 5.0)
	_shader_mat("wall", "hull_panel", {"base_color": Color(0.46, 0.51, 0.56), "lower_band": 0.9,
		"lower_color": Color(0.3, 0.32, 0.34), "panel_size": Vector2(1.2, 0.9)})
	_shader_mat("floor", "hull_panel", {"base_color": Color(0.64, 0.59, 0.49), "panel_size": Vector2(1.6, 1.2),
		"seam_dark": 0.45, "seam_width": 0.025, "grime": 0.4, "variation": 0.06, "rivets": 0.0,
		"metallic_amount": 0.15, "roughness_amount": 0.7})
	_shader_mat("ceiling", "hull_panel", {"base_color": Color(0.32, 0.35, 0.39), "panel_size": Vector2(1.6, 1.0),
		"rivets": 0.0, "grime": 0.25})
	_shader_mat("grate", "grate", {})
	_mat("trim", Color(0.29, 0.31, 0.34), 0.5, 0.6)
	_mat("rib", Color(0.22, 0.24, 0.26), 0.45, 0.7)
	_shader_mat("gunmetal", "hull_panel", {"base_color": Color(0.3, 0.31, 0.33), "lower_band": 0.0,
		"panel_size": Vector2(0.9, 0.6), "seam_dark": 0.4, "grime": 0.45, "variation": 0.1,
		"metallic_amount": 0.6, "roughness_amount": 0.45})
	_shader_mat("couch_leather", "worn", {"base_color": Color(0.74, 0.7, 0.62), "grime": 0.35, "chips": 0.0,
		"scratches": 0.15, "fade": 0.5, "noise_scale": 3.0, "roughness_amount": 0.5, "metallic_amount": 0.0})
	_shader_mat("couch_seam", "worn", {"base_color": Color(0.5, 0.45, 0.38), "grime": 0.5, "chips": 0.0,
		"scratches": 0.1, "fade": 0.3, "noise_scale": 3.0, "roughness_amount": 0.6, "metallic_amount": 0.0})
	_mat("pillow_rust", Color(0.62, 0.3, 0.18), 0.95)
	_mat("pillow_teal", Color(0.22, 0.4, 0.42), 0.95)
	_mat("pillow_cream", Color(0.82, 0.76, 0.64), 0.95)
	_mat("warm_tube", Color(1.0, 0.82, 0.6), 0.4, 0.0, 2.2)
	_mat("panel_led", Color(0.35, 0.8, 1.0), 0.3, 0.0, 2.5)
	_mat("panel_led_red", Color(1.0, 0.25, 0.2), 0.3, 0.0, 2.5)
	_shader_mat("leather_pad", "worn", {"base_color": Color(0.76, 0.63, 0.46), "grime": 0.35, "chips": 0.0,
		"scratches": 0.25, "fade": 0.5, "noise_scale": 4.0, "roughness_amount": 0.55, "metallic_amount": 0.0})
	_shader_mat("exhaust", "worn", {"base_color": Color(0.58, 0.52, 0.47), "chip_color": Color(0.42, 0.22, 0.12),
		"grime": 0.5, "chips": 0.45, "scratches": 0.3, "roughness_amount": 0.55, "metallic_amount": 0.4})
	_mat("canopy_frame", Color(0.42, 0.44, 0.47), 0.35, 0.65)
	mats["canopy_frame"].cull_mode = BaseMaterial3D.CULL_DISABLED
	ResourceSaver.save(mats["canopy_frame"], "res://ship/materials/canopy_frame.tres")
	_mat("metal_dark", Color(0.16, 0.17, 0.18), 0.5, 0.6)
	_mat("counter", Color(0.74, 0.72, 0.66), 0.45, 0.1)
	_mat("seat", Color(0.8, 0.77, 0.69), 0.6)
	_shader_mat("seat_shell", "worn", {"base_color": Color(0.7, 0.69, 0.65), "grime": 0.4, "chips": 0.55,
		"scratches": 0.5, "roughness_amount": 0.5, "metallic_amount": 0.2})
	_shader_mat("seat_pad", "worn", {"base_color": Color(0.3, 0.33, 0.37), "grime": 0.5, "chips": 0.0,
		"scratches": 0.0, "fade": 0.6, "noise_scale": 5.0, "roughness_amount": 0.95, "metallic_amount": 0.0})
	_shader_mat("harness", "worn", {"base_color": Color(0.24, 0.25, 0.27), "grime": 0.4, "chips": 0.0,
		"scratches": 0.0, "fade": 0.5, "roughness_amount": 0.9, "metallic_amount": 0.0})
	_mat("leather", Color(0.36, 0.22, 0.13), 0.55)
	_mat("blanket", Color(0.33, 0.37, 0.42), 1.0)
	_mat("crate", Color(0.55, 0.5, 0.39), 0.85)
	_mat("barrel", Color(0.42, 0.4, 0.36), 0.6, 0.4)
	var door := StandardMaterial3D.new()
	door.albedo_texture = load("res://ship/models/door/door_albedo.jpg")
	door.normal_enabled = true
	door.normal_texture = load("res://ship/models/door/door_normal.jpg")
	door.ao_enabled = true
	door.ao_texture = load("res://ship/models/door/door_ao.jpg")
	door.metallic = 0.8
	door.metallic_texture = load("res://ship/models/door/door_scratches.jpg")
	door.roughness = 0.5
	ResourceSaver.save(door, "res://ship/materials/door.tres")
	door.take_over_path("res://ship/materials/door.tres")
	mats["door"] = door
	_shader_mat("hose", "hose", {})
	_mat("wood", Color(0.36, 0.23, 0.14), 0.75)
	_shader_mat("crate", "worn", {"base_color": Color(0.8, 0.78, 0.71), "grime": 0.75, "chips": 0.15,
		"scratches": 0.45, "fade": 0.3, "noise_scale": 2.5, "roughness_amount": 0.7, "metallic_amount": 0.0})
	_shader_mat("pad_frame", "worn", {"base_color": Color(0.5, 0.47, 0.41), "grime": 0.6, "chips": 0.1,
		"scratches": 0.3, "fade": 0.3, "noise_scale": 2.0, "roughness_amount": 0.6, "metallic_amount": 0.2})
	_mat("tie", Color(0.86, 0.85, 0.8), 0.55)
	_mat("hazard", Color(0.78, 0.42, 0.12), 0.6, 0.2)
	_mat("copper", Color(0.62, 0.33, 0.18), 0.4, 0.85)
	_mat("cable", Color(0.06, 0.06, 0.06), 0.7)
	_mat("glass", Color(0.6, 0.8, 1.0), 0.05, 0.0, 0.0, 0.12)
	_mat("fixture", Color(1.0, 0.86, 0.68), 0.5, 0.0, 1.1)
	_mat("led_strip", Color(0.85, 0.88, 0.95), 0.5, 0.0, 1.1)
	_mat("fixture_warm", Color(1.0, 0.6, 0.25), 0.5, 0.0, 1.4)
	_mat("screen_cyan", Color(0.1, 0.55, 0.9), 0.3, 0.0, 1.2)
	_mat("screen_amber", Color(1.0, 0.6, 0.15), 0.3, 0.0, 1.2)
	_mat("reactor_core", Color(0.3, 0.7, 1.0), 0.3, 0.0, 4.0)


# ---------- helpers ----------

func _own(n: Node) -> Node:
	n.owner = scene_root
	return n


func _add(parent: Node, n: Node, name: String) -> Node:
	n.name = name
	parent.add_child(n)
	return _own(n)


# CSG box from min/max corners.
func _box(parent: Node, name: String, a: Vector3, b: Vector3, mat: String, sub := false) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.position = (a + b) / 2.0
	box.size = (b - a).abs()
	box.material = mats[mat]
	if sub:
		box.operation = CSGShape3D.OPERATION_SUBTRACTION
	return _add(parent, box, name)


func _room(hull: Node, name: String, x0: float, x1: float, z0: float, z1: float, h := 3.0) -> void:
	_box(hull, name, Vector3(x0, 0, z0), Vector3(x1, h, z1), "wall", true)


func _mesh_box(parent: Node, name: String, pos: Vector3, size: Vector3, mat: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mats[mat]
	mi.position = pos
	return _add(parent, mi, name)


func _light(parent: Node, name: String, pos: Vector3, color: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy * 0.55
	l.omni_range = rng * 1.25
	l.omni_attenuation = 0.6
	_add(parent, l, name)
	var warm := color.r > color.b * 1.5
	_mesh_box(l, "Fixture", Vector3(0, 0.2, 0), Vector3(0.2, 0.05, 1.6), "fixture_warm" if warm else "fixture")


func _glass(parent: Node, name: String, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	_add(parent, body, name)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	_add(body, cs, "CollisionShape3D")
	var pane := _mesh_box(body, "Pane", Vector3.ZERO, size, "glass")
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _interactable(parent: Node, name: String, script: String, pos: Vector3, props := {}) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.set_script(load("res://interactables/%s.gd" % script))
	for key in props:
		n.set(key, props[key])
	return _add(parent, n, name)


func _inspect(parent: Node, name: String, pos: Vector3, prompt: String, message: String, rng := 1.8) -> void:
	_interactable(parent, name, "inspect", pos, {"prompt": prompt, "message": message, "interact_range": rng})


# Places where Gana thinks out loud the first time he walks in.
func _thought_zones() -> void:
	var zones := _add(scene_root, Node3D.new(), "ThoughtZones")
	var add := func(name: String, centre: Vector3, size: Vector3, lines: Array, when := "any") -> void:
		var z := Area3D.new()
		z.set_script(load("res://world/thought_zone.gd"))
		z.position = centre
		z.set("lines", "|".join(lines))
		z.set("flag", "zone_" + name.to_snake_case())
		z.set("when", when)
		_add(zones, z, name)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		_add(z, cs, "Shape")
	add.call("LeavingCockpit", Vector3(4.0, 1.0, -6.0), Vector3(3.0, 2.0, 1.2), [
		"Forty-three days since the pirates hit us.",
		"Twenty minutes. That's all it took. Then nothing but the hum."])
	add.call("Quarters", Vector3(-0.4, 1.0, -7.9), Vector3(4.0, 2.0, 3.2), [
		"Hale's bunk. Still made. Never could bring myself to strip it.",
		"When they boarded, he went aft to lock down engineering. Told me to stay at the helm.",
		"By the time I got back there, the airlock had cycled.",
		"No body. No message. He was just... gone."])
	add.call("HalesLocker", Vector3(1.15, 1.0, -6.35), Vector3(1.2, 2.0, 0.9), [
		"His locker's still pried open.",
		"They went through Hale's things... and nothing else on the whole ship."])
	add.call("CargoCrates", Vector3(1.0, 1.0, 6.05), Vector3(1.6, 2.0, 1.4), [
		"Every crate still sealed. Six months of ore, right where we left it.",
		"What kind of pirates leave the cargo?"])
	add.call("Engineering", Vector3(-4.4, 1.0, 1.0), Vector3(3.4, 2.0, 4.2), [
		"Meki. Right where I left him on the bench.",
		"I gave up on you weeks ago, buddy. Nothing I tried would take.",
		"...I'm out of options now. One more try."], "meki_dead")


# Like _inspect, but Gana thinks the lines out loud.
func _thought(parent: Node, name: String, pos: Vector3, prompt: String, lines: Array, rng := 1.6) -> void:
	_interactable(parent, name, "inspect", pos, {"prompt": prompt, "message": "|".join(lines), "interact_range": rng, "thought": true})


# ---------- ship ----------


func _sp(parent: Node, name: String, mesh: Mesh, mat: String, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mats[mat]
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	return _add(parent, mi, name)


func _sbox(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m


func _scyl(r: float, h: float, sides := 16) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	return m


# Detailed cockpit seat, facing -Z, origin on the floor. Built once and
# instanced for the pilot, copilot and gunner.
func _build_seat() -> void:
	scene_root = Node3D.new()
	scene_root.name = "Seat"
	var R := scene_root
	const AX_Z := Vector3(PI / 2, 0, 0)
	const AX_X := Vector3(0, 0, PI / 2)

	var body := StaticBody3D.new()
	_add(R, body, "Collision")
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.68, 1.25, 0.72)
	cs.shape = shape
	cs.position = Vector3(0, 0.625, 0.02)
	_add(body, cs, "Shape")

	# Floor mount: plate, rails, pedestal, gas pistons, adjust lever.
	_sp(R, "BasePlate", _sbox(0.56, 0.03, 0.72), "metal_dark", Vector3(0, 0.015, 0.02))
	for x in [-0.2, 0.2]:
		_sp(R, "Rail%d" % int(x * 10), _sbox(0.05, 0.035, 0.72), "rib", Vector3(x, 0.045, 0.02))
		for z in [-0.28, 0.32]:
			_sp(R, "RailBolt%d%d" % [int(x * 10), int(z * 10)], _scyl(0.015, 0.02, 8), "seat_shell", Vector3(x, 0.07, z))
	_sp(R, "Pedestal", _sbox(0.22, 0.27, 0.26), "metal_dark", Vector3(0, 0.2, 0.04))
	_sp(R, "PedestalCollar", _sbox(0.26, 0.04, 0.3), "rib", Vector3(0, 0.08, 0.04))
	for x in [-0.14, 0.14]:
		_sp(R, "Piston%d" % int(x * 100), _scyl(0.022, 0.24, 10), "copper", Vector3(x, 0.19, 0.13), Vector3(-0.25, 0, 0))
		_sp(R, "PistonRod%d" % int(x * 100), _scyl(0.012, 0.1, 8), "seat_shell", Vector3(x, 0.3, 0.1), Vector3(-0.25, 0, 0))
	_sp(R, "AdjustLever", _sbox(0.025, 0.02, 0.2), "metal_dark", Vector3(0.23, 0.29, -0.14))
	_sp(R, "AdjustKnob", _scyl(0.02, 0.05, 8), "hazard", Vector3(0.23, 0.29, -0.25), AX_Z)

	# Seat pan.
	_sp(R, "PanFrame", _sbox(0.54, 0.06, 0.56), "seat_shell", Vector3(0, 0.36, -0.02))
	_sp(R, "PanCushion", _sbox(0.44, 0.08, 0.48), "seat_pad", Vector3(0, 0.43, -0.04))
	_sp(R, "PanFrontRoll", _scyl(0.045, 0.44, 12), "seat_pad", Vector3(0, 0.425, -0.285), AX_X)
	for z in [-0.14, 0.04]:
		_sp(R, "PanSeam%d" % int(z * 100), _sbox(0.445, 0.006, 0.01), "harness", Vector3(0, 0.472, z))
	for x in [-0.25, 0.25]:
		_sp(R, "PanBolster%d" % int(x * 10), _sbox(0.06, 0.09, 0.52), "seat_shell", Vector3(x, 0.44, -0.03))
	_sp(R, "Buckle", _sbox(0.09, 0.05, 0.025), "copper", Vector3(0, 0.49, -0.17))
	_sp(R, "LapStrapL", _sbox(0.2, 0.01, 0.05), "harness", Vector3(-0.13, 0.475, -0.12), Vector3(0, 0.5, 0))
	_sp(R, "LapStrapR", _sbox(0.2, 0.01, 0.05), "harness", Vector3(0.13, 0.475, -0.12), Vector3(0, -0.5, 0))

	# Armrests: right has a throttle grip, left a small button panel.
	for x in [-0.31, 0.31]:
		var t := "%d" % int(x * 10)
		_sp(R, "ArmPost" + t, _sbox(0.04, 0.2, 0.05), "metal_dark", Vector3(x, 0.5, 0.1))
		_sp(R, "ArmBar" + t, _sbox(0.05, 0.035, 0.36), "metal_dark", Vector3(x, 0.6, -0.02))
		_sp(R, "ArmPad" + t, _sbox(0.075, 0.045, 0.3), "seat_pad", Vector3(x, 0.638, 0.0))
	_sp(R, "ThrottleBase", _sbox(0.06, 0.03, 0.08), "metal_dark", Vector3(0.31, 0.63, -0.17))
	_sp(R, "ThrottleStick", _scyl(0.016, 0.1, 8), "rib", Vector3(0.31, 0.69, -0.17))
	_sp(R, "ThrottleGrip", _scyl(0.028, 0.06, 10), "harness", Vector3(0.31, 0.76, -0.17))
	_sp(R, "ArmButtons", _sbox(0.05, 0.008, 0.08), "screen_amber", Vector3(-0.31, 0.664, -0.12))

	# Backrest, leaned back.
	var back := Node3D.new()
	back.position = Vector3(0, 0.4, 0.24)
	back.rotation.x = 0.18
	_add(R, back, "Back")
	_sp(back, "Shell", _sbox(0.54, 0.7, 0.1), "seat_shell", Vector3(0, 0.4, 0.03))
	_sp(back, "ShellTop", _scyl(0.27, 0.1, 24), "seat_shell", Vector3(0, 0.75, 0.03), AX_Z, Vector3(1, 1, 0.38))
	for x in [-0.265, 0.265]:
		var t := "%d" % int(x * 100)
		_sp(back, "Wing" + t, _sbox(0.07, 0.58, 0.15), "seat_shell", Vector3(x, 0.36, -0.03), Vector3(0, -0.25 * signf(x), 0))
		_sp(back, "WingPad" + t, _sbox(0.03, 0.5, 0.1), "seat_pad", Vector3(x * 0.9, 0.36, -0.08), Vector3(0, -0.25 * signf(x), 0))
	for i in 3:
		_sp(back, "BackPad%d" % i, _sbox(0.4, 0.17, 0.05), "seat_pad", Vector3(0, 0.18 + i * 0.19, -0.045))
	# Headrest on two posts.
	for x in [-0.1, 0.1]:
		_sp(back, "HeadPost%d" % int(x * 10), _scyl(0.014, 0.14, 8), "rib", Vector3(x, 0.86, 0.02))
	_sp(back, "Headrest", _sbox(0.34, 0.18, 0.1), "seat_shell", Vector3(0, 0.98, 0.0))
	_sp(back, "HeadrestTop", _scyl(0.17, 0.1, 20), "seat_shell", Vector3(0, 1.07, 0.0), AX_Z, Vector3(1, 1, 0.32))
	_sp(back, "HeadPad", _sbox(0.28, 0.15, 0.04), "seat_pad", Vector3(0, 0.99, -0.065))
	# Harness shoulder straps over the top.
	for x in [-0.11, 0.11]:
		_sp(back, "Strap%d" % int(x * 100), _sbox(0.05, 0.6, 0.012), "harness", Vector3(x, 0.42, -0.077))
		_sp(back, "StrapOver%d" % int(x * 100), _sbox(0.05, 0.012, 0.14), "harness", Vector3(x, 0.74, 0.02))
		_sp(back, "StrapGuide%d" % int(x * 100), _sbox(0.07, 0.03, 0.03), "metal_dark", Vector3(x, 0.74, 0.09))
	# Rear: recessed panel, struts, lumbar box with vents, dial, handle, bolts.
	_sp(back, "RearPanel", _sbox(0.42, 0.54, 0.02), "metal_dark", Vector3(0, 0.38, 0.085))
	for x in [-0.13, 0.13]:
		_sp(back, "Strut%d" % int(x * 100), _sbox(0.035, 0.58, 0.03), "rib", Vector3(x, 0.38, 0.1))
	_sp(back, "CrossBar", _sbox(0.44, 0.035, 0.03), "rib", Vector3(0, 0.64, 0.1))
	_sp(back, "LumbarBox", _sbox(0.2, 0.15, 0.06), "seat_shell", Vector3(0, 0.24, 0.12))
	for i in 3:
		_sp(back, "Vent%d" % i, _sbox(0.14, 0.01, 0.006), "harness", Vector3(0, 0.2 + i * 0.035, 0.152))
	_sp(back, "Dial", _scyl(0.045, 0.03, 16), "metal_dark", Vector3(0.17, 0.72, 0.1), AX_Z)
	_sp(back, "DialCap", _scyl(0.026, 0.04, 12), "seat_shell", Vector3(0.17, 0.72, 0.11), AX_Z)
	_sp(back, "DialMark", _sbox(0.006, 0.02, 0.005), "hazard", Vector3(0.17, 0.735, 0.132))
	_sp(back, "Handle", _sbox(0.22, 0.025, 0.025), "rib", Vector3(0, 0.84, 0.13))
	for x in [-0.1, 0.1]:
		_sp(back, "HandlePost%d" % int(x * 10), _sbox(0.02, 0.02, 0.06), "rib", Vector3(x, 0.84, 0.1))
	for v in [Vector2(-0.19, 0.12), Vector2(0.19, 0.12), Vector2(-0.19, 0.62), Vector2(0.19, 0.62)]:
		_sp(back, "Bolt%d%d" % [int(v.x * 100), int(v.y * 100)], _scyl(0.012, 0.015, 8), "seat_shell", Vector3(v.x, v.y, 0.1), AX_Z)
	_sp(back, "WarningTag", _sbox(0.08, 0.03, 0.004), "hazard", Vector3(-0.15, 0.5, 0.098))
	_pipe(back, "CableA", Vector3(0.07, 0.18, 0.13), Vector3(0.12, -0.2, 0.05), 0.012, "cable")
	_pipe(back, "CableB", Vector3(-0.06, 0.18, 0.13), Vector3(-0.1, -0.22, 0.06), 0.01, "cable")

	_save(scene_root, "res://ship/seat.tscn")


func _build_ship() -> void:
	_build_seat()
	scene_root = Node3D.new()
	scene_root.name = "ShipInterior"

	# Kestrel B26 deck. Forward (cockpit) is -Z, boarding ramp is +Z.
	# Floor y=0, ceiling y=3. Wings are left solid.
	var hull := _add(scene_root, CSGCombiner3D.new(), "Hull")
	hull.use_collision = true
	_box(hull, "Outer", Vector3(-7.7, -0.2, -9.9), Vector3(5.9, 3.2, 9.5), "hull_outer")
	# Only the low walls of the nose are solid; the canopy above is glass.
	_box(hull, "NoseLower", Vector3(2.1, -0.2, -12.9), Vector3(5.9, 0.95, -9.9), "hull_outer")
	# Frame ring where the canopy meets the cabin (carved by the cockpit below).
	var rear_frame := CSGPolygon3D.new()
	rear_frame.polygon = PackedVector2Array([Vector2(2.1, -0.2), Vector2(5.9, -0.2), Vector2(5.9, 0.95),
		Vector2(5.4, 3.2), Vector2(2.6, 3.2), Vector2(2.1, 0.95)])
	rear_frame.depth = 0.3
	rear_frame.position.z = -9.85
	rear_frame.material = mats["hull_outer"]
	_add(hull, rear_frame, "CanopyRearFrame")
	_ccyl(hull, "LoungeOuter", 4.95, 3.4, Vector3(2.4, 1.5, 1.6), "hull_outer")

	# Cockpit: under the canopy it's just the low walls; behind it the
	# walls lean inward to match the canopy so the room isn't a box.
	_room(hull, "CockpitNose", 2.4, 5.6, -12.6, -10.15)
	var cockpit_room := CSGPolygon3D.new()
	cockpit_room.polygon = PackedVector2Array([Vector2(2.4, 0), Vector2(5.6, 0), Vector2(5.6, 0.95),
		Vector2(5.25, 3.0), Vector2(2.75, 3.0), Vector2(2.4, 0.95)])
	cockpit_room.depth = 3.15
	cockpit_room.position.z = -7.0
	cockpit_room.material = mats["wall"]
	cockpit_room.operation = CSGShape3D.OPERATION_SUBTRACTION
	_add(hull, cockpit_room, "Cockpit")
	_room(hull, "Kitchen", 2.4, 5.6, -6.8, -3.4)
	var lounge := _half_cyl(hull, "Lounge", 4.7, 3.0, 1.5, Vector3(2.4, 0, -3.2), Vector3(8, 3, 6.4), "gunmetal")
	lounge.operation = CSGShape3D.OPERATION_SUBTRACTION
	# Collar around the round lounge entrance, standing out into the lounge.
	_lounge_tube(hull, "LoungeEntranceCollar", LOUNGE_DOOR_R + 0.25, 2.0, 3.4, -0.2, "gunmetal")
	_room(hull, "Deck", -2.3, 2.0, -5.6, 9.2)
	_room(hull, "Quarters", -2.6, 1.8, -9.6, -5.9)
	_room(hull, "Bathroom", -6.0, -2.6, -4.4, -1.6)
	_room(hull, "Engineering", -6.3, -2.6, -1.3, 3.4)
	_room(hull, "Gunner", -7.4, -2.6, 3.7, 7.3)
	# Sleeping pods carved into the quarters' left wall (solid hull behind).
	for pod in POD_CENTERS:
		_carve_pod(hull, pod)

	# Oval doorways. Walls facing Z use axis "z", walls facing X use "x".
	_oval_door(hull, "Door_Kitchen", "x", Vector3(2.2, 1.0, -4.9), 0.95, 1.35)
	_lounge_tube(hull, "Door_Lounge", LOUNGE_DOOR_R, 1.8, 3.5, 0.02, "couch_seam").operation = CSGShape3D.OPERATION_SUBTRACTION
	# Square openings for the sliding doors (see _doors()).
	for d in DOORS:
		var cut := CSGBox3D.new()
		cut.size = Vector3(d[3] + 0.2, 2.4, 2.72 * d[4])
		cut.position = d[1] + Vector3(0, 1.0, 0)
		cut.rotation.y = d[2]
		cut.material = mats["trim"]
		cut.operation = CSGShape3D.OPERATION_SUBTRACTION
		_add(hull, cut, "Door_" + d[0])
	_oval_door(hull, "Door_Gunner", "z", Vector3(-4.0, 1.1, 3.55), 0.8, 1.5)

	var view := _half_cyl(hull, "Window_Lounge", 5.3, 1.4, 1.75, Vector3(5.95, 1.05, -5), Vector3(8, 2.45, 9), "trim")
	view.operation = CSGShape3D.OPERATION_SUBTRACTION

	_box(hull, "FloorPlates", Vector3(-7.7, -0.2, -9.9), Vector3(5.9, 0.02, 9.5), "floor")
	_box(hull, "FloorNose", Vector3(2.1, -0.2, -12.9), Vector3(5.9, 0.02, -9.9), "floor")
	_ccyl(hull, "LoungeFloor", 4.95, 0.22, Vector3(2.4, -0.09, 1.6), "floor")
	_box(hull, "CeilingPanels", Vector3(-7.7, 2.98, -9.9), Vector3(5.9, 3.2, 9.5), "ceiling")
	# Bevel the hull's outer top-right edge beside the cockpit to follow the canopy.
	var bevel_r := CSGPolygon3D.new()
	bevel_r.polygon = PackedVector2Array([Vector2(5.9, 0.95), Vector2(7.0, 0.95), Vector2(7.0, 3.5),
		Vector2(5.4, 3.5), Vector2(5.4, 3.2)])
	bevel_r.depth = 2.95
	bevel_r.position.z = -7.0
	bevel_r.material = mats["hull_outer"]
	bevel_r.operation = CSGShape3D.OPERATION_SUBTRACTION
	_add(hull, bevel_r, "CockpitHullBevel")
	_ccyl(hull, "LoungeCeiling", 4.95, 0.22, Vector3(2.4, 3.09, 1.6), "ceiling")
	# Angled ceiling edges along the main deck.
	for side in [[-2.19, 1.0], [1.89, -1.0]]:
		var bevel := CSGBox3D.new()
		bevel.size = Vector3(0.55, 0.55, 14.8)
		bevel.position = Vector3(side[0], 2.89, 1.8)
		bevel.rotation.z = PI / 4
		bevel.material = mats["ceiling"]
		_add(hull, bevel, "DeckBevelLeft" if side[1] > 0 else "DeckBevelRight")

	# Rib frames around the doorways (the "entrance lines").
	var ribs := _add(scene_root, Node3D.new(), "Ribs")
	for x in [1.95, 2.45]:
		_rib(ribs, "Kitchen%d" % int(x * 100), "x", Vector3(x, 1.0, -4.9), 0.95, 1.35)
	_rib(ribs, "Gunner", "z", Vector3(-4.0, 1.1, 3.4), 0.8, 1.5)

	_doors()
	_deck_details()

	var windows := _add(scene_root, Node3D.new(), "Windows")
	_canopy()
	var lounge_glass := _add(windows, CSGCombiner3D.new(), "LoungeGlass")
	lounge_glass.use_collision = true
	_ccyl(lounge_glass, "Pane", 4.88, 1.4, Vector3(2.4, 1.75, 1.6), "glass")
	var inner := _ccyl(lounge_glass, "Hollow", 4.82, 1.6, Vector3(2.4, 1.75, 1.6), "glass")
	inner.operation = CSGShape3D.OPERATION_SUBTRACTION
	var keep := _box(lounge_glass, "Keep", Vector3(5.9, 0.9, -5), Vector3(8, 2.6, 9), "glass")
	keep.operation = CSGShape3D.OPERATION_INTERSECTION

	var lights := _add(scene_root, Node3D.new(), "Lights")
	_light(lights, "Cockpit", Vector3(4.0, 2.75, -8.6), Color(0.85, 0.9, 1.0), 1.1, 5.0)
	var canopy_fill := OmniLight3D.new()
	canopy_fill.position = Vector3(4.0, 1.6, -11.6)
	canopy_fill.light_color = Color(0.6, 0.75, 1.0)
	canopy_fill.light_energy = 0.6
	canopy_fill.omni_range = 3.5
	_add(lights, canopy_fill, "CanopyFill")
	_light(lights, "Kitchen", Vector3(4.0, 2.75, -5.1), Color(1.0, 0.85, 0.65), 1.1, 4.0)
	_light(lights, "Lounge", Vector3(3.6, 2.75, 1.6), Color(1.0, 0.68, 0.42), 0.9, 6.0)
	_light(lights, "DeckFore", Vector3(-0.15, 2.75, -3.4), Color(1.0, 0.78, 0.58), 1.6, 6.5)
	_light(lights, "DeckMid", Vector3(-0.15, 2.75, 1.8), Color(1.0, 0.78, 0.58), 1.6, 6.5)
	_light(lights, "DeckAft", Vector3(-0.15, 2.75, 6.9), Color(1.0, 0.78, 0.58), 1.6, 6.5)
	_light(lights, "Quarters", Vector3(-0.4, 2.75, -7.7), Color(1.0, 0.8, 0.6), 1.0, 4.5)
	_light(lights, "Bathroom", Vector3(-4.3, 2.75, -3.0), Color(0.95, 0.97, 1.0), 0.8, 3.5)
	_light(lights, "Engineering", Vector3(-4.6, 2.75, 1.4), Color(1.0, 0.65, 0.4), 0.9, 4.5)
	_light(lights, "Gunner", Vector3(-5.0, 2.75, 5.5), Color(1.0, 0.35, 0.3), 0.8, 4.0)
	_glow(lights, "RampGlow", Vector3(0.0, 0.6, 8.7), 0.9, 4.0)
	_glow(lights, "EngineeringGlow", Vector3(-3.0, 0.5, 1.1), 0.6, 2.5)
	_glow(lights, "KitchenGlow", Vector3(3.6, 2.2, -5.2), 0.5, 2.5)

	var cockpit := _furniture("CockpitFurniture")
	_box(cockpit, "Console", Vector3(2.6, 0, -12.6), Vector3(5.4, 0.95, -11.9), "trim")
	_box(cockpit, "ComputerBench", Vector3(5.0, 0, -9.4), Vector3(5.6, 0.9, -7.4), "trim")
	# Small flat screens set into the dash (the main display is the windshield HUD).
	_mesh_box(scene_root, "ConsoleScreenLeft", Vector3(3.15, 0.96, -12.35), Vector3(0.5, 0.025, 0.22), "screen_amber")
	_mesh_box(scene_root, "ConsoleScreenRight", Vector3(4.75, 0.96, -12.35), Vector3(0.5, 0.025, 0.22), "screen_amber")

	var seat_scene: PackedScene = load("res://ship/seat.tscn")
	for seat_pos in [[Vector3(3.3, 0, -11.0), 0.0, "PilotChair"], [Vector3(4.7, 0, -11.0), 0.0, "CopilotChair"],
			[Vector3(-5.0, 0, 5.4), PI, "GunnerChair"]]:
		var chair: Node3D = seat_scene.instantiate()
		chair.position = seat_pos[0]
		chair.rotation.y = seat_pos[1]
		_add(scene_root, chair, seat_pos[2])

	var kitchen := _furniture("KitchenFurniture")
	_box(kitchen, "CounterSide", Vector3(5.0, 0, -6.6), Vector3(5.6, 0.92, -3.6), "trim")
	_box(kitchen, "CounterBack", Vector3(3.2, 0, -4.0), Vector3(5.0, 0.92, -3.4), "trim")
	_box(kitchen, "CountertopSide", Vector3(4.95, 0.92, -6.65), Vector3(5.6, 0.97, -3.55), "counter")
	_box(kitchen, "CountertopBack", Vector3(3.15, 0.92, -4.05), Vector3(4.95, 0.97, -3.4), "counter")
	_box(kitchen, "Cabinets", Vector3(5.2, 1.8, -6.6), Vector3(5.6, 2.5, -3.6), "trim")
	_box(kitchen, "FoodDispenser", Vector3(5.15, 0.97, -5.3), Vector3(5.6, 1.6, -4.7), "metal_dark")

	_lounge()
	_lounge_entrance()
	_bookshelf()
	_crates()
	_reactor_pod()

	var deck := _furniture("DeckFurniture")
	_box(deck, "SuitLocker", Vector3(1.45, 0, 6.6), Vector3(2.0, 2.1, 7.6), "metal_dark")
	_box(deck, "ArmoryLocker", Vector3(1.45, 0, 7.8), Vector3(2.0, 2.1, 8.8), "barrel")
	_box(deck, "RampDoor", Vector3(-1.4, 0, 9.12), Vector3(1.4, 2.5, 9.2), "hazard")
	_box(deck, "CrateA", Vector3(-2.3, 0, 7.6), Vector3(-1.5, 0.8, 8.4), "crate")
	_box(deck, "CrateB", Vector3(-2.3, 0, 8.4), Vector3(-1.6, 0.7, 9.1), "crate")

	var quarters := _furniture("QuartersFurniture")
	for i in POD_CENTERS.size():
		_pod_fittings(i, POD_CENTERS[i])
	_box(quarters, "Shelf", Vector3(1.4, 0.75, -8.0), Vector3(1.8, 0.8, -6.8), "trim")
	_box(quarters, "Locker", Vector3(1.1, 0, -6.5), Vector3(1.8, 2.0, -5.9), "metal_dark")
	# Hale's locker, pried open: the door hangs bent off its hinge.
	var door := _mesh_box(scene_root, "LockerDoor", Vector3.ZERO, Vector3(0.025, 1.85, 0.56), "trim")
	door.transform = Transform3D(Basis(Vector3.UP, 0.55) * Basis(Vector3.RIGHT, 0.05), Vector3(1.0, 1.0, -6.42))
	_mesh_box(scene_root, "LockerInside", Vector3(1.095, 1.0, -6.2), Vector3(0.01, 1.8, 0.52), "cable")
	_mesh_box(scene_root, "LockerScrape", Vector3(1.093, 1.15, -6.48), Vector3(0.01, 0.12, 0.03), "trim")
	# [name, z on the shelf, image, picture size]: Gana & Hale is landscape.
	for ph in [["PhotoHaleFrame", -7.82, "photo_gana_hale", Vector2(0.18, 0.135)],
			["PhotoAngelFrame", -6.95, "photo_angel", Vector2(0.12, 0.16)]]:
		var size: Vector2 = ph[3]
		var frame := Node3D.new()
		frame.position = Vector3(1.62, 0.8, ph[1])
		frame.rotation = Vector3(0, -PI / 2, 0)
		_add(scene_root, frame, ph[0])
		var back := _mesh_box(frame, "Frame", Vector3(0, size.y / 2.0 + 0.02, 0.01), Vector3(size.x + 0.03, size.y + 0.03, 0.015), "wood")
		back.rotation.x = -0.25
		var pic := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = size
		pic.mesh = qm
		var pm := StandardMaterial3D.new()
		pm.albedo_texture = load("res://ship/props/%s.png" % ph[2])
		pm.roughness = 0.5
		pic.material_override = pm
		pic.position = Vector3(0, size.y / 2.0 + 0.02, 0.019)
		pic.rotation.x = -0.25
		_add(frame, pic, "Picture")

	var bath := _furniture("BathroomFurniture")
	_box(bath, "ShowerTray", Vector3(-6.0, 0, -4.4), Vector3(-5.0, 0.08, -3.4), "counter")
	_box(bath, "Toilet", Vector3(-4.5, 0, -2.2), Vector3(-4.0, 0.45, -1.6), "counter")
	_box(bath, "ToiletTank", Vector3(-4.55, 0.45, -1.8), Vector3(-3.95, 0.85, -1.6), "counter")
	_box(bath, "Sink", Vector3(-4.0, 0, -4.4), Vector3(-3.3, 0.85, -3.95), "counter")
	_box(bath, "Mirror", Vector3(-4.0, 1.2, -4.4), Vector3(-3.3, 1.9, -4.37), "glass")
	var shower_glass := _add(scene_root, Node3D.new(), "ShowerGlass")
	_glass(shower_glass, "Side", Vector3(-5.0, 1.1, -4.0), Vector3(0.04, 2.2, 0.8))
	_glass(shower_glass, "Front", Vector3(-5.6, 1.1, -3.4), Vector3(0.8, 2.2, 0.04))

	var eng := _furniture("EngineeringFurniture")
	_box(eng, "Workbench", Vector3(-6.3, 0, -0.4), Vector3(-5.6, 0.9, 2.6), "metal_dark")
	_box(eng, "ToolWall", Vector3(-6.3, 1.2, -0.4), Vector3(-6.22, 2.2, 2.6), "trim")
	_box(eng, "PowerPanel", Vector3(-5.6, 0.8, -1.3), Vector3(-4.3, 2.0, -1.2), "trim")
	_box(eng, "Shelves", Vector3(-6.3, 0, 2.9), Vector3(-5.0, 2.0, 3.4), "trim")
	_mesh_box(scene_root, "PowerPanelScreen", Vector3(-4.95, 1.4, -1.18), Vector3(1.0, 0.6, 0.02), "screen_cyan")
	_parts_barrel(Vector3(-3.4, 0, -0.5))

	var gunner := _furniture("GunnerFurniture")
	_box(gunner, "TurretConsole", Vector3(-6.2, 0, 6.7), Vector3(-3.8, 1.0, 7.3), "trim")
	_mesh_box(scene_root, "TargetingScreen", Vector3(-5.0, 1.35, 7.15), Vector3(1.2, 0.6, 0.04), "screen_amber")

	# Things you can use.
	var use := _add(scene_root, Node3D.new(), "Interactables")

	var computer := _interactable(use, "ShipComputer", "ship_computer", Vector3(5.3, 0.9, -8.4), {"prompt": "Use ship computer"})
	var screen := _mesh_box(computer, "Screen", Vector3(0.1, 0.75, 0), Vector3(0.04, 0.45, 1.0), "screen_cyan")
	screen.rotation.z = 0.17

	var coffee := _interactable(use, "CoffeeMachine", "coffee_machine", Vector3(5.3, 0.97, -6.1), {"needs_power": true})
	_box(_own_csg(coffee, "Body"), "Shell", Vector3(-0.18, 0, -0.18), Vector3(0.18, 0.45, 0.18), "counter")
	var lamp := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	lamp.mesh = sphere
	lamp.position = Vector3(-0.19, 0.36, 0)
	_add(coffee, lamp, "Lamp")

	var log_terminal := _interactable(use, "LogTerminal", "log_terminal", Vector3(1.55, 0.8, -7.4), {"prompt": "Read personal log", "needs_power": true})
	_mesh_box(log_terminal, "Screen", Vector3(0.22, 0.65, 0), Vector3(0.04, 0.5, 0.75), "screen_amber")

	_interactable(use, "Bed", "bunk", Vector3(-2.75, 0.85, -7.6), {"prompt": "Sleep", "interact_range": 1.8})

	_thought(use, "Locker", Vector3(1.45, 1.0, -6.2), "Hale's locker", [
		"Hale's locker. Pried open.",
		"They went through his things... and nothing else on the whole ship.",
		"What were you mixed up in, Hale?"], 1.4)
	_interactable(use, "PhotoHale", "photo", Vector3(1.6, 0.9, -7.82), {"prompt": "Look at photo", "interact_range": 1.3,
		"image": load("res://ship/props/photo_gana_hale.png"),
		"lines": "Asura, the draft. Hale and me, too young and too stupid to be scared.|He swore we'd always make it out together."})
	_interactable(use, "PhotoAngel", "photo", Vector3(1.6, 0.9, -6.95), {"prompt": "Look at photo of Angel", "interact_range": 1.3,
		"image": load("res://ship/props/photo_angel.png"),
		"lines": "Angel.|Hang on. I'm coming home. I promised."})
	_thought(use, "CargoCrates", Vector3(1.35, 0.7, 6.05), "Cargo crates", [
		"Every crate still sealed. Six months of ore, right where we left it.",
		"What kind of pirates leave the cargo?"], 1.3)
	if crashed:
		_inspect(use, "PilotSeat", Vector3(3.3, 0.5, -11.0), "Pilot seat",
			"Not going anywhere until the nav array's fixed.", 1.3)
	else:
		# Flight panel (switches + windshield HUD), the pilot seat that
		# drives it, and the engineering power panel for Meki's reroute.
		var panel := Node3D.new()
		panel.set_script(load("res://ship/cockpit_panel.gd"))
		_add(scene_root, panel, "CockpitPanel")
		_interactable(use, "PilotSeat", "pilot_seat", Vector3(3.3, 0.0, -11.0),
			{"interact_range": 1.2, "panel_path": NodePath("../../CockpitPanel"), "computer_path": NodePath("../ShipComputer")})
		# The jack socket on the back wall beside it: Meki plugs in here.
		var socket: Node3D = (load("res://ship/mechanical_assembly.tscn") as PackedScene).instantiate()
		socket.set("outer_radius", 0.2)
		# Back of the housing flush with the wall, face out into the room.
		socket.position = Vector3(-3.6, 1.38, -1.3 + 0.26 * 0.4)
		socket.rotation.y = PI
		_add(scene_root, socket, "JackSocket")
		_interactable(use, "JackSocket", "jack_socket", Vector3(-3.6, 1.2, -1.0),
			{"interact_range": 1.7, "socket_path": NodePath("../../JackSocket")})
		_thought_zones()
	_inspect(use, "FoodDispenser", Vector3(5.35, 1.2, -5.0), "Food dispenser",
		"Ration paste. Today's flavor: 'savory'.", 1.6)
	_inspect(use, "LoungeWindow", Vector3(6.6, 1.6, 1.6), "Look outside",
		"Stars. A lot of them, and none of them any closer than yesterday.", 2.2)
	_inspect(use, "Shower", Vector3(-5.5, 1.0, -3.9), "Shower",
		"Recycled water, two-minute limit. Luxury.", 1.8)
	_inspect(use, "Mirror", Vector3(-3.65, 1.5, -4.2), "Mirror",
		"You look tired. The ship doesn't judge.", 1.6)
	_inspect(use, "Reactor", Vector3(2.85, 1.2, -6.0), "Check reactor",
		"Limping along at 31%. It's been humming like that since the pirates hit us.", 1.4)
	_interactable(use, "Workbench", "workbench", Vector3(-5.9, 1.0, 1.1), {"interact_range": 1.6})
	_interactable(use, "PartsBarrel", "parts_barrel", Vector3(-3.4, 1.0, -0.5), {"interact_range": 1.5, "per_rummage": 3})
	_inspect(use, "TurretControls", Vector3(-5.0, 1.0, 6.4), "Turret controls",
		"Turret systems cold. Nothing to shoot at out here. Thankfully.", 1.8)
	_inspect(use, "SuitLocker", Vector3(1.7, 1.0, 7.1), "EVA suit",
		"Patched twice. Rated for a lot more than it's been through.", 1.4)
	_inspect(use, "ArmoryLocker", Vector3(1.7, 1.0, 8.3), "Armory locker",
		"One rifle, one sidearm, and a box of shells you hope stays full.", 1.4)
	_inspect(use, "BoardingRamp", Vector3(0, 1.2, 8.9), "Boarding ramp",
		"Ramp sealed. Opening it out here would be a very short walk.", 1.8)

	if crashed:
		_make_world_materials()
	_exterior()
	if crashed:
		_apply_crash_damage()
		_save(scene_root, "res://ship/ship_crashed.tscn")
	else:
		_save(scene_root, "res://ship/ship_interior.tscn")


# Sliding doors: [name, floor centre in the wall, yaw, wall thickness,
# width scale]. The model is 0.3 deep along x and 2.8 wide along z.
const DOORS := [
	["Quarters", Vector3(-0.15, 0, -5.75), PI / 2, 0.3, 0.85],
	["Cockpit", Vector3(4.0, 0, -6.9), PI / 2, 0.2, 0.7],
	["Bathroom", Vector3(-2.45, 0, -3.0), 0.0, 0.3, 0.85],
	["Engineering", Vector3(-2.45, 0, 1.1), 0.0, 0.3, 0.85],
]
const DOOR_HEIGHT := 0.85


func _doors() -> void:
	var root := _add(scene_root, Node3D.new(), "Doors")
	var frame_mesh: Mesh = load("res://ship/models/door/frame.obj")
	var sound: AudioStream = load("res://audio/door_slide.ogg")
	for d in DOORS:
		var thick: float = d[3]
		var ws: float = d[4]
		var door := Node3D.new()
		door.set_script(load("res://ship/sliding_door.gd"))
		door.position = d[1]
		door.rotation.y = d[2]
		door.set("travel", 1.3 * ws)
		door.set("sluggish", crashed)
		_add(root, door, d[0])
		# Frame sticks out a little past both wall faces so it doesn't flicker.
		var frame := MeshInstance3D.new()
		frame.mesh = frame_mesh
		frame.material_override = mats["door"]
		frame.scale = Vector3((thick + 0.04) / 0.3, DOOR_HEIGHT, ws)
		_add(door, frame, "Frame")
		for leaf in [["LeafLeft", "leaf_left", -0.583], ["LeafRight", "leaf_right", 0.565]]:
			var body := AnimatableBody3D.new()
			_add(door, body, leaf[0])
			var mi := MeshInstance3D.new()
			mi.mesh = load("res://ship/models/door/%s.obj" % leaf[1])
			mi.material_override = mats["door"]
			mi.scale = Vector3(thick / 0.3, DOOR_HEIGHT, ws)
			_add(body, mi, "Mesh")
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.1 * thick / 0.3, 2.44 * DOOR_HEIGHT, 1.414 * ws)
			cs.shape = shape
			cs.position = Vector3(0, 1.33 * DOOR_HEIGHT, leaf[2] * ws)
			_add(body, cs, "Shape")
		var sensor := Area3D.new()
		sensor.collision_mask = 3  # the player and Meki
		_add(door, sensor, "Sensor")
		var scs := CollisionShape3D.new()
		var sbox := BoxShape3D.new()
		sbox.size = Vector3(3.6, 2.2, 2.2 * ws)
		scs.shape = sbox
		scs.position = Vector3(0, 1.1, 0)
		_add(sensor, scs, "Shape")
		var sp := AudioStreamPlayer3D.new()
		sp.stream = sound
		sp.volume_db = -8.0
		sp.unit_size = 3.0
		sp.position = Vector3(0, 2.0, 0)
		_add(door, sp, "Sound")


# Warm orange accent light with no fixture (doorway / ramp glow).
func _glow(parent: Node, name: String, pos: Vector3, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = Color(1.0, 0.55, 0.22)
	l.light_energy = energy
	l.omni_range = rng
	_add(parent, l, name)


func _pipe(parent: Node, name: String, from: Vector3, to: Vector3, radius: float, mat: String) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = from.distance_to(to)
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = mats[mat]
	_add(parent, mi, name)
	mi.position = (from + to) / 2.0
	var dir := (to - from).normalized()
	if dir.abs() != Vector3.UP:
		mi.basis = Basis(Quaternion(Vector3.UP, dir))


# Canopy corners, flush with the inside of the low nose walls (y 0.95); the
# windshield slopes back to the roof and the sides lean inward.
const C_FL0 := Vector3(2.4, 0.95, -12.6)
const C_FR0 := Vector3(5.6, 0.95, -12.6)
const C_RL0 := Vector3(2.4, 0.95, -10.15)
const C_RR0 := Vector3(5.6, 0.95, -10.15)
const C_FL1 := Vector3(2.75, 3.0, -11.4)
const C_FR1 := Vector3(5.25, 3.0, -11.4)
const C_RL1 := Vector3(2.75, 3.0, -10.15)
const C_RR1 := Vector3(5.25, 3.0, -10.15)


# A flat glass pane through four corners, solid so the camera stays inside.
func _glass_quad(parent: Node, name: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var body := StaticBody3D.new()
	_add(parent, body, name)
	var n := (b - a).cross(d - a).normalized()
	var shape := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for v in [a, b, c, d]:
		pts.append(v + n * 0.02)
		pts.append(v - n * 0.02)
	shape.points = pts
	var cs := CollisionShape3D.new()
	cs.shape = shape
	_add(body, cs, "CollisionShape3D")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(n)
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mats["glass"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(body, mi, "Pane")


# A flat window frame on a 4-sided pane: a band of width `band` around a
# rounded opening, with `depth` of thickness toward `inside`.
func _frame_ring(parent: Node, name: String, corners: Array, inside: Vector3,
		band := 0.11, radius := 0.2, depth := 0.07) -> void:
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	var d: Vector3 = corners[3]
	var normal: Vector3 = (b - a).cross(d - a).normalized()
	var center: Vector3 = (a + b + c + d) / 4.0
	if normal.dot(inside - center) < 0.0:
		normal = -normal
	var e1: Vector3 = (b - a).normalized()
	var e2: Vector3 = normal.cross(e1)
	var outer := PackedVector2Array()
	for corner: Vector3 in corners:
		outer.append(Vector2((corner - a).dot(e1), (corner - a).dot(e2)))
	# Counter-clockwise order so "left" of each edge points inward.
	var area := 0.0
	for k in 4:
		area += outer[k].cross(outer[(k + 1) % 4])
	var order := [0, 1, 2, 3] if area > 0.0 else [3, 2, 1, 0]
	var pts := PackedVector2Array()
	for k in order:
		pts.append(outer[k])
	# Inset every edge by `band`, then intersect neighbours for the inner corners.
	var inner := PackedVector2Array()
	for k in 4:
		var p_prev := pts[(k + 3) % 4]
		var p := pts[k]
		var p_next := pts[(k + 1) % 4]
		var d0 := (p - p_prev).normalized()
		var d1 := (p_next - p).normalized()
		var n0 := Vector2(-d0.y, d0.x)
		var n1 := Vector2(-d1.y, d1.x)
		var hit = Geometry2D.line_intersects_line(p_prev + n0 * band, d0, p + n1 * band, d1)
		inner.append(hit)
	# Round each inner corner; every arc point fans to its outer corner.
	var ring_outer := []
	var ring_inner := []
	for k in 4:
		var q := inner[k]
		var u_in := (q - inner[(k + 3) % 4]).normalized()
		var u_out := (inner[(k + 1) % 4] - q).normalized()
		var half := (PI - u_in.angle_to(u_out)) / 2.0
		var r := minf(radius, minf(q.distance_to(inner[(k + 3) % 4]), q.distance_to(inner[(k + 1) % 4])) * 0.45 * tan(half))
		var t := r / tan(half)
		var t1 := q - u_in * t
		var t2 := q + u_out * t
		var c2 := t1 + Vector2(-u_in.y, u_in.x) * r
		var a1 := (t1 - c2).angle()
		var sweep := wrapf((t2 - c2).angle() - a1, -PI, PI)
		for step in 7:
			ring_inner.append(c2 + Vector2.from_angle(a1 + sweep * step / 6.0) * r)
			ring_outer.append(pts[k])
	var to3 := func(v: Vector2, lift: float) -> Vector3:
		return a + e1 * v.x + e2 * v.y + normal * lift
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := func(p0: Vector3, p1: Vector3, p2: Vector3) -> void:
		var fn := (p1 - p0).cross(p2 - p0).normalized()
		if fn.dot(normal) < -0.5:
			fn = -fn
		st.set_normal(fn)
		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(p2)
	var count := ring_inner.size()
	for i in count:
		var j := (i + 1) % count
		for lift in [0.0, depth]:
			var i0: Vector3 = to3.call(ring_inner[i], lift)
			var i1: Vector3 = to3.call(ring_inner[j], lift)
			var o0: Vector3 = to3.call(ring_outer[i], lift)
			var o1: Vector3 = to3.call(ring_outer[j], lift)
			tri.call(o0, i0, i1)
			if ring_outer[i] != ring_outer[j]:
				tri.call(o0, i1, o1)
		# Reveal: the inner edge of the opening.
		var a0: Vector3 = to3.call(ring_inner[i], 0.0)
		var a1b: Vector3 = to3.call(ring_inner[j], 0.0)
		var b0: Vector3 = to3.call(ring_inner[i], depth)
		var b1: Vector3 = to3.call(ring_inner[j], depth)
		tri.call(a0, a1b, b1)
		tri.call(a0, b1, b0)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mats["canopy_frame"]
	_add(parent, mi, name)


func _canopy() -> void:
	var canopy := _add(scene_root, Node3D.new(), "Canopy")
	_glass_quad(canopy, "Windshield", C_FL0, C_FR0, C_FR1, C_FL1)
	_glass_quad(canopy, "SideLeft", C_RL0, C_FL0, C_FL1, C_RL1)
	_glass_quad(canopy, "SideRight", C_FR0, C_RR0, C_RR1, C_FR1)
	_glass_quad(canopy, "Roof", C_FL1, C_FR1, C_RR1, C_RL1)

	# Sleek frames with rounded window openings. The windshield is split
	# into two windows by a wide center pillar.
	var mid0 := C_FL0.lerp(C_FR0, 0.5)
	var mid1 := C_FL1.lerp(C_FR1, 0.5)
	var inside := Vector3(4.0, 1.6, -10.8)
	_frame_ring(canopy, "FrameWindshieldL", [C_FL0, mid0, mid1, C_FL1], inside)
	_frame_ring(canopy, "FrameWindshieldR", [mid0, C_FR0, C_FR1, mid1], inside)
	_frame_ring(canopy, "FrameSideL", [C_RL0, C_FL0, C_FL1, C_RL1], inside)
	_frame_ring(canopy, "FrameSideR", [C_FR0, C_RR0, C_RR1, C_FR1], inside)
	_frame_ring(canopy, "FrameRoof", [C_FL1, C_FR1, C_RR1, C_RL1], inside)

	# Overhead console hanging from the roof.
	_mesh_box(canopy, "OverheadPost", Vector3(4.0, 2.92, -10.75), Vector3(0.07, 0.22, 0.07), "metal_dark")
	_mesh_box(canopy, "OverheadConsole", Vector3(4.0, 2.74, -10.75), Vector3(0.55, 0.16, 0.32), "metal_dark")
	_mesh_box(canopy, "OverheadScreen", Vector3(4.0, 2.74, -10.915), Vector3(0.4, 0.1, 0.01), "screen_amber")
	for i in 3:
		_pipe(canopy, "Cable%d" % i, Vector3(2.5 + i * 0.06, 0.05, -12.0), Vector3(2.5 + i * 0.06, 0.05, -9.0), 0.025, "cable")


# Sleeping pods: (y, z) centre of each opening on the wall at x = -2.6.
const POD_CENTERS := [Vector2(0.85, -7.6), Vector2(2.0, -7.6)]
const POD_W := 1.35
const POD_H := 0.95
const POD_R := 0.28
const POD_X0 := -2.65
const POD_X1 := -4.75


# Rounded-rectangle tunnel into the wall; its surfaces take the leather.
func _carve_pod(hull: Node, c: Vector2) -> void:
	var mid := (POD_X0 + POD_X1) / 2.0
	var depth := POD_X0 - POD_X1 + 0.1
	var parts := []
	var b1 := CSGBox3D.new()
	b1.size = Vector3(depth, POD_H - 2.0 * POD_R, POD_W)
	parts.append(b1)
	var b2 := CSGBox3D.new()
	b2.size = Vector3(depth, POD_H, POD_W - 2.0 * POD_R)
	parts.append(b2)
	for sy in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var cyl := CSGCylinder3D.new()
			cyl.radius = POD_R
			cyl.height = depth
			cyl.sides = 16
			cyl.rotation.z = PI / 2
			cyl.position = Vector3(0, sy * (POD_H / 2.0 - POD_R), sz * (POD_W / 2.0 - POD_R))
			parts.append(cyl)
	var i := 0
	for part in parts:
		part.position += Vector3(mid, c.x, c.y)
		part.material = mats["leather_pad"]
		part.operation = CSGShape3D.OPERATION_SUBTRACTION
		_add(hull, part, "Pod%d_%d" % [int(c.x * 10), i])
		i += 1


func _pod_fittings(index: int, c: Vector2) -> void:
	var pod := _add(scene_root, Node3D.new(), "SleepPod%d" % index)
	var y0 := c.x - POD_H / 2.0
	var y1 := c.x + POD_H / 2.0
	var z0 := c.y - POD_W / 2.0
	var z1 := c.y + POD_W / 2.0
	var length := POD_X0 - POD_X1
	var mid := (POD_X0 + POD_X1) / 2.0
	# Bedding.
	_mesh_box(pod, "Mattress", Vector3(mid - 0.02, y0 + 0.08, c.y), Vector3(length - 0.1, 0.14, POD_W - 0.12), "leather_pad")
	_mesh_box(pod, "Sheet", Vector3(mid - 0.02, y0 + 0.155, c.y), Vector3(length - 0.14, 0.012, POD_W - 0.2), "counter")
	_mesh_box(pod, "Blanket", Vector3(mid + 0.35, y0 + 0.18, c.y + 0.05), Vector3(1.1, 0.05, POD_W - 0.16), "blanket")
	_mesh_box(pod, "Pillow", Vector3(POD_X1 + 0.3, y0 + 0.21, c.y), Vector3(0.35, 0.1, 0.62), "counter")
	# Upholstery seams: rings around the tunnel and lines on the back panel.
	for k in 4:
		var x := POD_X0 - 0.45 - k * 0.45
		_mesh_box(pod, "SeamTop%d" % k, Vector3(x, y1 - 0.004, c.y), Vector3(0.012, 0.008, POD_W - 2.0 * POD_R), "harness")
		for sz in [-1.0, 1.0]:
			_mesh_box(pod, "SeamSide%d_%d" % [k, int(sz)], Vector3(x, c.x + 0.05, c.y + sz * (POD_W / 2.0 - 0.004)),
				Vector3(0.012, POD_H - 2.0 * POD_R, 0.008), "harness")
	for k in 3:
		_mesh_box(pod, "BackSeam%d" % k, Vector3(POD_X1 + 0.004, y0 + 0.35 + k * 0.17, c.y), Vector3(0.008, 0.01, POD_W - 0.3), "harness")
	# Reading light.
	_mesh_box(pod, "LightStrip", Vector3(POD_X1 + 0.6, y1 - 0.012, c.y), Vector3(0.5, 0.02, 0.08), "fixture_warm")
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(POD_X1 + 0.7, y1 - 0.15, c.y)
	lamp.light_color = Color(1.0, 0.72, 0.45)
	lamp.light_energy = 0.35
	lamp.omni_range = 1.8
	_add(pod, lamp, "ReadingLight")
	# Frame with rounded opening, protruding into the room.
	var band := 0.12
	var fx := -2.595
	var corners := [Vector3(fx, y0 - band, z0 - band), Vector3(fx, y0 - band, z1 + band),
		Vector3(fx, y1 + band, z1 + band), Vector3(fx, y1 + band, z0 - band)]
	_frame_ring(pod, "Frame", corners, Vector3(0.0, c.x, c.y), band, POD_R + 0.02, 0.08)
	# Little control panel beside the opening.
	_mesh_box(pod, "Panel", Vector3(-2.58, c.x + 0.15, z1 + 0.32), Vector3(0.04, 0.22, 0.14), "metal_dark")
	_mesh_box(pod, "PanelScreen", Vector3(-2.555, c.x + 0.18, z1 + 0.32), Vector3(0.01, 0.08, 0.1), "screen_amber")
	_mesh_box(pod, "PanelButton", Vector3(-2.555, c.x + 0.08, z1 + 0.32), Vector3(0.012, 0.03, 0.03), "hazard")


# Padded leather arch on the deck's right wall: a circular curve that
# comes out of the wall near the floor, bows into the deck and returns
# near the ceiling. Soft leather rolls on a curved steel backing.
func _side_arch(z: float) -> void:
	var arch := _add(scene_root, Node3D.new(), "SideArch")
	# Circle centred out in the deck: the middle of the curve sits flat on
	# the wall and the ends sweep out toward the floor and ceiling.
	var r := 1.6
	var center := Vector2(1.98 - 0.08 - r, 1.45)
	var a0 := -1.12
	var a1 := 1.19
	var pads := 12
	var step := (a1 - a0) / pads
	var roll := CapsuleMesh.new()
	roll.radius = 0.16
	roll.height = 0.54
	roll.radial_segments = 16
	roll.rings = 4
	var stud := SphereMesh.new()
	stud.radius = 0.018
	stud.height = 0.036
	stud.radial_segments = 8
	stud.rings = 4
	for k in pads:
		var ang := a0 + step * (k + 0.5)
		var dir := Vector2(cos(ang), sin(ang))
		var n := -dir
		var t := Vector2(-n.y, n.x)
		var basis := Basis(Vector3(t.x, t.y, 0), Vector3(n.x, n.y, 0), Vector3(0, 0, -1))
		var at := func(rad: float) -> Vector3:
			var q := center + dir * rad
			return Vector3(q.x, q.y, z)
		var seg := r * step + 0.01
		var back := _mesh_box(arch, "Backing%d" % k, Vector3.ZERO, Vector3(seg, 0.16, 0.6), "rib")
		back.transform = Transform3D(basis, at.call(r))
		for side in [-0.28, 0.28]:
			var rail := _mesh_box(arch, "Rail%d_%d" % [k, int(side * 10)], Vector3.ZERO, Vector3(seg, 0.12, 0.04), "metal_dark")
			rail.transform = Transform3D(basis, at.call(r - 0.1) + Vector3(0, 0, side))
		var pad := MeshInstance3D.new()
		pad.mesh = roll
		pad.material_override = mats["leather_pad"]
		_add(arch, pad, "Pad%d" % k)
		var pb := basis.scaled_local(Vector3((r - 0.15) * step / 0.31, 0.62, 1.0)) * Basis(Vector3.RIGHT, PI / 2)
		pad.transform = Transform3D(pb, at.call(r - 0.15))
		for zz in [-0.13, 0.13]:
			var button := MeshInstance3D.new()
			button.mesh = stud
			button.material_override = mats["harness"]
			_add(arch, button, "Stud%d_%d" % [k, int(zz * 10)])
			button.position = at.call(r - 0.245) + Vector3(0, 0, zz)
	# Solid panel filling the gap between the back of the arch and the wall.
	var fill_pts := PackedVector2Array()
	for k in 25:
		var ang := a0 + (a1 - a0) * k / 24.0
		fill_pts.append(center + Vector2(cos(ang), sin(ang)) * (r + 0.07))
	fill_pts.append(Vector2(1.99, center.y + sin(a1) * (r + 0.07)))
	fill_pts.append(Vector2(1.99, center.y + sin(a0) * (r + 0.07)))
	var fill := CSGPolygon3D.new()
	fill.polygon = fill_pts
	fill.depth = 0.6
	fill.position.z = z + 0.3
	fill.material = mats["rib"]
	fill.use_collision = true
	_add(arch, fill, "BackFill")
	var foot := center + Vector2(cos(a0), sin(a0)) * r
	_mesh_box(arch, "Foot", Vector3(foot.x + 0.05, 0.05, z), Vector3(0.5, 0.1, 0.64), "metal_dark")
	var body := StaticBody3D.new()
	_add(arch, body, "Collision")
	for k in 8:
		var ang := a0 + (a1 - a0) * (k + 0.5) / 8.0
		var q := center + Vector2(cos(ang), sin(ang)) * (r - 0.05)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.35, 0.6, 0.6)
		cs.shape = sh
		cs.position = Vector3(q.x, q.y, z)
		_add(body, cs, "Shape%d" % k)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0.9, 1.5, z)
	glow.light_color = Color(1.0, 0.7, 0.45)
	glow.light_energy = 0.35
	glow.omni_range = 3.0
	_add(arch, glow, "ArchGlow")


# Wall-mounted exhaust unit on the deck's left wall: grille housing, a big
# clamped duct elbowing into the wall, drain pipe and a valve block.
func _exhaust() -> void:
	var ex := _add(scene_root, Node3D.new(), "Exhaust")
	var solid := _add(ex, CSGCombiner3D.new(), "Housing")
	solid.use_collision = true
	_box(solid, "Unit", Vector3(-2.3, 1.62, 4.95), Vector3(-1.86, 2.36, 6.25), "exhaust")
	_box(solid, "UnitLip", Vector3(-1.88, 1.58, 4.92), Vector3(-1.84, 1.66, 6.28), "metal_dark")
	_box(solid, "ValveBlock", Vector3(-2.3, 0.82, 4.25), Vector3(-2.1, 1.2, 4.6), "exhaust")
	_box(solid, "Bracket", Vector3(-2.3, 1.45, 5.15), Vector3(-2.0, 1.62, 5.25), "metal_dark")
	_box(solid, "Bracket2", Vector3(-2.3, 1.45, 5.95), Vector3(-2.0, 1.62, 6.05), "metal_dark")
	# Grille: dark backing with slats.
	_mesh_box(ex, "GrilleBack", Vector3(-1.855, 2.0, 5.6), Vector3(0.01, 0.56, 1.1), "cable")
	for i in 10:
		_mesh_box(ex, "Slat%d" % i, Vector3(-1.845, 1.76 + i * 0.053, 5.6), Vector3(0.025, 0.022, 1.1), "metal_dark")
	_pipe(ex, "TopRoll", Vector3(-1.95, 2.36, 4.95), Vector3(-1.95, 2.36, 6.25), 0.09, "exhaust")
	_mesh_box(ex, "Label", Vector3(-1.85, 1.68, 5.0 + 0.25), Vector3(0.005, 0.05, 0.18), "hazard")
	# Big duct with ring clamps, elbowing into the wall.
	_pipe(ex, "Duct", Vector3(-2.08, 2.02, 4.95), Vector3(-2.08, 2.02, 3.62), 0.16, "exhaust")
	for zc in [4.75, 4.35, 3.95]:
		_pipe(ex, "Clamp%d" % int(zc * 100), Vector3(-2.08, 2.02, zc - 0.03), Vector3(-2.08, 2.02, zc + 0.03), 0.19, "metal_dark")
	var elbow := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	sm.radial_segments = 16
	sm.rings = 8
	elbow.mesh = sm
	elbow.material_override = mats["exhaust"]
	elbow.position = Vector3(-2.08, 2.02, 3.6)
	_add(ex, elbow, "Elbow")
	_pipe(ex, "DuctIn", Vector3(-2.08, 2.02, 3.6), Vector3(-2.32, 2.02, 3.6), 0.16, "exhaust")
	_pipe(ex, "WallHole", Vector3(-2.3, 2.02, 3.6), Vector3(-2.28, 2.02, 3.6), 0.25, "cable")
	_pipe(ex, "WallCollar", Vector3(-2.29, 2.02, 3.6), Vector3(-2.24, 2.02, 3.6), 0.21, "metal_dark")
	# Drain down to the floor.
	_pipe(ex, "Drain", Vector3(-2.2, 1.62, 6.1), Vector3(-2.2, 0.0, 6.1), 0.045, "exhaust")
	for yc in [1.2, 0.5]:
		_pipe(ex, "DrainClamp%d" % int(yc * 10), Vector3(-2.2, yc - 0.02, 6.1), Vector3(-2.2, yc + 0.02, 6.1), 0.06, "metal_dark")
	# Valve block feed pipes with handwheels and a gauge.
	for yv in [1.08, 0.92]:
		var tag := "%d" % int(yv * 100)
		_pipe(ex, "Feed" + tag, Vector3(-2.2, yv, 3.75), Vector3(-2.2, yv, 4.25), 0.03, "copper")
		var wheel := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.045
		tm.outer_radius = 0.065
		tm.rings = 12
		tm.ring_segments = 6
		wheel.mesh = tm
		wheel.material_override = mats["hazard"]
		wheel.position = Vector3(-2.2, yv, 3.98)
		wheel.rotation.x = PI / 2
		_add(ex, wheel, "Wheel" + tag)
	_pipe(ex, "GaugeBody", Vector3(-2.1, 1.12, 4.42), Vector3(-2.07, 1.12, 4.42), 0.055, "metal_dark")
	_pipe(ex, "GaugeFace", Vector3(-2.075, 1.12, 4.42), Vector3(-2.068, 1.12, 4.42), 0.045, "counter")
	var warm := OmniLight3D.new()
	warm.position = Vector3(-1.6, 1.3, 5.4)
	warm.light_color = Color(1.0, 0.62, 0.32)
	warm.light_energy = 0.45
	warm.omni_range = 3.0
	_add(ex, warm, "ExhaustGlow")


# Structural ribs arching over the deck, pipes and cables along the
# ceiling edges, and a grated walkway down the middle.
func _deck_details() -> void:
	var ribs := _add(scene_root, CSGCombiner3D.new(), "DeckRibs")
	ribs.use_collision = true
	for z in [-1.6, 3.2, 5.4, 8.9]:
		var tag := "%d" % int(round(z * 10))
		_box(ribs, "PostL" + tag, Vector3(-2.3, 0, z - 0.12), Vector3(-2.16, 2.55, z + 0.12), "rib")
		_box(ribs, "PostR" + tag, Vector3(1.86, 0, z - 0.12), Vector3(2.0, 2.55, z + 0.12), "rib")
		_box(ribs, "Beam" + tag, Vector3(-1.85, 2.86, z - 0.12), Vector3(1.55, 2.98, z + 0.12), "rib")
		for side in [[-1.958, PI / 4, "L"], [1.658, -PI / 4, "R"]]:
			var brace := CSGBox3D.new()
			brace.size = Vector3(0.72, 0.12, 0.24)
			brace.position = Vector3(side[0], 2.658, z)
			brace.rotation.z = side[1]
			brace.material = mats["rib"]
			_add(ribs, brace, "Brace" + side[2] + tag)

	var pipes := _add(scene_root, Node3D.new(), "Pipes")
	_pipe(pipes, "EngRiserA", Vector3(-6.15, 0, -1.15), Vector3(-6.15, 3.0, -1.15), 0.07, "copper")
	_pipe(pipes, "EngRiserB", Vector3(-5.95, 0, -1.15), Vector3(-5.95, 3.0, -1.15), 0.045, "copper")
	_pipe(pipes, "EngOverhead", Vector3(-6.15, 2.7, -1.15), Vector3(-2.7, 2.7, -1.15), 0.06, "copper")
	_ship_hoses()

	_side_arch(4.3)
	_exhaust()

	for x in [-1.05, 0.75]:
		_mesh_box(scene_root, "FloorRail%d" % int(x * 100), Vector3(x, 0.025, 1.8), Vector3(0.28, 0.01, 14.4), "grate")
		_mesh_box(scene_root, "RailEdgeA%d" % int(x * 100), Vector3(x - 0.16, 0.03, 1.8), Vector3(0.04, 0.02, 14.4), "rib")
		_mesh_box(scene_root, "RailEdgeB%d" % int(x * 100), Vector3(x + 0.16, 0.03, 1.8), Vector3(0.04, 0.02, 14.4), "rib")
	# Low cool-blue strips along the base of the deck walls.
	# Segments stop short of each doorway.
	var strips := [[-2.28, -5.5, -3.75], [-2.28, -2.25, 0.35], [-2.28, 1.85, 9.1],
		[1.98, -3.8, -0.4], [1.98, 2.4, 9.1]]
	for i in strips.size():
		var z0: float = strips[i][1]
		var z1: float = strips[i][2]
		_mesh_box(scene_root, "LedStrip%d" % i, Vector3(strips[i][0], 0.18, (z0 + z1) / 2.0), Vector3(0.03, 0.04, z1 - z0), "led_strip")

	var clutter := _add(scene_root, CSGCombiner3D.new(), "Clutter")
	clutter.use_collision = true
	_ccyl(clutter, "BarrelA", 0.28, 0.85, Vector3(-1.95, 0.425, 6.9), "barrel")
	_ccyl(clutter, "BarrelB", 0.28, 0.85, Vector3(-5.9, 0.425, 3.0), "barrel")
	_ccyl(clutter, "BarrelC", 0.22, 0.7, Vector3(5.25, 0.35, -9.7), "barrel")


# Cylinder (vertical axis) as a CSG child.
func _ccyl(parent: Node, name: String, radius: float, height: float, pos: Vector3, mat: String) -> CSGCylinder3D:
	var c := CSGCylinder3D.new()
	c.radius = radius
	c.height = height
	c.sides = 64
	c.position = pos
	c.material = mats[mat]
	return _add(parent, c, name)


# Vertical half-cylinder: a cylinder of `radius` around (2.4, *, 1.6) clipped to the box a..b.
func _half_cyl(parent: Node, name: String, radius: float, height: float, y: float, a: Vector3, b: Vector3, mat: String) -> CSGCombiner3D:
	var comb := _add(parent, CSGCombiner3D.new(), name)
	_ccyl(comb, "Round", radius, height, Vector3(2.4, y, 1.6), mat)
	var clip := _box(comb, "Clip", a, b, mat)
	clip.operation = CSGShape3D.OPERATION_INTERSECTION
	return comb


func _orient(node: Node3D, axis: String, stretch: float) -> void:
	if axis == "x":
		node.rotation.z = PI / 2
		node.scale = Vector3(stretch, 1, 1)
	else:
		node.rotation.x = PI / 2
		node.scale = Vector3(1, 1, stretch)


func _oval_door(hull: Node, name: String, axis: String, pos: Vector3, radius: float, stretch: float) -> void:
	var c := CSGCylinder3D.new()
	c.radius = radius
	c.height = 0.9
	c.sides = 32
	c.position = pos
	c.material = mats["trim"]
	c.operation = CSGShape3D.OPERATION_SUBTRACTION
	_orient(c, axis, stretch)
	_add(hull, c, name)


func _rib(parent: Node, name: String, axis: String, pos: Vector3, radius: float, stretch: float) -> void:
	var t := CSGTorus3D.new()
	t.inner_radius = radius
	t.outer_radius = radius + 0.14
	t.sides = 32
	t.ring_sides = 8
	t.position = pos
	t.material = mats["rib"]
	t.use_collision = true
	_orient(t, axis, stretch)
	_add(parent, t, name)


func _ring(parent: Node, name: String, r_in: float, r_out: float, height: float, y: float, mat: String) -> void:
	var comb := _add(parent, CSGCombiner3D.new(), name)
	_ccyl(comb, "Outer", r_out, height, Vector3(2.4, y, 1.6), mat)
	var hole := _ccyl(comb, "Hole", r_in, height + 0.2, Vector3(2.4, y, 1.6), mat)
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION

func _furniture(name: String) -> Node:
	var c := _add(scene_root, CSGCombiner3D.new(), name)
	c.use_collision = true
	return c


func _own_csg(parent: Node, name: String) -> Node:
	var c := _add(parent, CSGCombiner3D.new(), name)
	c.use_collision = true
	return c


func _cyl(parent: Node, name: String, radius: float, height: float, y: float, mat: String, collide: bool) -> void:
	var c := CSGCylinder3D.new()
	c.radius = radius
	c.height = height
	c.sides = 24
	c.position = Vector3(0, y, 0)
	c.material = mats[mat]
	c.use_collision = collide
	_add(parent, c, name)


func _save(node: Node, path: String) -> void:
	var uid := ResourceLoader.get_resource_uid(path) if FileAccess.file_exists(path) else ResourceUID.INVALID_ID
	if uid == ResourceUID.INVALID_ID:
		uid = ResourceUID.create_id()
	var ps := PackedScene.new()
	var err := ps.pack(node)
	assert(err == OK)
	err = ResourceSaver.save(ps, path)
	ResourceSaver.set_uid(path, uid)
	if ResourceUID.has_id(uid):
		ResourceUID.set_id(uid, path)
	else:
		ResourceUID.add_id(uid, path)
	print("saved ", path, " err=", err, " uid=", ResourceUID.id_to_text(uid))


# ---------- HUD ----------

func _label(parent: Node, name: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.unique_name_in_owner = true
	return _add(parent, l, name)


func _stylebox(bg: Color, border: Color, width := 0, margin := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(margin)
	return sb


func _build_hud() -> void:
	scene_root = CanvasLayer.new()
	scene_root.name = "HUD"
	scene_root.set_script(load("res://ui/hud.gd"))
	scene_root.add_to_group("hud", true)

	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.unique_name_in_owner = true
	_add(scene_root, fade, "Fade")

	var held := _label(scene_root, "HeldLabel", 20, Color(1.0, 0.85, 0.6))
	held.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	held.position = Vector2(24, 20)
	held.size = Vector2(400, 40)

	var bottom := VBoxContainer.new()
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 80
	bottom.offset_right = -80
	bottom.offset_top = -180
	bottom.offset_bottom = -48
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(scene_root, bottom, "Bottom")
	_label(bottom, "MessageLabel", 22, Color(0.92, 0.92, 0.92))
	_label(bottom, "PromptLabel", 26, Color(1.0, 0.9, 0.6))

	# Terminal screen used by the log and the ship computer.
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Menlo", "SF Mono", "Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	theme.default_font = font
	theme.default_font_size = 18
	var cyan := Color(0.55, 0.92, 1.0)
	theme.set_color("font_color", "Label", cyan)
	theme.set_color("default_color", "RichTextLabel", Color(0.78, 0.95, 1.0))
	theme.set_color("font_color", "ItemList", Color(0.5, 0.75, 0.8))
	theme.set_color("font_selected_color", "ItemList", Color.WHITE)
	theme.set_color("font_hovered_color", "ItemList", cyan)
	theme.set_stylebox("panel", "ItemList", _stylebox(Color(0, 0, 0, 0.35), Color(0.2, 0.6, 0.75, 0.5), 1, 8))
	theme.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	theme.set_stylebox("selected", "ItemList", _stylebox(Color(0.1, 0.45, 0.6, 0.6), Color.TRANSPARENT))
	theme.set_stylebox("selected_focus", "ItemList", _stylebox(Color(0.1, 0.45, 0.6, 0.8), Color.TRANSPARENT))
	theme.set_constant("v_separation", "ItemList", 10)
	theme.set_color("font_color", "Button", cyan)
	theme.set_stylebox("normal", "Button", _stylebox(Color(0.05, 0.2, 0.26), Color(0.2, 0.6, 0.75), 1, 8))
	theme.set_stylebox("hover", "Button", _stylebox(Color(0.08, 0.3, 0.38), Color(0.3, 0.8, 1.0), 1, 8))
	theme.set_stylebox("pressed", "Button", _stylebox(Color(0.1, 0.4, 0.5), Color(0.3, 0.8, 1.0), 1, 8))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("panel", "PanelContainer", _stylebox(Color(0.02, 0.05, 0.07, 0.96), Color(0.2, 0.75, 1.0, 0.8), 2, 24))
	ResourceSaver.save(theme, "res://ui/terminal_theme.tres")
	theme.take_over_path("res://ui/terminal_theme.tres")

	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.theme = theme
	screen.unique_name_in_owner = true
	_add(scene_root, screen, "Screen")

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(screen, dim, "Dim")

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(screen, center, "Center")

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 580)
	_add(center, panel, "Panel")

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_add(panel, vbox, "VBox")

	var header := HBoxContainer.new()
	_add(vbox, header, "Header")
	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.unique_name_in_owner = true
	_add(header, title, "ScreenTitle")
	var close := Button.new()
	close.text = "CLOSE [ESC]"
	close.unique_name_in_owner = true
	_add(header, close, "CloseButton")

	_add(vbox, HSeparator.new(), "HSeparator")

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	_add(vbox, body, "Body")
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(260, 0)
	list.unique_name_in_owner = true
	_add(body, list, "EntryList")
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.unique_name_in_owner = true
	_add(body, text, "EntryBody")

	_save(scene_root, "res://ui/hud.tscn")


# ---------- main scene ----------

func _update_main() -> void:
	scene_root = (load("res://main.tscn") as PackedScene).instantiate()
	for old in ["Ground", "CSGBox3D", "DirectionalLight3D"]:
		var n := scene_root.get_node_or_null(old)
		if n:
			scene_root.remove_child(n)
			n.free()

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://ship/space_sky.gdshader")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.5, 0.4)
	env.ambient_light_energy = 0.8
	env.tonemap_exposure = 1.05
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.5, 0.38, 0.3)
	env.fog_density = 0.018
	env.fog_sky_affect = 0.0
	scene_root.get_node("WorldEnvironment").environment = env

	var ship: Node = (load("res://ship/ship_interior.tscn") as PackedScene).instantiate()
	scene_root.add_child(ship)
	scene_root.move_child(ship, 1)
	ship.owner = scene_root

	# Start in the crew quarters, looking in at the bunk and desk.
	var player: Node3D = scene_root.get_node("Player")
	player.position = Vector3(-0.3, 1.1, -6.5)
	var pivot: Node3D = player.get_node("CameraPivot")
	pivot.position = Vector3(0, 0.75, 0)
	pivot.rotation = Vector3(-0.2, 0, 0)

	# Spring arm pulls the camera in when a wall is behind you.
	var cam: Camera3D = pivot.get_node("Camera3D")
	pivot.remove_child(cam)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	arm.spring_length = 2.4
	arm.position = Vector3(0.5, 0, 0)  # over the right shoulder
	arm.margin = 0.15
	var arm_shape := SphereShape3D.new()
	arm_shape.radius = 0.15
	arm.shape = arm_shape
	pivot.add_child(arm)
	arm.owner = scene_root
	cam.position = Vector3.ZERO
	arm.add_child(cam)
	cam.owner = scene_root

	# Swap the placeholder capsule for the character model.
	var capsule := player.get_node("MeshInstance3D")
	player.remove_child(capsule)
	capsule.free()
	var model: Node3D = (load("res://character/character.tscn") as PackedScene).instantiate()
	model.name = "Model"
	model.position = Vector3(0, -1.0, 0)
	player.add_child(model)
	player.move_child(model, 1)
	model.owner = scene_root

	var hum := AudioStreamPlayer.new()
	hum.name = "ShipHum"
	hum.set_script(load("res://ship/ship_hum.gd"))
	scene_root.add_child(hum)
	hum.owner = scene_root

	var hud: Node = (load("res://ui/hud.tscn") as PackedScene).instantiate()
	scene_root.add_child(hud)
	hud.owner = scene_root

	# Meki, dead on the engineering workbench, and the emergency power that
	# stays on until he's repaired.
	for old in ["Meki", "ShipPower"]:
		var n := scene_root.get_node_or_null(old)
		if n:
			scene_root.remove_child(n)
			n.free()
	var meki := CharacterBody3D.new()
	meki.name = "Meki"
	meki.set_script(load("res://characters/meki/meki.gd"))
	meki.position = Vector3(-5.95, 1.1, 1.1)
	scene_root.add_child(meki)
	meki.owner = scene_root
	var power := Node.new()
	power.name = "ShipPower"
	power.set_script(load("res://ship/ship_power.gd"))
	power.set("lights_path", NodePath("../ShipInterior/Lights"))
	power.set("hum_path", NodePath("../ShipHum"))
	scene_root.add_child(power)
	power.owner = scene_root

	_save(scene_root, "res://main.tscn")


# ---------- character ----------

func _char_mat(name: String, color: Color, rough := 0.8, metal := 0.0, emit := 0.0) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.6
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	var path := "res://character/materials/%s.tres" % name
	ResourceSaver.save(m, path)
	m.take_over_path(path)
	mats["char_" + name] = m


func _pivot(parent: Node, name: String, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	p.rotation = rot
	return _add(parent, p, name)


func _part(parent: Node, name: String, mesh: Mesh, mat: String, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mats["char_" + mat]
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	return _add(parent, mi, name)


# Low-poly mesh shapes (few sides on purpose, for the retro look).
func _tube(top: float, bottom: float, height: float, sides := 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	return m


func _ball(radius: float, sides := 10, rings := 6, hemisphere := false) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * (1.0 if hemisphere else 2.0)
	m.radial_segments = sides
	m.rings = rings
	m.is_hemisphere = hemisphere
	return m


func _block(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _donut(radius: float, thickness: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = radius - thickness
	m.outer_radius = radius + thickness
	m.rings = 12
	m.ring_segments = 6
	return m


# Rotation that points a mesh's +Y axis along `dir`.
func _aim(dir: Vector3) -> Vector3:
	return Basis(Quaternion(Vector3.UP, dir.normalized())).get_euler()



# Paints the face onto the head sphere's texture, N64 style.
# SphereMesh UVs wrap around: u=0.5 is the front (-Z), v=0 is the top.
# Features are laid out in meters on the face surface (x right = +X, y up).
func _paint_face() -> ImageTexture:
	const W := 512
	const H := 256
	const R := 0.16
	var skin := Color(0.86, 0.64, 0.5)
	var lid := Color(0.09, 0.06, 0.05)
	var iris_dark := Color(0.17, 0.09, 0.05)
	var iris_light := Color(0.45, 0.25, 0.11)
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for py in H:
		for px in W:
			var u := (px + 0.5) / W
			var v := (py + 0.5) / H
			var col := skin
			if absf(u - 0.5) < 0.2 and v > 0.3 and v < 0.75:
				var fx := (u - 0.5) * TAU * R
				var fy := (0.5 - v) * PI * R
				col = _face_pixel(fx, fy, skin, lid, iris_dark, iris_light)
			img.set_pixel(px, py, col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _face_pixel(fx: float, fy: float, skin: Color, lid: Color, iris_dark: Color, iris_light: Color) -> Color:
	var col := skin
	# Faint cheek blush.
	for side: float in [-1.0, 1.0]:
		var d := Vector2(fx - 0.078 * side, fy + 0.045).length()
		if d < 0.022:
			col = col.lerp(Color(0.92, 0.55, 0.48), 0.25 * (1.0 - d / 0.022))
	# Nose: a small shaded tick.
	if absf(fx - 0.006) < 0.006 and absf(fy + 0.032) < 0.004:
		col = col.lerp(Color(0.6, 0.38, 0.28), 0.8)
	# Mouth: short line with a slight curve.
	var my := -0.072 + 5.0 * fx * fx
	if absf(fx) < 0.02 and absf(fy - my) < 0.0035:
		col = col.lerp(Color(0.45, 0.2, 0.16), 0.9)
	# Eyes: big dark irises under a thick, flat upper lid that angles down
	# toward the nose for a determined look.
	for side: float in [-1.0, 1.0]:
		var ex := fx - 0.056 * side
		var ey := fy - 0.004
		var inward := -ex * side
		var lid_line := 0.024 - inward * 0.35
		var shape := (ex / 0.033) ** 2 + (ey / 0.04) ** 2
		var outline := (ex / 0.038) ** 2 + (ey / 0.046) ** 2
		if shape <= 1.0 and ey < lid_line:
			col = Color(0.97, 0.96, 0.93)
			var iris := Vector2(ex + 0.003 * side, ey + 0.002).length()
			if iris < 0.029:
				col = iris_dark.lerp(iris_light, clampf((-ey + 0.015) / 0.05, 0.0, 1.0))
			if iris < 0.013:
				col = Color(0.04, 0.03, 0.03)
			if Vector2(ex - 0.01, ey - 0.008).length() < 0.008:
				col = Color.WHITE
			if Vector2(ex + 0.009, ey + 0.014).length() < 0.0035:
				col = Color(0.85, 0.85, 0.9)
		elif outline <= 1.0 and ey > -0.015 and ey < lid_line + 0.014:
			col = lid
		elif outline <= 1.0 and ey < -0.034:
			col = col.lerp(lid, 0.35)
	return col


func _build_character() -> void:
	_char_mat("metal", Color(0.76, 0.76, 0.73), 0.4, 0.6)
	_char_mat("metal_dark", Color(0.26, 0.27, 0.29), 0.45, 0.7)
	_char_mat("copper", Color(0.68, 0.38, 0.22), 0.4, 0.8)
	_char_mat("cable", Color(0.55, 0.15, 0.1), 0.5)
	_char_mat("glow", Color(0.3, 0.85, 1.0), 0.3, 0.0, 4.0)

	# Adventurer by Quaternius (CC0), rotated to face -Z like the player.
	scene_root = Node3D.new()
	scene_root.name = "Character"
	scene_root.set_script(load("res://character/character_model.gd"))
	var model: Node3D = (load("res://character/adventurer.glb") as PackedScene).instantiate()
	model.name = "Adventurer"
	model.rotation.y = PI
	scene_root.add_child(model)
	model.owner = scene_root
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]

	# Cybernetic right arm, attached to the bones so it follows the animations.
	# The armature is scaled x100, so each attachment gets a x0.01 holder and
	# its parts are laid out in metres along the bone (+Y points down the arm).
	var upper := _bone_holder(skel, "UpperArm.R")
	_part(upper, "ShoulderPlate", _block(Vector3(0.15, 0.06, 0.15)), "metal", Vector3(0, 0.02, 0), Vector3(0, 0, 0.1))
	_part(upper, "PlateTrim", _block(Vector3(0.155, 0.015, 0.155)), "metal_dark", Vector3(0, -0.01, 0))
	_part(upper, "UpperSleeve", _tube(0.052, 0.046, 0.12), "metal_dark", Vector3(0, 0.12, 0))
	_part(upper, "Piston", _tube(0.011, 0.011, 0.14), "copper", Vector3(0.045, 0.1, 0.0))
	var fore := _bone_holder(skel, "LowerArm.R")
	_part(fore, "Elbow", _ball(0.055, 8, 6), "copper", Vector3(0, 0.0, 0))
	_part(fore, "Forearm", _tube(0.058, 0.048, 0.2, 8), "metal", Vector3(0, 0.11, 0))
	_part(fore, "Plate", _tube(0.062, 0.06, 0.06, 8), "metal_dark", Vector3(0, 0.05, 0))
	_part(fore, "CableA", _tube(0.011, 0.011, 0.18, 5), "cable", Vector3(0.055, 0.11, 0.0))
	_part(fore, "CableB", _tube(0.011, 0.011, 0.18, 5), "cable", Vector3(-0.02, 0.11, 0.052))
	_part(fore, "WristGlow", _donut(0.05, 0.011), "glow", Vector3(0, 0.215, 0))
	var hand := _bone_holder(skel, "Wrist.R")
	_part(hand, "HandPlate", _block(Vector3(0.075, 0.07, 0.03)), "metal", Vector3(0, 0.045, 0))
	_part(hand, "Palm", _tube(0.022, 0.022, 0.006, 8), "glow", Vector3(0, 0.05, 0.02), Vector3(PI / 2, 0, 0))
	var palm_light := OmniLight3D.new()
	palm_light.position = Vector3(0, 0.06, 0.06)
	palm_light.light_color = Color(0.3, 0.85, 1.0)
	palm_light.light_energy = 0.3
	palm_light.omni_range = 0.6
	_add(hand, palm_light, "PalmLight")

	_save(scene_root, "res://character/character.tscn")


func _bone_holder(_skel: Skeleton3D, bone: String) -> Node3D:
	# Saved under RobotArm; character_model.gd moves it onto the bone at runtime
	# (nodes added inside an imported model aren't kept when the scene is saved).
	var arm := scene_root.get_node_or_null("RobotArm")
	if arm == null:
		arm = _add(scene_root, Node3D.new(), "RobotArm")
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * 0.01
	holder.set_meta("bone", bone)
	return _add(arm, holder, bone.replace(".", ""))



# ---------- lounge ----------

const LOUNGE_C := Vector2(2.4, 1.6)   # (x, z) centre of the round lounge


func _lounge_xf(ang: float, r: float, y: float, face_in := true) -> Transform3D:
	var d := Vector2(cos(ang), sin(ang))
	var pos := Vector3(LOUNGE_C.x + d.x * r, y, LOUNGE_C.y + d.y * r)
	# +Z of the basis points into the room, +X along the curve.
	var inward := Vector3(-d.x, 0, -d.y)
	var tangent := Vector3(-d.y, 0, d.x)
	return Transform3D(Basis(tangent, Vector3.UP, inward if face_in else -inward), pos)


func _puff(parent: Node, name: String, xf: Transform3D, size: Vector3, mat: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 14
	sm.rings = 7
	mi.mesh = sm
	mi.material_override = mats[mat]
	_add(parent, mi, name)
	mi.transform = xf * Transform3D(Basis().scaled(size), Vector3.ZERO)
	return mi


# Cushion of size 1x1x1: puffed in the middle, thin at the seams, corners
# pinched. Higher `flat` gives a flatter face with rounded edges (pads).
func _cushion_mesh(flat: float, pinch: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	for side in [1.0, -1.0]:
		var pts := []
		for j in n + 1:
			var row := []
			for i in n + 1:
				var u := float(i) / n * 2.0 - 1.0
				var v := float(j) / n * 2.0 - 1.0
				var t := pow(maxf(0.0, (1.0 - pow(absf(u), flat)) * (1.0 - pow(absf(v), flat))), 0.5)
				var x := u * (1.0 - pinch * v * v) * 0.5
				var y := v * (1.0 - pinch * u * u) * 0.5
				row.append(Vector3(x, y, side * t * 0.5))
			pts.append(row)
		for j in n:
			for i in n:
				var a: Vector3 = pts[j][i]
				var b: Vector3 = pts[j][i + 1]
				var c: Vector3 = pts[j + 1][i + 1]
				var d: Vector3 = pts[j + 1][i]
				# Godot's front faces wind clockwise seen from outside.
				if side > 0:
					for q in [a, c, b, a, d, c]:
						st.add_vertex(q)
				else:
					for q in [a, b, c, a, c, d]:
						st.add_vertex(q)
	st.generate_normals()
	return st.commit()


func _cushion(parent: Node, name: String, mesh: Mesh, xf: Transform3D, size: Vector3, mat: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mats[mat]
	_add(parent, mi, name)
	mi.transform = xf * Transform3D(Basis().scaled(size), Vector3.ZERO)
	return mi


# Big curved Falcon-style couch in beige leather, a holo-table, throw
# pillows, gunmetal walls with ducts and wiring, and warm tube lights.
func _lounge() -> void:
	var L := _add(scene_root, Node3D.new(), "Lounge")
	var couch := _add(L, Node3D.new(), "Couch")
	var a0 := deg_to_rad(-64.0)
	var a1 := deg_to_rad(64.0)
	var segs := 12
	var da := (a1 - a0) / segs
	var body := StaticBody3D.new()
	_add(couch, body, "Collision")
	var pad_mesh := _cushion_mesh(10.0, 0.0)
	var pillow_mesh := _cushion_mesh(2.2, 0.12)
	for k in segs:
		var ang := a0 + da * (k + 0.5)
		var seg := _add(couch, Node3D.new(), "Seg%d" % k)
		seg.set_meta("angle", rad_to_deg(ang))
		var w := 4.2 * da
		# Base plinth, seat cushion with a rounded front roll, tufted back.
		var base := _mesh_box(seg, "Base", Vector3.ZERO, Vector3(w * 1.02, 0.3, 0.85), "metal_dark")
		base.transform = _lounge_xf(ang, 4.1, 0.15)
		var seat := _mesh_box(seg, "Seat", Vector3.ZERO, Vector3(w * 0.97, 0.16, 0.78), "couch_leather")
		seat.transform = _lounge_xf(ang, 4.1, 0.38)
		var seat_xf := _lounge_xf(ang, 4.08, 0.46)
		seat_xf.basis = seat_xf.basis * Basis(Vector3.RIGHT, -PI / 2)
		_cushion(seg, "SeatPad", pad_mesh, seat_xf, Vector3(w * 0.96, 0.76, 0.12), "couch_leather")
		var roll := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.1
		cap.height = w * 0.97
		cap.radial_segments = 12
		roll.mesh = cap
		roll.material_override = mats["couch_leather"]
		_add(seg, roll, "FrontRoll")
		roll.transform = _lounge_xf(ang, 3.74, 0.4) * Transform3D(Basis(Vector3.BACK, PI / 2), Vector3.ZERO)
		# Back: a darker leather frame holding two rows of sculpted
		# rectangular pads, with a rounded top roll.
		var back := _mesh_box(seg, "BackFrame", Vector3.ZERO, Vector3(w * 1.01, 0.78, 0.22), "couch_seam")
		back.transform = _lounge_xf(ang, 4.62, 0.86)
		for row in 2:
			for col in 2:
				var off := (col - 0.5) * w * 0.49
				var xf := _lounge_xf(ang, 4.5, 0.68 + row * 0.33)
				xf.origin += xf.basis.x * off
				_cushion(seg, "Pad%d%d" % [row, col], pad_mesh, xf, Vector3(w * 0.46, 0.3, 0.1), "couch_leather")
		var top := MeshInstance3D.new()
		var top_cap := CapsuleMesh.new()
		top_cap.radius = 0.09
		top_cap.height = w * 1.01
		top_cap.radial_segments = 12
		top.mesh = top_cap
		top.material_override = mats["couch_leather"]
		_add(seg, top, "TopRoll")
		top.transform = _lounge_xf(ang, 4.6, 1.26) * Transform3D(Basis(Vector3.BACK, PI / 2), Vector3.ZERO)
		var stud := _mesh_box(seg, "Switch", Vector3.ZERO, Vector3(0.05, 0.07, 0.02), "panel_led" if k % 3 else "panel_led_red")
		stud.transform = _lounge_xf(ang, 4.5, 1.2)
		stud.transform.origin += stud.transform.basis.x * (w * 0.45)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(w, 0.5, 0.9)
		cs.shape = shape
		_add(body, cs, "Shape%d" % k)
		cs.transform = _lounge_xf(ang, 4.1, 0.25)
	# Places to sit; the hologram turns to face whoever's sitting.
	for i in 5:
		var sa := -44.0 + i * 22.0
		var seat := _interactable(couch, "Seat%d" % i, "couch_seat", Vector3.ZERO,
			{"interact_range": 1.3, "media_path": NodePath("../../HoloTable/MediaPlayer")})
		seat.transform = _lounge_xf(deg_to_rad(sa), 3.98, 0.0, false)
		seat.set_meta("angle", sa)
	# Throw pillows leaning against the back.
	var pillows := [[-48.0, "pillow_rust", 0.25], [-30.0, "pillow_cream", -0.2], [22.0, "pillow_teal", 0.15],
		[38.0, "pillow_rust", -0.3], [52.0, "pillow_cream", 0.2]]
	for i in pillows.size():
		var pa := deg_to_rad(pillows[i][0])
		var xf := _lounge_xf(pa, 4.3, 0.72)
		xf.basis = xf.basis * Basis(Vector3.RIGHT, -0.45) * Basis(Vector3.BACK, pillows[i][2])
		var pillow := _cushion(couch, "Pillow%d" % i, pillow_mesh, xf, Vector3(0.52, 0.48, 0.22), pillows[i][1])
		pillow.set_meta("angle", pillows[i][0])

	# Holo-table: rounded rim, game-board top, pedestal and base disc.
	var table := _add(L, Node3D.new(), "HoloTable")
	table.position = Vector3(4.75, 0, 1.6)
	var tbody := StaticBody3D.new()
	_add(table, tbody, "Collision")
	var tcs := CollisionShape3D.new()
	var tshape := CylinderShape3D.new()
	tshape.radius = 0.75
	tshape.height = 0.78
	tcs.shape = tshape
	tcs.position.y = 0.39
	_add(tbody, tcs, "Shape")
	var base_disc := MeshInstance3D.new()
	base_disc.mesh = _scyl(0.55, 0.06, 32)
	base_disc.material_override = mats["metal_dark"]
	base_disc.position.y = 0.03
	_add(table, base_disc, "BaseDisc")
	var ped := MeshInstance3D.new()
	ped.mesh = _scyl(0.18, 0.66, 20)
	ped.material_override = mats["metal_dark"]
	ped.position.y = 0.39
	_add(table, ped, "Pedestal")
	var top := MeshInstance3D.new()
	top.mesh = _scyl(0.72, 0.08, 40)
	top.material_override = mats["counter"]
	top.position.y = 0.74
	_add(table, top, "Top")
	var rim := MeshInstance3D.new()
	var rt := TorusMesh.new()
	rt.inner_radius = 0.66
	rt.outer_radius = 0.8
	rt.rings = 40
	rt.ring_segments = 10
	rim.mesh = rt
	rim.material_override = mats["metal_dark"]
	rim.position.y = 0.74
	rim.scale = Vector3(1, 0.7, 1)
	_add(table, rim, "Rim")
	var board := MeshInstance3D.new()
	board.mesh = _scyl(0.6, 0.012, 40)
	var bm := ShaderMaterial.new()
	bm.shader = load("res://ship/holo_board.gdshader")
	ResourceSaver.save(bm, "res://ship/materials/holo_board.tres")
	bm.take_over_path("res://ship/materials/holo_board.tres")
	board.material_override = bm
	board.position.y = 0.785
	_add(table, board, "Board")
	for i in 8:
		var led := MeshInstance3D.new()
		led.mesh = _scyl(0.018, 0.012, 8)
		led.material_override = mats["panel_led" if i % 4 else "panel_led_red"]
		var la := TAU * i / 8.0
		led.position = Vector3(cos(la) * 0.73, 0.8, sin(la) * 0.73)
		_add(table, led, "Led%d" % i)
	# Holo-pad media player floating over the table (builds its own hologram).
	_interactable(table, "MediaPlayer", "holo_media_player", Vector3.ZERO, {"interact_range": 2.3})

	# Ducts, flex hose and wiring running along the top of the curved wall.
	var ducts := _add(L, Node3D.new(), "Ducts")
	var steps := 18
	for k in steps:
		var ang := a0 - 0.15 + (a1 - a0 + 0.3) * k / steps
		var ang2 := a0 - 0.15 + (a1 - a0 + 0.3) * (k + 1) / steps
		var p1 := Vector3(LOUNGE_C.x + cos(ang) * 4.45, 2.72, LOUNGE_C.y + sin(ang) * 4.45)
		var p2 := Vector3(LOUNGE_C.x + cos(ang2) * 4.45, 2.72, LOUNGE_C.y + sin(ang2) * 4.45)
		_pipe(ducts, "Duct%d" % k, p1, p2, 0.13, "metal_dark")
		if k % 2 == 0:
			_pipe(ducts, "DuctRib%d" % k, p1 - (p2 - p1).normalized() * 0.03, p1 + (p2 - p1).normalized() * 0.03, 0.16, "rib")
	# Flex hoses draped along under the duct, running between the end vents.
	var hose_anchors := []
	for k in 9:
		var ang := deg_to_rad(-70.0 + k * 17.5)
		var p := Vector3(LOUNGE_C.x + cos(ang) * 4.62, 2.44 if k % 2 else 2.5, LOUNGE_C.y + sin(ang) * 4.62)
		hose_anchors.append(_anchor(p, Vector3(-cos(ang), 0, -sin(ang)), 1.2))
	_hoses(ducts, "LoungeHoses", _hose_bundle(hose_anchors, 4, 67, 0.022, 0.05, 0.09))
	# Vent grilles and switch panels at each end of the window.
	for side in [-1.0, 1.0]:
		var ang := deg_to_rad(70.0 * side)
		var vent := _mesh_box(ducts, "Vent%d" % int(side), Vector3.ZERO, Vector3(0.7, 0.32, 0.1), "metal_dark")
		vent.transform = _lounge_xf(ang, 4.62, 2.2)
		for i in 5:
			var slat := _mesh_box(ducts, "Slat%d_%d" % [int(side), i], Vector3.ZERO, Vector3(0.62, 0.025, 0.02), "trim")
			slat.transform = _lounge_xf(ang, 4.56, 2.08 + i * 0.06)
		var panel := _mesh_box(ducts, "Panel%d" % int(side), Vector3.ZERO, Vector3(0.5, 0.36, 0.06), "trim")
		panel.transform = _lounge_xf(ang, 4.62, 1.45)
		for i in 4:
			var led := _mesh_box(ducts, "PanelLed%d_%d" % [int(side), i], Vector3.ZERO, Vector3(0.06, 0.04, 0.02), "panel_led" if i % 2 else "panel_led_red")
			led.transform = _lounge_xf(ang, 4.58, 1.38 + (i / 2) * 0.12)
			led.transform.origin += led.transform.basis.x * ((i % 2) * 0.18 - 0.09)
	# Warm tube lights glowing under the duct.
	for i in 4:
		var ang := deg_to_rad(-48.0 + i * 32.0)
		var tube := MeshInstance3D.new()
		var tc := CapsuleMesh.new()
		tc.radius = 0.05
		tc.height = 0.7
		tube.mesh = tc
		tube.material_override = mats["warm_tube"]
		_add(ducts, tube, "Tube%d" % i)
		tube.transform = _lounge_xf(ang, 4.4, 2.5) * Transform3D(Basis(Vector3.BACK, PI / 2), Vector3.ZERO)
		var tl := OmniLight3D.new()
		tl.light_color = Color(1.0, 0.72, 0.45)
		tl.light_energy = 0.55
		tl.omni_range = 3.2
		_add(ducts, tl, "TubeLight%d" % i)
		tl.transform = _lounge_xf(ang, 4.1, 2.3)


# Round Falcon-style entrance between the corridor and the lounge.
const LOUNGE_DOOR_R := 1.45
const LOUNGE_DOOR_C := Vector2(1.35, 1.0)  # (y, z) of the tunnel's axis


# Cylinder along x (from x0 to x1) around the lounge entrance axis, cut off
# below `floor_y` and at the ceiling.
func _lounge_tube(parent: Node, name: String, radius: float, x0: float, x1: float, floor_y: float, mat: String) -> CSGCombiner3D:
	var comb := _add(parent, CSGCombiner3D.new(), name)
	var c := CSGCylinder3D.new()
	c.radius = radius
	c.height = x1 - x0
	c.sides = 48
	c.rotation.z = PI / 2
	c.position = Vector3((x0 + x1) / 2.0, LOUNGE_DOOR_C.x, LOUNGE_DOOR_C.y)
	c.material = mats[mat]
	_add(comb, c, "Round")
	var clip := _box(comb, "Clip", Vector3(x0 - 0.1, floor_y, -2.0), Vector3(x1 + 0.1, 3.0, 4.0), mat)
	clip.operation = CSGShape3D.OPERATION_INTERSECTION
	return comb


# Flat grimy beige pads lining the entrance tunnel in staggered rings, with
# chunky frame rings at both mouths, little warm lamps and floor glow strips.
func _lounge_entrance() -> void:
	var E := _add(scene_root, Node3D.new(), "LoungeEntrance")
	var pad_mesh := _cushion_mesh(10.0, 0.0)
	var r := LOUNGE_DOOR_R
	var around := 18
	var rings := [[2.0, 2.47], [2.47, 2.94], [2.94, 3.4]]
	for i in rings.size():
		var x0: float = rings[i][0]
		var x1: float = rings[i][1]
		for k in around:
			var ang := TAU * (k + 0.5 * (i % 2)) / around
			var out := Vector3(0, cos(ang), sin(ang))
			var pos := Vector3((x0 + x1) / 2.0, LOUNGE_DOOR_C.x, LOUNGE_DOOR_C.y) + out * (r - 0.045)
			if pos.y < 0.3:
				continue
			var tangent := Vector3(0, -sin(ang), cos(ang))
			var inward := -out
			if tangent.cross(Vector3.RIGHT).dot(inward) < 0.0:
				tangent = -tangent
			var xf := Transform3D(Basis(tangent, Vector3.RIGHT, inward), pos)
			_cushion(E, "Pad%d_%d" % [i, k], pad_mesh, xf, Vector3(TAU * r / around - 0.08, x1 - x0 - 0.06, 0.09), "couch_leather")
	for x in [1.96, 3.42]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r - 0.1
		tm.outer_radius = r + 0.16
		tm.rings = 48
		tm.ring_segments = 10
		ring.mesh = tm
		ring.material_override = mats["pad_frame"]
		ring.position = Vector3(x, LOUNGE_DOOR_C.x, LOUNGE_DOOR_C.y)
		ring.rotation.z = PI / 2
		_add(E, ring, "Frame%d" % int(x * 100))
	# A row of small warm lamps up one side, like the Falcon's.
	var lamp := SphereMesh.new()
	lamp.radius = 0.045
	lamp.height = 0.05
	for i in 4:
		var ang := deg_to_rad(52.0 + i * 9.0)
		var mi := MeshInstance3D.new()
		mi.mesh = lamp
		mi.material_override = mats["warm_tube"]
		mi.position = Vector3(2.7, LOUNGE_DOOR_C.x + cos(ang) * (r - 0.1), LOUNGE_DOOR_C.y - sin(ang) * (r - 0.1))
		_add(E, mi, "Lamp%d" % i)
	for side in [-1.0, 1.0]:
		_mesh_box(E, "FloorGlow%d" % int(side), Vector3(2.7, 0.03, LOUNGE_DOOR_C.y + side * 0.78), Vector3(1.35, 0.02, 0.04), "led_strip")
	var glow := OmniLight3D.new()
	glow.position = Vector3(2.7, 2.2, LOUNGE_DOOR_C.y)
	glow.light_color = Color(1.0, 0.75, 0.5)
	glow.light_energy = 0.5
	glow.omni_range = 2.6
	_add(E, glow, "Glow")


# Rounded box (corner radius r) centred on the origin.
func _rounded_box_mesh(size: Vector3, r: float) -> ArrayMesh:
	var h := size / 2.0
	var inner := h - Vector3.ONE * r
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var first := 0
	for f in 6:
		var n: Vector3 = axes[f % 3] * (1.0 if f < 3 else -1.0)
		var u: Vector3 = axes[(f + 1) % 3]
		var v: Vector3 = axes[(f + 2) % 3]
		var su := _round_steps(absf(u.dot(h)), r)
		var sv := _round_steps(absf(v.dot(h)), r)
		for a in sv:
			for b in su:
				var q: Vector3 = n * absf(n.dot(h)) + u * b + v * a
				var c := q.clamp(-inner, inner)
				var d := (q - c).normalized()
				st.set_normal(d)
				st.add_vertex(c + d * r)
		var w := su.size()
		for j in sv.size() - 1:
			for i in w - 1:
				var a0 := first + j * w + i
				# u x v points out of the positive faces; Godot wants clockwise
				# winding seen from outside, so those faces are flipped.
				var tris := [a0, a0 + w, a0 + 1, a0 + 1, a0 + w, a0 + w + 1] if f < 3 else [a0, a0 + 1, a0 + w, a0 + 1, a0 + w + 1, a0 + w]
				for t in tris:
					st.add_index(t)
		first += w * sv.size()
	return st.commit()


# Sample positions across one axis of a rounded box face, bunched into the
# rounded edges.
func _round_steps(half: float, r: float) -> Array:
	var out := []
	for k in 4:
		out.append(-(half - r) - r * cos(k / 3.0 * PI / 2.0))
	for k in 4:
		out.append((half - r) + r * sin(k / 3.0 * PI / 2.0))
	return out


# Wooden bookshelf on the lounge's flat wall, packed with old books. Two of
# them (see Library) can be taken down and read.
func _bookshelf() -> void:
	var B := _furniture("Bookshelf")
	var x0 := 2.4
	var x1 := 2.76
	var z0 := 3.55
	var z1 := 4.85
	_box(B, "Back", Vector3(x0, 0, z0), Vector3(x0 + 0.04, 1.9, z1), "wood")
	_box(B, "SideA", Vector3(x0, 0, z0), Vector3(x1, 1.9, z0 + 0.04), "wood")
	_box(B, "SideB", Vector3(x0, 0, z1 - 0.04), Vector3(x1, 1.9, z1), "wood")
	_box(B, "Top", Vector3(x0, 1.86, z0), Vector3(x1 + 0.02, 1.92, z1), "wood")
	var shelves := [0.06, 0.5, 0.94, 1.38]
	for y in shelves:
		_box(B, "Shelf%d" % int(y * 100), Vector3(x0, y - 0.03, z0), Vector3(x1, y, z1), "wood")
	# Filler books as one coloured MultiMesh.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var colors := [Color(0.45, 0.12, 0.1), Color(0.14, 0.2, 0.36), Color(0.36, 0.38, 0.18), Color(0.62, 0.48, 0.2),
		Color(0.8, 0.75, 0.62), Color(0.3, 0.2, 0.13), Color(0.16, 0.32, 0.33), Color(0.5, 0.3, 0.32)]
	var spots := []  # [transform, color]
	var real_row := 2
	for row in shelves.size():
		var z := z0 + 0.05
		while z < z1 - 0.08:
			var w := rng.randf_range(0.025, 0.055)
			if row == real_row and z > 4.02 and z < 4.2:
				z = 4.2  # room for the readable books
				continue
			if rng.randf() < 0.06:
				z += rng.randf_range(0.05, 0.12)  # a gap
				continue
			var h := rng.randf_range(0.21, 0.33)
			var d := rng.randf_range(0.17, 0.23)
			var tilt := 0.0
			if rng.randf() < 0.07:
				tilt = rng.randf_range(0.12, 0.3)  # leaning on its neighbour
			var basis := Basis(Vector3.RIGHT, -tilt).scaled(Vector3(d, h, w))
			var pos := Vector3(x0 + 0.04 + d / 2.0, shelves[row] + h / 2.0 * cos(tilt), z + w / 2.0 + sin(tilt) * h / 2.0)
			spots.append([Transform3D(basis, pos), colors[rng.randi() % colors.size()].darkened(rng.randf_range(0.0, 0.25))])
			z += w + sin(tilt) * h + 0.002
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, spots[i][0])
		mm.set_instance_color(i, spots[i][1])
	var books := MultiMeshInstance3D.new()
	books.multimesh = mm
	var bm := StandardMaterial3D.new()
	bm.vertex_color_use_as_albedo = true
	bm.roughness = 0.85
	books.material_override = bm
	_add(scene_root, books, "ShelfBooks")
	# The readable ones, with gold titles down their spines.
	var font: Font = load("res://ui/fonts/LiberationSerif-Bold.ttf")
	for i in Library.BOOKS.size():
		var book: Dictionary = Library.BOOKS[i]
		var w := 0.06
		var h := 0.31
		var d := 0.22
		var z := 4.05 + i * (w + 0.008)
		var spine := _mesh_box(scene_root, "Book_" + book.id, Vector3(x0 + 0.04 + d / 2.0, shelves[real_row] + h / 2.0, z + w / 2.0), Vector3(d, h, w), "wood")
		var mat := StandardMaterial3D.new()
		mat.albedo_color = book.color
		mat.roughness = 0.7
		spine.material_override = mat
		var title := Label3D.new()
		title.text = String(book.title).to_upper()
		title.font = font
		title.font_size = 40
		title.pixel_size = 0.0005
		title.outline_size = 0
		title.modulate = Color(0.95, 0.8, 0.45)
		# Faces the room, reading top to bottom like a real spine.
		title.basis = Basis(Vector3.DOWN, Vector3(0, 0, -1), Vector3.RIGHT)
		title.position = Vector3(d / 2.0 + 0.002, 0, 0)
		_add(spine, title, "Title")
	_interactable(scene_root, "BookshelfUse", "bookshelf", Vector3(2.95, 1.0, 4.2), {"interact_range": 1.6})


# Reactor column beside the cockpit door, in the galley corner.
func _reactor_pod() -> void:
	var r := Node3D.new()
	r.set_script(load("res://ship/reactor.gd"))
	r.position = Vector3(2.85, 0, -6.0)
	_add(scene_root, r, "ReactorPod")
	var model: Node3D = (load("res://ship/models/reactor/reactor_pod.glb") as PackedScene).instantiate()
	model.scale = Vector3.ONE * 0.42
	r.add_child(model)
	model.owner = scene_root
	var body := StaticBody3D.new()
	_add(r, body, "Collision")
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.38
	cyl.height = 1.52
	cs.shape = cyl
	cs.position.y = 0.76
	_add(body, cs, "Shape")


# Barrel of salvage in engineering with parts poking out of the top.
func _parts_barrel(pos: Vector3) -> void:
	var b := _add(scene_root, Node3D.new(), "PartsBarrel")
	b.position = pos
	var solid := _add(b, CSGCombiner3D.new(), "Body")
	solid.use_collision = true
	_ccyl(solid, "Drum", 0.3, 0.86, Vector3(0, 0.43, 0), "barrel")
	_ccyl(solid, "Rim", 0.315, 0.04, Vector3(0, 0.86, 0), "metal_dark")
	var hole := _ccyl(solid, "Hollow", 0.27, 0.3, Vector3(0, 0.78, 0), "metal_dark")
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	# Junk: pipes, coils, capacitors and a panel at odd angles.
	var junk := [["pipe", Vector3(0.08, 0.95, 0.05), Vector3(0.3, 0, 0.4), "copper"],
		["pipe", Vector3(-0.1, 0.92, -0.06), Vector3(-0.45, 0.3, 0.1), "metal_dark"],
		["cap", Vector3(-0.05, 0.9, 0.12), Vector3(0.6, 0, -0.3), "panel_led"],
		["cap", Vector3(0.12, 0.88, -0.1), Vector3(-0.2, 0, 0.7), "hazard"],
		["coil", Vector3(-0.12, 0.86, 0.05), Vector3(1.2, 0.2, 0.3), "copper"],
		["panel", Vector3(0.02, 0.98, -0.12), Vector3(0.35, 0.6, -0.2), "trim"],
		["pipe", Vector3(0.14, 0.97, 0.12), Vector3(0.15, 0, -0.55), "cable"]]
	for i in junk.size():
		var j: Array = junk[i]
		var mi := MeshInstance3D.new()
		match j[0]:
			"pipe":
				mi.mesh = _scyl(0.025, 0.5, 10)
			"cap":
				mi.mesh = _scyl(0.035, 0.12, 12)
			"coil":
				var tm := TorusMesh.new()
				tm.inner_radius = 0.05
				tm.outer_radius = 0.08
				tm.rings = 16
				tm.ring_segments = 6
				mi.mesh = tm
			"panel":
				var bm := BoxMesh.new()
				bm.size = Vector3(0.22, 0.3, 0.015)
				mi.mesh = bm
		mi.material_override = mats[j[3]]
		mi.position = j[1]
		mi.rotation = j[2]
		_add(b, mi, "Junk%d" % i)


# Battered cream storage crates: rounded shell, lid seam, latches, side grips.
const CRATE := Vector3(0.9, 0.42, 0.6)

func _crates() -> void:
	var C := _add(scene_root, Node3D.new(), "Crates")
	var shell := _rounded_box_mesh(CRATE, 0.07)
	var seam := _rounded_box_mesh(Vector3(CRATE.x + 0.01, 0.014, CRATE.z + 0.01), 0.075)
	var grip := _rounded_box_mesh(Vector3(0.03, 0.09, 0.24), 0.012)
	var handle := _rounded_box_mesh(Vector3(0.24, 0.035, 0.07), 0.015)
	# [position on the floor, yaw, how many stacked]
	var spots := [[Vector3(1.66, 0, 6.05), PI / 2 + 0.04, 2], [Vector3(-1.97, 0, 7.85), PI / 2 - 0.06, 1],
		[Vector3(-3.2, 0, 2.95), 0.05, 2], [Vector3(4.45, 0, -4.5), 0.12, 1]]
	for i in spots.size():
		var base: Vector3 = spots[i][0]
		for level in spots[i][2]:
			var yaw: float = spots[i][1] + (0.09 if level == 1 else 0.0)
			var crate := Node3D.new()
			crate.position = base + Vector3(0, level * (CRATE.y + 0.005), 0)
			crate.rotation.y = yaw
			if crashed and level == 1:
				# Knocked half off the one below in the crash.
				crate.position += Vector3(0.12, -0.04, 0.1)
				crate.rotation += Vector3(0.0, 0.3, 0.1)
			_add(C, crate, "Crate%d_%d" % [i, level])
			var parts := [[shell, "crate", Vector3(0, CRATE.y / 2.0, 0)], [seam, "rib", Vector3(0, CRATE.y * 0.7, 0)],
				[handle, "crate", Vector3(0.18, CRATE.y + 0.012, 0.14)]]
			for side in [-1.0, 1.0]:
				parts.append([grip, "rib", Vector3(side * CRATE.x / 2.0, CRATE.y * 0.45, 0)])
				for lx in [-0.28, 0.28]:
					parts.append([null, "metal_dark", Vector3(lx, CRATE.y * 0.7, side * (CRATE.z / 2.0 + 0.008))])
			for k in parts.size():
				if parts[k][0] == null:
					_mesh_box(crate, "Latch%d" % k, parts[k][2], Vector3(0.05, 0.08, 0.02), parts[k][1])
					continue
				var mi := MeshInstance3D.new()
				mi.mesh = parts[k][0]
				mi.material_override = mats[parts[k][1]]
				mi.position = parts[k][2]
				_add(crate, mi, "Part%d" % k)
			var body := StaticBody3D.new()
			_add(crate, body, "Body")
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = CRATE
			cs.shape = box
			cs.position.y = CRATE.y / 2.0
			_add(body, cs, "Shape")


# ---------- flex hoses ----------

# Mostly beige, a few greyer ones, like old ship conduit.
const HOSE_TINTS := [Color(0.78, 0.74, 0.64), Color(0.72, 0.68, 0.58), Color(0.84, 0.81, 0.72),
	Color(0.67, 0.63, 0.55), Color(0.76, 0.74, 0.68), Color(0.53, 0.52, 0.5)]


# Anchor for _hose_bundle: where the bundle is fixed, which way is away from
# the surface it's fixed to, how much the span after it sags (1 = normal),
# extra stand-off (to clear a brace) and whether there's a bracket here.
func _anchor(p: Vector3, out: Vector3, sag := 1.0, lift := 0.0, strap := false) -> Dictionary:
	return {"p": p, "out": out.normalized(), "sag": sag, "lift": lift, "strap": strap}


# Smooth path through `pts` (Catmull-Rom), sampled about every `step` metres.
func _spline(pts: Array, step := 0.09) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := pts.size()
	for i in n - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, n - 1)]
		var steps := maxi(2, ceili(p1.distance_to(p2) / step))
		for s in steps:
			var t := float(s) / steps
			out.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t * t * t))
	out.append(pts[n - 1])
	return out


# Appends a tube swept along `path` to `st` and returns the next free vertex
# index. UV.x is metres along the hose, restarted every HOSE_UV_WRAP (a whole
# number of ribs) because GPUs lose the precision for fine ribs on big values;
# the ring at each restart is doubled so the ribs stay seamless.
const HOSE_UV_WRAP := 0.6

func _sweep(st: SurfaceTool, path: PackedVector3Array, radius: float, tint: Color, first: int) -> int:
	var sides := 9
	var ring := sides + 1
	var t := (path[1] - path[0]).normalized()
	var nrm := t.cross(Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT).normalized()
	var length := 0.0
	var base := 0.0
	var rings := 0
	for i in path.size():
		var prev_t := t
		if i == path.size() - 1:
			t = (path[i] - path[i - 1]).normalized()
		elif i > 0:
			t = (path[i + 1] - path[i - 1]).normalized()
		if i > 0:
			length += path[i].distance_to(path[i - 1])
			# Parallel transport keeps the rings from twisting.
			var axis := prev_t.cross(t)
			if axis.length() > 0.0001:
				nrm = nrm.rotated(axis.normalized(), prev_t.angle_to(t))
		nrm = (nrm - t * nrm.dot(t)).normalized()
		var bin := t.cross(nrm)
		var us := [length - base]
		if length - base >= HOSE_UV_WRAP:
			base += floorf((length - base) / HOSE_UV_WRAP) * HOSE_UV_WRAP
			us.append(length - base)
		for n in us.size():
			if i > 0 and n == 0:
				var a := first + (rings - 1) * ring
				for k in sides:
					for v in [a + k, a + ring + k, a + k + 1, a + k + 1, a + ring + k, a + ring + k + 1]:
						st.add_index(v)
			for k in ring:
				var ang := TAU * k / sides
				var d := nrm * cos(ang) + bin * sin(ang)
				st.set_color(tint)
				st.set_normal(d)
				# Tangent runs along the hose, which is the way the ribs bump.
				st.set_tangent(Plane(t, 1.0))
				st.set_uv(Vector2(us[n], float(k) / sides))
				st.add_vertex(path[i] + d * radius)
			rings += 1
	return first + rings * ring


# Builds hose runs into one mesh (saved next to the ship's materials so the
# scenes stay small) with white zip ties. Each run: {"pts", "r", "tint", "ties"}
# where "ties" lists indices into "pts".
func _hoses(parent: Node, name: String, runs: Array) -> Node3D:
	var node := _add(parent, Node3D.new(), name)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var first := 0
	var ties: Array[Transform3D] = []
	for run: Dictionary in runs:
		var pts: Array = run.pts
		first = _sweep(st, _spline(pts), run.r, run.tint, first)
		for i: int in run.ties:
			var tan: Vector3 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
			var side := tan.cross(Vector3.UP if absf(tan.y) < 0.9 else Vector3.RIGHT).normalized()
			var s: float = run.r * 1.05
			ties.append(Transform3D(Basis(side * s, tan * s, side.cross(tan) * s), pts[i]))
	var path := "res://ship/meshes/%s.res" % name.to_snake_case()
	DirAccess.make_dir_recursive_absolute("res://ship/meshes")
	ResourceSaver.save(st.commit(), path)
	var mi := MeshInstance3D.new()
	mi.mesh = load(path)
	mi.material_override = mats["hose"]
	_add(node, mi, "Hoses")
	if ties.size() > 0:
		var tie := TorusMesh.new()
		tie.inner_radius = 0.92
		tie.outer_radius = 1.12
		tie.rings = 12
		tie.ring_segments = 4
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = tie
		mm.instance_count = ties.size()
		for i in ties.size():
			mm.set_instance_transform(i, ties[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mats["tie"]
		_add(node, mmi, "Ties")
	return node


# A loose bundle of `count` hoses strung between anchors. Every hose gets
# its own thickness, colour, stand-off and sag, and wanders a little at each
# anchor, so they cross over and droop unevenly instead of running in lines.
func _hose_bundle(anchors: Array, count: int, seed: int, rmin := 0.025, rmax := 0.055, sag := 0.07) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var spacing := (rmin + rmax) * 1.1
	var runs := []
	for i in count:
		var r := rng.randf_range(rmin, rmax)
		var slot := (i - (count - 1) / 2.0) * spacing
		var stand := rng.randf_range(0.0, 0.05)
		var sag_i := sag * rng.randf_range(0.3, 1.7)
		var qs := []
		for j in anchors.size():
			var a: Dictionary = anchors[j]
			var dir: Vector3 = (anchors[mini(j + 1, anchors.size() - 1)].p - anchors[maxi(j - 1, 0)].p).normalized()
			var spread: Vector3 = a.out.cross(dir).normalized()
			qs.append(a.p + spread * (slot + rng.randf_range(-0.03, 0.03))
				+ a.out * (r + stand + a.lift + rng.randf_range(-0.01, 0.02)))
		var pts := []
		var ties := []
		for j in qs.size():
			if j > 0 and j < qs.size() - 1 and rng.randf() < 0.75:
				ties.append(pts.size())
			pts.append(qs[j])
			if j == qs.size() - 1:
				break
			var span: float = qs[j].distance_to(qs[j + 1])
			if span > 0.45:
				var flat := 1.0 - absf((qs[j + 1] - qs[j]).normalized().y)
				var out: Vector3 = anchors[j].out
				pts.append((qs[j] + qs[j + 1]) / 2.0 + Vector3.DOWN * sag_i * span * flat * anchors[j].sag
					+ out * rng.randf_range(-0.01, 0.04))
		runs.append({"pts": pts, "r": r, "tint": HOSE_TINTS[rng.randi() % HOSE_TINTS.size()], "ties": ties})
	return runs


# Dark metal strap holding a bundle at an anchor, with legs back to the surface.
func _hose_straps(parent: Node, tag: String, anchors: Array, count: int, rmax: float) -> void:
	var width := count * rmax * 2.2 + 0.1
	for j in anchors.size():
		var a: Dictionary = anchors[j]
		if not a.strap:
			continue
		var dir: Vector3 = (anchors[mini(j + 1, anchors.size() - 1)].p - anchors[maxi(j - 1, 0)].p).normalized()
		var spread: Vector3 = a.out.cross(dir).normalized()
		var depth: float = a.lift + rmax * 2.0 + 0.08
		var basis := Basis(spread, dir, a.out)
		var bar := _mesh_box(parent, tag + "Strap%d" % j, Vector3.ZERO, Vector3(width, 0.05, 0.025), "metal_dark")
		bar.transform = Transform3D(basis, a.p + a.out * depth)
		for side in [-1.0, 1.0]:
			var leg := _mesh_box(parent, tag + "StrapLeg%d_%d" % [j, int(side)], Vector3.ZERO, Vector3(0.025, 0.05, depth), "metal_dark")
			leg.transform = Transform3D(basis, a.p + spread * side * width * 0.5 + a.out * depth * 0.5)


# Single hand-routed hose with ties at its inner points.
func _hose_run(pts: Array, r: float, tint: Color) -> Dictionary:
	return {"pts": pts, "r": r, "tint": tint, "ties": range(1, pts.size() - 1)}


func _junction_box(parent: Node, name: String, pos: Vector3, size: Vector3) -> void:
	_mesh_box(parent, name, pos, size, "metal_dark")
	# Status light on the face toward the room (boxes sit on the side walls).
	_mesh_box(parent, name + "Led", pos + Vector3(-signf(pos.x) * size.x * 0.5, size.y * 0.25, 0), Vector3(0.012, 0.025, 0.025), "panel_led")


# Hoses down the main corridor and through engineering, the galley and the
# cockpit. Along the corridor they ride the angled ceiling edges, bump over
# the braces at each rib, droop between them and peel off around doors.
func _ship_hoses() -> void:
	var root := _add(scene_root, Node3D.new(), "FlexHoses")
	var B := 0.7071
	# Left ceiling edge: the bevel face is x = y - 4.69.
	var out_l := Vector3(B, -B, 0)
	var left := []
	for a in [[-5.6, 1.0, 0.0, false], [-4.5, 0.4, 0.0, false], [-1.6, 1.0, 0.13, true], [-0.35, 0.25, 0.0, false],
			[2.45, 1.0, 0.0, false], [3.2, 0.35, 0.13, true], [5.4, 0.35, 0.13, true], [7.2, 1.2, 0.0, false],
			[8.9, 1.0, 0.13, true], [9.2, 1.0, 0.0, false]]:
		left.append(_anchor(Vector3(-2.13, 2.56, a[0]), out_l, a[1], a[2], a[3]))
	var right := []
	var out_r := Vector3(-B, -B, 0)
	for a in [[-5.6, 1.0, 0.0, false], [-3.7, 1.0, 0.0, false], [-1.6, 0.8, 0.13, true], [-0.5, 0.35, 0.0, false],
			[2.5, 1.0, 0.0, false], [3.2, 1.3, 0.13, true], [5.4, 1.0, 0.13, true], [8.9, 1.0, 0.13, true],
			[9.2, 1.0, 0.0, false]]:
		right.append(_anchor(Vector3(1.73, 2.66, a[0]), out_r, a[1], a[2], a[3]))
	var corridor := _hose_bundle(left, 5, 11, 0.025, 0.058) + _hose_bundle(right, 4, 23, 0.022, 0.048)
	var c1 := Color(0.78, 0.74, 0.64)
	var c2 := Color(0.68, 0.64, 0.55)
	# Drop beside the bathroom door into a junction box.
	corridor.append(_hose_run([Vector3(-2.1, 2.42, -5.0), Vector3(-2.19, 1.95, -4.68), Vector3(-2.23, 1.6, -4.5), Vector3(-2.24, 1.36, -4.45)], 0.04, c1))
	corridor.append(_hose_run([Vector3(-2.05, 2.36, -5.2), Vector3(-2.17, 1.9, -4.82), Vector3(-2.24, 1.6, -4.5), Vector3(-2.25, 1.36, -4.4)], 0.028, c2))
	_junction_box(root, "BoxBath", Vector3(-2.25, 1.22, -4.45), Vector3(0.1, 0.3, 0.22))
	# Up and over the engineering door frame and down the far side.
	for k in 2:
		var dx := -2.21 + k * 0.07
		var dz := k * 0.06
		var top := 2.34 + k * 0.05
		corridor.append(_hose_run([Vector3(-2.24, 0.95, -0.38 - dz), Vector3(dx, 1.4, -0.3 - dz), Vector3(dx, 2.05, -0.24 - dz),
			Vector3(dx, top, 0.15), Vector3(dx, top + 0.03, 1.1), Vector3(dx, top, 2.05), Vector3(dx, 2.0, 2.44 + dz),
			Vector3(dx, 1.45, 2.5 + dz), Vector3(-2.24, 1.1, 2.56 + dz)], 0.05 - k * 0.015, c1 if k == 0 else Color(0.48, 0.47, 0.44)))
	_junction_box(root, "BoxEngA", Vector3(-2.25, 0.8, -0.42), Vector3(0.1, 0.3, 0.24))
	_junction_box(root, "BoxEngB", Vector3(-2.25, 0.95, 2.6), Vector3(0.1, 0.3, 0.24))
	# One feeding the exhaust unit.
	corridor.append(_hose_run([Vector3(-2.12, 2.4, 4.85), Vector3(-2.04, 2.47, 5.25), Vector3(-2.0, 2.44, 5.5), Vector3(-1.98, 2.3, 5.62)], 0.045, c2))
	# Right side: one drops to a floor box beside the lounge door.
	corridor.append(_hose_run([Vector3(1.8, 2.55, 2.55), Vector3(1.9, 1.9, 2.62), Vector3(1.93, 0.9, 2.65), Vector3(1.92, 0.3, 2.67)], 0.04, c1))
	_junction_box(root, "BoxLounge", Vector3(1.9, 0.14, 2.67), Vector3(0.16, 0.28, 0.22))
	# A few strung across the ceiling between the two sides.
	for c in [[-0.95, 0.04, c1], [-0.8, 0.03, c2], [4.75, 0.05, c2], [4.92, 0.032, Color(0.47, 0.46, 0.43)]]:
		var z: float = c[0]
		corridor.append(_hose_run([Vector3(-2.06, 2.64, z - 0.12), Vector3(-1.65, 2.9, z - 0.06), Vector3(-0.2, 2.76 - c[1], z),
			Vector3(1.25, 2.9, z + 0.06), Vector3(1.68, 2.7, z + 0.12)], c[1], c[2]))
	var cn := _hoses(root, "CorridorHoses", corridor)
	_hose_straps(cn, "Left", left, 5, 0.058)
	_hose_straps(cn, "Right", right, 4, 0.048)

	# Engineering: a droopy bundle from the back corner plugs into the
	# reactor cap, and two fat feeds snake across the floor to the power panel.
	var eng := []
	for p in [Vector3(-6.28, 2.9, 2.6), Vector3(-5.3, 2.93, 2.0), Vector3(-4.6, 2.93, 0.4), Vector3(-4.75, 2.9, -1.28)]:
		eng.append(_anchor(p, Vector3.DOWN, 1.0))
	var eng_runs := _hose_bundle(eng, 5, 37, 0.03, 0.065, 0.12)
	eng_runs.append(_hose_run([Vector3(-3.5, 0.15, -0.35), Vector3(-3.95, 0.065, 0.05), Vector3(-4.6, 0.065, 0.12),
		Vector3(-5.08, 0.065, -0.45), Vector3(-5.14, 0.3, -1.0), Vector3(-5.12, 0.82, -1.24)], 0.065, c1))
	eng_runs.append(_hose_run([Vector3(-3.55, 0.12, -0.55), Vector3(-4.0, 0.05, -0.3), Vector3(-4.68, 0.05, -0.32),
		Vector3(-4.84, 0.07, -0.75), Vector3(-4.8, 0.4, -1.1), Vector3(-4.78, 0.84, -1.24)], 0.05, c2))
	_hoses(root, "EngineeringHoses", eng_runs)

	# Galley: three along the ceiling corner over the cabinets.
	var galley := []
	for z in [-6.8, -5.7, -4.5, -3.4]:
		galley.append(_anchor(Vector3(5.5, 2.86, z), Vector3(-B, -B, 0)))
	_hoses(root, "GalleyHoses", _hose_bundle(galley, 3, 41, 0.025, 0.045))

	# Cockpit: a bundle along the leaning right wall, one hose dropping into
	# the computer bench.
	var lean := Vector3(-0.986, -0.168, 0)
	var cockpit := []
	for a in [[-6.95, 1.0, false], [-8.0, 1.0, true], [-9.0, 1.0, false], [-9.8, 1.0, false]]:
		cockpit.append(_anchor(Vector3(5.31, 2.6, a[0]), lean, a[1], 0.0, a[2]))
	var cockpit_runs := _hose_bundle(cockpit, 3, 53, 0.025, 0.05)
	cockpit_runs.append(_hose_run([Vector3(5.22, 2.5, -9.0), Vector3(5.36, 1.7, -9.15), Vector3(5.43, 1.12, -9.22), Vector3(5.45, 0.86, -9.25)], 0.035, c1))
	_hose_straps(_hoses(root, "CockpitHoses", cockpit_runs), "", cockpit, 3, 0.05)


# ---------- exterior ----------

# Side profile given as (z, y) points, extruded across x from x_from down to x_to.
func _profile_x(parent: Node, name: String, pts: Array, x_from: float, x_to: float, mat: String) -> CSGPolygon3D:
	var poly := PackedVector2Array()
	for q: Vector2 in pts:
		poly.append(Vector2(-q.x, q.y))
	var c := CSGPolygon3D.new()
	c.polygon = poly
	c.depth = x_from - x_to
	c.rotation.y = PI / 2
	c.position.x = x_from
	c.material = mats[mat]
	return _add(parent, c, name)


# Front profile given as (x, y) points, extruded along z from z_back to z_front.
func _profile_z(parent: Node, name: String, pts: Array, z_back: float, z_front: float, mat: String) -> CSGPolygon3D:
	var c := CSGPolygon3D.new()
	c.polygon = PackedVector2Array(pts)
	c.depth = z_back - z_front
	c.position.z = z_back
	c.material = mats[mat]
	return _add(parent, c, name)


func _exterior() -> void:
	var R := scene_root
	var ext := _add(R, CSGCombiner3D.new(), "Exterior")
	ext.use_collision = true
	# Nose under the canopy and a sloped fairing on the body's front face.
	_profile_x(ext, "NoseCone", [Vector2(-12.85, -0.2), Vector2(-12.85, 0.95), Vector2(-13.6, 0.8),
		Vector2(-14.3, 0.3), Vector2(-14.1, -0.2)], 5.9, 2.1, "hull_outer")
	_profile_x(ext, "FrontFairing", [Vector2(-9.85, -0.2), Vector2(-9.85, 3.2), Vector2(-10.6, 2.6),
		Vector2(-11.7, 0.5), Vector2(-11.6, -0.2)], 2.1, -7.7, "hull_outer")
	# Dorsal ridge along the spine.
	_profile_x(ext, "DorsalRidge", [Vector2(-9.8, 3.15), Vector2(-8.6, 3.75), Vector2(7.6, 3.75),
		Vector2(9.4, 3.15)], 1.6, -4.6, "hull_outer")
	_profile_x(ext, "DorsalCap", [Vector2(-8.0, 3.7), Vector2(-7.4, 3.9), Vector2(6.6, 3.9), Vector2(7.2, 3.7)], 0.4, -3.4, "trim")
	# Wings sloping down to both sides, with stepped (swept) outer sections and low tip rails
	# (kept below the lounge window line so they don't show over the couch).
	var wing_l := _add(ext, CSGCombiner3D.new(), "WingLeft")
	_profile_z(wing_l, "Inner", [Vector2(-7.65, 0.7), Vector2(-7.65, 1.15), Vector2(-11.0, 0.45), Vector2(-11.0, 0.2)], 7.5, -9.3, "hull_outer")
	_profile_z(wing_l, "Outer", [Vector2(-10.9, 0.22), Vector2(-10.9, 0.47), Vector2(-14.0, -0.1), Vector2(-14.0, -0.25)], 6.5, -4.5, "hull_outer")
	_profile_x(wing_l, "TipFin", [Vector2(-4.0, -0.3), Vector2(-3.4, 0.25), Vector2(4.7, 0.25), Vector2(6.3, -0.3)], -13.75, -14.05, "hull_outer")
	var wing_r := _add(ext, CSGCombiner3D.new(), "WingRight")
	_profile_z(wing_r, "Inner", [Vector2(5.85, 0.55), Vector2(5.85, 0.95), Vector2(10.0, 0.35), Vector2(10.0, 0.1)], 8.5, -6.8, "hull_outer")
	_profile_z(wing_r, "Outer", [Vector2(9.9, 0.12), Vector2(9.9, 0.37), Vector2(12.8, -0.15), Vector2(12.8, -0.3)], 7.5, -3.0, "hull_outer")
	# Carve the wing root out of the lounge's round bulge.
	var lounge_hole := _ccyl(wing_r, "LoungeClearance", 4.75, 3.2, Vector3(2.4, 1.5, 1.6), "hull_outer")
	lounge_hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	_profile_x(wing_r, "TipFin", [Vector2(-2.5, -0.35), Vector2(-1.9, 0.2), Vector2(6.0, 0.2), Vector2(7.3, -0.35)], 12.85, 12.55, "hull_outer")
	# Engine block and six thrusters around the ramp door.
	_box(ext, "EngineBlockL", Vector3(-7.4, 0.1, 9.45), Vector3(-1.9, 3.1, 10.1), "metal_dark")
	_box(ext, "EngineBlockR", Vector3(1.9, 0.1, 9.45), Vector3(5.7, 3.1, 10.1), "metal_dark")
	_box(ext, "RampDoorOuter", Vector3(-1.55, -0.15, 9.45), Vector3(1.55, 2.65, 9.6), "hazard")
	_box(ext, "RampHinge", Vector3(-1.6, -0.2, 9.5), Vector3(1.6, 0.05, 9.75), "metal_dark")
	var thrusters := [Vector2(-6.2, 0.95), Vector2(-4.2, 0.95), Vector2(-5.2, 2.35),
		Vector2(2.95, 0.95), Vector2(4.75, 0.95), Vector2(3.85, 2.35)]
	for i in thrusters.size():
		var t: Vector2 = thrusters[i]
		var bell := CSGCylinder3D.new()
		bell.radius = 0.72
		bell.height = 1.3
		bell.sides = 16
		bell.cone = false
		bell.rotation.x = PI / 2
		bell.position = Vector3(t.x, t.y, 10.7)
		bell.material = mats["metal_dark"]
		_add(ext, bell, "Thruster%d" % i)
		var hollow := CSGCylinder3D.new()
		hollow.radius = 0.56
		hollow.height = 1.0
		hollow.sides = 16
		hollow.rotation.x = PI / 2
		hollow.position = Vector3(t.x, t.y, 11.0)
		hollow.material = mats["scorched"] if mats.has("scorched") else mats["cable"]
		hollow.operation = CSGShape3D.OPERATION_SUBTRACTION
		_add(ext, hollow, "ThrusterHollow%d" % i)
		var ring := CSGTorus3D.new()
		ring.inner_radius = 0.66
		ring.outer_radius = 0.8
		ring.sides = 16
		ring.ring_sides = 6
		ring.rotation.x = PI / 2
		ring.position = Vector3(t.x, t.y, 11.3)
		ring.material = mats["copper"]
		_add(ext, ring, "ThrusterRim%d" % i)
		var core := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.54
		disc.bottom_radius = 0.54
		disc.height = 0.02
		disc.radial_segments = 16
		core.mesh = disc
		core.rotation.x = PI / 2
		core.position = Vector3(t.x, t.y, 10.55)
		core.material_override = mats["metal_dark"] if crashed else mats["thruster_glow"]
		_add(R, core, "ThrusterCore%d" % i)
	# Turret dome with twin barrels over the gunner station.
	var turret := Node3D.new()
	turret.position = Vector3(-5.0, 3.2, 5.6)
	_add(R, turret, "Turret")
	_mesh_box(turret, "Mount", Vector3(0, 0.12, 0), Vector3(1.6, 0.24, 1.6), "metal_dark")
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.8
	dm.height = 0.8
	dm.is_hemisphere = true
	dm.radial_segments = 16
	dm.rings = 6
	dome.mesh = dm
	dome.position.y = 0.24
	dome.material_override = mats["hull_outer"]
	_add(turret, dome, "Dome")
	_mesh_box(turret, "Visor", Vector3(0, 0.55, 0.55), Vector3(0.7, 0.18, 0.12), "glass")
	for i in 2:
		var x := -0.22 + i * 0.44
		var barrel := Node3D.new()
		barrel.position = Vector3(x, 0.55, 0.5)
		_add(turret, barrel, "Barrel%d" % i)
		_pipe(barrel, "Tube", Vector3.ZERO, Vector3(0, 0, 1.9), 0.07, "metal_dark")
		_pipe(barrel, "Muzzle", Vector3(0, 0, 1.75), Vector3(0, 0, 2.0), 0.1, "metal_dark")
		if crashed and i == 1:
			barrel.rotation = Vector3(0.35, 0.4, 0)
	# Side hatch on the cockpit tower, window trim around the lounge, side stripe.
	_box(ext, "HatchFrame", Vector3(5.85, 0.0, -9.3), Vector3(6.05, 2.3, -7.3), "metal_dark")
	_box(ext, "HatchDoor", Vector3(6.0, 0.15, -9.1), Vector3(6.1, 2.15, -7.5), "hull_outer")
	_box(ext, "HatchStripe", Vector3(6.08, 2.15, -9.1), Vector3(6.12, 2.3, -7.5), "hazard")
	var trim := _add(R, CSGCombiner3D.new(), "WindowTrim")
	for y in [0.92, 2.58]:
		var band := _half_cyl(trim, "Band%d" % int(y * 100), 5.05, 0.14, y, Vector3(5.95, -1, -5), Vector3(8, 4, 9), "metal_dark")
		var inner := _ccyl(band, "Inner", 4.9, 0.3, Vector3(2.4, y, 1.6), "metal_dark")
		inner.operation = CSGShape3D.OPERATION_SUBTRACTION
	_box(ext, "StripeLeft", Vector3(-7.75, 1.9, -9.6), Vector3(-7.65, 2.15, 9.4), "stripe")
	# Right stripe stops either side of the lounge's bulge so it doesn't cut through the room.
	_box(ext, "StripeRight", Vector3(5.85, 2.65, -9.6), Vector3(5.95, 2.9, -2.0), "stripe")
	_box(ext, "StripeRightAft", Vector3(5.85, 2.65, 5.2), Vector3(5.95, 2.9, 9.4), "stripe")
	_box(ext, "StripeNose", Vector3(2.05, 0.75, -12.95), Vector3(5.95, 0.92, -12.8), "stripe")
	if crashed:
		# Right wing torn off where the hull is breached; trim follows the breach.
		var tear := _box(wing_r, "Torn", Vector3(5.5, -1.0, -0.4), Vector3(13.5, 2.0, 5.2), "scorched", true)
		tear.operation = CSGShape3D.OPERATION_SUBTRACTION
		_add(trim, _breach_cutter(1.15), "Breach")
		var char_l := _box(ext, "Scorch", Vector3(-7.8, 0.2, 4.0), Vector3(-7.6, 2.8, 9.4), "scorched")
		char_l.operation = CSGShape3D.OPERATION_UNION


# ---------- crash version ----------

func _wmat(name: String, color: Color, rough := 0.9, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	var path := "res://world/materials/%s.tres" % name
	ResourceSaver.save(m, path)
	m.take_over_path(path)
	mats[name] = m
	return m


func _fol_mat(name: String, palette: Array, texel: float, ragged := 0.0, grain := 1.0, bands := 1.0) -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://world/pixel_foliage.gdshader")
	for i in 4:
		m.set_shader_parameter(["c_dark", "c_mid", "c_light", "c_high"][i], palette[i])
	m.set_shader_parameter("texel", texel)
	m.set_shader_parameter("ragged", ragged)
	m.set_shader_parameter("grain", grain)
	m.set_shader_parameter("bands", bands)
	var path := "res://world/materials/%s.tres" % name
	ResourceSaver.save(m, path)
	m.take_over_path(path)
	mats[name] = m


func _terrain_mat(name: String, dirt: float) -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://world/terrain.gdshader")
	m.set_shader_parameter("dirt_amount", dirt)
	m.set_shader_parameter("flowers", 0.0 if dirt > 0.5 else 1.0)
	var path := "res://world/materials/%s.tres" % name
	ResourceSaver.save(m, path)
	m.take_over_path(path)
	mats[name] = m


func _make_world_materials() -> void:
	if mats.has("scorched"):
		return
	_wmat("scorched", Color(0.12, 0.1, 0.09), 0.85, 0.5)
	_wmat("emergency", Color(1.0, 0.12, 0.08), 0.5, 0.0, 2.5)
	_wmat("spark", Color(1.0, 0.7, 0.3), 0.5, 0.0, 6.0)
	_fol_mat("bark", [Color(0.16, 0.07, 0.05), Color(0.33, 0.15, 0.08), Color(0.5, 0.25, 0.13), Color(0.64, 0.38, 0.2)], 0.14, 0.0, 4.0, 2.0)
	_fol_mat("bark_light", [Color(0.2, 0.14, 0.1), Color(0.34, 0.25, 0.17), Color(0.48, 0.37, 0.25), Color(0.62, 0.5, 0.34)], 0.12, 0.0, 3.0, 2.0)
	_fol_mat("canopy", [Color(0.06, 0.2, 0.1), Color(0.14, 0.38, 0.13), Color(0.3, 0.58, 0.15), Color(0.5, 0.74, 0.24)], 0.2, 0.55)
	_fol_mat("pine", [Color(0.03, 0.13, 0.1), Color(0.07, 0.24, 0.15), Color(0.14, 0.37, 0.18), Color(0.3, 0.52, 0.22)], 0.22, 0.4)
	_fol_mat("bush", [Color(0.07, 0.24, 0.1), Color(0.17, 0.44, 0.14), Color(0.34, 0.64, 0.18), Color(0.62, 0.84, 0.3)], 0.14, 0.38)
	_fol_mat("rock", [Color(0.26, 0.28, 0.27), Color(0.4, 0.42, 0.4), Color(0.55, 0.56, 0.52), Color(0.68, 0.7, 0.62)], 0.12)
	_fol_mat("moss_rock", [Color(0.2, 0.26, 0.2), Color(0.33, 0.4, 0.3), Color(0.35, 0.55, 0.2), Color(0.55, 0.72, 0.3)], 0.12)
	_fol_mat("reed", [Color(0.1, 0.3, 0.12), Color(0.2, 0.42, 0.14), Color(0.32, 0.55, 0.18), Color(0.5, 0.7, 0.25)], 0.08)
	_wmat("flower", Color(0.95, 0.75, 0.3), 0.6)
	var grass := _wmat("grass_blade", Color(1, 1, 1))
	grass.vertex_color_use_as_albedo = true
	grass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var smoke := _wmat("smoke", Color(0.35, 0.35, 0.36, 0.35))
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke.billboard_keep_scale = true
	smoke.vertex_color_use_as_albedo = true
	var puff := GradientTexture2D.new()
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	puff.width = 64
	puff.height = 64
	var pg := Gradient.new()
	pg.set_color(0, Color(1, 1, 1, 1))
	pg.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = pg
	smoke.albedo_texture = puff
	smoke.albedo_color = Color(1, 1, 1, 1)
	ResourceSaver.save(smoke, "res://world/materials/smoke.tres")
	_terrain_mat("ground", 0.0)
	_terrain_mat("dirt", 1.0)
	mats["leaf_a"] = mats["bush"]
	mats["leaf_b"] = mats["canopy"]
	var flower := _wmat("flower_vc", Color(1, 1, 1))
	flower.vertex_color_use_as_albedo = true
	var water := ShaderMaterial.new()
	water.shader = load("res://world/water.gdshader")
	ResourceSaver.save(water, "res://world/materials/water.tres")
	water.take_over_path("res://world/materials/water.tres")
	mats["water"] = water
	var beam := ShaderMaterial.new()
	beam.shader = load("res://world/sunbeam.gdshader")
	ResourceSaver.save(beam, "res://world/materials/sunbeam.tres")
	beam.take_over_path("res://world/materials/sunbeam.tres")
	mats["sunbeam"] = beam
	_wmat("wing", Color(1.0, 0.5, 0.15), 0.8, 0.0, 0.4).cull_mode = BaseMaterial3D.CULL_DISABLED
	_wmat("wing_red", Color(0.9, 0.2, 0.25), 0.8, 0.0, 0.4).cull_mode = BaseMaterial3D.CULL_DISABLED
	# Re-save materials changed after _wmat first wrote them.
	for n in ["grass_blade", "flower_vc", "wing", "wing_red"]:
		ResourceSaver.save(mats[n], "res://world/materials/%s.tres" % n)


# Jagged breach through the lounge wall, as (z, y) points in ship space.
const BREACH := [Vector2(0.5, 0.0), Vector2(0.3, 0.6), Vector2(0.65, 1.1), Vector2(0.2, 1.75),
	Vector2(0.75, 2.25), Vector2(1.2, 2.6), Vector2(1.75, 2.35), Vector2(2.3, 2.8),
	Vector2(2.9, 2.45), Vector2(3.45, 2.65), Vector2(3.85, 2.1), Vector2(4.35, 1.8),
	Vector2(4.05, 1.2), Vector2(4.5, 0.7), Vector2(4.2, 0.0)]


func _breach_cutter(scale := 1.0) -> CSGPolygon3D:
	var poly := PackedVector2Array()
	var mid := Vector2(2.35, 1.3)
	for q: Vector2 in BREACH:
		var v := mid + (q - mid) * scale
		if q.y == 0.0:
			v.y = 0.0
		poly.append(Vector2(-v.x, v.y))
	var c := CSGPolygon3D.new()
	c.polygon = poly
	c.depth = 3.6
	c.rotation.y = PI / 2
	c.position.x = 9.0
	c.material = mats["scorched"]
	c.operation = CSGShape3D.OPERATION_SUBTRACTION
	return c


func _apply_crash_damage() -> void:
	_make_world_materials()
	var R := scene_root
	var hull: CSGCombiner3D = R.get_node("Hull")
	# Keel: the hull sits buried in the dirt.
	_box(hull, "Keel", Vector3(-7.7, -1.6, -12.9), Vector3(5.9, -0.19, 9.5), "hull_outer")
	_ccyl(hull, "LoungeKeel", 4.95, 1.4, Vector3(2.4, -0.9, 1.6), "hull_outer")
	_add(hull, _breach_cutter(), "Breach")
	_add(R.get_node("Windows/LoungeGlass"), _breach_cutter(1.15), "Breach")
	# Couch sections where the hull tore open are gone.
	for n in R.get_node("Lounge/Couch").get_children():
		if n.has_meta("angle") and n.get_meta("angle") > -26.0 and n.get_meta("angle") < 36.0:
			n.queue_free()
			n.get_parent().remove_child(n)
	var couch_body: StaticBody3D = R.get_node("Lounge/Couch/Collision")
	for k in 12:
		var a := -64.0 + (k + 0.5) * 128.0 / 12.0
		if a > -26.0 and a < 36.0:
			var cs := couch_body.get_node("Shape%d" % k)
			couch_body.remove_child(cs)
			cs.free()
	R.get_node("Windows/LoungeGlass").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Lights: mostly dead or dim, red emergency lights, one flickering.
	var lights := R.get_node("Lights")
	var dead := ["DeckMid", "Kitchen", "Gunner", "Bathroom", "CanopyFill"]
	for l in lights.get_children():
		if l is OmniLight3D:
			if l.name in dead:
				l.light_energy = 0.0
				if l.has_node("Fixture"):
					l.get_node("Fixture").material_override = mats["metal_dark"]
			else:
				l.light_energy *= 0.35
	var flicker: OmniLight3D = lights.get_node("DeckFore")
	flicker.set_script(load("res://ship/flicker_light.gd"))
	flicker.set("base_energy", 0.7)
	for e in [[Vector3(-0.15, 2.7, 1.0), "EmergencyDeck"], [Vector3(-0.4, 2.7, -7.0), "EmergencyQuarters"],
			[Vector3(4.0, 2.7, -8.0), "EmergencyCockpit"], [Vector3(-4.5, 2.7, 1.0), "EmergencyEngineering"]]:
		var red := OmniLight3D.new()
		red.position = e[0]
		red.light_color = Color(1.0, 0.18, 0.1)
		red.light_energy = 0.7
		red.omni_range = 5.0
		_add(lights, red, e[1])
		_mesh_box(red, "Lamp", Vector3(0, 0.22, 0), Vector3(0.18, 0.08, 0.18), "emergency")
	for i in [1, 3]:
		var strip := R.get_node_or_null("LedStrip%d" % i)
		if strip:
			strip.visible = false

	# Knocked-over and shifted things.
	var deck: CSGCombiner3D = R.get_node("DeckFurniture")
	var crate_a: CSGBox3D = deck.get_node("CrateA")
	crate_a.position = Vector3(-1.1, 0.4, 6.4)
	crate_a.rotation = Vector3(0.0, 0.6, 0.0)
	var crate_b: CSGBox3D = deck.get_node("CrateB")
	crate_b.position = Vector3(0.3, 0.3, 7.2)
	crate_b.rotation = Vector3(0.25, -0.4, 0.5)
	crate_b.position.y = 0.42
	var clutter: CSGCombiner3D = R.get_node("Clutter")
	var barrel: CSGCylinder3D = clutter.get_node("BarrelA")
	barrel.rotation = Vector3(0.0, 0.7, PI / 2)
	barrel.position = Vector3(0.6, 0.28, 5.6)
	var table: Node3D = R.get_node("Lounge/HoloTable")
	table.rotation = Vector3(0.0, 0.6, 1.35)
	table.position = Vector3(4.0, 0.72, 2.9)
	# No power for the media player after the crash.
	var player_node := table.get_node("MediaPlayer")
	table.remove_child(player_node)
	player_node.free()
	R.get_node("PilotChair").rotation.y = 0.35
	R.get_node("CopilotChair").rotation.y = -0.5
	R.get_node("CopilotChair").position.x += 0.1
	R.get_node("GunnerChair").rotation.y = PI - 0.4
	var canopy := R.get_node("Canopy")
	for n in ["OverheadPost", "OverheadConsole", "OverheadScreen"]:
		var part: Node3D = canopy.get_node(n)
		part.rotation.z = 0.55
		part.position.x -= 0.12
		part.position.y -= 0.12
	canopy.get_node("OverheadScreen").material_override = mats["metal_dark"]
	R.get_node("ConsoleScreenRight").material_override = mats["metal_dark"]

	# Cracked windshield (right pane).
	var crack := Node3D.new()
	_add(canopy, crack, "Crack")
	var mid0 := C_FL0.lerp(C_FR0, 0.5)
	var mid1 := C_FL1.lerp(C_FR1, 0.5)
	var pane_at := func(u: float, v: float) -> Vector3:
		return mid0.lerp(C_FR0, u).lerp(mid1.lerp(C_FR1, u), v) + Vector3(0, 0, 0.03)
	var hub: Vector3 = pane_at.call(0.45, 0.4)
	var tips := [[0.1, 0.9], [0.8, 0.95], [0.95, 0.5], [0.85, 0.05], [0.2, 0.1], [0.05, 0.45], [0.55, 0.75]]
	for i in tips.size():
		var tip: Vector3 = pane_at.call(tips[i][0], tips[i][1])
		var bend: Vector3 = hub.lerp(tip, 0.5) + Vector3(0.03 * (i % 3 - 1), 0.04 * (i % 2), 0)
		_pipe(crack, "LineA%d" % i, hub, bend, 0.005, "cable")
		_pipe(crack, "LineB%d" % i, bend, tip, 0.004, "cable")

	# Fallen ceiling panel, dangling cables and sparks on the deck.
	var fallen := _mesh_box(R, "FallenPanel", Vector3(0.9, 0.12, -0.6), Vector3(1.3, 0.04, 0.9), "ceiling")
	fallen.rotation = Vector3(0.12, 0.5, 0.18)
	_mesh_box(R, "CeilingGap", Vector3(0.9, 2.975, -0.6), Vector3(1.1, 0.01, 0.8), "cable")
	for i in 3:
		_pipe(R, "Dangle%d" % i, Vector3(0.7 + i * 0.15, 2.95, -0.5 - i * 0.1),
			Vector3(0.6 + i * 0.25, 1.5 + i * 0.25, -0.2 - i * 0.15), 0.018, "cable")
	var sparks := CPUParticles3D.new()
	sparks.position = Vector3(0.85, 1.55, -0.35)
	sparks.amount = 24
	sparks.lifetime = 0.7
	sparks.explosiveness = 0.85
	sparks.direction = Vector3(0, -1, 0)
	sparks.spread = 70.0
	sparks.initial_velocity_min = 1.0
	sparks.initial_velocity_max = 2.5
	sparks.gravity = Vector3(0, -9.8, 0)
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.015, 0.015, 0.05)
	spark_mesh.material = mats["spark"]
	sparks.mesh = spark_mesh
	_add(R, sparks, "Sparks")
	var spark_light := OmniLight3D.new()
	spark_light.position = Vector3(0.85, 1.5, -0.35)
	spark_light.light_color = Color(1.0, 0.65, 0.3)
	spark_light.light_energy = 0.5
	spark_light.omni_range = 2.5
	spark_light.set_script(load("res://ship/flicker_light.gd"))
	spark_light.set("base_energy", 0.6)
	_add(R, spark_light, "SparkLight")

	# Debris and shards near the breach, plants creeping in.
	var rng := RandomNumberGenerator.new()
	rng.seed = 26
	var debris := _add(R, Node3D.new(), "Debris")
	for i in 14:
		var chunk := _mesh_box(debris, "Chunk%d" % i,
			Vector3(rng.randf_range(4.8, 6.6), 0.05, rng.randf_range(0.5, 4.3)),
			Vector3(rng.randf_range(0.1, 0.45), rng.randf_range(0.04, 0.12), rng.randf_range(0.1, 0.4)),
			"hull_outer" if i % 3 else "scorched")
		chunk.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
	for i in 18:
		var shard := _mesh_box(debris, "Shard%d" % i,
			Vector3(rng.randf_range(4.0, 6.5), 0.03, rng.randf_range(0.0, 4.6)),
			Vector3(rng.randf_range(0.05, 0.18), 0.01, rng.randf_range(0.04, 0.15)), "glass")
		shard.rotation.y = rng.randf() * TAU
	var blade := CylinderMesh.new()
	blade.top_radius = 0.0
	blade.bottom_radius = 0.025
	blade.height = 0.3
	blade.radial_segments = 3
	for i in 40:
		var g := MeshInstance3D.new()
		g.mesh = blade
		g.material_override = mats["leaf_b" if i % 2 else "leaf_a"]
		g.position = Vector3(rng.randf_range(5.9, 7.2), 0.15, rng.randf_range(0.6, 4.2))
		g.rotation = Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
		g.scale = Vector3.ONE * rng.randf_range(0.7, 1.6)
		_add(debris, g, "Grass%d" % i)

	# Updated text.
	var use := R.get_node("Interactables")
	# By the crash Meki is long since repaired; nothing waits on him here.
	for n in use.get_children():
		if "needs_power" in n:
			n.set("needs_power", false)
	use.get_node("ShipComputer").set("crashed", true)
	use.get_node("ShipComputer").set("hull", 18)
	use.get_node("ShipComputer").set("fuel", 6)
	use.get_node("ShipComputer").set("oxygen", 71)
	use.get_node("ShipComputer").set("power", 9)
	use.get_node("LogTerminal").set("crashed", true)
	var lines := {
		"PilotSeat": "Not flying anywhere. Maybe not ever.",
		"LoungeWindow": "Well. That's the new front door.",
		"Reactor": "Output 9%. Emergency power only. It's still humming, at least.",
		"BoardingRamp": "Ramp's buckled shut. The hole in the lounge will have to do.",
		"TurretControls": "Turret's dead. Hopefully nothing out there needs shooting.",
		"Workbench": "Tools everywhere. Half of them are on the floor now.",
	}
	for n in lines:
		use.get_node(n).set("message", lines[n])
	use.get_node("LoungeWindow").set("prompt", "Hull breach")
	_inspect(use, "FallenPanel", Vector3(0.9, 0.4, -0.6), "Fallen panel",
		"Ceiling panel came down in the landing. Those cables are still live.", 1.6)


# ---------- crash site ----------

func _tree(parent: Node, rng: RandomNumberGenerator, pos: Vector3, idx: int) -> void:
	var t := StaticBody3D.new()
	t.position = pos
	t.rotation.y = rng.randf() * TAU
	_add(parent, t, "Tree%d" % idx)
	var kind := rng.randi() % 10
	var s := rng.randf_range(0.8, 1.5)
	var trunk_h := rng.randf_range(3.0, 6.0) * s
	var trunk_r := 0.18 * s
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = trunk_r * 0.6
	tm.bottom_radius = trunk_r
	tm.height = trunk_h
	tm.radial_segments = 6
	tm.rings = 1
	trunk.mesh = tm
	trunk.material_override = mats["bark_light" if kind == 9 else "bark"]
	trunk.position.y = trunk_h / 2.0
	_add(t, trunk, "Trunk")
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = trunk_r
	shape.height = trunk_h
	cs.shape = shape
	cs.position.y = trunk_h / 2.0
	_add(t, cs, "Collision")
	var leaf: String = ["leaf_a", "leaf_b", "leaf_c"][rng.randi() % 3]
	if kind < 5:
		# Pine: stacked cones.
		for k in 3:
			var cone := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = (1.6 - k * 0.4) * s
			cm.height = 1.9 * s
			cm.radial_segments = 7
			cm.rings = 1
			cone.mesh = cm
			cone.material_override = mats[leaf]
			cone.position.y = trunk_h * 0.45 + k * 1.1 * s + 0.9 * s
			_add(t, cone, "Cone%d" % k)
	else:
		# Broadleaf (or alien purple): clustered low-poly blobs.
		if kind == 9:
			leaf = "leaf_alien"
		for k in 4:
			var blob := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = rng.randf_range(0.9, 1.4) * s
			sm.height = sm.radius * 1.7
			sm.radial_segments = 7
			sm.rings = 4
			blob.mesh = sm
			blob.material_override = mats[leaf]
			var a := k * TAU / 4.0 + rng.randf()
			blob.position = Vector3(cos(a) * 0.8 * s, trunk_h + rng.randf_range(-0.4, 0.6) * s, sin(a) * 0.8 * s)
			if k == 3:
				blob.position = Vector3(0, trunk_h + 0.9 * s, 0)
			_add(t, blob, "Blob%d" % k)


func _blob(parent: Node, name: String, pos: Vector3, size: Vector3, mat: String, rot := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 5
	mi.mesh = sm
	mi.material_override = mats[mat]
	mi.position = pos
	mi.scale = size
	mi.rotation.y = rot
	return _add(parent, mi, name)


func _build_crash_site() -> void:
	_make_world_materials()
	scene_root = (load("res://main.tscn") as PackedScene).instantiate()
	var R := scene_root
	const GROUND_Y := -0.5
	# Built from the space scene, but the ship's space hum doesn't belong on
	# the ground (it would also play under the start menu, which uses this).
	for n in ["ShipHum", "Meki", "ShipPower"]:
		var node := R.get_node_or_null(n)
		if node:
			R.remove_child(node)
			node.free()

	# Day sky and sun.
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://world/day_sky.gdshader")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.65, 0.55)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.52, 0.7, 0.66)
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_depth_begin = 16.0
	env.fog_depth_end = 90.0
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.0
	R.get_node("WorldEnvironment").environment = env
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.transform = Transform3D(Basis.looking_at(Vector3(-0.65, -0.62, -0.25).normalized(), Vector3.UP), Vector3.ZERO)
	R.add_child(sun)
	sun.owner = R
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.55, 0.66, 1.0)
	moon.light_energy = 0.0
	moon.transform = Transform3D(Basis.looking_at(-Vector3(-0.8, 0.5, 0.35).normalized(), Vector3.UP), Vector3.ZERO)
	R.add_child(moon)
	moon.owner = R
	var music := Node.new()
	music.name = "OutdoorMusic"
	music.set_script(load("res://world/outdoor_music.gd"))
	R.add_child(music)
	music.owner = R
	var clock := Node.new()
	clock.name = "DayNight"
	clock.set_script(load("res://world/day_night.gd"))
	R.add_child(clock)
	clock.owner = R

	# Swap the space ship for the crashed one, tilted and sunk into the dirt.
	var old := R.get_node("ShipInterior")
	R.remove_child(old)
	old.free()
	var ship := Node3D.new()
	ship.name = "Ship"
	ship.rotation = Vector3(0.02, 0.0, -0.05)
	R.add_child(ship)
	R.move_child(ship, 1)
	ship.owner = R
	var crashed_ship: Node3D = (load("res://ship/ship_crashed.tscn") as PackedScene).instantiate()
	ship.add_child(crashed_ship)
	crashed_ship.owner = R
	# Dirt slope out of the breach.
	var slope := CSGPolygon3D.new()
	slope.name = "BreachSlope"
	slope.polygon = PackedVector2Array([Vector2(6.9, -1.2), Vector2(6.9, 0.02), Vector2(9.0, 0.0),
		Vector2(12.0, -0.45), Vector2(12.0, -1.2)])
	slope.depth = 4.4
	slope.position.z = 4.6
	slope.material = mats["dirt"]
	slope.use_collision = true
	slope.add_to_group("grass_surface", true)
	ship.add_child(slope)
	slope.owner = R

	# Player wakes up in the quarters, facing the hatch.
	var player: Node3D = R.get_node("Player")
	player.position = ship.transform * Vector3(-1.2, 1.1, -7.0)
	player.get_node("CameraPivot").rotation = Vector3(-0.2, PI, 0)

	scene_root = R
	var site := Node3D.new()
	_add(R, site, "CrashSite")

	# Ground.
	var ground := StaticBody3D.new()
	ground.position.y = GROUND_Y
	ground.add_to_group("grass_surface", true)
	_add(site, ground, "Ground")
	var gm := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	gm.mesh = plane
	gm.material_override = mats["ground"]
	_add(ground, gm, "Mesh")
	var gcs := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(600, 2, 600)
	gcs.shape = gshape
	gcs.position.y = -1.0
	_add(ground, gcs, "Collision")
	# Invisible walls so you can't wander off the map.
	for b in [[Vector3(0, 5, -95), Vector3(200, 12, 2)], [Vector3(0, 5, 95), Vector3(200, 12, 2)],
			[Vector3(-95, 5, 0), Vector3(2, 12, 200)], [Vector3(95, 5, 0), Vector3(2, 12, 200)]]:
		var wall := StaticBody3D.new()
		wall.position = b[0]
		_add(site, wall, "Boundary")
		var wcs := CollisionShape3D.new()
		var ws := BoxShape3D.new()
		ws.size = b[1]
		wcs.shape = ws
		_add(wall, wcs, "Shape")

	# Crash trail behind the ship: torn earth, snapped trees, logs.
	var trail := _add(site, Node3D.new(), "CrashTrail")
	var dirt := MeshInstance3D.new()
	var dp := PlaneMesh.new()
	dp.size = Vector2(11, 75)
	dirt.mesh = dp
	dirt.material_override = mats["dirt"]
	dirt.position = Vector3(-0.8, GROUND_Y + 0.02, 46.0)
	_add(trail, dirt, "Furrow")
	var rng := RandomNumberGenerator.new()
	rng.seed = 113
	for i in 26:
		var side := -1.0 if i % 2 else 1.0
		var z := rng.randf_range(10.0, 80.0)
		_blob(trail, "Berm%d" % i, Vector3(-0.8 + side * rng.randf_range(5.3, 6.5), GROUND_Y, z),
			Vector3(rng.randf_range(2.0, 4.0), rng.randf_range(0.6, 1.3), rng.randf_range(3.0, 6.0)), "dirt", rng.randf_range(-0.3, 0.3))
	for i in 10:
		var stump := StaticBody3D.new()
		var side := -1.0 if i % 2 else 1.0
		stump.position = Vector3(-0.8 + side * rng.randf_range(3.5, 7.0), GROUND_Y, rng.randf_range(14.0, 75.0))
		_add(trail, stump, "Stump%d" % i)
		var h := rng.randf_range(0.5, 1.4)
		var smi := MeshInstance3D.new()
		var sc := CylinderMesh.new()
		sc.top_radius = 0.22
		sc.bottom_radius = 0.3
		sc.height = h
		sc.radial_segments = 6
		smi.mesh = sc
		smi.material_override = mats["bark"]
		smi.position.y = h / 2.0
		_add(stump, smi, "Mesh")
		var jag := MeshInstance3D.new()
		var jc := CylinderMesh.new()
		jc.top_radius = 0.0
		jc.bottom_radius = 0.22
		jc.height = 0.5
		jc.radial_segments = 4
		jag.mesh = jc
		jag.material_override = mats["bark_light"]
		jag.position = Vector3(0.05, h + 0.2, 0)
		jag.rotation.z = 0.3
		_add(stump, jag, "Splinter")
		var scs := CollisionShape3D.new()
		var ss := CylinderShape3D.new()
		ss.radius = 0.3
		ss.height = h
		scs.shape = ss
		scs.position.y = h / 2.0
		_add(stump, scs, "Collision")
	for i in 6:
		var log_body := StaticBody3D.new()
		var side := -1.0 if i % 2 else 1.0
		log_body.position = Vector3(-0.8 + side * rng.randf_range(6.5, 10.0), GROUND_Y + 0.3, rng.randf_range(16.0, 70.0))
		log_body.rotation = Vector3(0, rng.randf_range(-0.8, 0.8), PI / 2)
		_add(trail, log_body, "Log%d" % i)
		var lm := MeshInstance3D.new()
		var lc := CylinderMesh.new()
		lc.top_radius = 0.3
		lc.bottom_radius = 0.34
		lc.height = rng.randf_range(4.0, 7.0)
		lc.radial_segments = 7
		lm.mesh = lc
		lm.material_override = mats["bark"]
		_add(log_body, lm, "Mesh")
		var lcs := CollisionShape3D.new()
		var ls := CylinderShape3D.new()
		ls.radius = 0.32
		ls.height = lc.height
		lcs.shape = ls
		_add(log_body, lcs, "Collision")
	# Dirt heaped against the hull.
	for v in [[Vector3(-8.6, GROUND_Y, -2.0), Vector3(3, 1.4, 12)], [Vector3(-8.2, GROUND_Y, 7.0), Vector3(3, 1.2, 6)],
			[Vector3(3.8, GROUND_Y, -14.0), Vector3(7, 1.2, 3)], [Vector3(7.0, GROUND_Y, -5.5), Vector3(3, 1.0, 5)],
			[Vector3(6.2, GROUND_Y, 8.0), Vector3(3, 1.0, 5)], [Vector3(-4.0, GROUND_Y, -11.5), Vector3(5, 1.3, 3)]]:
		_blob(trail, "HullBerm", v[0], v[1], "dirt")

	# Smoke rising from the back of the ship.
	var smoke := CPUParticles3D.new()
	smoke.position = Vector3(-5.2, 2.6, 11.0)
	smoke.amount = 40
	smoke.lifetime = 9.0
	smoke.preprocess = 9.0
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.8
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 1.4
	smoke.gravity = Vector3(0.25, 0.15, 0.1)
	smoke.scale_amount_min = 1.5
	smoke.scale_amount_max = 3.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 2.5))
	smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.3, 0.3, 0.3, 0.55))
	fade.set_color(1, Color(0.6, 0.6, 0.62, 0.0))
	smoke.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	quad.material = mats["smoke"]
	smoke.mesh = quad
	_add(site, smoke, "Smoke")

	# Forest: a dense ring of big pixel-art trees around an irregular clearing.
	var trunks := []
	var cones := []
	var blobs := []
	var bushes := []
	var bodies := _add(site, Node3D.new(), "TreeCollision")
	var gx := -92.0
	var tree_count := 0
	while gx <= 92.0:
		var gz := -92.0
		while gz <= 92.0:
			var p := Vector2(gx + rng.randf_range(-2.6, 2.6), gz + rng.randf_range(-2.6, 2.6))
			gz += 6.0
			if _keep_clear(p, 0.0):
				continue
			var base := Vector3(p.x, GROUND_Y, p.y)
			var edge := clampf((_clear_dist(p) - 2.0) / 25.0, 0.0, 1.0)
			var kind := rng.randf()
			var tint := Color(1, 1, 1) * rng.randf_range(0.85, 1.12)
			var h: float
			var r: float
			if kind < 0.72:
				# Old-growth giant: tall bare trunk, layered drooping tiers to a point.
				h = rng.randf_range(18.0, 26.0) + edge * rng.randf_range(0.0, 10.0)
				r = rng.randf_range(0.7, 1.0) + edge * 0.45
				var crown_base := h * rng.randf_range(0.38, 0.5)
				var visible_h := crown_base + (h - crown_base) * 0.45
				trunks.append([Transform3D(Basis().scaled(Vector3(r, visible_h, r)), base + Vector3(0, visible_h / 2.0, 0)), Color(1, 1, 1)])
				trunks.append([Transform3D(Basis().scaled(Vector3(r * 1.6, 1.4, r * 1.6)), base + Vector3(0, 0.7, 0)), Color(1, 1, 1)])
				var crown_h := h - crown_base + 2.5
				var tiers := int(crown_h / 1.25)
				var width := rng.randf_range(3.6, 5.0) * (0.8 + h / 60.0)
				for k in tiers:
					var f := float(k) / tiers
					var tr := width * (1.0 - f * 0.88) * rng.randf_range(0.85, 1.1)
					var th := 3.2 + tr * 0.45
					var off := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
					cones.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(tr, th, tr)),
						base + off + Vector3(0, crown_base + f * crown_h + th * 0.3, 0)), tint * (0.82 + f * 0.3)])
			elif kind < 0.95:
				# Young pine: full cone of tiers almost to the ground.
				h = rng.randf_range(6.0, 12.0)
				r = rng.randf_range(0.25, 0.4)
				trunks.append([Transform3D(Basis().scaled(Vector3(r, h, r)), base + Vector3(0, h / 2.0, 0)), Color(1, 1, 1)])
				var tiers := int(h / 1.1)
				for k in tiers:
					var f := float(k) / tiers
					var tr := (2.4 - f * 2.0) * rng.randf_range(0.85, 1.1)
					cones.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(tr, 2.6, tr)),
						base + Vector3(0, 1.2 + f * (h - 0.5), 0)), tint * 1.08])
			else:
				# Occasional small broadleaf in the understory.
				h = rng.randf_range(4.0, 6.5)
				r = rng.randf_range(0.22, 0.32)
				trunks.append([Transform3D(Basis().scaled(Vector3(r, h, r)), base + Vector3(0, h / 2.0, 0)), Color(1, 1, 1)])
				for k in rng.randi_range(5, 8):
					var a := rng.randf() * TAU
					var rad := sqrt(rng.randf()) * 1.8
					var bs := rng.randf_range(1.3, 2.0)
					blobs.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(bs, bs * 0.8, bs)),
						base + Vector3(cos(a) * rad, h + rng.randf_range(-0.4, 1.0), sin(a) * rad)), tint])
			if _clear_dist(p) < 45.0:
				var body := StaticBody3D.new()
				body.position = base + Vector3(0, h / 2.0, 0)
				_add(bodies, body, "Tree%d" % tree_count)
				var cs := CollisionShape3D.new()
				var shape := CylinderShape3D.new()
				shape.radius = r
				shape.height = h
				cs.shape = shape
				_add(body, cs, "Shape")
			for k in rng.randi_range(1, 3):
				var bp := p + Vector2(rng.randf_range(-3.5, 3.5), rng.randf_range(-3.5, 3.5))
				var bsz := rng.randf_range(0.8, 1.9)
				bushes.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(bsz * 1.4, bsz, bsz * 1.3)),
					Vector3(bp.x, GROUND_Y + bsz * 0.3, bp.y)), tint])
			tree_count += 1
		gx += 6.0
	# Extra undergrowth fringing the clearing.
	for k in 260:
		var a := rng.randf() * TAU
		var p := _clear_edge(a) * rng.randf_range(0.95, 1.12)
		if _in_ship_zone(p, 2.5):
			continue
		var bsz := rng.randf_range(0.6, 1.6)
		bushes.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(bsz * 1.4, bsz, bsz * 1.3)),
			Vector3(p.x, GROUND_Y + bsz * 0.3, p.y)), Color(1, 1, 1) * rng.randf_range(0.85, 1.15)])

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.75
	trunk_mesh.bottom_radius = 1.0
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 8
	trunk_mesh.rings = 1
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 1.0
	cone_mesh.height = 1.0
	cone_mesh.radial_segments = 10
	cone_mesh.rings = 3
	var blob_mesh := SphereMesh.new()
	blob_mesh.radius = 0.5
	blob_mesh.height = 1.0
	blob_mesh.radial_segments = 10
	blob_mesh.rings = 6
	_multimesh(site, "Trunks", trunk_mesh, trunks, "bark")
	_multimesh(site, "Pines", cone_mesh, cones, "pine")
	_multimesh(site, "Canopies", blob_mesh, blobs, "canopy")
	_multimesh(site, "Bushes", blob_mesh, bushes, "bush")

	# Rocks, some mossy, and a ring of stones and reeds around the pond.
	var rocks := []
	var mossy := []
	for k in 70:
		var p := Vector2(rng.randf_range(-85, 85), rng.randf_range(-85, 85))
		if _in_ship_zone(p, 3.0):
			continue
		var rs := rng.randf_range(0.4, 1.8)
		var t := [Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rs * 1.3, rs * 0.75, rs)),
			Vector3(p.x, GROUND_Y + rs * 0.15, p.y)), Color(1, 1, 1)]
		(mossy if k % 2 else rocks).append(t)
	var pond_c := Vector2(20.5, 4.0)
	var reeds := []
	for k in 26:
		var a := k * TAU / 26.0 + rng.randf_range(-0.1, 0.1)
		var e := pond_c + _pond_radius(a) * Vector2(cos(a), sin(a)) * 1.05
		var rs := rng.randf_range(0.3, 0.7)
		rocks.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rs * 1.4, rs * 0.6, rs)),
			Vector3(e.x, GROUND_Y + 0.05, e.y)), Color(1, 1, 1)])
		if k % 2 == 0:
			for q in 5:
				var rp := e + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
				var rh := rng.randf_range(0.7, 1.4)
				reeds.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2)).scaled(Vector3(0.04, rh, 0.04)),
					Vector3(rp.x, GROUND_Y + rh / 2.0, rp.y)), Color(1, 1, 1)])
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.5
	rock_mesh.height = 1.0
	rock_mesh.radial_segments = 7
	rock_mesh.rings = 4
	_multimesh(site, "Rocks", rock_mesh, rocks, "rock")
	_multimesh(site, "MossyRocks", rock_mesh, mossy, "moss_rock")
	_multimesh(site, "Reeds", trunk_mesh, reeds, "reed")

	# Pond.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var segs := 40
	for k in segs:
		var a0 := k * TAU / segs
		var a1 := (k + 1) * TAU / segs
		st.add_vertex(Vector3(pond_c.x, GROUND_Y + 0.03, pond_c.y))
		var e1 := pond_c + _pond_radius(a1) * Vector2(cos(a1), sin(a1))
		var e0 := pond_c + _pond_radius(a0) * Vector2(cos(a0), sin(a0))
		st.add_vertex(Vector3(e1.x, GROUND_Y + 0.03, e1.y))
		st.add_vertex(Vector3(e0.x, GROUND_Y + 0.03, e0.y))
	var pond := MeshInstance3D.new()
	pond.mesh = st.commit()
	pond.material_override = mats["water"]
	_add(site, pond, "Pond")

	# Grass blades and flowers, densest in the clearing.
	var blade := CylinderMesh.new()
	blade.top_radius = 0.0
	blade.bottom_radius = 0.04
	blade.height = 0.5
	blade.radial_segments = 3
	blade.rings = 1
	var grass := []
	var flowers := []
	var greens := [Color(0.2, 0.45, 0.12), Color(0.32, 0.58, 0.15), Color(0.48, 0.7, 0.2), Color(0.62, 0.8, 0.28)]
	var petals := [Color(0.95, 0.3, 0.25), Color(0.98, 0.96, 0.9), Color(1.0, 0.82, 0.25), Color(0.6, 0.68, 1.0), Color(0.95, 0.55, 0.8)]
	while grass.size() < 14000:
		var in_clear := grass.size() < 9000
		var p: Vector2
		if in_clear:
			var a := rng.randf() * TAU
			p = Vector2(4.0, 0.0) + (_clear_edge(a) - Vector2(4.0, 0.0)) * sqrt(rng.randf())
		else:
			p = Vector2(rng.randf_range(-80, 80), rng.randf_range(-80, 80))
		if _in_ship_zone(p, 0.5) or _in_trail(p) or p.distance_to(pond_c) < 4.6:
			continue
		var gh := rng.randf_range(0.6, 1.5)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
		grass.append([Transform3D(b.scaled(Vector3(1, gh, 1)), Vector3(p.x, GROUND_Y + 0.25 * gh, p.y)), greens[rng.randi() % 4]])
		if in_clear and rng.randf() < 0.45:
			var fp := p + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
			var fs := rng.randf_range(0.06, 0.11)
			flowers.append([Transform3D(Basis().scaled(Vector3(fs, fs * 0.6, fs)), Vector3(fp.x, GROUND_Y + rng.randf_range(0.15, 0.4), fp.y)),
				petals[rng.randi() % petals.size()]])
	var grass_mm := _multimesh(site, "Grass", blade, grass, "grass_blade")
	grass_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var petal := BoxMesh.new()
	var flower_mm := _multimesh(site, "Flowers", petal, flowers, "flower_vc")
	flower_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Sunbeams slanting through the canopy.
	var axis := -Vector3(-0.65, -0.62, -0.25).normalized()
	var beam_quad := QuadMesh.new()
	beam_quad.size = Vector2(2.6, 26)
	for k in 6:
		var a := rng.randf() * TAU
		var bp := Vector2(4.0, 0.0) + (_clear_edge(a) - Vector2(4.0, 0.0)) * rng.randf_range(0.5, 0.95)
		if _in_ship_zone(bp, 1.0):
			continue
		var c := Vector3(bp.x, GROUND_Y, bp.y) + axis * 11.0
		for q in 2:
			var bm := MeshInstance3D.new()
			bm.mesh = beam_quad
			bm.material_override = mats["sunbeam"]
			bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var x_axis := axis.cross(Vector3.FORWARD).normalized().rotated(axis, q * PI / 2)
			bm.transform = Transform3D(Basis(x_axis, axis, x_axis.cross(axis)), c)
			bm.add_to_group("day_only", true)
			_add(site, bm, "Sunbeam%d_%d" % [k, q])

	# Butterflies around the meadow and pond.
	var wing_quad := QuadMesh.new()
	wing_quad.size = Vector2(0.12, 0.1)
	for k in 8:
		var fly := Node3D.new()
		fly.set_script(load("res://world/butterfly.gd"))
		fly.add_to_group("day_only", true)
		var home := pond_c + Vector2(rng.randf_range(-9, 6), rng.randf_range(-8, 8))
		fly.position = Vector3(home.x, GROUND_Y + rng.randf_range(0.6, 1.6), home.y)
		_add(site, fly, "Butterfly%d" % k)
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			_add(fly, pivot, "WingL" if side < 0 else "WingR")
			var w := MeshInstance3D.new()
			w.mesh = wing_quad
			w.material_override = mats["wing" if k % 3 else "wing_red"]
			w.position = Vector3(0.06 * side, 0, 0)
			w.rotation.x = -PI / 2
			_add(pivot, w, "Wing")

	_build_ruins(site)

	# Fireflies over the pond and meadow at night.
	var glow := _wmat("firefly", Color(0.85, 1.0, 0.45), 0.5, 0.0, 6.0)
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ResourceSaver.save(glow, "res://world/materials/firefly.tres")
	var bug := SphereMesh.new()
	bug.radius = 0.035
	bug.height = 0.07
	bug.radial_segments = 6
	bug.rings = 3
	bug.material = glow
	for k in 3:
		var flies := CPUParticles3D.new()
		flies.position = Vector3(pond_c.x + [0.0, -8.0, -4.0][k], GROUND_Y + 1.2, pond_c.y + [0.0, 6.0, -8.0][k])
		flies.amount = 45
		flies.lifetime = 6.0
		flies.preprocess = 6.0
		flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		flies.emission_box_extents = Vector3(7, 1.0, 7)
		flies.direction = Vector3(0, 1, 0)
		flies.spread = 180.0
		flies.gravity = Vector3.ZERO
		flies.initial_velocity_min = 0.1
		flies.initial_velocity_max = 0.4
		var blink := Gradient.new()
		blink.set_color(0, Color(1, 1, 1, 0))
		blink.add_point(0.3, Color(1, 1, 1, 1))
		blink.add_point(0.6, Color(1, 1, 1, 0.2))
		blink.add_point(0.8, Color(1, 1, 1, 1))
		blink.set_color(blink.get_point_count() - 1, Color(1, 1, 1, 0))
		flies.color_ramp = blink
		flies.mesh = bug
		flies.visible = false
		flies.emitting = false
		flies.add_to_group("night_only", true)
		_add(site, flies, "Fireflies%d" % k)

	_save(R, "res://crash_site.tscn")


func _multimesh(parent: Node, name: String, mesh: Mesh, items: Array, mat: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mats[mat]
	return _add(parent, mmi, name)


func _pond_radius(a: float) -> float:
	return 4.2 + 0.6 * sin(a * 3.0 + 1.0) + 0.35 * sin(a * 5.0)


# Edge of the meadow clearing in direction `a` (centred just off the ship's right side).
func _clear_edge(a: float) -> Vector2:
	var rx := 29.0
	var rz := 24.0
	var wobble := 1.0 + 0.12 * sin(a * 3.0 + 0.7) + 0.08 * sin(a * 7.0 + 2.0)
	return Vector2(4.0, 0.0) + Vector2(cos(a) * rx, sin(a) * rz) * wobble


func _clear_dist(p: Vector2) -> float:
	var d := p - Vector2(4.0, 0.0)
	var edge := _clear_edge(atan2(d.y, d.x)) - Vector2(4.0, 0.0)
	return d.length() - edge.length()


func _in_ship_zone(p: Vector2, margin: float) -> bool:
	return p.x > -14.5 - margin and p.x < 13.5 + margin and p.y > -15.0 - margin and p.y < 11.8 + margin


func _in_trail(p: Vector2) -> bool:
	return absf(p.x + 0.8) < 6.0 and p.y > 8.0 and p.y < 85.0


# True if a point should stay free of trees: the clearing, the ship, the trail.
func _keep_clear(p: Vector2, margin: float) -> bool:
	return _clear_dist(p) < margin or _in_ship_zone(p, 3.0 + margin) or _in_trail(p) or _in_vista(p)


# Thinned corridors through the forest so each ruin is framed from the meadow.
func _in_vista(p: Vector2) -> bool:
	var c := Vector2(14.0, 0.0)
	for target: Vector3 in [RING_POS, ARC_POS, SPIRE_POS]:
		var t := Vector2(target.x, target.z)
		var dir := (t - c).normalized()
		var along := (p - c).dot(dir)
		if along < 0.0 or along > (t - c).length() - 30.0:
			continue
		var lateral := absf((p - c).dot(Vector2(-dir.y, dir.x)))
		if lateral < 4.5 + along * 0.06:
			return true
	return false


# ---------- ancient ruins ----------

const RING_POS := Vector3(132, 0, -16)
const LOOKOUT_DECK_Y := 46.6
const ARC_POS := Vector3(-34, 0, -128)
const SPIRE_POS := Vector3(-118, 0, 66)
const RUIN_HULL := Color(0.7, 0.71, 0.73)
const RUIN_DARK := Color(0.3, 0.1, 0.07)
const RUIN_PLATE := Color(0.86, 0.86, 0.85)
const RUIN_RUST := Color(0.66, 0.34, 0.18)
const RUIN_STEEL := Color(0.55, 0.57, 0.6)
const RUIN_FRAME := Color(0.42, 0.15, 0.09)
const RUIN_GLOW_BLUE := Color(0.35, 0.75, 1.0, 0.0)
const RUIN_GLOW_WARM := Color(1.0, 0.6, 0.3, 0.0)


# Box centred at xf.origin, oriented by xf.basis, with vertex colour.
func _rbox(st: SurfaceTool, xf: Transform3D, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	for n in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var u: Vector3 = Vector3.UP if absf(n.y) < 0.5 else Vector3.RIGHT
		var v: Vector3 = n.cross(u)
		u = v.cross(n)
		var c: Vector3 = n * absf(n.dot(h))
		var hu := absf(u.dot(h))
		var hv := absf(v.dot(h))
		var p := [c - u * hu - v * hv, c + u * hu - v * hv, c + u * hu + v * hv, c - u * hu + v * hv]
		var wn: Vector3 = (xf.basis * n).normalized()
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.set_normal(wn)
			st.add_vertex(xf * p[k])


# Prism (cylinder) along the basis' Y axis.
func _rcyl(st: SurfaceTool, xf: Transform3D, r: float, height: float, col: Color, sides := 10) -> void:
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var p0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		var up := Vector3(0, height * 0.5, 0)
		var wn: Vector3 = (xf.basis * Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))).normalized()
		for q in [p0 - up, p1 - up, p1 + up, p0 - up, p1 + up, p0 + up]:
			st.set_color(col)
			st.set_normal(wn)
			st.add_vertex(xf * q)
		for cap in [-1.0, 1.0]:
			var cn: Vector3 = (xf.basis * Vector3(0, cap, 0)).normalized()
			for q in [Vector3(0, cap * height * 0.5, 0), p0 + up * cap, p1 + up * cap]:
				st.set_color(col)
				st.set_normal(cn)
				st.add_vertex(xf * q)


func _ruin_col(rng: RandomNumberGenerator) -> Color:
	var r := rng.randf()
	return RUIN_HULL if r < 0.35 else (RUIN_PLATE if r < 0.68 else (RUIN_DARK if r < 0.8 else (RUIN_STEEL if r < 0.92 else RUIN_RUST)))


# Detailed ring (or arc) section in the XY plane, axis = Z.
# R = radius to tube centre, T = radial thickness, W = axial width.
func _ring_ruin(st: SurfaceTool, rng: RandomNumberGenerator, R: float, T: float, W: float,
		a_from: float, a_to: float, gap_from := 99.0, gap_to := 99.0) -> void:
	var steps := int((a_to - a_from) * R / 0.9)
	var da := (a_to - a_from) / steps
	var pipes := [[0.35, 0.42], [0.2, -0.42], [-0.3, 0.46], [0.55, 0.1], [-0.55, -0.2]]
	var ends := []
	for i in steps:
		var a := a_from + da * (i + 0.5)
		if a > gap_from and a < gap_to:
			continue
		if (i == 0 or (a - da < gap_to and a - da > gap_from)):
			ends.append([a - da * 0.5, -1.0])
		if (i == steps - 1 or (a + da > gap_from and a + da < gap_to)):
			ends.append([a + da * 0.5, 1.0])
		var rd := Vector3(cos(a), sin(a), 0)
		var tg := Vector3(-sin(a), cos(a), 0)
		var b := Basis(tg, rd, Vector3.BACK)
		var arc := R * da * 1.03
		# Core hull, darker in the inner trench.
		_rbox(st, Transform3D(b, rd * R), Vector3(arc, T, W), RUIN_HULL)
		_rbox(st, Transform3D(b, rd * (R - T * 0.5 - 0.4) + Vector3(0, 0, 0)), Vector3(arc, 0.8, W * 0.55), RUIN_DARK)
		# Layered outer panels: stepped bands running around the ring, each
		# layer narrower and a little proud of the one beneath.
		var lift := 0.0
		var layer_w := W * 1.04
		for layer in 3:
			if rng.randf() < 0.1 + layer * 0.08:
				break
			var th := rng.randf_range(0.35, 0.7)
			var pz := rng.randf_range(-(W - layer_w) * 0.5, (W - layer_w) * 0.5) if layer > 0 else 0.0
			var plate_col := RUIN_PLATE if rng.randf() < 0.7 else (RUIN_HULL if rng.randf() < 0.7 else RUIN_RUST)
			_rbox(st, Transform3D(b, rd * (R + T * 0.5 + lift + th * 0.5) + Vector3(0, 0, pz)), Vector3(arc * 0.97, th, layer_w), plate_col)
			lift += th
			layer_w *= rng.randf_range(0.55, 0.8)
		# Seam lines between panels.
		if i % 3 == 0:
			_rbox(st, Transform3D(b, rd * (R + T * 0.5 + 0.1)), Vector3(0.18, 0.5, W * 1.06), RUIN_DARK)
		# Stepped side panels.
		for side in [-1.0, 1.0]:
			_rbox(st, Transform3D(b, rd * (R + T * 0.18) + Vector3(0, 0, side * (W * 0.5 + 0.2))), Vector3(arc * 0.98, T * 0.6, 0.4), RUIN_PLATE)
			_rbox(st, Transform3D(b, rd * (R + T * 0.3) + Vector3(0, 0, side * (W * 0.5 + 0.5))), Vector3(arc * 0.98, T * 0.3, 0.3), RUIN_HULL)
		# Sparse outer details (vents, small housings).
		for g in (1 if rng.randf() < 0.3 else 0):
			var gh := rng.randf_range(0.3, 1.0)
			var gs := Vector3(arc * rng.randf_range(0.4, 1.2), gh, rng.randf_range(0.6, 2.0))
			var gz := rng.randf_range(-W * 0.45, W * 0.45)
			_rbox(st, Transform3D(b, rd * (R + T * 0.5 + lift + gh * 0.5) + Vector3(0, 0, gz)), gs, RUIN_HULL)
		# Inner trench machinery (where the reference is busiest).
		for g in rng.randi_range(2, 4):
			var gh := rng.randf_range(0.3, 1.6)
			var gz := rng.randf_range(-W * 0.4, W * 0.4)
			_rbox(st, Transform3D(b, rd * (R - T * 0.5 - 0.8 - gh * 0.5) + Vector3(0, 0, gz)),
				Vector3(arc * rng.randf_range(0.3, 1.5), gh, rng.randf_range(0.4, 2.0)), _ruin_col(rng))
		# Side faces: panels, vents and glowing windows.
		for side in [-1.0, 1.0]:
			for g in (1 if rng.randf() < 0.35 else 0):
				var ph := rng.randf_range(0.6, T * 0.5)
				var pr := rng.randf_range(-T * 0.4, T * 0.4)
				var pd := rng.randf_range(0.15, 1.1)
				_rbox(st, Transform3D(b, rd * (R + pr) + Vector3(0, 0, side * (W * 0.5 + pd * 0.5))),
					Vector3(arc * rng.randf_range(0.5, 1.8), ph, pd), _ruin_col(rng))
			if rng.randf() < 0.14:
				var wr := rng.randf_range(-T * 0.3, T * 0.3)
				_rbox(st, Transform3D(b, rd * (R + wr) + Vector3(0, 0, side * (W * 0.5 + 0.08))),
					Vector3(arc * 0.6, 0.35, 0.12), RUIN_GLOW_BLUE if rng.randf() < 0.7 else RUIN_GLOW_WARM)
		# Pipes running around the ring, with clamps.
		for pp in pipes:
			var pos: Vector3 = rd * (R + T * 0.5 * pp[0] + (T * 0.5 + 0.7) * signf(pp[0]) * 0.0) + Vector3(0, 0, W * pp[1])
			if absf(pp[1]) > 0.4:
				pos = rd * (R + T * pp[0] * 0.5) + Vector3(0, 0, signf(pp[1]) * (W * 0.5 + 0.55))
			else:
				pos = rd * (R + T * 0.5 + 0.55) + Vector3(0, 0, W * pp[1])
			_rbox(st, Transform3D(b, pos), Vector3(arc * 1.02, 0.55, 0.55), RUIN_STEEL if pp[0] > 0 else RUIN_RUST)
			if i % 7 == 0:
				_rbox(st, Transform3D(b, pos), Vector3(0.35, 0.9, 0.9), RUIN_DARK)
		# Occasional big modules: tanks, towers, antennae.
		if rng.randf() < 0.06:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var base := rd * (R + rng.randf_range(-T * 0.3, T * 0.3)) + Vector3(0, 0, side * (W * 0.5 + 1.6))
			_rcyl(st, Transform3D(Basis(Vector3.RIGHT, PI / 2) * Basis(), base), rng.randf_range(1.0, 1.8), 3.2, RUIN_PLATE, 12)
			_rbox(st, Transform3D(b, base + Vector3(0, 0, side * 1.7)), Vector3(1.4, 1.4, 0.3), RUIN_DARK)
		if rng.randf() < 0.05:
			var mh := rng.randf_range(3.0, 7.0)
			var mpos := rd * (R + T * 0.5 + mh * 0.5) + Vector3(0, 0, rng.randf_range(-W * 0.3, W * 0.3))
			_rbox(st, Transform3D(b, mpos), Vector3(rng.randf_range(2, 4), mh, rng.randf_range(2, 4)), RUIN_HULL)
			_rbox(st, Transform3D(b, mpos + rd * (mh * 0.5 + 0.2)), Vector3(1.5, 0.4, 1.5), RUIN_PLATE)
			_rbox(st, Transform3D(b, mpos + rd * (mh * 0.5 + 2.2)), Vector3(0.15, 4.0, 0.15), RUIN_STEEL)
	# Scaffolding wrapped around a few stretches of the ring.
	for sc in 4:
		var a0 := a_from + (a_to - a_from) * rng.randf()
		var span := rng.randf_range(0.18, 0.4)
		var bays := int(span * R / 2.4)
		var side := -1.0 if sc % 2 else 1.0
		for k in bays + 1:
			var a := a0 + span * k / bays
			if a > gap_from and a < gap_to:
				continue
			var rd := Vector3(cos(a), sin(a), 0)
			var tg := Vector3(-sin(a), cos(a), 0)
			var b := Basis(tg, rd, Vector3.BACK)
			var outer := R + T * 0.5 + 4.5
			var face := Vector3(0, 0, side * (W * 0.5 + 2.2))
			# Posts out from the hull and across the side face.
			_rbox(st, Transform3D(b, rd * (R + T * 0.5 + 2.25) + face), Vector3(0.22, 4.5, 0.22), RUIN_FRAME)
			_rbox(st, Transform3D(b, rd * outer + Vector3(0, 0, side * W * 0.25)), Vector3(0.22, 0.22, W * 0.5 + 4.4), RUIN_FRAME)
			for lv in 3:
				var y := R - T * 0.5 + T * lv / 2.0
				_rbox(st, Transform3D(b, rd * y + face), Vector3(0.18, 0.18, 0.18), RUIN_FRAME)
			if k < bays:
				var an := a0 + span * (k + 0.5) / bays
				var rdn := Vector3(cos(an), sin(an), 0)
				var bn := Basis(Vector3(-sin(an), cos(an), 0), rdn, Vector3.BACK)
				var bay := R * span / bays
				# Rails, walkway planks and a diagonal brace per bay.
				for lv in 3:
					var rr := R - T * 0.5 + T * lv / 2.0
					_rbox(st, Transform3D(bn, rdn * rr + face), Vector3(bay, 0.16, 0.16), RUIN_FRAME)
				_rbox(st, Transform3D(bn, rdn * (R + T * 0.5 + 0.6) + face), Vector3(bay, 0.12, 1.4), RUIN_STEEL)
				_rbox(st, Transform3D(bn, rdn * outer + face * 0.0), Vector3(bay, 0.16, 0.16), RUIN_FRAME)
				var diag := Basis(Vector3.BACK, 0.9 * (1.0 if k % 2 else -1.0))
				_rbox(st, Transform3D(bn * diag, rdn * R + face), Vector3(0.14, T * 1.1, 0.14), RUIN_FRAME)

	# Broken ends: exposed ribs, bent beams, dangling cables.
	for e in ends:
		var a: float = e[0]
		var dir: float = e[1]
		var rd := Vector3(cos(a), sin(a), 0)
		var tg := Vector3(-sin(a), cos(a), 0) * dir
		var b := Basis(tg, rd, Vector3.BACK)
		for k in 7:
			var rr := rng.randf_range(-T * 0.45, T * 0.45)
			var zz := rng.randf_range(-W * 0.45, W * 0.45)
			var ln := rng.randf_range(1.5, 7.0)
			var bend := Basis(Vector3.BACK, rng.randf_range(-0.5, 0.5)) * Basis(rd, rng.randf_range(-0.4, 0.4))
			var bb := b * bend
			_rbox(st, Transform3D(bb, rd * (R + rr) + Vector3(0, 0, zz) + bb.x * ln * 0.5),
				Vector3(ln, rng.randf_range(0.25, 0.6), rng.randf_range(0.25, 0.6)), RUIN_STEEL if k % 2 else RUIN_RUST)
		for k in 3:
			_rbox(st, Transform3D(b, rd * R + tg * (0.4 + k * 0.9)), Vector3(0.3, T * rng.randf_range(0.6, 1.0), W * rng.randf_range(0.5, 0.95)), RUIN_DARK)
		for k in 4:
			var cl := rng.randf_range(2.0, 6.0)
			var cpos := rd * (R + rng.randf_range(-T * 0.4, T * 0.4)) + tg * rng.randf_range(0.5, 2.0) + Vector3(0, 0, rng.randf_range(-W * 0.4, W * 0.4))
			_rbox(st, Transform3D(Basis(), cpos - Vector3(0, cl * 0.5, 0)), Vector3(0.12, cl, 0.12), RUIN_DARK)


# Tall greebled spire along +Y.
func _spire_ruin(st: SurfaceTool, rng: RandomNumberGenerator, height: float, base_w: float) -> void:
	var seg := 2.4
	var n := int(height / seg)
	for k in n:
		var f := float(k) / n
		var w := base_w * (1.0 - f * 0.7)
		var y := k * seg + seg * 0.5
		_rbox(st, Transform3D(Basis(Vector3.UP, f * 0.6), Vector3(0, y, 0)), Vector3(w, seg * 1.02, w * 0.8), RUIN_HULL)
		if k % 4 == 0:
			_rbox(st, Transform3D(Basis(Vector3.UP, f * 0.6), Vector3(0, y, 0)), Vector3(w * 1.15, 0.6, w * 0.95), RUIN_PLATE)
		for face in 4:
			var ang := f * 0.6 + face * PI / 2
			var out := Vector3(sin(ang), 0, cos(ang))
			var half := (w if face % 2 else w * 0.8) * 0.5
			for g in rng.randi_range(1, 3):
				var gd := rng.randf_range(0.2, 1.4)
				var side := out.cross(Vector3.UP) * rng.randf_range(-half * 0.7, half * 0.7)
				_rbox(st, Transform3D(Basis(Vector3.UP, ang), Vector3(0, y + rng.randf_range(-0.8, 0.8), 0) + out * (half + gd * 0.5) + side),
					Vector3(rng.randf_range(0.4, half), rng.randf_range(0.4, 2.0), gd), _ruin_col(rng))
			if rng.randf() < 0.18:
				_rbox(st, Transform3D(Basis(Vector3.UP, ang), Vector3(0, y, 0) + out * (half + 0.06)), Vector3(0.6, 0.3, 0.1),
					RUIN_GLOW_BLUE)
	# Broken top.
	for k in 6:
		var ln := rng.randf_range(2.0, 6.0)
		var bb := Basis(Vector3.BACK, rng.randf_range(-0.6, 0.6)) * Basis(Vector3.RIGHT, rng.randf_range(-0.6, 0.6))
		_rbox(st, Transform3D(bb, Vector3(rng.randf_range(-1, 1), n * seg + ln * 0.4, rng.randf_range(-1, 1))), Vector3(0.35, ln, 0.35),
			RUIN_STEEL if k % 2 else RUIN_RUST)


func _ruin_instance(parent: Node, name: String, st: SurfaceTool, xf: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mats["ruin"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = xf
	_add(parent, mi, name)


# Rusty lookout platform on top of the Great Ring (menu perch, future quest).
# Built in the ring's local space; the deck's front edge overhangs the ring.
func _lookout(ring: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deck_y := LOOKOUT_DECK_Y
	_rbox(st, Transform3D(Basis(), Vector3(0, deck_y - 0.1, 2.6)), Vector3(4.2, 0.2, 7.6), RUIN_STEEL)
	for k in 12:
		_rbox(st, Transform3D(Basis(), Vector3(0, deck_y + 0.01, -0.9 + k * 0.6)), Vector3(4.0, 0.03, 0.08), RUIN_DARK)
	_rbox(st, Transform3D(Basis(), Vector3(0, deck_y - 0.25, 2.6)), Vector3(4.4, 0.15, 7.8), RUIN_FRAME)
	for x in [-1.9, 1.9]:
		for z in [-1.0, 2.0, 5.0]:
			_rbox(st, Transform3D(Basis(), Vector3(x, deck_y - 1.6, z)), Vector3(0.18, 2.7, 0.18), RUIN_FRAME)
		# Side railings; the front edge is left open.
		for z in [-1.0, 1.0, 3.0, 5.0]:
			_rbox(st, Transform3D(Basis(), Vector3(x, deck_y + 0.5, z)), Vector3(0.08, 1.0, 0.08), RUIN_FRAME)
		_rbox(st, Transform3D(Basis(), Vector3(x, deck_y + 1.0, 2.0)), Vector3(0.1, 0.08, 6.2), RUIN_RUST)
	_rbox(st, Transform3D(Basis(), Vector3(0, deck_y + 1.0, -1.0)), Vector3(3.9, 0.08, 0.1), RUIN_RUST)
	# A beacon mast and a crate someone left up here long ago.
	_rbox(st, Transform3D(Basis(), Vector3(-1.6, deck_y + 2.0, -0.7)), Vector3(0.12, 4.0, 0.12), RUIN_STEEL)
	_rbox(st, Transform3D(Basis(), Vector3(-1.6, deck_y + 4.05, -0.7)), Vector3(0.3, 0.2, 0.3), RUIN_GLOW_WARM)
	_rbox(st, Transform3D(Basis(Vector3.UP, 0.3), Vector3(1.2, deck_y + 0.35, -0.2)), Vector3(0.8, 0.7, 0.6), RUIN_RUST)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mats["ruin"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(ring, mi, "Lookout")


func _build_ruins(site: Node) -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://world/ruin.gdshader")
	ResourceSaver.save(m, "res://world/materials/ruin.tres")
	m.take_over_path("res://world/materials/ruin.tres")
	mats["ruin"] = m
	var ruins := _add(site, Node3D.new(), "Ruins")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2600

	# The great ring: east of the crash site, beyond the trees, facing the
	# clearing, half-buried and tilted, with a broken gap at the top left.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ring_ruin(st, rng, 40.0, 7.5, 12.0, 0.0, TAU, 1.95, 2.45)
	var face_clearing := Basis(Vector3.UP, -PI / 2 + 0.25)
	var tilt := Basis(Vector3.RIGHT, 0.12) * Basis(Vector3.BACK, 0.18)
	_ruin_instance(ruins, "GreatRing", st, Transform3D(face_clearing * tilt, RING_POS + Vector3(0, 22.0, 0)))
	_lookout(ruins.get_node("GreatRing"))

	# A broken arc of another ring jutting out of the ground to the north.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ring_ruin(st, rng, 28.0, 6.0, 8.0, 0.35, 2.25)
	_ruin_instance(ruins, "BrokenArc", st, Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.BACK, 0.3), ARC_POS + Vector3(0, -10.0, 0)))

	# A leaning spire to the south-west.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_spire_ruin(st, rng, 78.0, 11.0)
	_ruin_instance(ruins, "Spire", st, Transform3D(Basis(Vector3.BACK, -0.22) * Basis(Vector3.RIGHT, 0.08), SPIRE_POS + Vector3(0, -6.0, 0)))
