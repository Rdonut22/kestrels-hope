extends Node3D

## A field of flowing low-poly grass (tufts from world/grass_tuft.gd, wind in
## world/grass.gdshader). Where it grows and how tall comes from
## `density_map`: red = how thick (0..1), green = how tall, covering a square
## `area_size` metres across centred on this node. The field is split into
## chunks (one MultiMesh per tuft shape per chunk) so off-screen and distant
## chunks are culled; blades sink into the ground towards `view_distance`.
## Built when the scene starts; no collision.

@export var density_map: Texture2D
@export var area_size := 200.0
@export var chunk_size := 16.0
## Tufts per square metre where the map is fully red (the main quality knob).
@export_range(0.1, 10.0) var density := 6.0
@export var min_height := 0.22
@export var max_height := 1.05
## Grass is drawn out to here (metres from the camera).
@export var view_distance := 38.0
@export var seed := 4023

@export_group("Wind")
@export var wind_direction := Vector2(1.0, 0.35):
	set(v):
		wind_direction = v
		_set_param("wind_direction", v)
@export_range(0.0, 2.0) var wind_strength := 0.55:
	set(v):
		wind_strength = v
		_set_param("wind_strength", v)
@export_range(0.0, 10.0) var wind_speed := 2.4:
	set(v):
		wind_speed = v
		_set_param("wind_speed", v)
@export_range(1.0, 60.0) var wave_scale := 14.0:
	set(v):
		wave_scale = v
		_set_param("wave_scale", v)
@export_range(0.0, 2.0) var gust_strength := 0.7:
	set(v):
		gust_strength = v
		_set_param("gust_strength", v)
@export_range(5.0, 200.0) var gust_scale := 45.0:
	set(v):
		gust_scale = v
		_set_param("gust_scale", v)
@export_range(0.0, 1.0) var flutter := 0.12:
	set(v):
		flutter = v
		_set_param("flutter", v)

const Tuft := preload("res://world/grass_tuft.gd")
## Tuft shapes: [seed, short]. Short ones go where the map says low grass.
const SHAPES := [[7, false], [21, false], [33, false], [5, true], [12, true]]

var material: ShaderMaterial
var _player: Node3D
var _map := PackedByteArray()
var _map_w := 1
var _map_h := 1
var _meshes := []
var _pending: Array[Vector2i] = []


func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://world/grass.gdshader")
	for p in ["wind_direction", "wind_strength", "wind_speed", "wave_scale", "gust_strength", "gust_scale", "flutter"]:
		material.set_shader_parameter(p, get(p))
	material.set_shader_parameter("fade_start", view_distance - 10.0)
	material.set_shader_parameter("fade_end", view_distance)
	_build.call_deferred()
	# Darken with the day-night cycle like the rest of the world.
	var clock := get_tree().get_first_node_in_group("day_night")
	if clock and "_tinted" in clock:
		clock._tinted.append(material)


func _set_param(p: String, v: Variant) -> void:
	if material:
		material.set_shader_parameter(p, v)


func _build() -> void:
	if not density_map:
		return
	var img := density_map.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	_map = img.get_data()
	_map_w = img.get_width()
	_map_h = img.get_height()
	for s in SHAPES:
		_meshes.append(Tuft.build(22 if not s[1] else 16, 0.62 if not s[1] else 0.5, s[0], s[1]))
	var n := int(ceil(area_size / chunk_size))
	for cz in n:
		for cx in n:
			_pending.append(Vector2i(cx, cz))
	# What's around the camera right away; the rest streams in (_process).
	_stream(9999, view_distance + chunk_size)


## Build up to `budget` not-yet-built chunks, nearest the camera first (only
## those within `reach` metres).
func _stream(budget: int, reach := INF) -> void:
	if _pending.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	var eye := to_local(cam.global_position) if cam else Vector3.ZERO
	var half := area_size / 2.0
	var centre := func(c: Vector2i) -> Vector2:
		return Vector2(-half + (c.x + 0.5) * chunk_size, -half + (c.y + 0.5) * chunk_size)
	_pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return centre.call(a).distance_squared_to(Vector2(eye.x, eye.z)) < centre.call(b).distance_squared_to(Vector2(eye.x, eye.z)))
	while budget > 0 and not _pending.is_empty():
		var c: Vector2i = _pending[0]
		if (centre.call(c) as Vector2).distance_to(Vector2(eye.x, eye.z)) > reach:
			return
		_pending.pop_front()
		_build_chunk(c)
		budget -= 1


func _build_chunk(c: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(seed, c.x, c.y))
	var half := area_size / 2.0
	var x0 := -half + c.x * chunk_size
	var z0 := -half + c.y * chunk_size
	var bufs := []
	for s in SHAPES:
		bufs.append([])
	for k in int(density * chunk_size * chunk_size):
		var x := x0 + rng.randf() * chunk_size
		var z := z0 + rng.randf() * chunk_size
		var m := _sample(x, z)
		if rng.randf() >= m.x:
			continue
		var h := lerpf(min_height, max_height, m.y) * rng.randf_range(0.75, 1.2)
		var short := h < 0.5
		var shape := (3 + rng.randi() % 2) if short else rng.randi() % 3
		var size := h / (0.55 if short else 1.0)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size * rng.randf_range(0.85, 1.25), size, size * rng.randf_range(0.85, 1.25)))
		var tint := Color(1, 1, 1).lerp(Color(1.12, 1.08, 0.8), rng.randf() * 0.5).lerp(Color(0.8, 0.9, 0.8), rng.randf() * 0.3)
		# MultiMesh buffer layout: 3x4 transform rows, then the colour.
		(bufs[shape] as Array).append_array([b.x.x, b.y.x, b.z.x, x, b.x.y, b.y.y, b.z.y, 0.0,
			b.x.z, b.y.z, b.z.z, z, tint.r, tint.g, tint.b, 1.0])
	for i in SHAPES.size():
		if (bufs[i] as Array).is_empty():
			continue
		var buf := PackedFloat32Array(bufs[i])
		if buf.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _meshes[i]
		mm.instance_count = buf.size() / 16
		mm.buffer = buf
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Chunk%d_%d_%d" % [c.x, c.y, i]
		mmi.multimesh = mm
		mmi.material_override = material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.extra_cull_margin = 1.5
		mmi.visibility_range_end = view_distance + chunk_size * 0.75
		mmi.visibility_range_end_margin = 4.0
		add_child(mmi)


## Bilinear lookup in the density map at a local ground point:
## (thickness, height), 0..1.
func _sample(x: float, z: float) -> Vector2:
	var u := (x / area_size + 0.5) * _map_w - 0.5
	var v := (z / area_size + 0.5) * _map_h - 0.5
	var x0 := clampi(int(floor(u)), 0, _map_w - 1)
	var y0 := clampi(int(floor(v)), 0, _map_h - 1)
	var x1 := mini(x0 + 1, _map_w - 1)
	var y1 := mini(y0 + 1, _map_h - 1)
	var fx := clampf(u - floor(u), 0.0, 1.0)
	var fy := clampf(v - floor(v), 0.0, 1.0)
	var top := _px(x0, y0).lerp(_px(x1, y0), fx)
	var bottom := _px(x0, y1).lerp(_px(x1, y1), fx)
	return top.lerp(bottom, fy)


func _px(x: int, y: int) -> Vector2:
	var i := (y * _map_w + x) * 3
	return Vector2(_map[i] / 255.0, _map[i + 1] / 255.0)


func _process(_delta: float) -> void:
	_stream(2)
	if not _player or not is_instance_valid(_player):
		var scene := get_tree().current_scene
		_player = scene.get_node_or_null("Player") if scene else null
		if not _player:
			return
	material.set_shader_parameter("player_pos", _player.global_position + Vector3(0, -1.0, 0))
