@tool
extends Node3D

## Stand-alone test scene for the towering cumulus (world/clouds/sky_clouds.gd):
## an open meadow under the crash site's day sky, sun, moons and day-night
## cycle, with nothing in the way of the sky. Tune the clouds on the SkyClouds
## node; set the time of day on DayNight (hour) and the view on Camera3D.
## Built at runtime, so the saved .tscn holds only this root.

@export_range(0.0, 24.0) var start_hour := 11.0
## Let the day-night cycle run (off = hold start_hour).
@export var run_clock := false
@export_range(-180.0, 180.0) var view_azimuth := -35.0
@export_range(-10.0, 80.0) var view_pitch := 14.0


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://world/day_sky.gdshader")
	sky.sky_material = sky_mat
	env.sky = sky
	# Same look as the crash site (tools/build_scenes.gd).
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.65, 0.55)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.4
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	add_child(sun)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.55, 0.66, 1.0)
	moon.light_energy = 0.0
	add_child(moon)

	var ground := MeshInstance3D.new()
	ground.name = "Meadow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.62, 0.2)
	gm.roughness = 1.0
	ground.material_override = gm
	add_child(ground)

	var clouds := SkyClouds.new()
	clouds.name = "SkyClouds"
	add_child(clouds)
	var moons := Node3D.new()
	moons.name = "SkyMoons"
	moons.set_script(load("res://world/sky_moons.gd"))
	add_child(moons)

	var clock := Node.new()
	clock.name = "DayNight"
	clock.set_script(load("res://world/day_night.gd"))
	clock.set("hour", start_hour)
	add_child(clock)
	clock.set_process(run_clock and not Engine.is_editor_hint())
	clock.set_process_unhandled_input(not Engine.is_editor_hint())

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 70.0
	cam.far = 4000.0
	cam.position = Vector3(0, 1.7, 0)
	cam.rotation = Vector3(deg_to_rad(view_pitch), -deg_to_rad(view_azimuth), 0.0)
	add_child(cam)
	cam.current = true
