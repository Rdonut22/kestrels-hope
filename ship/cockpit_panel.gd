extends Node3D

## The cockpit's flight panel: three switches on the dash (MAIN DRIVE, NAV,
## DIAGNOSTICS) with a reactor gauge, and the HUD projected onto the
## windshield. The pilot seat passes input here in panel view.
##
## Without the backup cell rerouted the switches fail. Once powered, flip
## all three and the HUD boots. Every tab has to be looked at before NAV
## offers INITIATE LANDING, which Hale's recovered letter then interrupts.

const SWITCHES := ["MAIN DRIVE", "NAV", "DIAGNOSTICS"]
## Windshield: bottom edge centre and the direction up the glass.
const GLASS_BASE := Vector3(4.0, 0.95, -12.6)
const GLASS_UP := Vector3(0.0, 0.8633, 0.5054)
const HUD_SIZE := Vector2(2.5, 1.26)
const HUD_PX := Vector2i(1060, 534)

var view: Control  # windshield_view.gd
var _levers: Array[Node3D] = []
var _lamps: Array[StandardMaterial3D] = []
var _gauge: Label3D
var _tint: StandardMaterial3D
var _sfx: AudioStreamPlayer
var _fails := 0
var _active := false
var _pending_tab := ""
var _busy := false


func _ready() -> void:
	add_to_group("cockpit_panel")
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -6.0
	add_child(_sfx)
	_build_switches()
	_build_hud()
	if _all_on():
		view.on = true
		view.boot()


# ---------- building ----------

func _build_switches() -> void:
	# The levers stand in the pedestal's slots between the seats
	# (ship/cockpit_fitout.gd builds the pedestal), sliding forward for on.
	var m := {}
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.17, 0.18, 0.19)
	steel.metallic = 0.7
	steel.roughness = 0.5
	m["steel"] = steel
	var edge := steel.duplicate() as StandardMaterial3D
	edge.albedo_color = Color(0.32, 0.31, 0.29)
	edge.roughness = 0.35
	m["steel_edge"] = edge
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.55, 0.38, 0.2)
	bronze.metallic = 0.85
	bronze.roughness = 0.38
	m["bronze"] = bronze
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.06, 0.06, 0.06)
	rubber.roughness = 0.8
	m["rubber"] = rubber
	var font: Font = load("res://ui/fonts/JetBrainsMono-Bold.ttf")
	var top := Basis(Vector3.RIGHT, -0.12)
	var tc := _local(CockpitFitout.top_centre())
	for i in SWITCHES.size():
		var cap := StandardMaterial3D.new()
		cap.albedo_color = Color(0.1, 0.1, 0.1)
		cap.emission_enabled = true
		cap.emission = Color.BLACK
		m["amber"] = cap
		var pivot := CockpitFitout.make_lever(m)
		pivot.transform = _lever_xf(i, -1.0)
		add_child(pivot)
		_levers.append(pivot)
		# The handle's emitter cap is its status lamp.
		_lamps.append(cap)
		var label := Label3D.new()
		label.text = SWITCHES[i]
		label.font = font
		label.font_size = 20
		label.pixel_size = 0.0006
		label.modulate = Color(0.85, 0.8, 0.65)
		label.outline_size = 0
		# Flat on the pedestal top beside its slot, reading from the seats.
		label.basis = top * Basis(Vector3.RIGHT, -PI / 2) * Basis(Vector3.FORWARD, PI / 2)
		label.position = tc + top * Vector3(CockpitFitout.SLOT_X[i] + 0.034, 0.02, 0.02)
		add_child(label)
		if _is_on(i):
			_set_lever(i, true, false)
	_gauge = Label3D.new()
	_gauge.font = font
	_gauge.font_size = 24
	_gauge.pixel_size = 0.0007
	_gauge.outline_size = 0
	_gauge.font_size = 16
	_gauge.basis = Basis(Vector3.RIGHT, -0.12) * Basis(Vector3.RIGHT, -PI / 2)
	_gauge.position = _local(CockpitFitout.top_centre()) + Basis(Vector3.RIGHT, -0.12) * Vector3(0, 0.02, 0.33)
	add_child(_gauge)
	_update_gauge()
	Game.state().power_restored_changed.connect(func(_on: bool) -> void: _update_gauge())


func _build_hud() -> void:
	var vp := SubViewport.new()
	vp.size = HUD_PX
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	view = (load("res://ui/windshield_view.gd") as GDScript).new()
	view.size = Vector2(HUD_PX)
	vp.add_child(view)
	view.tab_shown.connect(_on_tab_shown)
	var n := Vector3.RIGHT.cross(GLASS_UP)
	var centre := GLASS_BASE + GLASS_UP * (0.25 + HUD_SIZE.y / 2.0)
	var basis := Basis(Vector3.RIGHT, GLASS_UP, n)
	# Darkening film on the glass behind the projection.
	var tint := MeshInstance3D.new()
	var tq := QuadMesh.new()
	tq.size = HUD_SIZE + Vector2(0.1, 0.1)
	tint.mesh = tq
	_tint = StandardMaterial3D.new()
	_tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tint.albedo_color = Color(0.0, 0.02, 0.01, 0.0)
	tint.material_override = _tint
	tint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tint.transform = Transform3D(basis, centre + n * 0.02)
	add_child(tint)
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = HUD_SIZE
	quad.mesh = qm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ship/holo_screen.gdshader")
	mat.set_shader_parameter("screen", vp.get_texture())
	mat.set_shader_parameter("tint", Color(0.45, 1.0, 0.55))
	mat.set_shader_parameter("strength", 1.6)
	mat.set_shader_parameter("jitter", 0.0)
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Floats just inside the window frames so the centre pillar doesn't cut it.
	quad.transform = Transform3D(basis, centre + n * 0.2)
	add_child(quad)


## Where the panel camera sits and looks (used by the pilot seat).
## (The panel moves up with the flight deck: ship/kestrel_exterior.gd.)
func view_eye() -> Vector3:
	return to_global(_local(Vector3(3.62, 1.3, -11.55)))


func view_target() -> Vector3:
	return to_global(_local(CockpitFitout.top_centre() + Vector3(0, 0.0, -0.02)))


# ---------- state ----------

func _is_on(i: int) -> bool:
	return Game.state().has_flag("switch_%d" % i)


func _all_on() -> bool:
	for i in SWITCHES.size():
		if not _is_on(i):
			return false
	return true


func _update_gauge() -> void:
	if Game.state().power_restored:
		_gauge.text = "REACTOR 41%  //  REQ 40%"
		_gauge.modulate = Color(0.45, 1.0, 0.55)
	else:
		_gauge.text = "REACTOR 12%  //  REQ 40%"
		_gauge.modulate = Color(1.0, 0.45, 0.25)


## Ship space (cockpit_fitout.gd) -> this node's frame: the panel moves
## forward with the cockpit (kestrel_exterior.gd), the fitout is built
## where the cockpit ends up.
func _local(p: Vector3) -> Vector3:
	return p - Vector3(0, 0, KestrelExterior.COCKPIT_SHIFT)


func _lever_xf(i: int, t: float) -> Transform3D:
	var xf := CockpitFitout.lever_transform(i, t)
	xf.origin = _local(xf.origin)
	return xf


## Slide lever i to t (-1 back, toward the seats = off; 1 forward = on).
func _slide(i: int, t: float, secs: float) -> void:
	var to := _lever_xf(i, t).origin
	if secs <= 0.0:
		_levers[i].position = to
	else:
		create_tween().tween_property(_levers[i], "position", to, secs)


func _set_lever(i: int, down: bool, animate := true) -> void:
	_slide(i, 1.0 if down else -1.0, 0.16 if animate else 0.0)
	_lamps[i].emission = Color(0.3, 1.0, 0.4) if down else Color.BLACK
	_lamps[i].emission_energy_multiplier = 2.0


func _play(path: String, pitch := 1.0) -> void:
	_sfx.stream = load(path)
	_sfx.pitch_scale = pitch
	_sfx.play()


func _hud() -> Node:
	return get_tree().get_first_node_in_group("hud")


# ---------- panel view ----------

func set_active(on: bool) -> void:
	_active = on
	create_tween().tween_property(_tint, "albedo_color:a", 0.55 if on else 0.0, 0.4)


func prompt() -> String:
	if not view.on:
		return "[1] MAIN DRIVE   [2] NAV   [3] DIAGNOSTICS      [Esc] Back"
	if view.confirm_landing:
		return "[E] Confirm landing      [Esc] Abort"
	var text := "[A/D] Screens"
	match view.current_tab():
		"DIAGNOSTICS":
			text += "   [W/S] Systems"
		"NAV":
			if Game.state().has_flag("hud_all_seen") and not Game.state().has_flag("landing_confirmed"):
				text += "   [E] Initiate landing"
	return text + "      [Esc] Back"


## Returns true if the panel used the event.
func handle_input(event: InputEvent) -> bool:
	if _busy:
		return event is InputEventKey
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_3:
			flip(k - KEY_1)
			return true
	if not view.on:
		return false
	if view.confirm_landing:
		if event.is_action_pressed("interact"):
			_confirm_landing()
			return true
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("jump"):
			view.confirm_landing = false
			return true
		return false
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_switch_tab(view.tab - 1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_switch_tab(view.tab + 1)
	elif view.current_tab() == "DIAGNOSTICS" and (event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up")):
		view.system = wrapi(view.system - 1, 0, view.SYSTEMS.size())
		_play("res://audio/sfx/click.ogg", 1.4)
	elif view.current_tab() == "DIAGNOSTICS" and (event.is_action_pressed("move_back") or event.is_action_pressed("ui_down")):
		view.system = wrapi(view.system + 1, 0, view.SYSTEMS.size())
		_play("res://audio/sfx/click.ogg", 1.4)
	elif event.is_action_pressed("interact") and view.current_tab() == "NAV" \
			and Game.state().has_flag("hud_all_seen") and not Game.state().has_flag("landing_confirmed"):
		view.confirm_landing = true
		_play("res://audio/sfx/beep.ogg", 0.8)
	else:
		return false
	return true


func _switch_tab(i: int) -> void:
	_play("res://audio/sfx/click.ogg", 1.2)
	view.select_tab(i)


func flip(i: int) -> void:
	var gs := Game.state()
	if _is_on(i):
		return
	if not gs.power_restored:
		_fail(i)
		return
	gs.set_flag("switch_%d" % i)
	_play("res://audio/sfx/power_on.ogg", 1.3)
	_set_lever(i, true)
	if _all_on():
		await get_tree().create_timer(0.5).timeout
		view.boot()
		await get_tree().create_timer(2.8).timeout
		view.select_tab(0)
		_hud().think([["MEKI", "Flight systems are yours, Gana. Check every screen; I want to know what we're dealing with."]], "hud_boot")
	else:
		_hud().think(["There she is."], "first_switch_on")


# A switch with no power: clack, a sick amber flicker, and back it comes.
func _fail(i: int) -> void:
	_busy = true
	_play("res://audio/sfx/click.ogg", 0.9)
	_slide(i, 1.0, 0.1)
	view.flash_no_power()
	for k in 5:
		_lamps[i].emission = Color(1.0, 0.6, 0.15) if k % 2 == 0 else Color.BLACK
		await get_tree().create_timer(0.08).timeout
	_play("res://audio/sfx/thunk.ogg")
	_lamps[i].emission = Color.BLACK
	_slide(i, -1.0, 0.25)
	_busy = false
	_fails += 1
	var gs := Game.state()
	if gs.meki_online:
		_hud().think([["MEKI", "Not yet, Gana. Meet me at the power junction first."]])
		return
	if _fails == 1:
		_hud().think(["Nothing. Reactor's at twelve percent... I need forty just to wake her up."], "fail_1")
	elif _fails == 2:
		_hud().think(["Come on, girl."], "fail_2")
	elif _fails >= 3:
		_hud().think(["Meki would know how to squeeze more out of it. If he weren't a paperweight.",
			"...Alright. One more try, buddy. The workbench."], "fail_3")


# ---------- tabs and landing ----------

func _on_tab_shown(tab: String) -> void:
	_pending_tab = tab
	await get_tree().create_timer(1.0).timeout
	if _pending_tab != tab or view.current_tab() != tab:
		return
	var gs := Game.state()
	var key := "seen_tab_" + tab.to_lower()
	if not gs.has_flag(key):
		gs.set_flag(key)
		match tab:
			"ALTITUDE":
				_hud().think(["Four hundred and twelve kilometres. Orbit's holding... for now."])
			"DIAGNOSTICS":
				_hud().think(["Red, amber, red. Hale would've had a field day with this.",
					["MEKI", "HALE_PRIVATE.LOG is on the link page. I'm still rebuilding it."]])
			"COMMS":
				_hud().think(["...Angel. I'm so sorry. I promise I'll come back.",
					"Hmm. Still nothing from Ushida. Or our emergency beacon.",
					"What the hell are we supposed to do?"])
			"NAV":
				_hud().think(["That's not a reflection. Something down there is putting out power.",
					["MEKI", "And the air's breathable. Twenty-one percent oxygen."], "...Huh."])
		_check_all_seen()
	elif tab == "NAV" and gs.has_flag("hud_all_seen"):
		gs.set_flag("seen_landing_ready")


func _check_all_seen() -> void:
	var gs := Game.state()
	for t in view.TABS:
		if not gs.has_flag("seen_tab_" + String(t).to_lower()):
			return
	if gs.has_flag("hud_all_seen"):
		return
	gs.set_flag("hud_all_seen")
	_hud().think([["MEKI", "That's everything I can fix from up here, Gana."],
		"So we drift... or we go down there.",
		["MEKI", "The landing option's on nav. Whenever you're ready."]])


func _confirm_landing() -> void:
	_busy = true
	view.confirm_landing = false
	_play("res://audio/sfx/beep.ogg")
	var hud := _hud()
	await hud.think([["MEKI", "Gana, wait! Hale's file. It just finished."],
		["MEKI", "You need to see this before we do anything."]], "", true)
	Game.state().hale_file = 100.0
	var letter: Control = (load("res://ui/letter_view.gd") as GDScript).new()
	hud.add_overlay(letter)
	letter.open()
	await letter.closed
	await get_tree().create_timer(0.8).timeout
	await hud.think(["...",
		["MEKI", "You're landing now? Chances of survival... twenty-three percent."],
		"Great. What a helpful little droid."])
	Game.state().set_flag("landing_confirmed")
	# And down we go (ship/descent.gd).
	var descent := get_tree().current_scene.get_node_or_null("Descent")
	if descent:
		descent.begin()
