extends SceneTree

## The galley cooking (cooking/): the cupboard's supplies reach the counter,
## the cooking view opens and closes, things are picked up, dropped,
## poured and stirred with the mouse, a missed release uses nothing up,
## coffee and the ship meal are made start to finish, and having them
## changes the vitals and finishes the "make something to eat" task.
##   godot --path . -s tools/cooking_playtest.gd [-- <shots dir>]

var out := "user://playtest_shots/"
var fails := 0
var player: Node
var kitchen: Kitchen
var session: CookSession


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	Game.state().reset()
	change_scene_to_file("res://main.tscn")
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _secs(s: float) -> void:
	# Game time, whatever the frame rate.
	var t := 0.0
	while t < s:
		await process_frame
		t += root.get_process_delta_time()


func _check(c: bool, what: String) -> void:
	print(("PASS " if c else "FAIL ") + what)
	if not c:
		fails += 1


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))


## Moves the cursor in steps to a target or slot, frames passing between.
func _move_to(id: String, steps := 8) -> void:
	var to := session.test_screen_point(id)
	var from: Vector2 = session.get("_mouse")
	for i in steps:
		session.test_mouse(from.lerp(to, float(i + 1) / steps))
		await _wait(2)


## Drags something (a slot or a kitchen thing) onto a target and lets go.
func _drag(what: String, onto: String) -> void:
	await _move_to(what, 4)
	session.press()
	await _wait(3)
	await _move_to(onto, 10)
	await _wait(6)


func _settle() -> void:
	await _wait(5)
	while kitchen.busy:
		await process_frame
	await _wait(5)


func _run() -> void:
	while current_scene == null:
		await process_frame
	await _wait(30)
	player = current_scene.get_node("Player")
	if player.get("_seat"):
		player.call("stand")
	kitchen = get_first_node_in_group("kitchen") as Kitchen
	_check(kitchen != null, "the galley has its kitchen")
	if kitchen == null:
		_finish()
		return
	var gs := Game.state()
	var counter: Node3D = kitchen.get_node("CookingCounter")
	var cupboard: Node3D = kitchen.get_node("Cupboard")
	_check(counter is Interactable and cupboard is Interactable, "a cooking counter and a cupboard to use")

	# The cupboard: take the supplies to the counter.
	_check(gs.at_counter.is_empty(), "nothing on the counter at first")
	var hud: Node = get_first_node_in_group("hud")
	cupboard.call("interact", player)
	await _wait(5)
	var supplies: Node = null
	for c in hud.get_children():
		if c is SupplyHud:
			supplies = c
	_check(supplies != null, "the cupboard opens its supplies")
	var stock_before: float = float(gs.stores.get("meal_pack", 0))
	for b: Button in supplies.find_children("*", "Button", true, false):
		pass
	gs.set_counter_amount("coffee_grounds", 1.0)
	gs.set_counter_amount("water", 1.0)
	gs.set_store_amount("meal_pack", stock_before - 1)
	gs.set_counter_amount("meal_pack", 1.0)
	if supplies:
		supplies.call("close")
	await _wait(5)
	_check(gs.counter_amount("meal_pack") == 1.0 and float(gs.stores["meal_pack"]) == stock_before - 1, "a meal pack taken from the cupboard's stores")

	# The cooking view.
	player.global_position = counter.global_position + Vector3(-1.0, 0.0, 0.0)
	await _wait(5)
	counter.call("interact", player)
	await _wait(5)
	session = kitchen.get_node("CookSession") as CookSession
	while session and not session.active:
		await process_frame
	_check(session != null and session.cam.current, "E at the counter: the cooking view")
	_check(not (player.get_node("Model") as Node3D).visible, "with no body or hands in it")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "and a free mouse cursor")
	await _shot("cook_1_view")

	# Hover: the spatula outlines white.
	await _move_to("spatula")
	await _wait(4)
	_check(session.get("_hover") == "spatula", "hovering the spatula picks it out")
	await _shot("cook_2_hover")

	# A missed release uses nothing up and returns it.
	var water0: float = gs.counter_amount("water")
	await _move_to("water", 4)
	session.press()
	await _wait(4)
	_check(session.held_id() == "water", "holding the left button on the water picks it up")
	session.test_mouse(session.test_screen_point("kettle") + Vector2(-260, -160))
	await _wait(10)
	session.release()
	await _wait(30)
	_check(gs.counter_amount("water") == water0 and kitchen.kettle_water == 0.0, "let go over nothing: nothing poured, nothing used")

	# Water into the kettle.
	await _drag("water", "kettle")
	_check(session.get("_drop") == "kettle" and session.get("_drop_ok"), "over the kettle it can go in (amber)")
	await _shot("cook_3_drop_water")
	session.release()
	await _settle()
	_check(kitchen.kettle_water > 0.0 and gs.counter_amount("water") < water0, "released: poured into the kettle, the flask lower (%.2f left)" % gs.counter_amount("water"))

	# The right burner heats it.
	var pt := session.test_screen_point("knob_right")
	session.test_mouse(pt)
	await _wait(4)
	session.press()
	session.release()
	await _wait(3)
	_check(kitchen.burners["right"], "clicking the right knob lights its burner")

	# Grounds into the mug while the water heats.
	await _drag("coffee_grounds", "mug")
	var coffee_prompt: String = kitchen.drop_prompt({"type": "ingredient", "id": "coffee_grounds"}, "mug")
	_check(coffee_prompt == "Release to add coffee grounds", "over the mug: \"%s\"" % coffee_prompt)
	await _shot("cook_4_grounds")
	session.release()
	await _settle()
	_check(kitchen.mug_grounds, "the grounds go into the mug")
	_check(gs.counter_amount("coffee_grounds") == 1.0, "coffee grounds don't run out")

	# Too soon: the kettle won't pour cold water.
	if kitchen.kettle_heat < Kitchen.HOT:
		await _drag("kettle", "mug")
		_check(not session.get("_drop_ok"), "the kettle won't pour before it's hot")
		session.release()
		await _settle()
		await _wait(20)
	await _secs(Kitchen.KETTLE_HEAT_TIME + 1.0)
	_check(kitchen.kettle_heat >= Kitchen.HOT, "the water heats on the burner (%.2f)" % kitchen.kettle_heat)
	await _shot("cook_5_boiling")

	# Pour it.
	await _drag("kettle", "mug")
	_check(session.get("_drop_ok"), "now the kettle pours into the mug")
	session.release()
	await _settle()
	await _wait(20)
	_check(kitchen.ready_dish("mug") != null and kitchen.ready_dish("mug").id == "coffee", "grounds and hot water: coffee")
	await _shot("cook_6_coffee")

	# Drink it.
	var hyd0: float = gs.vitals["hydration"]
	await _move_to("mug")
	await _wait(4)
	session.press()
	session.release()
	await _settle()
	_check(gs.vitals["hydration"] > hyd0, "drinking it: hydration %.0f -> %.0f" % [hyd0, gs.vitals["hydration"]])
	_check(gs.modifier("move_speed") > 1.0, "and a little quicker on his feet for a while")
	_check(not kitchen.mug_grounds and kitchen.mug_fill == 0.0, "the mug is empty again")

	# The meal: the pack into the wok.
	await _drag("meal_pack", "pan")
	_check(session.get("_drop_ok"), "a meal pack can go in the wok")
	session.release()
	await _settle()
	_check(kitchen.pan_food != null and gs.counter_amount("meal_pack") == 0.0, "it empties into the wok (packs left: %d)" % int(gs.counter_amount("meal_pack")))
	pt = session.test_screen_point("knob_left")
	session.test_mouse(pt)
	await _wait(4)
	session.press()
	session.release()
	await _wait(3)
	_check(kitchen.burners["left"], "the left knob lights the wok's burner")
	await _secs(Kitchen.PAN_HEAT_TIME + 0.5)
	# Stir: hold the spatula and move it about in the wok.
	await _drag("spatula", "pan")
	_check(session.held_id() == "spatula" and session.get("_drop") == "pan", "the spatula goes into the wok")
	var c := session.test_screen_point("pan")
	var t := 0.0
	var shot_taken := false
	while kitchen.pan_cooked < 1.0 and t < 40.0:
		session.test_mouse(c + Vector2(cos(t * 5.0), sin(t * 5.0)) * 40.0)
		await process_frame
		t += root.get_process_delta_time()
		if not shot_taken and kitchen.pan_cooked > 0.5:
			await _shot("cook_7_stirring")
			shot_taken = true
	session.release()
	await _settle()
	_check(kitchen.pan_cooked >= 1.0, "stirred over the heat, it cooks through (%.0f s)" % t)
	_check(t < Kitchen.COOK_TIME * 2.0, "stirring makes it quicker than leaving it")

	# Serve it and eat it.
	await _drag("pan", "bowl")
	_check(session.get("_drop_ok"), "the cooked wok can be tipped into the bowl")
	session.release()
	await _settle()
	_check(kitchen.bowl_food != null and kitchen.pan_food == null, "served into the bowl")
	await _shot("cook_8_served")
	gs.add_objective(gs.EAT_TASK)
	var hunger0: float = gs.vitals["hunger"]
	await _move_to("bowl")
	await _wait(4)
	session.press()
	session.release()
	await _settle()
	_check(gs.vitals["hunger"] > hunger0, "eating it: hunger %.0f -> %.0f" % [hunger0, gs.vitals["hunger"]])
	_check(gs.objective_done(gs.EAT_TASK) and gs.has_flag("ate_meal"), "and the \"make something to eat\" task is done")

	# Leaving, and saving what's left.
	session.leave()
	await _wait(60)
	_check(player.get("_cooking") == null and (player.get_node("Model") as Node3D).visible, "E: back on his feet")
	_check(gs.save_game(), "it saves")
	var water_left: float = gs.counter_amount("water")
	gs.load_game()
	await _wait(60)
	_check(absf(Game.state().counter_amount("water") - water_left) < 0.001, "and loading keeps the water flask's level")
	_finish()


func _finish() -> void:
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
