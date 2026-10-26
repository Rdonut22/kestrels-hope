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
	var lounge := _half_cyl(hull, "Lounge", 4.7, 3.0, 1.5, Vector3(2.4, 0, -3.2), Vector3(8, 3, 6.4), "wall")
	lounge.operation = CSGShape3D.OPERATION_SUBTRACTION
	_room(hull, "Deck", -2.3, 2.0, -5.6, 9.2)
	_room(hull, "Quarters", -2.6, 1.8, -9.6, -5.9)
	_room(hull, "Bathroom", -6.0, -2.6, -4.4, -1.6)
	_room(hull, "Engineering", -6.3, -2.6, -1.3, 3.4)
	_room(hull, "Gunner", -7.4, -2.6, 3.7, 7.3)
	# Sleeping pods carved into the quarters' left wall (solid hull behind).
	for pod in POD_CENTERS:
		_carve_pod(hull, pod)

	# Oval doorways. Walls facing Z use axis "z", walls facing X use "x".
	_oval_door(hull, "Door_Quarters", "z", Vector3(-0.15, 1.05, -5.75), 1.1, 1.15)
	_oval_door(hull, "Door_Kitchen", "x", Vector3(2.2, 1.0, -4.9), 0.95, 1.35)
	_oval_door(hull, "Door_Lounge", "x", Vector3(2.2, 0.55, 1.0), 1.3, 1.35)
	_oval_door(hull, "Door_Cockpit", "z", Vector3(4.0, 1.1, -6.9), 0.8, 1.5)
	_oval_door(hull, "Door_Bathroom", "x", Vector3(-2.45, 1.1, -3.0), 0.8, 1.5)
	_oval_door(hull, "Door_Engineering", "x", Vector3(-2.45, 1.1, 1.1), 0.8, 1.5)
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
	_rib(ribs, "Quarters", "z", Vector3(-0.15, 1.05, -5.55), 1.1, 1.15)
	for x in [1.95, 2.45]:
		_rib(ribs, "Kitchen%d" % int(x * 100), "x", Vector3(x, 1.0, -4.9), 0.95, 1.35)
	for x in [1.95, 2.45, 2.9, 3.35]:
		_rib(ribs, "Lounge%d" % int(x * 100), "x", Vector3(x, 0.55, 1.0), 1.3, 1.35)
	_rib(ribs, "Cockpit", "z", Vector3(4.0, 1.1, -6.75), 0.8, 1.5)
	_rib(ribs, "Bathroom", "x", Vector3(-2.25, 1.1, -3.0), 0.8, 1.5)
	_rib(ribs, "Engineering", "x", Vector3(-2.25, 1.1, 1.1), 0.8, 1.5)
	_rib(ribs, "Gunner", "z", Vector3(-4.0, 1.1, 3.4), 0.8, 1.5)

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
	_light(lights, "Lounge", Vector3(4.4, 2.75, 1.6), Color(1.0, 0.72, 0.45), 1.3, 6.5)
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
	_mesh_box(scene_root, "ConsoleScreenLeft", Vector3(3.3, 1.05, -12.3), Vector3(0.6, 0.2, 0.3), "screen_amber")
	_mesh_box(scene_root, "ConsoleScreenRight", Vector3(4.7, 1.05, -12.3), Vector3(0.6, 0.2, 0.3), "screen_amber")

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

	var lounge_f := _furniture("LoungeFurniture")
	_ccyl(lounge_f, "TableTop", 0.7, 0.06, Vector3(4.9, 0.75, 1.6), "counter")
	_ccyl(lounge_f, "TableLeg", 0.12, 0.72, Vector3(4.9, 0.36, 1.6), "metal_dark")
	var couch := _add(lounge_f, CSGCombiner3D.new(), "CurvedCouch")
	_ring(couch, "Seat", 3.95, 4.45, 0.45, 0.225, "leather")
	_ring(couch, "Back", 4.45, 4.69, 0.95, 0.475, "leather")
	var span := _box(couch, "Span", Vector3(4.7, -0.1, -5), Vector3(8, 1.2, 9), "leather")
	span.operation = CSGShape3D.OPERATION_INTERSECTION

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
	var reactor := _add(scene_root, Node3D.new(), "Reactor")
	reactor.position = Vector3(-3.4, 0, -0.5)
	_cyl(reactor, "Base", 0.7, 0.25, 0.125, "metal_dark", true)
	_cyl(reactor, "Cap", 0.7, 0.25, 2.855, "metal_dark", true)
	_cyl(reactor, "Glass", 0.55, 2.48, 1.49, "glass", true)
	_cyl(reactor, "Core", 0.22, 2.48, 1.49, "reactor_core", false)
	var core_light := OmniLight3D.new()
	core_light.position = Vector3(0, 1.5, 0)
	core_light.light_color = Color(0.4, 0.7, 1.0)
	core_light.light_energy = 0.6
	core_light.omni_range = 3.0
	_add(reactor, core_light, "CoreLight")

	var gunner := _furniture("GunnerFurniture")
	_box(gunner, "TurretConsole", Vector3(-6.2, 0, 6.7), Vector3(-3.8, 1.0, 7.3), "trim")
	_mesh_box(scene_root, "TargetingScreen", Vector3(-5.0, 1.35, 7.15), Vector3(1.2, 0.6, 0.04), "screen_amber")

	# Things you can use.
	var use := _add(scene_root, Node3D.new(), "Interactables")

	var computer := _interactable(use, "ShipComputer", "ship_computer", Vector3(5.3, 0.9, -8.4), {"prompt": "Use ship computer"})
	var screen := _mesh_box(computer, "Screen", Vector3(0.1, 0.75, 0), Vector3(0.04, 0.45, 1.0), "screen_cyan")
	screen.rotation.z = 0.17

	var coffee := _interactable(use, "CoffeeMachine", "coffee_machine", Vector3(5.3, 0.97, -6.1))
	_box(_own_csg(coffee, "Body"), "Shell", Vector3(-0.18, 0, -0.18), Vector3(0.18, 0.45, 0.18), "counter")
	var lamp := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	lamp.mesh = sphere
	lamp.position = Vector3(-0.19, 0.36, 0)
	_add(coffee, lamp, "Lamp")

	var log_terminal := _interactable(use, "LogTerminal", "log_terminal", Vector3(1.55, 0.8, -7.4), {"prompt": "Read personal log"})
	_mesh_box(log_terminal, "Screen", Vector3(0.22, 0.65, 0), Vector3(0.04, 0.5, 0.75), "screen_amber")

	_interactable(use, "Bed", "bunk", Vector3(-2.75, 0.85, -7.6), {"prompt": "Sleep", "interact_range": 1.8})

	_inspect(use, "SpareBed", Vector3(-2.75, 2.0, -7.6), "Upper pod",
		"Mostly holds laundry these days.")
	_inspect(use, "Locker", Vector3(1.45, 1.0, -6.2), "Open locker",
		"Flight suit, two spare shirts, and a photo you don't look at much anymore.", 1.4)
	_inspect(use, "PilotSeat", Vector3(3.3, 0.5, -11.0), "Pilot seat",
		"Not going anywhere until the nav array's fixed.", 1.3)
	_inspect(use, "FoodDispenser", Vector3(5.35, 1.2, -5.0), "Food dispenser",
		"Ration paste. Today's flavor: 'savory'.", 1.6)
	_inspect(use, "LoungeWindow", Vector3(6.6, 1.6, 1.6), "Look outside",
		"Stars. A lot of them, and none of them any closer than yesterday.", 2.2)
	_inspect(use, "Shower", Vector3(-5.5, 1.0, -3.9), "Shower",
		"Recycled water, two-minute limit. Luxury.", 1.8)
	_inspect(use, "Mirror", Vector3(-3.65, 1.5, -4.2), "Mirror",
		"You look tired. The ship doesn't judge.", 1.6)
	_inspect(use, "Reactor", Vector3(-3.4, 1.2, -0.5), "Check reactor",
		"Output steady at 72%. The hum is the closest thing to company out here.", 1.6)
	_inspect(use, "Workbench", Vector3(-5.9, 1.0, 1.1), "Workbench",
		"A half-disassembled nav sensor. The fault's in here somewhere.", 1.6)
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
	_pipe(pipes, "CopperA", Vector3(-2.2, 2.62, -5.6), Vector3(-2.2, 2.62, 9.2), 0.05, "copper")
	_pipe(pipes, "CopperB", Vector3(-2.12, 2.52, -5.6), Vector3(-2.12, 2.52, 9.2), 0.035, "copper")
	for i in 3:
		_pipe(pipes, "Cable%d" % i, Vector3(1.92, 2.64 - i * 0.05, -5.6), Vector3(1.92, 2.64 - i * 0.05, 9.2), 0.03, "cable")
	_pipe(pipes, "EngRiserA", Vector3(-6.15, 0, -1.15), Vector3(-6.15, 3.0, -1.15), 0.07, "copper")
	_pipe(pipes, "EngRiserB", Vector3(-5.95, 0, -1.15), Vector3(-5.95, 3.0, -1.15), 0.045, "copper")
	_pipe(pipes, "EngOverhead", Vector3(-6.15, 2.7, -1.15), Vector3(-2.7, 2.7, -1.15), 0.06, "copper")
	_pipe(pipes, "KitchenPipe", Vector3(5.5, 2.75, -6.7), Vector3(5.5, 2.75, -3.5), 0.05, "copper")

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

	var hud: Node = (load("res://ui/hud.tscn") as PackedScene).instantiate()
	scene_root.add_child(hud)
	hud.owner = scene_root

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
	_char_mat("skin", Color(0.86, 0.64, 0.5))
	_char_mat("hair", Color(0.36, 0.22, 0.13))
	_char_mat("shirt", Color(0.55, 0.32, 0.19))
	_char_mat("scarf", Color(0.62, 0.16, 0.13))
	_char_mat("pants", Color(0.4, 0.27, 0.17))
	_char_mat("belt", Color(0.24, 0.16, 0.1), 0.6)
	_char_mat("leather", Color(0.33, 0.2, 0.12), 0.6)
	_char_mat("boots", Color(0.2, 0.18, 0.16), 0.7)
	_char_mat("sole", Color(0.1, 0.09, 0.09))
	_char_mat("laces", Color(0.7, 0.66, 0.58))
	_char_mat("pack", Color(0.38, 0.44, 0.23))
	_char_mat("strap", Color(0.27, 0.3, 0.17))
	_char_mat("bedroll", Color(0.55, 0.47, 0.33))
	_char_mat("metal", Color(0.76, 0.76, 0.73), 0.4, 0.6)
	_char_mat("metal_dark", Color(0.26, 0.27, 0.29), 0.45, 0.7)
	_char_mat("copper", Color(0.68, 0.38, 0.22), 0.4, 0.8)
	_char_mat("cable", Color(0.55, 0.15, 0.1), 0.5)
	_char_mat("glow", Color(0.3, 0.85, 1.0), 0.3, 0.0, 4.0)
	_char_mat("band_dark", Color(0.16, 0.16, 0.18), 0.7)
	_char_mat("band_light", Color(0.78, 0.78, 0.76), 0.7)
	var face_tex := _paint_face()
	ResourceSaver.save(face_tex, "res://character/face.res")
	face_tex.take_over_path("res://character/face.res")
	var face := StandardMaterial3D.new()
	face.albedo_texture = face_tex
	face.roughness = 0.8
	face.rim_enabled = true
	face.rim = 0.3
	face.rim_tint = 0.6
	ResourceSaver.save(face, "res://character/materials/face.tres")
	face.take_over_path("res://character/materials/face.tres")
	mats["char_face"] = face

	# Feet at y=0, facing -Z.
	scene_root = Node3D.new()
	scene_root.name = "Character"
	scene_root.set_script(load("res://character/character_model.gd"))
	var rig := _pivot(scene_root, "Rig", Vector3.ZERO)

	# ---- legs ----
	for side in [-1.0, 1.0]:
		var tag := "L" if side < 0 else "R"
		var hip := _pivot(rig, "Hip" + tag, Vector3(0.11 * side, 0.86, 0))
		_part(hip, "Thigh", _tube(0.1, 0.085, 0.44), "pants", Vector3(0, -0.21, 0))
		_part(hip, "CargoPocket", _block(Vector3(0.05, 0.15, 0.13)), "pants", Vector3(0.09 * side, -0.26, 0))
		_part(hip, "PocketFlap", _block(Vector3(0.055, 0.03, 0.14)), "leather", Vector3(0.09 * side, -0.18, 0))
		var knee := _pivot(hip, "Knee" + tag, Vector3(0, -0.42, 0))
		_part(knee, "Shin", _tube(0.082, 0.07, 0.34), "pants", Vector3(0, -0.15, 0))
		_part(knee, "BootShaft", _tube(0.088, 0.092, 0.15), "boots", Vector3(0, -0.33, 0))
		_part(knee, "BootCuff", _tube(0.097, 0.097, 0.035), "leather", Vector3(0, -0.26, 0))
		_part(knee, "Foot", _block(Vector3(0.15, 0.1, 0.24)), "boots", Vector3(0, -0.39, -0.05))
		_part(knee, "ToeCap", _ball(0.078, 8, 4), "boots", Vector3(0, -0.395, -0.16), Vector3.ZERO, Vector3(1, 0.65, 1))
		_part(knee, "Sole", _block(Vector3(0.165, 0.035, 0.31)), "sole", Vector3(0, -0.425, -0.07))
		_part(knee, "Laces", _block(Vector3(0.05, 0.12, 0.01)), "laces", Vector3(0, -0.33, -0.092))

	# ---- hips and belt ----
	_part(rig, "Pelvis", _tube(0.2, 0.19, 0.14), "pants", Vector3(0, 0.86, 0), Vector3.ZERO, Vector3(1, 1, 0.75))
	_part(rig, "Belt", _tube(0.212, 0.212, 0.065, 10), "belt", Vector3(0, 0.935, 0), Vector3.ZERO, Vector3(1, 1, 0.78))
	_part(rig, "Buckle", _block(Vector3(0.07, 0.055, 0.02)), "copper", Vector3(0, 0.935, -0.168))
	_part(rig, "PouchA", _block(Vector3(0.09, 0.09, 0.06)), "leather", Vector3(0.13, 0.9, -0.13), Vector3(0, -0.5, 0))
	_part(rig, "PouchB", _block(Vector3(0.09, 0.09, 0.06)), "leather", Vector3(-0.08, 0.9, 0.15), Vector3(0, 0.3, 0))
	_part(rig, "Holster", _block(Vector3(0.05, 0.2, 0.09)), "leather", Vector3(-0.22, 0.8, 0.0), Vector3(0, 0, 0.1))
	_part(rig, "Pistol", _block(Vector3(0.04, 0.07, 0.11)), "metal_dark", Vector3(-0.225, 0.92, -0.02), Vector3(0, 0, 0.1))

	# ---- chest (leans and twists as he walks) ----
	var chest := _pivot(rig, "Chest", Vector3(0, 0.95, 0))
	_part(chest, "Torso", _tube(0.24, 0.19, 0.44, 10), "shirt", Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1, 1, 0.68))
	_part(chest, "Collar", _tube(0.09, 0.12, 0.05), "shirt", Vector3(0, 0.43, 0))
	_part(chest, "Scarf", _donut(0.095, 0.035), "scarf", Vector3(0, 0.44, 0), Vector3(0.15, 0, 0))
	_part(chest, "ScarfTail", _tube(0.0, 0.08, 0.14, 3), "scarf", Vector3(0, 0.34, -0.15), Vector3(PI, 0, 0), Vector3(1, 1, 0.35))
	_part(chest, "Neck", _tube(0.055, 0.06, 0.1), "skin", Vector3(0, 0.47, 0))

	# Backpack with bedroll.
	_part(chest, "Backpack", _block(Vector3(0.32, 0.38, 0.17)), "pack", Vector3(0, 0.22, 0.2))
	_part(chest, "PackFlap", _block(Vector3(0.33, 0.1, 0.18)), "strap", Vector3(0, 0.37, 0.2))
	_part(chest, "PackPocket", _block(Vector3(0.22, 0.14, 0.05)), "strap", Vector3(0, 0.12, 0.3))
	_part(chest, "Bedroll", _tube(0.07, 0.07, 0.42, 8), "bedroll", Vector3(0, 0.48, 0.21), Vector3(0, 0, PI / 2))
	for x in [-0.12, 0.12]:
		_part(chest, "BedrollTie%d" % int(x * 100), _tube(0.075, 0.075, 0.02, 8), "strap", Vector3(x, 0.48, 0.21), Vector3(0, 0, PI / 2))
		_part(chest, "StrapFront%d" % int(x * 100), _block(Vector3(0.05, 0.34, 0.02)), "strap", Vector3(x * 0.9, 0.24, -0.165))
		_part(chest, "StrapTop%d" % int(x * 100), _block(Vector3(0.05, 0.025, 0.36)), "strap", Vector3(x * 0.9, 0.42, 0.02))

	# ---- head ----
	var head := _pivot(chest, "Head", Vector3(0, 0.5, 0))
	_part(head, "Skull", _ball(0.16, 16, 10), "face", Vector3(0, 0.17, 0), Vector3.ZERO, Vector3(1, 1.05, 0.95))
	for side in [-1.0, 1.0]:
		_part(head, "Ear" + ("L" if side < 0 else "R"), _ball(0.04, 6, 4), "skin", Vector3(0.158 * side, 0.15, 0.01), Vector3.ZERO, Vector3(0.5, 1, 0.8))
	_part(head, "Nose", _ball(0.016, 6, 4), "skin", Vector3(0, 0.138, -0.149), Vector3.ZERO, Vector3(0.8, 1, 0.9))
	# Striped headband just above the eyes.
	var stripes := ["band_dark", "band_light", "band_dark", "band_light", "band_dark"]
	for i in stripes.size():
		_part(head, "Headband%d" % i, _tube(0.17, 0.17, 0.0125, 16), stripes[i], Vector3(0, 0.232 + i * 0.0125, 0.004), Vector3(0.12, 0, 0), Vector3(1, 1, 0.96))
	_part(head, "HeadbandKnot", _block(Vector3(0.06, 0.05, 0.04)), "band_dark", Vector3(0, 0.25, 0.175))
	_part(head, "HeadbandTail", _block(Vector3(0.035, 0.012, 0.13)), "band_dark", Vector3(0.02, 0.2, 0.22), Vector3(0.9, 0.2, 0))

	# Hair: a cap tilted back off the forehead, plus spikes.
	_part(head, "HairCap", _ball(0.178, 12, 4, true), "hair", Vector3(0, 0.2, 0.02), Vector3(0.42, 0, 0), Vector3(1, 0.95, 1))
	_part(head, "HairBack", _ball(0.165, 10, 6), "hair", Vector3(0, 0.16, 0.07), Vector3.ZERO, Vector3(0.98, 1, 0.85))
	var crown := Vector3(0, 0.2, 0.02)
	var spikes := [
		[Vector3(0, 1, 0.15), 0.2], [Vector3(0.45, 0.9, 0.3), 0.19], [Vector3(-0.45, 0.9, 0.3), 0.19],
		[Vector3(0, 0.75, 0.75), 0.21], [Vector3(0.55, 0.55, 0.6), 0.18], [Vector3(-0.55, 0.55, 0.6), 0.18],
		[Vector3(0.85, 0.5, 0.05), 0.15], [Vector3(-0.85, 0.5, 0.05), 0.15], [Vector3(0, 0.3, 1), 0.17],
		[Vector3(0.3, 0.95, -0.35), 0.17], [Vector3(-0.3, 0.95, -0.35), 0.16],
		[Vector3(0.1, 0.55, -0.9), 0.14], [Vector3(-0.25, 0.5, -0.85), 0.12],
	]
	for i in spikes.size():
		var dir: Vector3 = spikes[i][0].normalized()
		var length: float = spikes[i][1]
		_part(head, "Spike%d" % i, _tube(0.0, 0.055, length, 5), "hair", crown + dir * (0.13 + length * 0.4), _aim(dir))

	# ---- left arm: flesh, short sleeve, fingerless glove ----
	var arm_l := _pivot(chest, "ShoulderL", Vector3(-0.265, 0.38, 0), Vector3(0, 0, -0.1))
	_part(arm_l, "Sleeve", _tube(0.07, 0.092, 0.2), "shirt", Vector3(0, -0.06, 0))
	_part(arm_l, "SleeveHem", _tube(0.095, 0.095, 0.025), "shirt", Vector3(0, -0.155, 0))
	_part(arm_l, "UpperArm", _tube(0.056, 0.05, 0.24), "skin", Vector3(0, -0.17, 0))
	var elbow_l := _pivot(arm_l, "ElbowL", Vector3(0, -0.29, 0), Vector3(0.25, 0, 0))
	_part(elbow_l, "Forearm", _tube(0.05, 0.044, 0.24), "skin", Vector3(0, -0.11, 0))
	_part(elbow_l, "GloveCuff", _tube(0.055, 0.052, 0.07), "leather", Vector3(0, -0.21, 0))
	_part(elbow_l, "Hand", _ball(0.058, 8, 6), "leather", Vector3(0, -0.29, -0.005), Vector3.ZERO, Vector3(0.75, 1.1, 1))
	_part(elbow_l, "Thumb", _tube(0.018, 0.02, 0.06, 6), "leather", Vector3(0.03, -0.27, -0.04), Vector3(0.5, 0, 0.5))
	_part(elbow_l, "Fingers", _block(Vector3(0.07, 0.05, 0.075)), "skin", Vector3(0, -0.345, -0.005))

	# ---- right arm: cybernetic ----
	var arm_r := _pivot(chest, "ShoulderR", Vector3(0.265, 0.38, 0), Vector3(0, 0, 0.1))
	_part(arm_r, "ShoulderJoint", _tube(0.07, 0.075, 0.12, 8), "metal_dark", Vector3(0, -0.02, 0))
	_part(arm_r, "ShoulderPlate", _block(Vector3(0.15, 0.035, 0.17)), "metal", Vector3(0.025, 0.045, 0), Vector3(0, 0, -0.35))
	_part(arm_r, "ShoulderPlateLower", _block(Vector3(0.035, 0.08, 0.16)), "metal", Vector3(0.09, -0.02, 0), Vector3(0, 0, 0.1))
	_part(arm_r, "PlateTrim", _block(Vector3(0.155, 0.012, 0.175)), "metal_dark", Vector3(0.02, 0.027, 0), Vector3(0, 0, -0.35))
	_part(arm_r, "UpperArm", _tube(0.056, 0.05, 0.24), "metal_dark", Vector3(0, -0.16, 0))
	_part(arm_r, "PistonA", _tube(0.014, 0.014, 0.2, 6), "copper", Vector3(0.062, -0.16, 0.0))
	_part(arm_r, "PistonB", _tube(0.012, 0.012, 0.2, 6), "copper", Vector3(-0.02, -0.16, 0.062))
	var elbow_r := _pivot(arm_r, "ElbowR", Vector3(0, -0.29, 0), Vector3(0.25, 0, 0))
	_part(elbow_r, "ElbowJoint", _ball(0.062, 8, 6), "copper", Vector3.ZERO)
	_part(elbow_r, "Forearm", _tube(0.074, 0.06, 0.22, 8), "metal", Vector3(0, -0.13, 0))
	_part(elbow_r, "ForearmPlate", _tube(0.078, 0.076, 0.08, 8), "metal_dark", Vector3(0, -0.06, 0))
	_part(elbow_r, "CableFront", _tube(0.013, 0.013, 0.2, 5), "cable", Vector3(0.0, -0.13, -0.072))
	_part(elbow_r, "CableSide", _tube(0.013, 0.013, 0.2, 5), "cable", Vector3(0.07, -0.13, -0.01))
	_part(elbow_r, "WristGlow", _donut(0.054, 0.012), "glow", Vector3(0, -0.245, 0))
	_part(elbow_r, "Hand", _ball(0.064, 8, 6), "metal", Vector3(0, -0.3, -0.005), Vector3.ZERO, Vector3(0.85, 1.05, 1))
	for i in 3:
		_part(elbow_r, "Finger%d" % i, _tube(0.014, 0.012, 0.07, 5), "metal_dark", Vector3(-0.022 + i * 0.022, -0.36, -0.035))
	_part(elbow_r, "Thumb", _tube(0.015, 0.013, 0.06, 5), "metal_dark", Vector3(-0.045, -0.29, -0.04), Vector3(0.4, 0, -0.5))
	_part(elbow_r, "Palm", _tube(0.03, 0.03, 0.006, 8), "glow", Vector3(-0.054, -0.3, 0), Vector3(0, 0, PI / 2))
	var palm_light := OmniLight3D.new()
	palm_light.position = Vector3(-0.1, -0.3, 0)
	palm_light.light_color = Color(0.3, 0.85, 1.0)
	palm_light.light_energy = 0.3
	palm_light.omni_range = 0.6
	_add(elbow_r, palm_light, "PalmLight")

	_save(scene_root, "res://character/character.tscn")



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
	# Wings sloping down to both sides, with stepped (swept) outer sections and tip fins.
	var wing_l := _add(ext, CSGCombiner3D.new(), "WingLeft")
	_profile_z(wing_l, "Inner", [Vector2(-7.65, 0.7), Vector2(-7.65, 1.15), Vector2(-11.0, 0.45), Vector2(-11.0, 0.2)], 7.5, -9.3, "hull_outer")
	_profile_z(wing_l, "Outer", [Vector2(-10.9, 0.22), Vector2(-10.9, 0.47), Vector2(-14.0, -0.1), Vector2(-14.0, -0.25)], 6.5, -4.5, "hull_outer")
	_profile_x(wing_l, "TipFin", [Vector2(-4.0, -0.15), Vector2(-3.2, 1.3), Vector2(4.5, 1.3), Vector2(6.3, -0.15)], -13.75, -14.05, "hull_outer")
	var wing_r := _add(ext, CSGCombiner3D.new(), "WingRight")
	_profile_z(wing_r, "Inner", [Vector2(5.85, 0.55), Vector2(5.85, 0.95), Vector2(10.0, 0.35), Vector2(10.0, 0.1)], 8.5, -6.8, "hull_outer")
	_profile_z(wing_r, "Outer", [Vector2(9.9, 0.12), Vector2(9.9, 0.37), Vector2(12.8, -0.15), Vector2(12.8, -0.3)], 7.5, -3.0, "hull_outer")
	_profile_x(wing_r, "TipFin", [Vector2(-2.5, -0.2), Vector2(-1.8, 1.2), Vector2(5.8, 1.2), Vector2(7.3, -0.2)], 12.85, 12.55, "hull_outer")
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
	_box(ext, "StripeRight", Vector3(5.85, 2.65, -9.6), Vector3(5.95, 2.9, 9.4), "stripe")
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
	var couch: CSGCombiner3D = R.get_node("LoungeFurniture/CurvedCouch")
	var gone := _box(couch, "Torn", Vector3(5.2, -0.2, 0.1), Vector3(8.0, 1.5, 4.7), "leather", true)
	gone.operation = CSGShape3D.OPERATION_SUBTRACTION
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
	var lounge: CSGCombiner3D = R.get_node("LoungeFurniture")
	var top: CSGCylinder3D = lounge.get_node("TableTop")
	top.rotation = Vector3(PI / 2 - 0.15, 0.0, 0.4)
	top.position = Vector3(4.3, 0.68, 2.6)
	var leg: CSGCylinder3D = lounge.get_node("TableLeg")
	leg.rotation = Vector3(0.0, 0.0, PI / 2)
	leg.position = Vector3(4.5, 0.12, 2.3)
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
			_add(site, bm, "Sunbeam%d_%d" % [k, q])

	# Butterflies around the meadow and pond.
	var wing_quad := QuadMesh.new()
	wing_quad.size = Vector2(0.12, 0.1)
	for k in 8:
		var fly := Node3D.new()
		fly.set_script(load("res://world/butterfly.gd"))
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
	return _clear_dist(p) < margin or _in_ship_zone(p, 3.0 + margin) or _in_trail(p)
