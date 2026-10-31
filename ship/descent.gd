extends Node3D

## The landing: from orbit to the crash site in one continuous flight.
##
## How it works. The moon is not one continuous level: the crash site is its
## own scene. So the descent happens here, in the space scene, around the
## real ship. Gana stays in the pilot seat with his own camera, Meki and the
## HUD keep working. The *world* moves instead: everything outside (the moon,
## clouds, sun, and the crash site's own terrain, trees and sky, loaded from
## crash_site.tscn) sits under `_world`, laid out in the crash site's
## coordinates, and each frame `_world` gets the inverse of where the ship is
## on its flight path. The path ends exactly where the wreck lies in the
## crash site (origin, tilted by REST), along the existing furrow and through
## the trees whose stumps line it. Gana blacks out on impact, and the crash
## site scene opens with him waking up in the wreck (world/wake_up.gd).
##
## Before the landing the same world is shown at the start of the path, so
## the moon hangs in the windows during the whole space part of the game.

const R := 6000.0                 # moon radius (m)
const CRASH_SCENE := "res://crash_site.tscn"
## The wreck's rotation in crash_site.tscn (its "Ship" node).
const REST := Vector3(0.02, 0.0, -0.05)
## Flight path: [seconds, metres along the ground from the wreck (+Z, the
## way it came in), altitude of the ship's origin (m)].
const PATH := [[0.0, 9000.0, 900.0], [8.0, 8500.0, 880.0], [30.0, 4300.0, 330.0], [46.0, 1500.0, 150.0],
	[58.0, 620.0, 80.0], [66.0, 230.0, 30.0], [72.0, 86.0, 0.5], [76.5, 0.0, 0.0]]
const T_PREP := 8.0       # computer briefing, ship swings onto the descent heading
const T_FAIL := 50.0      # attitude control gives out
const T_CONTACT := 72.0   # first touch, start of the furrow
const T_REST := 76.5      # wreck comes to rest
const T_BLACK := 80.5     # Gana passes out
const T_END := 83.0       # crash site takes over
const CLOUD_ALTS := [150.0, 182.0]
const CAP_ANGLE := 0.42   # radians of moon covered by the detailed cap
## Hour of the day at the crash site when Gana wakes (day_night.gd default).
const HOUR := 9.0

var running := false
var t := 0.0

var _world: Node3D
var _planet: MeshInstance3D
var _cap: MeshInstance3D
var _planet_mat: ShaderMaterial
var _atmo: MeshInstance3D
var _atmo_mat: ShaderMaterial
var _clouds: Array[MeshInstance3D] = []
var _puffs: MultiMeshInstance3D
var _forest: MultiMeshInstance3D
var _sun: DirectionalLight3D
var _to_sun := Vector3.UP
var _sky: ShaderMaterial
var _env: Environment
var _env_start := {}
var _crash_env: Environment

var _site: Node3D           # the crash site's CrashSite node, once loaded
var _trail: Node3D
var _furrow: MeshInstance3D
var _furrow_len := 75.0
var _stumps: Array = []     # [stump node, tree node, broken]
var _loading := false
var _low_detail: Array[Node3D] = []  # grass and flowers: only near the ground

# Flight control.
var _bank := 0.0            # radians, + = right wing down
var _pitch_in := 0.0
var _x_off := 0.0           # metres off the path (from banking)
var _err := 0.0             # accumulated bank error while failing
var _err_time := 0.0
var _impact_done := false
var _skid: CPUParticles3D

# Cabin effects (in ship space: this node isn't moved).
var _glow_mat: ShaderMaterial
var _streaks: CPUParticles3D
var _heat_light: OmniLight3D
var _alarm_light: OmniLight3D
var _fx: ColorRect          # blur / dark / vignette
var _fx_mat: ShaderMaterial
var _white: ColorRect
var _rumble: AudioStreamPlayer
var _engine: AudioStreamPlayer
var _sfx: AudioStreamPlayer
var _ring: AudioStreamPlayer
var _alarm_timer := 0.0
var _cues: Array = []
var _shake := 0.0
var _base_fov := 70.0
var _cam: Camera3D


func _ready() -> void:
	process_priority = 10
	_env = _find_env()
	_build_world()
	_place(0.0)


# ---------- setup ----------

func _find_env() -> Environment:
	var we := get_tree().current_scene.get_node_or_null("WorldEnvironment") if get_tree().current_scene else null
	if not we:
		we = get_parent().get_node_or_null("WorldEnvironment")
	return we.environment if we else null


func _build_world() -> void:
	_world = Node3D.new()
	_world.name = "World"
	_world.top_level = true
	add_child(_world)
	# Sun as the crash site has it at HOUR (see world/day_night.gd).
	var a := (HOUR - 6.0) / 12.0 * PI
	_to_sun = Vector3(cos(a), sin(a) * 0.9, 0.3).normalized()
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.light_color = Color(1.0, 0.95, 0.85)
	_sun.light_energy = 1.8
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 60.0
	_sun.basis = Basis.looking_at(-_to_sun, Vector3.UP)
	_world.add_child(_sun)
	# The moon: a coarse sphere for orbit, and a finer cap of the same
	# sphere (same shader, same object space) around the crash site.
	_planet_mat = ShaderMaterial.new()
	_planet_mat.shader = load("res://world/planet.gdshader")
	_planet_mat.set_shader_parameter("zoom", 7.0)
	_planet_mat.set_shader_parameter("texel", 0.006)
	_planet_mat.set_shader_parameter("site_forest", 1.0)
	_planet_mat.set_shader_parameter("haze_color", Color(0.52, 0.7, 0.66))
	var sphere := SphereMesh.new()
	sphere.radius = R - 2.0
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 160
	sphere.rings = 80
	_planet = MeshInstance3D.new()
	_planet.name = "Moon"
	_planet.mesh = sphere
	_planet.material_override = _planet_mat
	_planet.position = Vector3(0, -R, 0)
	_planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_planet)
	_cap = MeshInstance3D.new()
	_cap.name = "MoonCap"
	_cap.mesh = _cap_mesh(R - 1.5, CAP_ANGLE, 150)
	_cap.material_override = _planet_mat
	_cap.position = Vector3(0, -R, 0)
	_cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cap.visible = false
	_world.add_child(_cap)
	var shell := SphereMesh.new()
	shell.radius = R * 1.01
	shell.height = shell.radius * 2.0
	shell.radial_segments = 160
	shell.rings = 80
	_atmo_mat = ShaderMaterial.new()
	_atmo_mat.shader = load("res://world/atmosphere.gdshader")
	_atmo_mat.set_shader_parameter("sun_dir", _to_sun)
	_atmo = MeshInstance3D.new()
	_atmo.mesh = shell
	_atmo.material_override = _atmo_mat
	_atmo.position = Vector3(0, -R, 0)
	_world.add_child(_atmo)
	_build_clouds()
	_build_forest()
	# Space sky that can turn into the crash site's day sky.
	if _env:
		_sky = ShaderMaterial.new()
		_sky.shader = load("res://world/descent_sky.gdshader")
		_sky.set_shader_parameter("space", 1.0)
		_sky.set_shader_parameter("sun_dir", _to_sun)
		_env.sky.sky_material = _sky
		_env.sky.process_mode = Sky.PROCESS_MODE_REALTIME
		# The two moons, fading in with the sky as the stars give way.
		var moons := Node3D.new()
		moons.name = "SkyMoons"
		moons.set_script(load("res://world/sky_moons.gd"))
		add_child(moons)
		_env_start = {"amb": _env.ambient_light_color, "amb_e": _env.ambient_light_energy,
			"fog": _env.fog_light_color, "density": _env.fog_density, "exp": _env.tonemap_exposure}


## A patch of sphere (radius `r`, centred on +Y, `ang` radians across from
## the middle to the edge), finely tessellated.
func _cap_mesh(r: float, ang: float, n: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var e := tan(ang)
	for j in n + 1:
		for i in n + 1:
			var d := Vector3(lerpf(-e, e, float(i) / n), 1.0, lerpf(-e, e, float(j) / n)).normalized()
			st.set_normal(d)
			st.add_vertex(d * r)
	for j in n:
		for i in n:
			var k := j * (n + 1) + i
			st.add_index(k)
			st.add_index(k + 1)
			st.add_index(k + n + 1)
			st.add_index(k + 1)
			st.add_index(k + n + 2)
			st.add_index(k + n + 1)
	return st.commit()


## Height of the moon's surface (crash-site y) at a ground point.
static func _ground_y(x: float, z: float) -> float:
	return sqrt(maxf(R * R - x * x - z * z, 0.0)) - R - 0.5


func _build_clouds() -> void:
	var shader: Shader = load("res://world/cloud_deck.gdshader")
	for i in CLOUD_ALTS.size():
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("cover", 0.47 if i == 0 else 0.56)
		m.set_shader_parameter("opacity", 0.92 if i == 0 else 0.7)
		m.set_shader_parameter("scale", 0.0021 if i == 0 else 0.0013)
		m.set_shader_parameter("radius", (R + CLOUD_ALTS[i]) * tan(CAP_ANGLE))
		var deck := MeshInstance3D.new()
		deck.name = "Clouds%d" % i
		deck.mesh = _cap_mesh(R + CLOUD_ALTS[i], CAP_ANGLE, 48)
		deck.material_override = m
		deck.position = Vector3(0, -R, 0)
		deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(deck)
		_clouds.append(deck)
	# Low-poly puffs around the layers so there's something to fly through.
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 8
	puff.rings = 4
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color(0.93, 0.95, 1.0, 0.82)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.disable_fog = true
	pm.vertex_color_use_as_albedo = true
	puff.material = pm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = puff
	var rng := RandomNumberGenerator.new()
	rng.seed = 4023
	mm.instance_count = 320
	for i in mm.instance_count:
		var s := rng.randf_range(500.0, 3400.0)
		var x := rng.randf_range(-450.0, 450.0) * (1.0 if rng.randf() < 0.7 else 2.5)
		var alt: float = CLOUD_ALTS[rng.randi() % 2] + rng.randf_range(-14.0, 14.0)
		var up := Vector3(x, R, s).normalized()
		var pos := up * (R + alt) - Vector3(0, R, 0)
		var w := rng.randf_range(25.0, 70.0)
		var b := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, rng.randf() * TAU)
		mm.set_instance_transform(i, Transform3D(b.scaled(Vector3(w, rng.randf_range(7.0, 16.0), w * rng.randf_range(0.6, 1.2))), pos))
		var g := rng.randf_range(0.82, 1.0)
		mm.set_instance_color(i, Color(g, g, minf(1.0, g + 0.05), 0.8))
	_puffs = MultiMeshInstance3D.new()
	_puffs.name = "CloudPuffs"
	_puffs.multimesh = mm
	_puffs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_puffs)


## Low-poly pines carpeting the moon around the crash site (beyond the
## crash site's own trees) and under the approach.
func _build_forest() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 2.6
	cone.height = 10.0
	cone.radial_segments = 6
	cone.rings = 1
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	cone.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cone
	var rng := RandomNumberGenerator.new()
	rng.seed = 26
	var items := []
	while items.size() < 9000:
		var x: float
		var z: float
		if rng.randf() < 0.55:
			# Thick along the approach corridor.
			x = rng.randf_range(-700.0, 700.0)
			z = rng.randf_range(-400.0, 2600.0)
		else:
			var ang := rng.randf() * TAU
			var r := 110.0 + pow(rng.randf(), 1.6) * 2300.0
			x = cos(ang) * r
			z = sin(ang) * r
		if Vector2(x, z).length() < 110.0:
			continue
		# The clearing at the end of the furrow stays open.
		if absf(x + 0.8) < 9.0 and z > -10.0 and z < 100.0:
			continue
		if absf(x + 0.8) < 17.0 and z > -10.0 and z < 450.0:
			continue
		items.append(Vector2(x, z))
	mm.instance_count = items.size()
	for i in items.size():
		var p: Vector2 = items[i]
		var s := rng.randf_range(0.7, 1.4)
		var y := _ground_y(p.x, p.y)
		var up := Vector3(p.x, R, p.y).normalized()
		var b := Basis(Quaternion(Vector3.UP, up)).scaled(Vector3(s, s * rng.randf_range(0.9, 1.3), s))
		mm.set_instance_transform(i, Transform3D(b, Vector3(p.x, y, p.y) + up * 5.0 * s))
		var c := Color(0.12, 0.3, 0.16).lerp(Color(0.24, 0.42, 0.2), rng.randf())
		mm.set_instance_color(i, c)
	_forest = MultiMeshInstance3D.new()
	_forest.name = "Forest"
	_forest.multimesh = mm
	_forest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_forest.visible = false
	_world.add_child(_forest)


## Brings in the crash site's own world (terrain, trees, pond, ruins, sky
## settings) from crash_site.tscn, without its player, ship or HUD.
func _attach_site() -> void:
	var packed: PackedScene
	if _loading:
		packed = ResourceLoader.load_threaded_get(CRASH_SCENE)
	else:
		packed = load(CRASH_SCENE)
	var root: Node = packed.instantiate()
	_crash_env = (root.get_node("WorldEnvironment") as WorldEnvironment).environment
	_site = root.get_node("CrashSite")
	root.remove_child(_site)
	root.free()
	_site.owner = null
	_world.add_child(_site)
	# Nothing out there may push the ship, Gana or Meki around.
	for n in _site.find_children("*", "CollisionObject3D", true, false):
		n.collision_layer = 0
		n.collision_mask = 0
	for n in _site.find_children("*", "CSGShape3D", true, false):
		n.use_collision = false
	for n in _site.find_children("*", "", true, false):
		if n.is_in_group("night_only"):
			n.visible = false
	for n in ["Grass", "GrassEast", "Flowers", "Reeds"]:
		var node := _site.get_node_or_null(n) as Node3D
		if node:
			_low_detail.append(node)
	# The Kestrel is wider than the trail the crash site keeps clear; trees
	# overhanging the furrow would cut through the cabin as she skids.
	var redwoods := _site.get_node_or_null("Redwoods")
	if redwoods:
		for tree: Node3D in redwoods.get_children():
			if absf(tree.position.x + 0.8) < 12.0 and tree.position.z > 4.0 and tree.position.z < 110.0:
				tree.visible = false
	var bushes := _site.get_node_or_null("Bushes") as MultiMeshInstance3D
	if bushes:
		var mm := bushes.multimesh.duplicate() as MultiMesh
		for i in mm.instance_count:
			var xf := mm.get_instance_transform(i)
			var o := bushes.transform * xf.origin
			if absf(o.x + 0.8) < 12.0 and o.z > 4.0 and o.z < 110.0:
				mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), xf.origin))
		bushes.multimesh = mm
	# The crash hasn't happened yet: no smoke, no trail. The furrow is dug
	# as the ship skids, the trees at the stumps get knocked down.
	var smoke := _site.get_node_or_null("Smoke")
	if smoke:
		smoke.visible = false
		smoke.emitting = false
	# The far edge of the 600 m ground plate would show from the air; the
	# moon cap takes over past the clearing.
	var ground := _site.get_node_or_null("Ground/Mesh") as MeshInstance3D
	if ground:
		var plane := (ground.mesh as PlaneMesh).duplicate() as PlaneMesh
		plane.size = Vector2(240, 240)
		ground.mesh = plane
	_trail = _site.get_node_or_null("CrashTrail")
	if _trail:
		for c in _trail.get_children():
			c.visible = false
			if c.name.begins_with("Stump"):
				_stumps.append([c, _make_tree(c.position), false])
		_furrow = _trail.get_node_or_null("Furrow")
	for m in _site.find_children("*", "GeometryInstance3D", true, false):
		var mat = m.material_override
		if mat is ShaderMaterial and mat.shader and mat.shader.resource_path.begins_with("res://world/"):
			mat.set_shader_parameter("world_tint", Color.WHITE)
			mat.set_shader_parameter("haze", Color(0.52, 0.7, 0.66))
	_site.visible = false


## A young redwood standing where one of the trail's stumps is (the crash
## site's smallest redwood kind, from tools/build_scenes.gd, scaled down).
func _make_tree(at: Vector3) -> Node3D:
	var tree := Node3D.new()
	tree.position = at
	tree.rotation.y = randf() * TAU
	tree.scale = Vector3.ONE * randf_range(0.38, 0.5)
	_site.add_child(tree)
	for part in ["bark", "foliage"]:
		var mi := MeshInstance3D.new()
		mi.mesh = load("res://world/redwoods/kind5_lod0_%s.res" % part)
		mi.material_override = load("res://world/materials/redwood_%s.tres" % part)
		tree.add_child(mi)
	return tree


func _build_cabin_fx() -> void:
	# Plasma just outside the windshield.
	var up := Vector3(0.0, 0.8633, 0.5054)
	var out := Vector3(0.0, 0.5054, -0.8633)
	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = load("res://ship/entry_glow.gdshader")
	var glow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(6.0, 3.2)
	glow.mesh = q
	glow.material_override = _glow_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.transform = Transform3D(Basis(Vector3.RIGHT, up, -out), Vector3(4.0, 0.95, -12.6) + up * 1.0 + out * 0.45)
	add_child(glow)
	# Air streaming past the canopy.
	_streaks = CPUParticles3D.new()
	_streaks.amount = 90
	_streaks.lifetime = 0.6
	_streaks.emitting = false
	_streaks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_streaks.emission_box_extents = Vector3(14, 8, 2)
	_streaks.position = Vector3(3.5, 2.0, -45.0)
	_streaks.direction = Vector3(0, 0, 1)
	_streaks.spread = 2.0
	_streaks.gravity = Vector3.ZERO
	_streaks.initial_velocity_min = 70.0
	_streaks.initial_velocity_max = 95.0
	var sm := BoxMesh.new()
	sm.size = Vector3(0.03, 0.03, 3.0)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(1, 1, 1, 0.35)
	smat.vertex_color_use_as_albedo = true
	smat.disable_fog = true
	sm.material = smat
	_streaks.mesh = sm
	add_child(_streaks)
	_heat_light = OmniLight3D.new()
	_heat_light.light_color = Color(1.0, 0.55, 0.25)
	_heat_light.omni_range = 6.0
	_heat_light.light_energy = 0.0
	_heat_light.position = Vector3(3.8, 1.9, -12.9)
	add_child(_heat_light)
	_alarm_light = OmniLight3D.new()
	_alarm_light.light_color = Color(1.0, 0.15, 0.1)
	_alarm_light.omni_range = 7.0
	_alarm_light.light_energy = 0.0
	_alarm_light.position = Vector3(3.4, 2.5, -10.4)
	add_child(_alarm_light)
	# Screen effects in the HUD, under Gana's thoughts.
	var hud := _hud()
	_white = ColorRect.new()
	_white.color = Color(0.9, 0.93, 0.97, 0.0)
	_white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_white)
	_fx = ColorRect.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_mat = ShaderMaterial.new()
	_fx_mat.shader = load("res://ui/screen_fx.gdshader")
	_fx.material = _fx_mat
	_fx.visible = false
	hud.add_child(_fx)
	var thoughts: Node = hud.get("_thoughts")
	if thoughts:
		hud.move_child(thoughts, -1)
	# Sound.
	_rumble = _audio("res://audio/wind_ambience.ogg", -40.0, true)
	_engine = _audio("res://audio/thruster_flyby.ogg", -40.0, true)
	_sfx = _audio("res://audio/sfx/thunk.ogg", 0.0, false)
	_ring = AudioStreamPlayer.new()
	_ring.set_script(load("res://ui/ear_ring.gd"))
	add_child(_ring)


func _audio(path: String, db: float, loop: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = (load(path) as AudioStream).duplicate()
	if "loop" in p.stream:
		p.stream.loop = loop
	p.volume_db = db
	add_child(p)
	return p


func _one_shot(path: String, db: float, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _hud() -> Node:
	return get_tree().get_first_node_in_group("hud")


func _seat() -> Node:
	return get_tree().get_first_node_in_group("pilot_seat")


# ---------- the flight ----------

## Start the landing (from the cockpit panel, once INITIATE LANDING is
## confirmed). Gana must be in the pilot seat.
func begin() -> void:
	if running:
		return
	running = true
	t = 0.0
	ResourceLoader.load_threaded_request(CRASH_SCENE)
	_loading = true
	_build_cabin_fx()
	var seat := _seat()
	if seat:
		seat.call("lock_for_landing", self)
	_cam = get_viewport().get_camera_3d()
	if _cam:
		_base_fov = _cam.fov
	_engine.play()
	_rumble.play()
	_cues = [
		[0.6, [["KESTREL", "Descent profile loaded. Port thrusters: no response."],
			["MEKI", "I'll balance us on the starboard side. Keep her nose on the marker."], "Here we go."], true],
		[14.0, [["KESTREL", "Atmospheric interface in twenty seconds."]]],
		[29.0, [["KESTREL", "Hull temperature rising."], "She's held together worse.", ["MEKI", "She really hasn't."]]],
		[T_FAIL + 0.3, [["KESTREL", "Warning. Attitude control response below operational tolerance."], "I know. Compensating."], true],
		[57.0, [["KESTREL", "Descent trajectory is diverging."], "Then give me another one.", ["KESTREL", "Calculating."]]],
		[64.0, [["KESTREL", "Recommend preparing for impact."], "That's not a trajectory.", ["KESTREL", "No."]], true],
		[69.0, [["MEKI", "Clearing, dead ahead! Nose up!"]], true],
	]


func prompt() -> String:
	if t < T_PREP:
		return ""
	if t < T_FAIL:
		return "[A/D] Bank    [W/S] Nose"
	if t < T_CONTACT - 2.0:
		return "HOLD [A/D] AGAINST THE ROLL"
	return ""


func _path(time: float) -> Vector2:
	var n := PATH.size()
	if time <= PATH[0][0]:
		return Vector2(PATH[0][1], PATH[0][2])
	if time >= PATH[n - 1][0]:
		return Vector2(PATH[n - 1][1], PATH[n - 1][2])
	var i := 0
	while PATH[i + 1][0] < time:
		i += 1
	var p0 := _key(maxi(i - 1, 0))
	var p1 := _key(i)
	var p2 := _key(i + 1)
	var p3 := _key(mini(i + 2, n - 1))
	var t1: float = PATH[i][0]
	var t2: float = PATH[i + 1][0]
	var u := (time - t1) / (t2 - t1)
	# Catmull-Rom on unevenly spaced keys: tangents from the neighbours.
	var m1 := (p2 - p0) / maxf(PATH[mini(i + 1, n - 1)][0] - PATH[maxi(i - 1, 0)][0], 0.001) * (t2 - t1)
	var m2 := (p3 - p1) / maxf(PATH[mini(i + 2, n - 1)][0] - PATH[i][0], 0.001) * (t2 - t1)
	var u2 := u * u
	var u3 := u2 * u
	var v := (2 * u3 - 3 * u2 + 1) * p1 + (u3 - 2 * u2 + u) * m1 + (-2 * u3 + 3 * u2) * p2 + (u3 - u2) * m2
	return Vector2(maxf(v.x, 0.0), maxf(v.y, 0.0))


func _key(i: int) -> Vector2:
	return Vector2(PATH[i][1], PATH[i][2])


## Where the ship is, in crash-site coordinates, at time `time`.
func _pose(time: float) -> Transform3D:
	var sh := _path(time)
	var s := sh.x
	var h := sh.y
	var phi := s / R
	var up := Vector3(0, cos(phi), sin(phi))
	var ahead := Vector3(0, sin(phi), -cos(phi))
	# Off the path from banking; pulled back in for the last stretch.
	var x := _x_off * (1.0 - smoothstep(60.0, 71.0, time))
	var pos := Vector3(0, -R, 0) + up * (R + h) + Vector3(x, 0, 0)
	# Nose dipped to keep the horizon in the windshield, flaring at the end.
	var dip := acos(R / (R + h))
	var look_down := dip + deg_to_rad(lerpf(6.0, 15.0, smoothstep(40.0, 400.0, h)))
	var pitch := lerpf(-look_down, 0.07, smoothstep(65.0, 71.5, time)) + _pitch_in * deg_to_rad(5.0)
	var bank := _bank * (1.0 - smoothstep(70.5, 72.0, time))
	var yaw := bank * 0.3
	# Swing round onto the descent heading at the start.
	yaw += deg_to_rad(28.0) * (1.0 - smoothstep(1.0, T_PREP, time))
	bank += deg_to_rad(9.0) * sin(clampf((time - 1.0) / (T_PREP - 1.0), 0.0, 1.0) * PI)
	# Entry buffeting and the failure wobble.
	var heat := _heat(time)
	pitch += sin(time * 13.0) * 0.004 * heat + sin(time * 5.1) * 0.006 * heat
	if time > T_CONTACT:
		# Furrowing in: nose and wings jolt, then settle to the wreck's lie.
		var k := clampf((time - T_CONTACT) / (T_REST - T_CONTACT), 0.0, 1.0)
		var jolt := exp(-(time - T_CONTACT) * 1.6)
		pitch = lerpf(0.07, REST.x, smoothstep(0.0, 1.0, k)) + jolt * 0.06 * sin((time - T_CONTACT) * 11.0)
		bank = lerpf(0.0, -REST.z, smoothstep(0.0, 1.0, k)) + jolt * 0.08 * sin((time - T_CONTACT) * 7.0 + 1.0)
		yaw = jolt * 0.04 * sin((time - T_CONTACT) * 5.0)
	var b := Basis.looking_at(ahead, up) * Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, -bank)
	if time >= T_REST:
		return Transform3D(Basis.from_euler(REST), Vector3.ZERO)
	return Transform3D(b, pos)


func _heat(time: float) -> float:
	return smoothstep(22.0, 34.0, time) * (1.0 - smoothstep(41.0, 49.0, time))


func _fail(time: float) -> float:
	return smoothstep(T_FAIL, T_FAIL + 2.5, time) * (1.0 - smoothstep(69.0, 72.0, time))


func _process(delta: float) -> void:
	if not running:
		# Idle in orbit: the moon slowly turning under the windows.
		_place(0.0)
		_keep_far()
		return
	t += delta
	_control(delta)
	var pose := _place(t)
	var h := _path(t).y
	_keep_far()
	_update_world(h)
	_update_env(h)
	_update_trail(pose)
	_update_cabin(h, delta)
	_update_hud(h)
	_run_cues()
	if t >= T_CONTACT and not _impact_done:
		_impact(pose)
	if t >= T_END:
		running = false
		Game.state().set_flag("wake_after_crash")
		get_tree().change_scene_to_file(CRASH_SCENE)


func _place(time: float) -> Transform3D:
	var pose := _pose(time)
	if not running:
		# A slow drift so the view isn't frozen.
		var w := Time.get_ticks_msec() * 0.001
		pose = pose * Transform3D(Basis(Vector3.BACK, sin(w * 0.05) * 0.03) * Basis(Vector3.RIGHT, sin(w * 0.037) * 0.015), Vector3.ZERO)
	_world.global_transform = pose.affine_inverse()
	if _sky:
		var phi := _path(time).x / R
		# Sky in the crash site's frame, levelled to the local horizon.
		var q := Basis(Vector3.RIGHT, -phi)
		_sky.set_shader_parameter("sky_rot", q * pose.basis)
		_sky.set_shader_parameter("sun_dir", q * _to_sun)
	return pose


func _keep_far() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.far < 30000.0:
		cam.far = 30000.0


func _control(delta: float) -> void:
	var can := t > T_PREP and t < T_CONTACT - 1.5
	var steer := Input.get_axis("move_left", "move_right") if can else 0.0
	var nose := Input.get_axis("move_back", "move_forward") if can else 0.0
	_pitch_in = lerpf(_pitch_in, nose, minf(1.0, delta * 2.0))
	var fail := _fail(t)
	# Starboard-only thrust rolls her right; the player holds against it.
	var push := fail * deg_to_rad(30.0) * (1.0 + 0.35 * sin(t * 1.3) + 0.25 * sin(t * 3.7))
	var target := steer * deg_to_rad(32.0) + push
	_bank = lerpf(_bank, target, minf(1.0, delta * (1.4 + fail)))
	_x_off = clampf(_x_off + sin(_bank) * 28.0 * delta, -140.0, 140.0)
	if fail > 0.5:
		_err += absf(_bank) * delta
		_err_time += delta


## 0 = held her steady through the failure, 1 = let her roll.
func _wobble_score() -> float:
	return clampf(_err / maxf(_err_time, 0.01) / deg_to_rad(25.0), 0.0, 1.0)


func _update_world(h: float) -> void:
	var low := h < 380.0
	_planet.visible = not low
	_cap.visible = low
	_forest.visible = h < 260.0
	_atmo_mat.set_shader_parameter("strength", 5.0 * smoothstep(250.0, 700.0, h))
	_planet_mat.set_shader_parameter("clouds", smoothstep(300.0, 600.0, h))
	var air := 1.0 - smoothstep(60.0, 420.0, h)
	_planet_mat.set_shader_parameter("haze", air * 0.9)
	_planet_mat.set_shader_parameter("haze_near", lerpf(400.0, 120.0, air))
	_planet_mat.set_shader_parameter("haze_far", lerpf(9000.0, 1800.0, air))
	# The crash site's own world comes in inside the cloud layer.
	if h < 230.0 and not _site:
		_attach_site()
	if _site:
		_site.visible = h < 172.0
		for n in _low_detail:
			n.visible = h < 30.0
	_sky.set_shader_parameter("mountains", 1.0 - smoothstep(50.0, 150.0, h))
	for d in _clouds:
		d.visible = h > 60.0
	_puffs.visible = h > 60.0


func _update_env(h: float) -> void:
	if not _env:
		return
	var air := 1.0 - smoothstep(60.0, 420.0, h)
	_sky.set_shader_parameter("space", smoothstep(200.0, 560.0, h))
	var day_amb := Color(0.55, 0.65, 0.55)
	_env.ambient_light_color = (_env_start["amb"] as Color).lerp(day_amb, air)
	_env.ambient_light_energy = lerpf(_env_start["amb_e"], 0.55, air)
	_env.tonemap_exposure = lerpf(_env_start["exp"], 1.1, air)
	# Aerial haze instead of the cabin's dusty fog (which would hide the
	# whole moon): depth fog that only starts outside the ship.
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_density = 1.0
	_env.fog_light_color = Color(0.52, 0.7, 0.66)
	_env.fog_depth_begin = 30.0
	_env.fog_depth_end = lerpf(4000.0, 1200.0, air)
	_env.fog_depth_curve = 1.6
	# Inside a cloud layer: white-out.
	var w := 0.0
	for a in CLOUD_ALTS:
		w = maxf(w, 1.0 - absf(h - a) / 16.0)
	if _white:
		_white.color.a = clampf(w, 0.0, 1.0) * 0.9


func _update_trail(pose: Transform3D) -> void:
	if not _site or t < T_CONTACT - 0.5:
		return
	var z := pose.origin.z
	# The furrow is dug from the touchdown point to under the ship.
	if _furrow:
		var back := 83.5
		var front := clampf(z + 6.0, 8.5, back)
		var len := back - front
		_furrow.visible = len > 0.5
		_furrow.scale = Vector3(1, 1, maxf(len / _furrow_len, 0.001))
		_furrow.position.z = (back + front) / 2.0
	for c in _trail.get_children():
		if c.name.begins_with("Berm") or c.name.begins_with("HullBerm"):
			c.visible = c.position.z > z + 4.0
	# The nose (12 m ahead of the origin) snaps the trees.
	for st in _stumps:
		if not st[2] and z - 12.0 < (st[0] as Node3D).position.z:
			st[2] = true
			_snap(st[0], st[1])
	if t >= T_REST:
		for c in _trail.get_children():
			c.visible = true
		for st in _stumps:
			(st[1] as Node3D).visible = false


func _snap(stump: Node3D, tree: Node3D) -> void:
	stump.visible = true
	_one_shot("res://audio/sfx/thunk.ogg", -2.0, randf_range(1.5, 1.9))
	_burst(stump.position + Vector3(0, 3.0, 0), Color(0.2, 0.42, 0.18), 50, 5.0, 0.08)
	var side := 1.0 if tree.position.x > -0.8 else -1.0
	# Flung aside and out of the way of the hull.
	var tw := create_tween()
	tw.tween_property(tree, "rotation", Vector3(-0.4, 0, -side * 1.4), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(tree, "position", tree.position + Vector3(side * 7.0, 0, -4.0), 0.45)
	tw.tween_callback(tree.hide)


## Particles in the world (crash-site coordinates).
func _burst(at: Vector3, col: Color, amount: int, speed: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 1.6
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	var m := BoxMesh.new()
	m.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 1.0
	m.material = mat
	p.mesh = m
	p.position = at
	_world.add_child(p)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)
	return p


func _impact(pose: Transform3D) -> void:
	_impact_done = true
	_shake = 1.0
	_one_shot("res://audio/sfx/thunk.ogg", 6.0, 0.45)
	_one_shot("res://audio/sfx/thunk.ogg", 3.0, 0.7)
	_one_shot("res://audio/sfx/spark.ogg", 0.0, 0.8)
	var ground := Vector3(pose.origin.x, -0.5, pose.origin.z)
	_burst(ground + Vector3(0, 0.5, 8.0), Color(0.42, 0.32, 0.22), 90, 9.0, 0.35)
	_burst(ground + Vector3(0, 1.0, -6.0), Color(0.24, 0.4, 0.2), 70, 7.0, 0.12)
	_cabin_sparks()
	# A spray of dirt and smoke from under the hull while she skids.
	_skid = CPUParticles3D.new()
	_skid.amount = 140
	_skid.lifetime = 1.4
	_skid.direction = Vector3(0, 1, 0.6)
	_skid.spread = 50.0
	_skid.initial_velocity_min = 4.0
	_skid.initial_velocity_max = 10.0
	_skid.gravity = Vector3(0, -7, 0)
	_skid.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_skid.emission_box_extents = Vector3(6.5, 0.3, 3.0)
	_skid.scale_amount_min = 0.15
	_skid.scale_amount_max = 0.5
	var m := BoxMesh.new()
	m.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.31, 0.22)
	mat.roughness = 1.0
	mat.vertex_color_use_as_albedo = true
	m.material = mat
	_skid.mesh = m
	_skid.color = Color(1, 1, 1)
	_world.add_child(_skid)
	_skid.emitting = true


func _cabin_sparks() -> void:
	for at in [Vector3(3.1, 1.0, -12.0), Vector3(4.9, 1.1, -11.9), Vector3(2.5, 2.3, -11.5)]:
		var sparks := CPUParticles3D.new()
		sparks.one_shot = true
		sparks.amount = 26
		sparks.lifetime = 0.6
		sparks.explosiveness = 0.9
		sparks.direction = Vector3(0, 0.5, 1)
		sparks.spread = 70.0
		sparks.initial_velocity_min = 1.0
		sparks.initial_velocity_max = 3.0
		sparks.gravity = Vector3(0, -6, 0)
		sparks.scale_amount_min = 0.01
		sparks.scale_amount_max = 0.025
		var dot := SphereMesh.new()
		dot.radius = 0.5
		dot.height = 1.0
		dot.radial_segments = 4
		dot.rings = 2
		var hot := StandardMaterial3D.new()
		hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hot.albedo_color = Color(1.0, 0.75, 0.35)
		dot.material = hot
		sparks.mesh = dot
		sparks.position = at
		add_child(sparks)
		sparks.emitting = true
		get_tree().create_timer(1.5).timeout.connect(sparks.queue_free)
	_one_shot("res://audio/sfx/spark.ogg", -4.0, randf_range(0.9, 1.2))


func _update_cabin(h: float, delta: float) -> void:
	var heat := _heat(t)
	var fail := _fail(t)
	_glow_mat.set_shader_parameter("heat", heat)
	_heat_light.light_energy = heat * (2.2 + randf() * 0.8)
	var speed := 1.0 - smoothstep(0.0, 30.0, t - T_CONTACT) if t > T_CONTACT else 1.0
	var air := 1.0 - smoothstep(60.0, 420.0, h)
	_streaks.emitting = air > 0.15 and t < T_CONTACT
	_streaks.color = Color(1.0, 0.7, 0.45).lerp(Color.WHITE, 1.0 - heat)
	# Alarm in the emergency.
	_alarm_light.light_energy = fail * (0.5 + 0.5 * sin(t * 9.0)) * 1.8
	if fail > 0.3 and t < T_CONTACT:
		_alarm_timer -= delta
		if _alarm_timer <= 0.0:
			_alarm_timer = 0.55
			_one_shot("res://audio/sfx/beep.ogg", -8.0, 0.62)
	if t > T_FAIL and t < T_FAIL + 0.1:
		_cabin_sparks()
	if t > T_FAIL + 9.0 and t < T_FAIL + 9.1:
		_cabin_sparks()
	# Sound: engine and air roar, then sudden quiet once she stops.
	var roar := clampf(air * 0.7 + heat * 0.5 + fail * 0.4, 0.0, 1.0)
	if t < T_REST:
		_rumble.volume_db = linear_to_db(maxf(roar * speed, 0.001)) + 2.0
		_rumble.pitch_scale = lerpf(0.55, 0.9, roar)
		_engine.volume_db = linear_to_db(maxf(0.35 + fail * 0.3, 0.001)) - 6.0
		_engine.pitch_scale = 0.8 + 0.15 * sin(t * 2.0) * fail
	else:
		_rumble.volume_db = lerpf(_rumble.volume_db, -60.0, minf(1.0, delta * 6.0))
		_engine.volume_db = -80.0
		var hum := get_tree().current_scene.get_node_or_null("ShipHum")
		if hum:
			hum.set_process(false)
			(hum as AudioStreamPlayer).volume_db = -80.0
	if _skid:
		var pose := _pose(t)
		_skid.position = Vector3(pose.origin.x, -0.3, pose.origin.z + 4.0)
		_skid.emitting = t < T_REST - 0.4
	# Camera: shake from heat, the failure and the impact; a little FOV
	# kick with speed.
	_shake = maxf(_shake - delta * 0.5, 0.0)
	var amount := heat * 0.25 + fail * 0.35 + _shake * (0.6 + 0.6 * _wobble_score())
	if t > T_CONTACT and t < T_REST:
		amount += 0.25
	_cam = get_viewport().get_camera_3d()
	if _cam:
		var n := Time.get_ticks_msec() * 0.001
		_cam.h_offset = (sin(n * 31.0) * 0.6 + sin(n * 57.0) * 0.4) * 0.012 * amount
		_cam.v_offset = (sin(n * 27.0 + 1.0) * 0.6 + sin(n * 49.0) * 0.4) * 0.012 * amount
		_cam.fov = _base_fov + 5.0 * air * (1.0 - smoothstep(T_CONTACT, T_REST, t))
	# Impact: a brief dark flash, then fading out as Gana passes out.
	var dark := 0.0
	var blur := 0.0
	var vig := 0.0
	if t > T_CONTACT:
		var k := t - T_CONTACT
		dark = 0.75 * exp(-k * 5.0)
		blur = 2.0 * exp(-k * 2.0)
		vig = 0.4
	if t > T_REST:
		var k := clampf((t - T_REST) / (T_BLACK - T_REST), 0.0, 1.0)
		blur = maxf(blur, k * 3.5)
		vig = 0.4 + 0.6 * k
		dark = maxf(dark, smoothstep(0.55, 1.0, k))
		_ring.set("level", smoothstep(0.0, 0.5, k))
	if t > T_BLACK:
		dark = 1.0
	_fx.visible = dark > 0.001 or blur > 0.01 or vig > 0.01
	_fx_mat.set_shader_parameter("dark", dark)
	_fx_mat.set_shader_parameter("blur", blur)
	_fx_mat.set_shader_parameter("vignette", vig)


func _update_hud(h: float) -> void:
	var panel := get_tree().current_scene.find_child("CockpitPanel", true, false)
	if not panel:
		return
	var view: Control = panel.get("view")
	if not view:
		return
	var sh := _path(t)
	var warn := []
	if t < T_PREP:
		warn.append(["DESCENT PROFILE LOADED", Color(0.45, 1.0, 0.55)])
	warn.append(["PORT THRUST  0%", Color(1.0, 0.3, 0.25)])
	if _heat(t) > 0.2:
		warn.append(["HULL TEMP  %d C" % int(400 + 1200 * _heat(t)), Color(1.0, 0.72, 0.25)])
	if _fail(t) > 0.1:
		warn.append(["ATTITUDE CONTROL FAILURE", Color(1.0, 0.3, 0.25)])
	if t > 57.0 and t < T_CONTACT:
		warn.append(["TRAJECTORY DIVERGING", Color(1.0, 0.3, 0.25)])
	if t > 64.0 and t < T_CONTACT:
		warn.append(["BRACE FOR IMPACT", Color(1.0, 0.3, 0.25)])
	var alt_m := 412000.0 * pow(h / 900.0, 2.2)
	view.set("descent", {
		"alt": alt_m,
		"spd": 7800.0 * pow(h / 900.0, 0.9) + 90.0 * (1.0 - smoothstep(T_CONTACT, T_REST, t)),
		"bank": _bank,
		"pitch": _pitch_in,
		"x": _x_off * (1.0 - smoothstep(60.0, 71.0, t)),
		"warn": warn,
		"fail": _fail(t),
		"range": sh.x,
		"off": t > T_REST,
	})


func _run_cues() -> void:
	while not _cues.is_empty() and t >= _cues[0][0]:
		var c: Array = _cues.pop_front()
		_hud().think(c[1], "", c.size() > 2 and c[2])
	if t > T_REST + 0.8 and t < T_REST + 0.9:
		_hud().think([["MEKI", "Gana? ...Gana!"]], "", true)
