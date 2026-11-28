class_name CookProps
extends RefCounted

## Built-in placeholder props for the kitchen and the ingredient panel. Each
## stands in for a model still to come (see cooking/README.md): the mug, the
## serving bowl, the spatula, the coffee tin and the water jug; plus steam,
## falling grains and a pouring stream. Sizes in metres, origin at the
## bottom centre unless noted.

static var _mats := {}


static func mat(key: String, color: Color, rough := 0.6, metal := 0.0, alpha := 1.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	m.roughness = rough
	m.metallic = metal
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


static func _mesh(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, n := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	if n != "":
		mi.name = n
	parent.add_child(mi)
	return mi


static func _cyl(top: float, bottom: float, h: float, segs := 24) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


## A ceramic mug with a "Liquid" (its height set by set_mug) and a
## "Grounds" layer.
static func mug() -> Node3D:
	var root := Node3D.new()
	root.name = "Mug"
	var ceramic := mat("mug", Color(0.78, 0.74, 0.66), 0.55)
	_mesh(root, _cyl(0.042, 0.038, 0.095), ceramic, Vector3(0, 0.0475, 0))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.037
	rim.outer_radius = 0.043
	_mesh(root, rim, ceramic, Vector3(0, 0.095, 0))
	var handle := TorusMesh.new()
	handle.inner_radius = 0.018
	handle.outer_radius = 0.028
	var h := _mesh(root, handle, ceramic, Vector3(0.048, 0.05, 0))
	h.rotation.x = PI / 2
	var inside := _mesh(root, _cyl(0.037, 0.034, 0.002), mat("mug_in", Color(0.25, 0.22, 0.19), 0.7), Vector3(0, 0.012, 0), "Inside")
	inside.visible = true
	var grounds := _mesh(root, _cyl(0.035, 0.034, 0.008), mat("grounds", Color(0.16, 0.09, 0.05), 0.95), Vector3(0, 0.016, 0), "Grounds")
	grounds.visible = false
	var liquid := _mesh(root, _cyl(0.0365, 0.034, 1.0), mat("coffee", Color(0.11, 0.06, 0.03), 0.15), Vector3(0, 0.01, 0), "Liquid")
	liquid.visible = false
	return root


## How full the mug looks (0..1) and of what.
static func set_mug(m: Node3D, grounds: bool, fill: float, coffee: bool) -> void:
	(m.get_node("Grounds") as Node3D).visible = grounds and fill <= 0.01
	var l := m.get_node("Liquid") as MeshInstance3D
	l.visible = fill > 0.01
	var h := 0.075 * clampf(fill, 0.0, 1.0)
	l.scale = Vector3(1, maxf(h, 0.001), 1)
	l.position.y = 0.012 + h * 0.5
	l.material_override = mat("coffee", Color(0.11, 0.06, 0.03), 0.15) if coffee else mat("hot_water", Color(0.55, 0.62, 0.62), 0.05, 0.0, 0.6)


## A shallow serving bowl; its "Food" node holds what's served in it.
static func bowl() -> Node3D:
	var root := Node3D.new()
	root.name = "Bowl"
	var glaze := mat("bowl", Color(0.32, 0.42, 0.46), 0.45)
	_mesh(root, _cyl(0.085, 0.05, 0.045), glaze, Vector3(0, 0.0225, 0))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.08
	rim.outer_radius = 0.089
	_mesh(root, rim, glaze, Vector3(0, 0.045, 0))
	_mesh(root, _cyl(0.078, 0.05, 0.002), mat("bowl_in", Color(0.6, 0.6, 0.55), 0.5), Vector3(0, 0.044, 0))
	var food := Node3D.new()
	food.name = "Food"
	food.position = Vector3(0, 0.045, 0)
	root.add_child(food)
	return root


## A spatula, its origin at the middle of the handle; the blade along -Z.
static func spatula() -> Node3D:
	var root := Node3D.new()
	root.name = "Spatula"
	var wood := mat("spat_wood", Color(0.45, 0.29, 0.16), 0.75)
	var steel := mat("spat_steel", Color(0.7, 0.7, 0.72), 0.3, 0.9)
	var handle := _mesh(root, _cyl(0.009, 0.011, 0.16, 12), wood, Vector3(0, 0, 0.06))
	handle.rotation.x = PI / 2
	var neck := _mesh(root, _cyl(0.004, 0.004, 0.05, 8), steel, Vector3(0, 0, -0.045))
	neck.rotation.x = PI / 2
	var blade := BoxMesh.new()
	blade.size = Vector3(0.06, 0.004, 0.075)
	_mesh(root, blade, steel, Vector3(0, -0.002, -0.105))
	return root


## The coffee tin (the panel's coffee grounds): copper, grounds heaped in
## its open top. Origin at its bottom centre.
static func coffee_tin() -> Node3D:
	var root := Node3D.new()
	root.name = "CoffeeTin"
	_mesh(root, _cyl(0.045, 0.045, 0.09), mat("tin", Color(0.55, 0.3, 0.14), 0.4, 0.7), Vector3(0, 0.045, 0))
	_mesh(root, _cyl(0.046, 0.046, 0.022), mat("tin_band", Color(0.85, 0.62, 0.3), 0.5, 0.2), Vector3(0, 0.05, 0))
	var heap := SphereMesh.new()
	heap.radius = 0.043
	heap.height = 0.03
	_mesh(root, heap, mat("grounds", Color(0.16, 0.09, 0.05), 0.95), Vector3(0, 0.09, 0))
	return root


## The water jug: clear walls, a lid, and a "Water" column (set_jug).
static func water_jug() -> Node3D:
	var root := Node3D.new()
	root.name = "WaterJug"
	var glass := mat("jug_glass", Color(0.85, 0.92, 0.95), 0.05, 0.0, 0.22)
	_mesh(root, _cyl(0.05, 0.05, 0.16), glass, Vector3(0, 0.08, 0))
	_mesh(root, _cyl(0.052, 0.052, 0.02), mat("jug_lid", Color(0.35, 0.33, 0.3), 0.5, 0.6), Vector3(0, 0.17, 0))
	_mesh(root, _cyl(0.053, 0.053, 0.012), mat("jug_band", Color(0.85, 0.5, 0.15), 0.5, 0.3), Vector3(0, 0.006, 0))
	var water := _mesh(root, _cyl(0.046, 0.046, 1.0), mat("jug_water", Color(0.3, 0.6, 0.85), 0.05, 0.0, 0.7), Vector3(0, 0.01, 0), "Water")
	set_jug(root, 1.0)
	return root


static func set_jug(j: Node3D, level: float) -> void:
	var w := j.get_node("Water") as MeshInstance3D
	var h := 0.145 * clampf(level, 0.0, 1.0)
	w.visible = h > 0.002
	w.scale = Vector3(1, maxf(h, 0.001), 1)
	w.position.y = 0.012 + h * 0.5


## Soft steam rising from a point (set `emitting` and `amount_ratio`).
static func steam() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Steam"
	p.amount = 24
	p.lifetime = 2.2
	p.emitting = false
	var q := QuadMesh.new()
	q.size = Vector2(0.1, 0.1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _puff()
	q.material = m
	p.mesh = q
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.12
	p.gravity = Vector3(0, 0.03, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 2.2))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.add_point(0.2, Color(1, 1, 1, 0.35))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0.0))
	p.color_ramp = g
	return p


static var _puff_tex: Texture2D


static func _puff() -> Texture2D:
	if _puff_tex:
		return _puff_tex
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x - n / 2.0 + 0.5, y - n / 2.0 + 0.5).length() / (n / 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) * (1.0 - d)))
	_puff_tex = ImageTexture.create_from_image(img)
	return _puff_tex


## Little grains falling from a point (coffee into the mug).
static func grains(color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Grains"
	p.amount = 60
	p.lifetime = 0.5
	p.emitting = false
	var b := BoxMesh.new()
	b.size = Vector3.ONE * 0.004
	b.material = mat("grain", color, 0.9)
	p.mesh = b
	p.direction = Vector3.DOWN
	p.spread = 8.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	p.gravity = Vector3(0, -6.0, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.01
	return p


## A pouring stream: a thin column from `from` down to `to` (set_stream).
static func stream(color: Color, alpha := 0.75) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Stream"
	mi.mesh = _cyl(0.005, 0.0035, 1.0, 8)
	mi.material_override = mat("stream_%s" % color.to_html(), color, 0.05, 0.0, alpha)
	mi.visible = false
	return mi


static func set_stream(s: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var d := from - to
	s.global_position = (from + to) * 0.5
	s.scale = Vector3(1, maxf(d.length(), 0.001), 1)
	if d.length() > 0.001:
		var up := d.normalized()
		var side := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
		s.global_basis = Basis(side, up, side.cross(up)).scaled(s.scale)


# ------------------------------------------------------------ models

const SACK := "res://cooking/models/coffee_sack.glb"
const FLASK := "res://cooking/models/water_flask.glb"
const MEAL_PACK := "res://cooking/models/meal_pack.glb"
const RATION_CUBES := "res://cooking/models/ration_cubes.glb"


## A model file, scaled to `height` metres tall, its origin moved to the
## bottom centre.
static func model(path: String, height: float) -> Node3D:
	var root := Node3D.new()
	var scene := load(path) as PackedScene
	if scene == null:
		return root
	var inner: Node3D = scene.instantiate()
	root.add_child(inner)
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in inner.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var s := height / maxf(box.size.y, 0.0001)
	inner.scale = Vector3.ONE * s
	inner.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * s
	return root


## The coffee sack (the panel's coffee grounds).
static func coffee_sack() -> Node3D:
	var n := model(SACK, 0.2)
	n.name = "CoffeeSack"
	return n


## A scoop of grounds: what's carried from the sack to the mug. Placeholder.
static func scoop() -> Node3D:
	var root := Node3D.new()
	root.name = "Scoop"
	var wood := mat("scoop", Color(0.5, 0.33, 0.18), 0.7)
	var cup := _mesh(root, _cyl(0.03, 0.022, 0.03, 16), wood, Vector3(0, 0.015, 0))
	cup.name = "Cup"
	var handle := _mesh(root, _cyl(0.006, 0.007, 0.09, 8), wood, Vector3(0.06, 0.025, 0))
	handle.rotation.z = PI / 2 - 0.25
	var heap := SphereMesh.new()
	heap.radius = 0.028
	heap.height = 0.02
	_mesh(root, heap, mat("grounds", Color(0.16, 0.09, 0.05), 0.95), Vector3(0, 0.031, 0), "Heap")
	return root


## The water flask: its glass shows a "Water" column (set_flask).
static func water_flask(level := 1.0) -> Node3D:
	var root := model(FLASK, 0.24)
	root.name = "WaterFlask"
	var inner := root.get_child(0) as Node3D
	var glass := inner.find_child("Glass", true, false) as MeshInstance3D
	if glass and glass.mesh:
		# See-through glass (the model's own texture, faded), the water inside.
		var src := glass.mesh.surface_get_material(0) as StandardMaterial3D
		var m: StandardMaterial3D = src.duplicate() if src else StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, 0.32)
		m.cull_mode = BaseMaterial3D.CULL_BACK
		m.roughness = 0.08
		glass.material_override = m
	# The glass runs from model y -0.68 to 0.38 of its 1.9 height, radius 0.435.
	var s := inner.scale.x
	var bottom := (-0.66 + 0.952) * s
	var water := _mesh(root, _cyl(0.4 * s, 0.4 * s, 1.0), mat("flask_water", Color(0.32, 0.62, 0.88), 0.05, 0.0, 0.75), Vector3(0, bottom, 0), "Water")
	water.set_meta("bottom", bottom)
	water.set_meta("height", (0.36 + 0.66) * s)
	set_flask(root, level)
	return root


static func set_flask(f: Node3D, level: float) -> void:
	var w := f.get_node_or_null("Water") as MeshInstance3D
	if w == null:
		return
	var h: float = float(w.get_meta("height")) * clampf(level, 0.0, 1.0)
	w.visible = h > 0.001
	w.scale = Vector3(1, maxf(h, 0.001), 1)
	w.position.y = float(w.get_meta("bottom")) + h * 0.5


static func meal_pack() -> Node3D:
	var n := model(MEAL_PACK, 0.15)
	n.name = "MealPack"
	return n


## The pack's contents: a pair of ration cubes (one model).
static func ration_cubes() -> Node3D:
	var n := model(RATION_CUBES, 0.05)
	n.name = "RationCubes"
	return n


## Ration cubes' colour as they cook: dried pale grain to browned (0..1).
static func cook_tint(food: Node3D, done: float) -> void:
	var c := Color(1, 1, 1).lerp(Color(0.72, 0.5, 0.33), clampf(done, 0.0, 1.0))
	for mi: MeshInstance3D in food.find_children("*", "MeshInstance3D", true, false):
		var src := mi.get_active_material(0) as StandardMaterial3D
		if src == null:
			continue
		if not mi.has_meta("own_mat"):
			var m := src.duplicate() as StandardMaterial3D
			mi.material_override = m
			mi.set_meta("own_mat", true)
		(mi.material_override as StandardMaterial3D).albedo_color = c
