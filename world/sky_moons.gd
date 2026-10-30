@tool
extends Node3D

## The two moons in the sky: an enormous icy-blue moon, lit along one side,
## whose lower part sinks into the atmosphere, and a small, faint silver-blue
## moon nearby.
##
## Both are real spheres (world/sky_moon.gdshader) that stay a fixed distance
## out from whatever camera is current, so they hang in the sky, can't be
## walked up to, and are hidden by trees, the ship and the sky's painted
## mountains. Each frame they take the time of day (day, dusk, sun direction)
## from the sky material, so they stay up all day and night: in daylight the
## shadowed side is only a slightly deeper blue, warmer light at dusk, dark
## discs with bright lit edges at night.
##
## Positions are azimuth (degrees clockwise from north, -Z, towards east, +X)
## and elevation (degrees above the horizon), in the sky's frame. Sizes are
## angular radii in degrees.

@export_group("Giant moon")
@export_range(-180.0, 180.0) var giant_azimuth := 86.0
@export_range(-10.0, 90.0) var giant_elevation := 34.0
@export_range(1.0, 60.0) var giant_size := 28.0
## Turns the surface (which craters face us), in degrees.
@export var giant_spin := Vector3(20.0, 140.0, 0.0)
## Faint pearl sheen (cyan, lavender, violet) on the icy surface.
@export_range(0.0, 1.5) var iridescence := 0.8
@export_range(0.0, 3.0) var giant_crater_depth := 0.45
## Fraction of the giant moon (from the bottom) lost in the atmosphere.
@export_range(0.0, 0.9) var atmosphere_depth := 0.3
@export_range(0.0, 2.0) var rim_strength := 0.6
@export_range(0.0, 2.0) var glow_strength := 0.5
## How much of the shadowed body shows against the day sky.
@export_range(0.0, 1.0) var shadow_visibility := 0.3

@export_group("Small moon")
@export_range(-180.0, 180.0) var small_azimuth := 52.0
@export_range(-10.0, 90.0) var small_elevation := 54.0
@export_range(0.5, 20.0) var small_size := 3.5
@export var small_spin := Vector3(-30.0, 60.0, 10.0)
@export_range(0.0, 3.0) var small_crater_depth := 0.8

@export_group("Light")
## Where the light falls on the moons, as an angle round the giant moon's
## disc (degrees, 0 = from its right, 90 = from above) ...
@export_range(-180.0, 180.0) var light_angle := 170.0
## ... and how far it comes from behind them (thinner crescents) or from
## behind the viewer (fuller faces), -1..1.
@export_range(-1.0, 1.0) var light_fullness := -0.3

## Copied from the sky material each frame when it has them.
const SKY_PARAMS := ["day", "dusk", "sky_rot", "mountains", "space", "pixel"]

var _giant: ShaderMaterial
var _small: ShaderMaterial
var _halo: ShaderMaterial


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	var shader := load("res://world/sky_moon.gdshader")
	_giant = _add_moon("GiantMoon", sphere, shader)
	_small = _add_moon("SmallMoon", sphere, shader)
	_halo = ShaderMaterial.new()
	_halo.shader = load("res://world/sky_moon_halo.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	_add_instance("GiantHalo", quad, _halo)
	_update()


func _add_moon(n: String, mesh: Mesh, shader: Shader) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_add_instance(n, mesh, mat)
	return mat


func _add_instance(n: String, mesh: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader moves it out to the sky; never cull it where it sits.
	mi.extra_cull_margin = 16384.0
	add_child(mi)


func _process(_delta: float) -> void:
	_update()


## Points one moon ("giant" or "small") along a sky-frame direction.
func point_at(which: String, dir: Vector3) -> void:
	var d := dir.normalized()
	set(which + "_azimuth", rad_to_deg(atan2(d.x, -d.z)))
	set(which + "_elevation", rad_to_deg(asin(clampf(d.y, -1.0, 1.0))))
	_update()


static func _direction(azimuth: float, elevation: float) -> Vector3:
	var az := deg_to_rad(azimuth)
	var el := deg_to_rad(elevation)
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))


static func _spin_basis(spin: Vector3) -> Basis:
	return Basis.from_euler(spin * PI / 180.0)


func _update() -> void:
	if not _giant:
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	# Well inside the far plane, whatever camera this is.
	var dist := (cam.far if cam else 4000.0) * 0.8
	var sky: ShaderMaterial = null
	var world := get_viewport().find_world_3d() if is_inside_tree() else null
	if world and world.environment and world.environment.sky:
		sky = world.environment.sky.sky_material as ShaderMaterial
	var gdir := _direction(giant_azimuth, giant_elevation)
	var right := gdir.cross(Vector3.UP).normalized()
	var up := right.cross(gdir)
	var a := deg_to_rad(light_angle)
	var key := (right * cos(a) + up * sin(a)) * sqrt(1.0 - light_fullness * light_fullness) - gdir * light_fullness
	var ang := deg_to_rad(giant_size)
	var el := deg_to_rad(giant_elevation)
	var haze_top := el - ang * (1.0 - 2.0 * atmosphere_depth) if atmosphere_depth > 0.0 else -10.0
	_set_moon(_giant, 0, giant_azimuth, giant_elevation, giant_size, giant_spin, giant_crater_depth, dist, 1.0)
	_giant.set_shader_parameter("iridescence", iridescence)
	_giant.set_shader_parameter("rim_strength", rim_strength)
	_giant.set_shader_parameter("dark_alpha", shadow_visibility)
	_giant.set_shader_parameter("haze_top", haze_top)
	_giant.set_shader_parameter("haze_bottom", haze_top - ang * 0.45)
	_set_moon(_small, 1, small_azimuth, small_elevation, small_size, small_spin, small_crater_depth, dist * 0.98, 4.0)
	_small.set_shader_parameter("rim_strength", rim_strength)
	_small.set_shader_parameter("dark_alpha", shadow_visibility * 0.8)
	for m in [_giant, _small, _halo]:
		m.set_shader_parameter("key_light", key)
	_halo.set_shader_parameter("direction", gdir)
	_halo.set_shader_parameter("angular_radius", ang)
	_halo.set_shader_parameter("distance_m", dist)
	_halo.set_shader_parameter("strength", glow_strength)
	_halo.set_shader_parameter("haze_top", haze_top)
	_halo.set_shader_parameter("haze_bottom", haze_top - ang * 0.45)
	if sky:
		for p in SKY_PARAMS:
			var v: Variant = sky.get_shader_parameter(p)
			if v == null:
				continue
			for m in [_giant, _small, _halo]:
				m.set_shader_parameter(p, v)


func _set_moon(m: ShaderMaterial, kind: int, az: float, el: float, size: float, spin: Vector3, depth: float, dist: float, seed: float) -> void:
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("direction", _direction(az, el))
	m.set_shader_parameter("angular_radius", deg_to_rad(size))
	m.set_shader_parameter("distance_m", dist)
	m.set_shader_parameter("orient", _spin_basis(spin))
	m.set_shader_parameter("crater_depth", depth)
	m.set_shader_parameter("seed", seed)
