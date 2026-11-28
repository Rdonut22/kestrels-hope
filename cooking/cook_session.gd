class_name CookSession
extends Node

## The cooking view (started at the counter, cooking/counter.gd): a fixed
## camera over the stove and out of the window, a free mouse cursor, the
## ingredient panel (cooking/cook_hud.gd), and the hands-free handling of
## things (cooking/kitchen.gd does what they do):
##
## - hover: a thin white outline on what the cursor is on (something that
##   can be picked up or clicked now);
## - hold the left button on an ingredient's slot, or on the spatula, the
##   kettle or a cooked wok, to pick it up: it floats with the cursor,
##   outlined;
## - over somewhere it can go (a generous zone round the vessel) that place
##   outlines amber and says what releasing will do; release there and it
##   happens. Released anywhere else it drifts back, nothing used up;
## - click a stove knob to light or put out its burner; click the finished
##   coffee or meal to have it;
## - E, Esc or the right button steps back.

## Held things float this high over the worktop.
const HOLD_HEIGHT := 0.2
const FOLLOW := 14.0
## Drop zones reach this much further than the vessel itself (metres).
const DROP_REACH := 0.09
## How far the cursor may be from something on screen to point at it.
const HOVER_PX := 18.0
## The part of the worktop a held thing stays over (galley frame, x/z).
const AREA_MIN := Vector2(5.45, -6.45)
const AREA_MAX := Vector2(6.65, -3.8)

var kitchen: Kitchen
var player: Node
var cam: Camera3D
var hud: CookHud
var active := false

var _mouse := Vector2.ZERO
var _hover := ""
var _held := {}
var _drop := ""
var _drop_ok := false
var _held_prev := Vector3.ZERO
var _held_outline: OutlineSet
var _leaving := false
var _quiet: Control
var _t := 0.0


func start(k: Kitchen, p: Node) -> void:
	kitchen = k
	player = p
	player.call("start_cooking", self)
	var from := get_viewport().get_camera_3d()
	cam = Camera3D.new()
	cam.name = "CookCamera"
	cam.near = 0.03
	get_tree().current_scene.add_child(cam)
	if from:
		cam.global_transform = from.global_transform
		cam.fov = from.fov
	cam.make_current()
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "global_transform", kitchen.camera_transform(), 0.9)
	tw.tween_property(cam, "fov", Kitchen.CAM_FOV, 0.9)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse = get_viewport().get_visible_rect().size * 0.5
	await tw.finished
	hud = CookHud.new()
	add_child(hud)
	# The game HUD (vitals, compass) steps aside while cooking: an empty
	# overlay counts as busy for it (ui/hud.gd hides_chrome).
	var game_hud := get_tree().get_first_node_in_group("hud")
	if game_hud:
		_quiet = Control.new()
		_quiet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game_hud.call("add_overlay", _quiet)
	active = true
	if Game.state().at_counter.is_empty():
		var h := get_tree().get_first_node_in_group("hud")
		if h:
			h.call("think", ["Nothing to cook with. The cupboard's got supplies."], "thought_cook_empty")


func _input(event: InputEvent) -> void:
	if not active:
		if event is InputEventMouseButton or event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_mouse = mb.position
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				press()
			else:
				release()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			leave()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		leave()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	if not _held.is_empty():
		_update_held(delta)
		return
	# Hover: an ingredient slot, or something in the kitchen.
	var slot := hud.slot_at(_mouse)
	hud.set_hover(slot if hud.slot_ready(slot) else "")
	var over := "" if slot != "" or kitchen.busy else _target_under(_mouse)
	if over != _hover:
		if _hover != "":
			kitchen.highlight(_hover, false)
		_hover = over
		if _hover != "":
			kitchen.highlight(_hover, true, OutlineSet.WHITE)
	hud.show_prompt("", Vector2.ZERO)


## The usable thing nearest the cursor on screen, within reach.
func _target_under(p: Vector2) -> String:
	var best := ""
	var best_d := INF
	for id: String in kitchen.targets:
		if not (kitchen.can_grab(id) or kitchen.can_click(id)):
			continue
		var at := kitchen.target_point(id)
		if cam.is_position_behind(at):
			continue
		var sp := cam.unproject_position(at)
		var reach := _screen_radius(at, float(kitchen.targets[id]["radius"])) + HOVER_PX
		var d := sp.distance_to(p)
		if d < reach and d < best_d:
			best = id
			best_d = d
	return best


## A world radius at `at`, in screen pixels.
func _screen_radius(at: Vector3, r: float) -> float:
	var side := cam.global_basis.x * r
	return cam.unproject_position(at).distance_to(cam.unproject_position(at + side))


## The point on the holding plane under the cursor (global).
func _cursor_point() -> Vector3:
	var to_k := kitchen.global_transform.affine_inverse()
	var o := to_k * cam.project_ray_origin(_mouse)
	var d := to_k.basis * cam.project_ray_normal(_mouse)
	var y := Kitchen.COUNTER_Y + HOLD_HEIGHT
	var p := o
	if absf(d.y) > 0.0001:
		var t := (y - o.y) / d.y
		if t > 0.0:
			p = o + d * t
	p.x = clampf(p.x, AREA_MIN.x, AREA_MAX.x)
	p.z = clampf(p.z, AREA_MIN.y, AREA_MAX.y)
	p.y = y
	return kitchen.global_transform * p


# ------------------------------------------------------------ holding

func press() -> void:
	if not active or kitchen.busy or not _held.is_empty():
		return
	var slot := hud.slot_at(_mouse)
	if slot != "":
		if not hud.slot_ready(slot):
			return
		var proxy := _proxy(slot)
		kitchen.add_child(proxy)
		proxy.global_position = _cursor_point()
		_held = {"type": "ingredient", "id": slot, "node": proxy}
		_held_outline = OutlineSet.new(proxy)
		_held_outline.show(true)
		_held_prev = proxy.global_position
		hud.set_hover("")
		hud.set_held(slot)
		return
	if _hover == "":
		return
	if kitchen.can_grab(_hover):
		var n: Node3D = kitchen.targets[_hover]["node"]
		_held = {"type": "object", "id": _hover, "node": n}
		_held_prev = n.global_position
		kitchen.highlight(_hover, true, OutlineSet.WHITE)
		_hover = ""
	elif kitchen.can_click(_hover):
		kitchen.click(_hover)


func _proxy(id: String) -> Node3D:
	match id:
		"coffee_grounds":
			return CookProps.scoop()
		"water":
			return CookProps.water_flask(Game.state().counter_amount("water"))
	return CookHud.model_for(id)


func _update_held(delta: float) -> void:
	var n: Node3D = _held["node"]
	if not is_instance_valid(n):
		_held = {}
		return
	var goal := _cursor_point()
	var id: String = _held["id"]
	# Where it could go.
	var drop := ""
	var best := INF
	for tid: String in kitchen.targets:
		if tid == id:
			continue
		if kitchen.drop_prompt(_held, tid) == "" and kitchen.drop_hint(_held, tid) == "":
			continue
		# Over it: the held thing above the vessel, or the cursor on it.
		var tp := kitchen.target_point(tid)
		var r := float(kitchen.targets[tid]["radius"])
		var d := Vector2(goal.x - tp.x, goal.z - tp.z).length() / (r + DROP_REACH)
		if not cam.is_position_behind(tp):
			var on_screen := cam.unproject_position(tp).distance_to(_mouse) / (_screen_radius(tp, r + DROP_REACH) + HOVER_PX)
			d = minf(d, on_screen)
		if d < 1.0 and d < best:
			drop = tid
			best = d
	if drop != _drop:
		if _drop != "":
			kitchen.highlight(_drop, false)
		_drop = drop
	var prompt := kitchen.drop_prompt(_held, _drop) if _drop != "" else ""
	_drop_ok = prompt != ""
	if _drop != "":
		if _drop_ok:
			kitchen.highlight(_drop, true, OutlineSet.AMBER)
		hud.show_prompt(prompt if _drop_ok else kitchen.drop_hint(_held, _drop), cam.unproject_position(kitchen.target_point(_drop)), _drop_ok)
	else:
		hud.show_prompt("", Vector2.ZERO)
	# Stirring: the spatula goes down into the wok and moves with the cursor.
	if id == "spatula" and _drop == "pan" and _drop_ok:
		goal = Vector3(goal.x, kitchen.target_point("pan").y + 0.03, goal.z)
	# Follow, gently floating.
	goal.y += sin(_t * 3.0) * 0.006
	var p := n.global_position.lerp(goal, clampf(delta * FOLLOW, 0.0, 1.0))
	if id == "spatula" and _drop == "pan" and _drop_ok:
		kitchen.stir_motion(p.distance_to(_held_prev))
	_held_prev = p
	n.global_position = p


func release() -> void:
	if _held.is_empty():
		return
	var held := _held
	_held = {}
	var id: String = held["id"]
	var n: Node3D = held["node"]
	var target := _drop
	var ok := _drop_ok
	if _drop != "":
		kitchen.highlight(_drop, false)
	_drop = ""
	_drop_ok = false
	hud.show_prompt("", Vector2.ZERO)
	if held["type"] == "ingredient":
		hud.set_held("")
		if _held_outline:
			_held_outline.show(false)
		if ok:
			kitchen.drop_ingredient(id, target, n)
		else:
			_return_to_panel(n, id)
		return
	kitchen.highlight(id, false)
	if ok and id != "spatula":
		kitchen.drop_object(id, target)
	else:
		kitchen.go_home(id)


## A missed release: the ingredient drifts back toward its slot and fades.
func _return_to_panel(n: Node3D, id: String) -> void:
	var box: Rect2 = Rect2()
	for c in [id]:
		var slots: Dictionary = hud.get("_slots")
		if slots.has(c):
			box = (slots[c]["box"] as Control).get_global_rect()
	var to := n.global_position
	if box.size != Vector2.ZERO:
		to = cam.project_position(box.get_center(), cam.global_position.distance_to(n.global_position))
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "global_position", to, 0.35)
	tw.tween_property(n, "scale", Vector3.ONE * 0.2, 0.35)
	await tw.finished
	n.queue_free()


# ------------------------------------------------------------ leaving

func leave() -> void:
	if _leaving or not active or kitchen.busy:
		return
	if not _held.is_empty():
		release()
	_leaving = true
	active = false
	if _hover != "":
		kitchen.highlight(_hover, false)
	if hud:
		hud.queue_free()
	if _quiet:
		_quiet.queue_free()
	var back: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "global_transform", back.global_transform, 0.7)
	tw.tween_property(cam, "fov", back.fov, 0.7)
	await tw.finished
	player.call("stop_cooking")
	cam.queue_free()
	queue_free()


# ------------------------------------------------------------ for playtests

## Moves the cursor to a screen point, as the mouse would.
func test_mouse(p: Vector2) -> void:
	_mouse = p


## Where a kitchen target or an ingredient's slot is on screen.
func test_screen_point(id: String) -> Vector2:
	if kitchen.targets.has(id):
		return cam.unproject_position(kitchen.target_point(id))
	var slots: Dictionary = hud.get("_slots")
	if slots.has(id):
		return (slots[id]["box"] as Control).get_global_rect().get_center()
	return Vector2.ZERO


func held_id() -> String:
	return String(_held.get("id", ""))
