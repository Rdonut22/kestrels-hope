class_name Kitchen
extends Node3D

## The galley's cooking (added by ship/galley_windows.gd, which builds the
## stove, the wok and the kettle; this adds the mug, the serving bowl and
## the spatula on the window counter). It holds what each vessel has in it
## and how hot it is, runs the burners, and does what happens when
## something is dropped, poured or clicked. Coordinates are the galley's
## (the ship's frame): the window wall is +X, the stove at (5.86, -5.1).
##
## The player uses it from the cooking view (cooking/cook_session.gd),
## entered at the counter (cooking/counter.gd); supplies come from the
## cupboard (cooking/cupboard.gd, cooking/supply_hud.gd) and are kept in
## game_state.gd (at_counter). What the ingredients and dishes are is data:
## cooking/data/*.tres, read through cooking/cookbook.gd.
##
## Vessels: "kettle" (heats water on the right burner), "pan" (the wok, on
## the left burner: a meal pack cooks in it), "mug" (grounds + hot water =
## coffee), "bowl" (a cooked meal served from the pan).

signal changed

const COUNTER_Y := 0.99                   # the worktop (SILL_Y + 0.04)
const MUG_AT := Vector3(5.72, COUNTER_Y, -4.5)
const BOWL_AT := Vector3(5.9, COUNTER_Y, -4.18)
const SPATULA_AT := Vector3(5.64, COUNTER_Y + 0.012, -5.6)
## The cooking view: from in front of the counter, down over the stove to
## the window.
const CAM_AT := Vector3(4.62, 1.78, -5.32)
const CAM_LOOK := Vector3(6.5, 1.2, -4.95)
const CAM_FOV := 64.0
## In the stove's own frame (galley_windows.gd: STOVE_KNOBS_X, KETTLE_AT...).
const BURNERS := {"left": Vector3(-0.345, 0.16, -0.1), "right": Vector3(0.4, 0.16, -0.1)}
const KNOBS := {"left": Vector3(-0.5, 0.021, 0.572), "right": Vector3(0.535, 0.021, 0.572)}

## The kettle holds this much of the water flask; a pour into the mug
## takes a flask's use_amount (water.tres).
const KETTLE_CAP := 0.6
## Heating: seconds from cold to hot on a lit burner; cooling when off.
const KETTLE_HEAT_TIME := 9.0
const PAN_HEAT_TIME := 3.0
const COOL_TIME := 40.0
const HOT := 0.85
## A meal cooks through in COOK_TIME seconds of steady stirring over heat
## (slower, but it still gets there, left alone: COOK_UNSTIRRED share).
const COOK_TIME := 12.0
const COOK_UNSTIRRED := 0.25
const STIR_DECAY := 1.5

var stove: Node3D
var pan: Node3D
var kettle: Node3D
var cabinet: Node3D
var mug: Node3D
var bowl: Node3D
var spatula: Node3D

var burners := {"left": false, "right": false}
var kettle_water := 0.0
var kettle_heat := 0.0
var pan_food: Node3D            # the meal in the wok, if any
var pan_heat := 0.0
var pan_cooked := 0.0           # 0..1
var stir := 0.0                 # how much it's being stirred, 0..1
var mug_grounds := false
var mug_fill := 0.0             # 0..1 of hot water / coffee
var mug_hot := false
var bowl_food: Node3D
var bowl_cooked := false
## Something is being poured, dropped or eaten: the controls wait.
var busy := false

## Clickable, grabbable and drop-target things, by id: {"node", "radius"
## (metres, for finding it under the cursor), "lift" (its centre above the
## node), "outline" (OutlineSet), "home" (global transform to go back to)}.
var targets := {}

var _knob_mats := {}
var _flames := {}
var _lights := {}
var _knobs := {}
var _kettle_steam: CPUParticles3D
var _pan_steam: CPUParticles3D
var _mug_steam: CPUParticles3D
var _sfx := {}
var _click: AudioStreamPlayer3D
var _thunk: AudioStreamPlayer3D
var _t := 0.0


func _ready() -> void:
	add_to_group("kitchen")
	mug = CookProps.mug()
	add_child(mug)
	mug.position = MUG_AT
	bowl = CookProps.bowl()
	add_child(bowl)
	bowl.position = BOWL_AT
	spatula = CookProps.spatula()
	add_child(spatula)
	spatula.position = SPATULA_AT
	spatula.rotation.y = -0.4
	_build_burners()
	_build_effects()
	_add_target("kettle", kettle, 0.12, 0.09)
	_add_target("pan", pan, 0.17, 0.03)
	_add_target("mug", mug, 0.09, 0.05)
	_add_target("bowl", bowl, 0.11, 0.03)
	_add_target("spatula", spatula, 0.1, 0.0)
	for side in _knobs:
		_add_target("knob_" + side, _knobs[side], 0.05, 0.0)
	var counter := Node3D.new()
	counter.name = "CookingCounter"
	counter.set_script(load("res://cooking/counter.gd"))
	counter.set("kitchen", self)
	add_child(counter)
	counter.position = Vector3(5.45, 1.05, -5.1)
	var cupboard := Node3D.new()
	cupboard.name = "Cupboard"
	cupboard.set_script(load("res://cooking/cupboard.gd"))
	cupboard.set("kitchen", self)
	add_child(cupboard)
	if cabinet:
		cupboard.global_position = cabinet.global_position + Vector3(0, -0.1, 0)


func _add_target(id: String, node: Node3D, radius: float, lift: float) -> void:
	if node == null:
		return
	targets[id] = {"node": node, "radius": radius, "lift": lift, "outline": OutlineSet.new(node), "home": node.global_transform}


## Where a target is, for the cursor: its centre in the world.
func target_point(id: String) -> Vector3:
	var t: Dictionary = targets.get(id, {})
	if t.is_empty():
		return Vector3.ZERO
	return (t["node"] as Node3D).global_position + Vector3.UP * float(t["lift"])


func highlight(id: String, on: bool, color := OutlineSet.WHITE) -> void:
	var t: Dictionary = targets.get(id, {})
	if not t.is_empty():
		(t["outline"] as OutlineSet).show(on, color)


# ------------------------------------------------------------ the stove

func _build_burners() -> void:
	if stove == null:
		return
	for side in BURNERS:
		# A ring of flame under the vessel, and its glow.
		var ring := MeshInstance3D.new()
		ring.name = "Flame_" + side
		var tm := TorusMesh.new()
		tm.inner_radius = 0.17
		tm.outer_radius = 0.2
		tm.rings = 32
		tm.ring_segments = 6
		ring.mesh = tm
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = Color(0.35, 0.55, 1.0)
		fm.emission_enabled = true
		fm.emission = Color(0.35, 0.6, 1.0)
		fm.emission_energy_multiplier = 2.5
		ring.material_override = fm
		ring.position = BURNERS[side] + Vector3(0, -0.02, 0)
		ring.visible = false
		stove.add_child(ring)
		_flames[side] = ring
		var light := OmniLight3D.new()
		light.name = "BurnerLight_" + side
		light.light_color = Color(1.0, 0.55, 0.25)
		light.light_energy = 0.0
		light.omni_range = 0.9
		light.shadow_enabled = false
		light.position = BURNERS[side] + Vector3(0, 0.15, 0)
		stove.add_child(light)
		_lights[side] = light
		# The knob: what's clicked. Its glowing ring brightens when lit.
		var knob := Node3D.new()
		knob.name = "Knob_" + side
		knob.position = KNOBS[side]
		stove.add_child(knob)
		var cap := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.055
		cyl.height = 0.04
		cap.mesh = cyl
		cap.material_override = CookProps.mat("knob", Color(0.12, 0.12, 0.13), 0.5, 0.6)
		cap.rotation.x = PI / 2
		cap.position = Vector3(0, 0, 0.02)
		knob.add_child(cap)
		var mark := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.01, 0.04, 0.012)
		mark.mesh = bm
		mark.material_override = CookProps.mat("knob_mark", Color(0.95, 0.6, 0.2), 0.4)
		mark.position = Vector3(0, 0.02, 0.042)
		knob.add_child(mark)
		_knobs[side] = knob
	for ring in stove.get_children():
		if ring.name.begins_with("KnobRing") and ring is MeshInstance3D:
			var side := "left" if (ring as Node3D).position.x < 0.0 else "right"
			var m := ((ring as MeshInstance3D).material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			(ring as MeshInstance3D).material_override = m
			_knob_mats[side] = m
	_set_knob_look("left")
	_set_knob_look("right")


func toggle_burner(side: String) -> void:
	burners[side] = not burners[side]
	_set_knob_look(side)
	if _click:
		_click.global_position = (_knobs[side] as Node3D).global_position
		_click.play()
	changed.emit()


func _set_knob_look(side: String) -> void:
	var on: bool = burners[side]
	if _knobs.has(side):
		(_knobs[side] as Node3D).rotation.z = -PI / 2 if on else 0.0
	if _knob_mats.has(side):
		(_knob_mats[side] as StandardMaterial3D).emission_energy_multiplier = 4.0 if on else 1.0
	if _flames.has(side):
		(_flames[side] as Node3D).visible = on


# ------------------------------------------------------------ effects

func _build_effects() -> void:
	_kettle_steam = CookProps.steam()
	add_child(_kettle_steam)
	_pan_steam = CookProps.steam()
	add_child(_pan_steam)
	_mug_steam = CookProps.steam()
	_mug_steam.amount = 10
	add_child(_mug_steam)
	for k in ["sizzle", "bubble", "burner_left", "burner_right", "pour"]:
		var s := CookSfx.new()
		s.kind = "burner" if k.begins_with("burner") else k
		add_child(s)
		_sfx[k] = s
	_click = AudioStreamPlayer3D.new()
	_click.stream = load("res://audio/sfx/click.ogg")
	_click.unit_size = 2.0
	add_child(_click)
	_thunk = AudioStreamPlayer3D.new()
	_thunk.stream = load("res://audio/sfx/thunk.ogg")
	_thunk.unit_size = 2.0
	_thunk.volume_db = -8.0
	add_child(_thunk)


func clink(at: Vector3, pitch := 1.6) -> void:
	_thunk.global_position = at
	_thunk.pitch_scale = pitch * randf_range(0.92, 1.08)
	_thunk.play()


func _process(delta: float) -> void:
	_t += delta
	# Heat.
	var kettle_on: bool = burners["right"] and kettle_water > 0.0
	kettle_heat = move_toward(kettle_heat, 1.0 if kettle_on else 0.0, delta / (KETTLE_HEAT_TIME if kettle_on else COOL_TIME))
	if kettle_water <= 0.0:
		kettle_heat = 0.0
	pan_heat = move_toward(pan_heat, 1.0 if burners["left"] else 0.0, delta / (PAN_HEAT_TIME if burners["left"] else COOL_TIME * 0.5))
	# Cooking: over heat it cooks, faster for stirring.
	stir = maxf(stir - delta * STIR_DECAY, 0.0)
	if pan_food and pan_heat > 0.5 and pan_cooked < 1.0:
		pan_cooked = minf(1.0, pan_cooked + delta / COOK_TIME * lerpf(COOK_UNSTIRRED, 1.0, clampf(stir, 0.0, 1.0)))
		CookProps.cook_tint(pan_food, pan_cooked)
		if pan_cooked >= 1.0:
			changed.emit()
	# The burners' look and hiss.
	for side in burners:
		var on: bool = burners[side]
		if _lights.has(side):
			(_lights[side] as OmniLight3D).light_energy = (0.55 + 0.08 * sin(_t * 23.0 + (1.0 if side == "left" else 0.0))) if on else 0.0
		(_sfx["burner_" + side] as CookSfx).level = 0.25 if on else 0.0
		if _flames.has(side):
			(_sfx["burner_" + side] as Node3D).global_position = (_flames[side] as Node3D).global_position
	# Steam and sound: the kettle as it comes to the boil, the pan as it
	# cooks, the coffee.
	if kettle:
		_kettle_steam.global_position = kettle.global_position + Vector3(0, 0.12, 0)
	var boil := clampf((kettle_heat - 0.55) / 0.4, 0.0, 1.0)
	_kettle_steam.emitting = boil > 0.05
	(_sfx["bubble"] as CookSfx).level = boil * 0.8
	(_sfx["bubble"] as Node3D).global_position = _kettle_steam.global_position
	if pan:
		_pan_steam.global_position = pan.global_position + Vector3(0, 0.06, 0)
	var sizzle := clampf((pan_heat - 0.4) / 0.6, 0.0, 1.0) if pan_food else 0.0
	_pan_steam.emitting = sizzle > 0.2 and pan_cooked > 0.3
	(_sfx["sizzle"] as CookSfx).level = sizzle * (0.7 + 0.3 * clampf(stir, 0.0, 1.0))
	(_sfx["sizzle"] as Node3D).global_position = _pan_steam.global_position
	_mug_steam.global_position = mug.global_position + Vector3(0, 0.11, 0)
	_mug_steam.emitting = mug_hot and mug_fill > 0.5


## Moving the spatula through the wok: `amount` metres of travel.
func stir_motion(amount: float) -> void:
	if pan_food == null:
		return
	stir = minf(1.0, stir + amount * 6.0)
	if randf() < amount * 4.0:
		clink(pan.global_position, 2.2)


# ------------------------------------------------------------ what goes where

## What can be grabbed now: the spatula, the kettle (with water in it), the
## wok (once its meal is cooked).
func can_grab(id: String) -> bool:
	match id:
		"spatula":
			return true
		"kettle":
			return kettle_water > 0.0
		"pan":
			return pan_food != null and pan_cooked >= 1.0
	return false


## What can be clicked now: the knobs; the coffee and the meal once ready.
func can_click(id: String) -> bool:
	if id.begins_with("knob_"):
		return true
	match id:
		"mug":
			return ready_dish("mug") != null
		"bowl":
			return ready_dish("bowl") != null
	return false


## The finished dish a vessel holds (its recipe), or null.
func ready_dish(vessel: String) -> CookRecipe:
	match vessel:
		"mug":
			var c := []
			if mug_grounds:
				c.append("coffee_grounds")
			if mug_fill > 0.5:
				c.append("water")
			return Cookbook.match_recipe("mug", c, {"water_hot": mug_hot})
		"bowl":
			if bowl_food == null:
				return null
			return Cookbook.match_recipe("bowl", ["meal_pack"], {"cooked": bowl_cooked})
	return null


## The prompt for releasing `held` ({"type": "ingredient"|"object", "id"})
## over a target, or "" if it can't go there.
func drop_prompt(held: Dictionary, target: String) -> String:
	if held.get("type") == "ingredient":
		var ing := Cookbook.ingredient(held["id"])
		if ing == null or not target in ing.destinations:
			return ""
		match target:
			"kettle":
				if kettle_water + ing.use_amount > KETTLE_CAP + 0.001:
					return ""
			"mug":
				if mug_grounds or mug_fill > 0.5 and not mug_hot:
					return ""
				if ready_dish("mug"):
					return ""
			"pan":
				if pan_food != null:
					return ""
		return "Release to %s %s" % [ing.prompt_verb, ing.display_name.to_lower()]
	match [held.get("id"), target]:
		["kettle", "mug"]:
			var water := Cookbook.ingredient("water")
			var pour := water.use_amount if water else 0.2
			if kettle_heat >= HOT and kettle_water >= pour - 0.001 and mug_fill <= 0.01:
				return "Release to pour hot water"
		["pan", "bowl"]:
			if bowl_food == null:
				return "Release to serve"
		["spatula", "pan"]:
			if pan_food != null:
				return "Stir"
	return ""


## Why `held` can't go somewhere it nearly could (a gentle hint), or "".
func drop_hint(held: Dictionary, target: String) -> String:
	if held.get("id") == "kettle" and target == "mug" and mug_fill <= 0.01:
		return "The water isn't hot yet" if kettle_heat < HOT else ""
	return ""


# ------------------------------------------------------------ doing it

## Releasing an ingredient from the panel over a vessel. `proxy` is the
## model that was following the cursor; it's used up by the animation.
func drop_ingredient(id: String, target: String, proxy: Node3D) -> void:
	busy = true
	var ing := Cookbook.ingredient(id)
	var gs := Game.state()
	match id:
		"water":
			var above := target_point("kettle") + Vector3(-0.06, 0.16, 0.05)
			await _tween_to(proxy, above, Vector3(0, 0, -1.2), 0.3)
			var stream := CookProps.stream(Color(0.4, 0.65, 0.9))
			add_child(stream)
			stream.visible = true
			(_sfx["pour"] as CookSfx).level = 0.7
			var t := 0.0
			while t < 0.8:
				CookProps.set_stream(stream, proxy.global_position + proxy.global_basis * Vector3(0, 0.2, 0), kettle.global_position + Vector3(0, 0.08, 0))
				t += get_process_delta_time()
				await get_tree().process_frame
			(_sfx["pour"] as CookSfx).level = 0.0
			stream.queue_free()
			kettle_water = minf(KETTLE_CAP, kettle_water + ing.use_amount)
			gs.set_counter_amount("water", maxf(gs.counter_amount("water") - ing.use_amount, 0.0))
		"coffee_grounds":
			var above := target_point("mug") + Vector3(0, 0.12, 0)
			await _tween_to(proxy, above, Vector3(0, 0, -2.0), 0.3)
			var g := CookProps.grains(Color(0.16, 0.09, 0.05))
			add_child(g)
			g.global_position = proxy.global_position
			g.emitting = true
			var heap := proxy.find_child("Heap", true, false) as Node3D
			if heap:
				create_tween().tween_property(heap, "scale", Vector3(0.1, 0.1, 0.1), 0.5)
			await get_tree().create_timer(0.55).timeout
			g.emitting = false
			mug_grounds = true
			_show_mug()
			get_tree().create_timer(1.0).timeout.connect(g.queue_free)
		"meal_pack":
			var above := target_point("pan") + Vector3(0, 0.14, 0)
			await _tween_to(proxy, above, Vector3(-0.6, 0, 0), 0.3)
			# The pack splits open and empties into the wok.
			var tw := create_tween()
			tw.tween_property(proxy, "scale", Vector3(1.25, 0.7, 1.0), 0.12)
			tw.tween_property(proxy, "scale", Vector3(0.05, 0.05, 0.05), 0.25)
			var food := CookProps.ration_cubes()
			add_child(food)
			food.global_position = above
			food.rotation.y = randf() * TAU
			var land := pan.global_position + Vector3(0, 0.035, 0)
			var fall := create_tween()
			fall.tween_interval(0.12)
			fall.tween_property(food, "global_position", land, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			await fall.finished
			clink(land, 1.2)
			food.reparent(pan)
			pan_food = food
			pan_cooked = 0.0
			gs.set_counter_amount("meal_pack", gs.counter_amount("meal_pack") - 1.0)
	if is_instance_valid(proxy):
		proxy.queue_free()
	busy = false
	changed.emit()


## Releasing a held world object (kettle, wok) over its target. It goes
## home afterwards.
func drop_object(id: String, target: String) -> void:
	busy = true
	match [id, target]:
		["kettle", "mug"]:
			var spout := Vector3(0, 0.07, 0.11)   # tipped toward the mug
			var at := target_point("mug") + Vector3(0, 0.16, -0.13)
			await _tween_to(kettle, at, Vector3(-0.95, 0, 0), 0.35)
			var stream := CookProps.stream(Color(0.55, 0.62, 0.62), 0.6)
			add_child(stream)
			stream.visible = true
			(_sfx["pour"] as CookSfx).level = 0.6
			var t := 0.0
			mug_hot = true
			while t < 1.0:
				CookProps.set_stream(stream, kettle.global_position + kettle.global_basis.orthonormalized() * spout, mug.global_position + Vector3(0, 0.06, 0))
				mug_fill = minf(1.0, t)
				_show_mug()
				t += get_process_delta_time()
				await get_tree().process_frame
			(_sfx["pour"] as CookSfx).level = 0.0
			stream.queue_free()
			mug_fill = 1.0
			var water := Cookbook.ingredient("water")
			kettle_water = maxf(0.0, kettle_water - (water.use_amount if water else 0.2))
			_show_mug()
			await go_home("kettle")
		["pan", "bowl"]:
			var at := target_point("bowl") + Vector3(0, 0.12, 0.12)
			await _tween_to(pan, at, Vector3(0.8, 0, 0), 0.35)
			var food := pan_food
			pan_food = null
			food.reparent(bowl.get_node("Food"))
			var tw := create_tween()
			tw.tween_property(food, "position", Vector3(0, 0.005, 0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await tw.finished
			clink(bowl.global_position, 1.8)
			bowl_food = food
			bowl_cooked = pan_cooked >= 1.0
			pan_cooked = 0.0
			await go_home("pan")
	busy = false
	changed.emit()


## Clicking: a knob lights or puts out its burner; the coffee is drunk, the
## meal eaten.
func click(id: String) -> void:
	if id.begins_with("knob_"):
		toggle_burner(id.trim_prefix("knob_"))
		return
	var dish := ready_dish(id)
	if dish == null:
		return
	busy = true
	if id == "mug":
		var home: Transform3D = targets["mug"]["home"]
		var tw := create_tween()
		tw.tween_property(mug, "global_position", mug.global_position + Vector3(-0.18, 0.18, 0), 0.4).set_trans(Tween.TRANS_SINE)
		tw.tween_method(func(v: float) -> void:
			mug_fill = 1.0 - v
			_show_mug(), 0.0, 1.0, 1.2)
		tw.tween_property(mug, "global_transform", home, 0.4).set_trans(Tween.TRANS_SINE)
		await tw.finished
		clink(mug.global_position, 1.4)
		mug_grounds = false
		mug_fill = 0.0
		mug_hot = false
		_show_mug()
	else:
		for k in 3:
			clink(bowl.global_position, 2.0 + k * 0.1)
			var tw := create_tween()
			tw.tween_property(bowl_food, "scale", bowl_food.scale * 0.6, 0.35)
			await tw.finished
		bowl_food.queue_free()
		bowl_food = null
		bowl_cooked = false
	Game.state().consume_recipe(dish)
	if dish.id == "ship_meal" and Game.state().has_objective(Game.state().EAT_TASK) \
			and not Game.state().objective_done(Game.state().EAT_TASK):
		Game.state().complete_objective(Game.state().EAT_TASK)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and dish.on_consume != "":
		hud.call("show_message", dish.on_consume)
	busy = false
	changed.emit()


func _show_mug() -> void:
	CookProps.set_mug(mug, mug_grounds, mug_fill, mug_grounds)


## A held world object back where it belongs.
func go_home(id: String) -> void:
	var t: Dictionary = targets.get(id, {})
	if t.is_empty():
		return
	var n := t["node"] as Node3D
	var tw := create_tween()
	tw.tween_property(n, "global_transform", t["home"], 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	clink(n.global_position, 1.0 if id != "spatula" else 1.8)


func _tween_to(n: Node3D, at: Vector3, tilt: Vector3, secs: float) -> void:
	var base := n.global_basis
	var tw := create_tween().set_parallel()
	tw.tween_property(n, "global_position", at, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void:
		var p := n.global_position
		n.global_basis = base * Basis.from_euler(tilt * v)
		n.global_position = p, 0.0, 1.0, secs)
	await tw.finished


## The cooking camera's transform (global).
func camera_transform() -> Transform3D:
	var at := global_transform * CAM_AT
	var look := global_transform * CAM_LOOK
	return Transform3D(Basis.looking_at(look - at, Vector3.UP), at)
