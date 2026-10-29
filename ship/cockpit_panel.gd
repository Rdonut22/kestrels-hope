extends Node3D

## The cockpit's flight panel: three switches on the dash (MAIN DRIVE, NAV,
## DIAGNOSTICS) with a reactor gauge, and the HUD projected onto the
## windshield. The pilot seat passes input here in panel view.
##
## Without the backup cell rerouted the switches fail. Once powered, flip
## all three and the HUD boots. Every tab has to be looked at before NAV
## offers INITIATE LANDING, which Hale's recovered letter then interrupts.

const SWITCHES := ["MAIN DRIVE", "NAV", "DIAGNOSTICS"]
const PLATE := Vector3(3.95, 0.955, -12.08)
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
	var plate := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.78, 0.02, 0.3)
	plate.mesh = pm
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.12, 0.13)
	dark.roughness = 0.6
	dark.metallic = 0.5
	plate.material_override = dark
	plate.position = PLATE
	add_child(plate)
	var lever_mat := StandardMaterial3D.new()
	lever_mat.albedo_color = Color(0.75, 0.75, 0.72)
	lever_mat.metallic = 0.8
	lever_mat.roughness = 0.35
	var font: Font = load("res://ui/fonts/JetBrainsMono-Bold.ttf")
	for i in SWITCHES.size():
		var x := (i - 1) * 0.24
		var pivot := Node3D.new()
		pivot.position = PLATE + Vector3(x, 0.012, 0.03)
		add_child(pivot)
		var lever := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.009
		lm.bottom_radius = 0.012
		lm.height = 0.07
		lever.mesh = lm
		lever.material_override = lever_mat
		lever.position.y = 0.035
		pivot.add_child(lever)
		var knob := MeshInstance3D.new()
		var km := SphereMesh.new()
		km.radius = 0.014
		km.height = 0.028
		knob.mesh = km
		knob.material_override = lever_mat
		knob.position.y = 0.072
		pivot.add_child(knob)
		pivot.rotation.x = 0.5  # off: tipped toward the pilot
		_levers.append(pivot)
		var lamp := MeshInstance3D.new()
		var lamp_mesh := SphereMesh.new()
		lamp_mesh.radius = 0.012
		lamp_mesh.height = 0.012
		lamp.mesh = lamp_mesh
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(0.1, 0.1, 0.1)
		lmat.emission_enabled = true
		lmat.emission = Color.BLACK
		lamp.material_override = lmat
		lamp.position = PLATE + Vector3(x, 0.012, -0.07)
		add_child(lamp)
		_lamps.append(lmat)
		var label := Label3D.new()
		label.text = SWITCHES[i]
		label.font = font
		label.font_size = 28
		label.pixel_size = 0.0007
		label.modulate = Color(0.85, 0.8, 0.65)
		label.outline_size = 0
		label.rotation.x = -PI / 2
		label.position = PLATE + Vector3(x, 0.012, 0.115)
		add_child(label)
		if _is_on(i):
			_set_lever(i, true, false)
	_gauge = Label3D.new()
	_gauge.font = font
	_gauge.font_size = 24
	_gauge.pixel_size = 0.0007
	_gauge.outline_size = 0
	_gauge.rotation.x = -PI / 2
	_gauge.position = PLATE + Vector3(0, 0.012, -0.11)
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
func view_eye() -> Vector3:
	return Vector3(3.97, 1.42, -10.5)


func view_target() -> Vector3:
	return Vector3(3.97, 1.5, -12.1)


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


func _set_lever(i: int, down: bool, animate := true) -> void:
	var angle := -0.5 if down else 0.5
	if animate:
		create_tween().tween_property(_levers[i], "rotation:x", angle, 0.12)
	else:
		_levers[i].rotation.x = angle
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
	create_tween().tween_property(_levers[i], "rotation:x", -0.5, 0.1)
	view.flash_no_power()
	for k in 5:
		_lamps[i].emission = Color(1.0, 0.6, 0.15) if k % 2 == 0 else Color.BLACK
		await get_tree().create_timer(0.08).timeout
	_play("res://audio/sfx/thunk.ogg")
	_lamps[i].emission = Color.BLACK
	create_tween().tween_property(_levers[i], "rotation:x", 0.5, 0.25)
	_busy = false
	_fails += 1
	var gs := Game.state()
	if gs.meki_online:
		_hud().think([["MEKI", "Not yet, Gana. The power panel first."]])
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
	_busy = false
