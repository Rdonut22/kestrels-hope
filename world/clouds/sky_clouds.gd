@tool
class_name SkyClouds
extends Node

## Giant towering cumulus clouds for the day sky.
##
## The clouds are raymarched (world/clouds/cloud_bake.gdshader) into a sky
## panorama held in a SubViewport: one texel per sky direction, azimuth across,
## elevation up. Only a band of rows is re-rendered each frame, so the cost is
## small and constant however big the screen, and the clouds drift smoothly
## (the GL Compatibility renderer has no half-resolution sky pass, so this is
## how the expensive part is kept off the per-pixel sky).
##
## The panorama is handed to the sky material (world/day_sky.gdshader, which
## draws it between the sky and the painted mountains) as `cloud_tex`, and the
## moons (world/sky_moons.gd) pick it up from there so clouds pass in front of
## them. Time of day (day, dusk, sun_dir) and the sky colours are read from the
## sky material every frame, so world/day_night.gd needs no changes.
##
## Add this node anywhere in a scene whose WorldEnvironment uses the day sky.

enum Quality { LOW, MEDIUM, HIGH, ULTRA }

@export var enabled := true:
	set(v):
		enabled = v
		_sky_dirty = true

@export_group("Sky colour")
## Repaint the day sky a deeper, richer blue to set off the clouds
## (overrides top_color / horizon_color on the sky material).
@export var override_sky_colors := true
@export var sky_zenith := Color(0.1, 0.4, 0.8)
@export var sky_horizon := Color(0.56, 0.76, 0.92)

@export_group("Shape")
## How many clouds: the chance each patch of sky holds a cumulus.
@export_range(0.0, 1.0) var coverage := 0.55
## Height of the flat cloud bases above the ground.
@export_range(0.2, 6.0, 0.05, "suffix:km") var cloud_height := 1.6
## How tall the layer is: how high the towers can climb.
@export_range(1.0, 20.0, 0.1, "suffix:km") var cloud_thickness := 13.0
@export_range(0.1, 3.0) var cloud_density := 1.0
## Size of the formations (bigger = fewer, larger billows).
@export_range(0.3, 3.0) var cloud_scale := 1.0
## Width of the soft fall-off at the edges of each lobe.
@export_range(0.02, 1.0) var cloud_softness := 0.32
## How much the dense centres tower above the edges.
@export_range(0.0, 1.0) var tower_strength := 0.85
## Medium-sized rounded billows.
@export_range(0.0, 1.0) var billow_strength := 0.75
## Small lobes carved into the edges.
@export_range(0.0, 1.0) var detail_strength := 0.3
## Smaller planet = stronger curvature towards the horizon.
@export_range(500.0, 8000.0, 10.0, "suffix:km") var planet_radius := 2500.0
## Clouds thin out within this distance, keeping the sky overhead open so
## the towers stand around the horizon.
@export_range(0.0, 40.0, 0.5, "suffix:km") var clear_overhead := 16.0

## Fraction of the tallest towers that spread into a cumulonimbus anvil.
@export_range(0.0, 1.0) var anvil_chance := 0.25

@export_group("Hero tower")
## One giant, art-directed cumulus at a fixed place in the sky.
@export_range(0.0, 1.5) var hero_strength := 1.0
## Degrees clockwise from north (-Z) towards east (+X), like the moons.
@export_range(-180.0, 180.0) var hero_azimuth := 15.0
@export_range(5.0, 120.0, 0.5, "suffix:km") var hero_distance := 30.0
@export_range(1.0, 30.0, 0.5, "suffix:km") var hero_radius := 11.0

@export_group("Lighting")
## Override the sun direction (direction TO the sun). Zero = follow the day sky.
@export var sun_direction_override := Vector3.ZERO
@export_range(0.0, 3.0) var sun_strength := 1.9
@export_range(0.0, 3.0) var ambient_strength := 1.1
@export_range(0.0, 3.0) var brightness := 1.0
## Light absorbed per km of cloud: higher = more solid, sharper-shaded lobes.
@export_range(5.0, 120.0) var extinction := 30.0
@export var lit_tint := Color(1.0, 0.97, 0.91)
## Shadows high up the towers (pale cyan / blue).
@export var shadow_tint := Color(0.42, 0.76, 0.96)
## Shadows under the bases (cool grey).
@export var base_tint := Color(0.52, 0.66, 0.88)
## Keeps shadows luminous instead of storm-grey.
@export_range(0.0, 1.0) var shadow_lift := 0.75
@export_range(0.0, 2.0) var silver_lining := 0.5
## Distance over which far clouds fade into the horizon haze.
@export_range(10.0, 400.0, 1.0, "suffix:km") var aerial_distance := 90.0
@export_range(0.0, 1.0) var aerial_strength := 0.75

@export_group("Wind")
## Direction the clouds drift towards (x = east, y = south).
@export var wind_direction := Vector2(1.0, 0.3)
@export_range(0.0, 400.0, 1.0, "suffix:km/h") var wind_speed := 40.0
## Speeds the drift up (or freezes it at 0) without changing the wind.
@export_range(0.0, 50.0) var time_scale := 1.0

@export_group("Quality")
@export var quality := Quality.MEDIUM:
	set(v):
		quality = v
		_rebuild = true
## Draw clouds on the sky's pixel grid (matches the painted mountains),
## or smoothly filtered.
## Debug: 0 = clouds, 1 = shape noise slices, 2 = detail noise slices.
@export_range(0, 2) var debug_view := 0
@export var pixelated := true:
	set(v):
		pixelated = v
		_sky_dirty = true

# Per quality: panorama texels per sky pixel, max march steps, light steps,
# fine step (km), seconds to refresh the whole panorama, most rows per frame.
# The clouds drift slowly, so a refresh every several seconds is invisible.
const QUALITY_TABLE := {
	Quality.LOW: [0.5, 100, 3, 0.2, 10.0, 2],
	Quality.MEDIUM: [0.75, 150, 4, 0.15, 8.0, 3],
	Quality.HIGH: [1.0, 200, 5, 0.12, 6.0, 4],
	Quality.ULTRA: [2.0, 300, 6, 0.08, 6.0, 8],
}
# Lowest elevation in the panorama (radians); matches cloud_bake.gdshader.
const EL_MIN := -0.03

var _vp: SubViewport
var _rect: ColorRect
var _mat: ShaderMaterial
var _sky: ShaderMaterial
var _rebuild := true
var _sky_dirty := true
var _full_redraw := 0
var _row := 0
var _row_accum := 0.0
var _wind := Vector2.ZERO
var _wind_dir := Vector2.RIGHT
var _time := 0.0
var _weather: ImageTexture
var _shape: ImageTexture3D
var _detail: ImageTexture3D


func _ready() -> void:
	_make_noise()
	_build()


func _make_noise() -> void:
	# Generated synchronously (about 0.1 s) so the very first bake has them.
	var wn := FastNoiseLite.new()
	wn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wn.frequency = 0.018
	wn.fractal_type = FastNoiseLite.FRACTAL_FBM
	wn.fractal_octaves = 4
	wn.seed = 7
	var wimg := wn.get_seamless_image(256, 256, false, false, 0.1, true)
	_weather = ImageTexture.create_from_image(wimg)
	_shape = _worley(64, 0.06, 3, 11)
	_detail = _worley(32, 0.12, 2, 23)


# Inverted Worley fBm, tileable: bright rounded cells = billows.
func _worley(size: int, freq: float, octaves: int, seed: int) -> ImageTexture3D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	n.cellular_jitter = 0.9
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.fractal_gain = 0.45
	n.seed = seed
	var imgs := n.get_seamless_image_3d(size, size, size, true, 0.1, true)
	var t := ImageTexture3D.new()
	t.create(imgs[0].get_format(), size, size, size, false, imgs)
	return t


func _sky_pixel() -> float:
	if _sky:
		var p: Variant = _sky.get_shader_parameter("pixel")
		if p is float and p > 0.0:
			return p
	return 0.004


func _panorama_size() -> Vector2i:
	var px := _sky_pixel() / float(QUALITY_TABLE[quality][0])
	return Vector2i(int(ceil(TAU / px)), int(ceil((PI * 0.5 - EL_MIN) / px)))


func _build() -> void:
	_rebuild = false
	if not _vp:
		_vp = SubViewport.new()
		_vp.name = "CloudPanorama"
		_vp.disable_3d = true
		_vp.transparent_bg = true
		# Rendered only on frames that draw a band (UPDATE_ONCE in _set_band).
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(_vp)
		_rect = ColorRect.new()
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://world/clouds/cloud_bake.gdshader")
		_rect.material = _mat
		_vp.add_child(_rect)
	_find_sky()
	_vp.size = _panorama_size()
	_row = 0
	_full_redraw = 1
	_sky_dirty = true


func _find_sky() -> void:
	var world := get_viewport().find_world_3d() if is_inside_tree() else null
	var sky: ShaderMaterial = null
	if world and world.environment and world.environment.sky:
		sky = world.environment.sky.sky_material as ShaderMaterial
	if sky != _sky:
		_sky = sky
		_sky_dirty = true


func _process(delta: float) -> void:
	if not _vp:
		return
	if _rebuild:
		_build()
	_find_sky()
	if _sky_dirty and _sky:
		_sky_dirty = false
		_sky.set_shader_parameter("cloud_tex", _vp.get_texture())
		_sky.set_shader_parameter("clouds_on", 1.0 if enabled else 0.0)
		_sky.set_shader_parameter("cloud_pixelate", 1.0 if pixelated else 0.0)
	if _sky and override_sky_colors:
		_sky.set_shader_parameter("top_color", sky_zenith)
		_sky.set_shader_parameter("horizon_color", sky_horizon)
	if not enabled:
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return

	_time += delta * time_scale
	_wind_dir = wind_direction.normalized() if wind_direction.length() > 0.001 else Vector2.RIGHT
	# Shader adds the offset to positions, so subtract to drift downwind.
	_wind -= _wind_dir * wind_speed / 3600.0 * delta * time_scale

	var size := _vp.size
	if _full_redraw > 0:
		# First frame, and after big changes: the whole panorama at once.
		_full_redraw -= 1
		_push_params()
		_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
		_set_band(0, size.y)
		return
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	var q: Array = QUALITY_TABLE[quality]
	# Rows owed for this frame, capped so a slow frame never causes more work.
	_row_accum = minf(_row_accum + float(size.y) * minf(delta, 0.05) / float(q[4]), float(q[5]))
	var rows := int(_row_accum)
	if rows < 1:
		return
	_row_accum -= float(rows)
	if _row >= size.y:
		_row = 0
	rows = mini(rows, size.y - _row)
	_push_params()
	_set_band(_row, rows)
	_row += rows


func _set_band(first: int, rows: int) -> void:
	var size := _vp.size
	_rect.position = Vector2(0, first)
	_rect.size = Vector2(size.x, rows)
	_mat.set_shader_parameter("band_start", float(first) / float(size.y))
	_mat.set_shader_parameter("band_height", float(rows) / float(size.y))
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Places the hero tower along a world direction (like SkyMoons.point_at),
## optionally at a new distance (km).
func point_hero_at(dir: Vector3, distance_km := -1.0) -> void:
	var d := Vector3(dir.x, 0.0, dir.z).normalized()
	hero_azimuth = rad_to_deg(atan2(d.x, -d.z))
	if distance_km > 0.0:
		hero_distance = distance_km
	redraw()


## Redraws the whole panorama next frame (after big setting changes).
func redraw() -> void:
	_full_redraw = 1


func _push_params() -> void:
	var m := _mat
	var q: Array = QUALITY_TABLE[quality]
	if _sky:
		for p in ["day", "dusk", "sun_dir"]:
			var v: Variant = _sky.get_shader_parameter(p)
			if v != null:
				m.set_shader_parameter(p, v)
		var top: Variant = _sky.get_shader_parameter("top_color")
		var hor: Variant = _sky.get_shader_parameter("horizon_color")
		if top != null:
			m.set_shader_parameter("sky_top", top)
		if hor != null:
			m.set_shader_parameter("sky_horizon", hor)
	if sun_direction_override.length() > 0.001:
		m.set_shader_parameter("sun_dir", sun_direction_override.normalized())
	m.set_shader_parameter("time_s", _time)
	m.set_shader_parameter("wind", _wind)
	m.set_shader_parameter("wind_dir_n", _wind_dir)
	m.set_shader_parameter("anvil_chance", anvil_chance)
	m.set_shader_parameter("coverage", coverage)
	m.set_shader_parameter("bottom_km", cloud_height)
	m.set_shader_parameter("thickness_km", cloud_thickness)
	m.set_shader_parameter("density", cloud_density)
	m.set_shader_parameter("scale", cloud_scale)
	m.set_shader_parameter("softness", cloud_softness)
	m.set_shader_parameter("tower_strength", tower_strength)
	m.set_shader_parameter("billow_strength", billow_strength)
	m.set_shader_parameter("detail_strength", detail_strength)
	m.set_shader_parameter("planet_radius_km", planet_radius)
	m.set_shader_parameter("clear_radius_km", clear_overhead)
	var az := deg_to_rad(hero_azimuth)
	m.set_shader_parameter("hero", Vector4(sin(az) * hero_distance, -cos(az) * hero_distance, hero_radius, hero_strength))
	m.set_shader_parameter("extinction", extinction)
	m.set_shader_parameter("sun_strength", sun_strength)
	m.set_shader_parameter("ambient_strength", ambient_strength)
	m.set_shader_parameter("brightness", brightness)
	m.set_shader_parameter("lit_tint", lit_tint)
	m.set_shader_parameter("shadow_tint", shadow_tint)
	m.set_shader_parameter("base_tint", base_tint)
	m.set_shader_parameter("shadow_lift", shadow_lift)
	m.set_shader_parameter("silver_lining", silver_lining)
	m.set_shader_parameter("aerial_km", aerial_distance)
	m.set_shader_parameter("aerial_strength", aerial_strength)
	m.set_shader_parameter("max_steps", q[1])
	m.set_shader_parameter("light_steps", q[2])
	m.set_shader_parameter("fine_step_km", q[3])
	m.set_shader_parameter("debug_view", debug_view)
	m.set_shader_parameter("weather_noise", _weather)
	m.set_shader_parameter("shape_noise", _shape)
	m.set_shader_parameter("detail_noise", _detail)
