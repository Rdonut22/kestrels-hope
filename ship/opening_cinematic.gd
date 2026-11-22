extends Node

## The opening in the ship (main.tscn), after the exterior drift (intro.gd):
##
##   montage   cockpit, lounge, kitchen: three slow 2-second shots.
##   quarters  (cutscene, control locked) the camera settles behind Gana in
##             front of the sleeping pods; he talks to the empty pod, then
##             the ship computer gives its status report.
##   free      control enabled: the player can walk to the round window;
##             E "Look outside" there starts...
##   window    (cutscene) the camera moves to the glass until the moon
##             fills the frame, a five-second hold, then the computer.
##   hunger    control restored. The first time Gana leaves the quarters
##             his stomach growls, he thinks out loud, and the objective
##             "Make something to eat" comes up (GameState.objective()).
##
## Until Gana eats ("ate_meal"), GameState.opening_locked() keeps the
## cockpit door shut, Meki's repairs off and the wrist terminal away.
## Started by player.gd (root meta "opening_cinematic", or `start_at`
## "hunger" when a save from before the growl is loaded).
## Positions are in the ship's frame (forward -Z, floor y 0).

## Music slots (no suitable tracks in the project yet: the scene plays
## without them). The piano starts in intro.gd (root "OpeningMusic").
const MELODY := "res://audio/music/opening_melody.ogg"   # the haunting melody at the window
const GROWL := "res://audio/sfx/stomach_growl.ogg"       # Gana's stomach
const MUSIC_DB := -8.0

## Montage shots: [eye from, eye to, look at].
const MONTAGE := [
	[Vector3(4.0, 1.6, -9.6), Vector3(4.0, 1.52, -10.05), Vector3(4.0, 1.15, -13.6)],   # cockpit
	[Vector3(3.15, 1.7, 4.9), Vector3(3.35, 1.62, 4.45), Vector3(6.0, 0.7, 0.6)],      # lounge
	[Vector3(3.3, 1.65, -6.2), Vector3(3.5, 1.6, -5.95), Vector3(4.7, 1.05, -4.0)],    # kitchen
]
const SHOT_SECS := 2.0

## Gana in front of the empty pod (Hale's, SleepPod0 at z -8.8), facing it
## (-X); the camera behind him.
const GANA_AT := Vector3(-1.75, 0.0, -8.6)
const SETTLE_FROM := Vector3(0.55, 1.8, -8.1)
const SETTLE_EYE := Vector3(-0.45, 1.68, -8.3)
const SETTLE_LOOK := Vector3(-2.9, 1.15, -8.8)
## The round window (QuartersWindow: centre x -0.4, y 1.5, wall z -9.6).
const WINDOW_HOOK := Vector3(-0.4, 1.2, -9.25)
const WINDOW_EYE := Vector3(-0.4, 1.56, -9.42)
const WINDOW_LOOK := Vector3(-0.42, 1.25, -14.0)
## The quarters, for "has he left": x, z ranges.
const QUARTERS_X := Vector2(-2.7, 1.9)
const QUARTERS_Z := Vector2(-9.7, -5.85)

@export var start_at := "start"   # "start" or "hunger"

var _ship: Node3D
var _player: Node
var _hud: CanvasLayer
var _cam: Camera3D
var _actor: Node3D
var _ui: CanvasLayer
var _bars: Array[ColorRect] = []
var _fade: ColorRect
var _box: DialogueBox
var _melody: AudioStreamPlayer
var _tone: AudioStreamPlayer
var _hook: Node3D
var _watching := false
var _ran := false


func _ready() -> void:
	_player = get_parent().get_node_or_null("Player")
	_ship = get_parent().get_node_or_null("ShipInterior")
	_hud = get_parent().get_node_or_null("HUD")
	run.call_deferred()


func run() -> void:
	if _ran or _ship == null or _player == null:
		return
	_ran = true
	_build_ui()
	_build_audio()
	if start_at == "hunger":
		_watch_for_leaving()
		return
	Game.state().set_flag("opening_started")
	add_to_group("cinematic")
	_lock(true)
	_cam = Camera3D.new()
	_cam.fov = 55
	_cam.near = 0.05
	_cam.far = 20000
	_ship.add_child(_cam)
	_cam.make_current()
	_fade.color.a = 1.0
	await _montage()
	await _quarters()
	_enable_control()


# ---------- setup ----------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 0.88
		bar.anchor_bottom = 0.12 if top else 1.0
		bar.visible = start_at != "hunger"
		_ui.add_child(bar)
		_bars.append(bar)
	_box = (load("res://ui/dialogue/dialogue_box.tscn") as PackedScene).instantiate()
	_box.set("width_share", 0.5)
	_box.set("max_width", 860.0)
	_ui.add_child(_box)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fade)


func _build_audio() -> void:
	_melody = AudioStreamPlayer.new()
	add_child(_melody)
	if ResourceLoader.exists(MELODY):
		_melody.stream = load(MELODY)
	_tone = AudioStreamPlayer.new()
	_tone.stream = load("res://audio/sfx/beep.ogg")
	add_child(_tone)


## Player control and the gameplay HUD off (cutscene) or back on.
func _lock(on: bool) -> void:
	_player.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	if _hud:
		_hud.visible = not on
	for b in _bars:
		create_tween().tween_property(b, "modulate:a", 1.0 if on else 0.0, 0.8)
		b.visible = true


# ---------- beats ----------

func _montage() -> void:
	for i in MONTAGE.size():
		var shot: Array = MONTAGE[i]
		_place_cam(shot[0], shot[2])
		var tw := create_tween()
		tw.tween_method(func(k: float) -> void: _place_cam((shot[0] as Vector3).lerp(shot[1], k), shot[2]), 0.0, 1.0, SHOT_SECS)
		create_tween().tween_property(_fade, "color:a", 0.0, 0.5 if i == 0 else 0.25)
		await _wait(SHOT_SECS - 0.25)
		await _to(_fade, "color:a", 1.0, 0.25)


func _quarters() -> void:
	_actor = (load("res://character/character.tscn") as PackedScene).instantiate()
	_actor.name = "CinematicGana"
	_ship.add_child(_actor)
	_actor.position = GANA_AT
	_actor.rotation.y = PI / 2   # facing the pods (-X)
	(_player.get("mesh") as Node3D).visible = false
	_place_cam(SETTLE_FROM, SETTLE_LOOK)
	create_tween().tween_property(_fade, "color:a", 0.0, 1.0)
	var settle := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	settle.tween_method(func(k: float) -> void: _place_cam(SETTLE_FROM.lerp(SETTLE_EYE, k), SETTLE_LOOK), 0.0, 1.0, 3.5)
	await settle.finished
	await _wait(1.0)
	await _say("ganna", "Forty-three days...", 1.4)
	await _wait(0.6)
	await _say("ganna", "Can't believe it's been that long since you disappeared.", 1.6)
	await _wait(1.0)
	await _say("ganna", "Better do my rounds.", 1.0)
	await _wait(0.8)
	_beep()
	await _wait(0.8)
	await _say("ship_computer", "Good morning, Gana. Would you like a status report?", 1.0)
	await _say("ganna", "Yeah. Go ahead.", 0.8)
	await _say("ship_computer", "Main turbine remains critically damaged. Fuel reserves are at six percent.", 1.2)
	await _say("ship_computer", "The Kestrel has been drifting off course for forty-three days since the attack.", 1.2)
	await _say("ship_computer", "I was forced to establish orbit around a nearby moon to conserve our remaining fuel.", 1.2)
	await _say("ship_computer", "I'm also detecting an unidentified signal.", 1.4)
	await _say("ganna", "Wait... a moon? What moon?", 1.0)
	await _say("ship_computer", "You were in deep sleep during our approach.", 1.0)
	await _say("ship_computer", "See for yourself.", 1.2)


## Control enabled in the quarters, facing the window; E at the window
## starts the window scene.
func _enable_control() -> void:
	await _to(_fade, "color:a", 1.0, 0.5)
	_actor.queue_free()
	_actor = null
	var yaw := atan2(-(WINDOW_HOOK.x - GANA_AT.x), -(WINDOW_HOOK.z - GANA_AT.z))
	(_player as Node3D).global_position = _ship.to_global(GANA_AT + Vector3(0, 1.0, 0))
	(_player.get("pivot") as Node3D).rotation = Vector3(-0.1, yaw, 0)
	(_player.get("mesh") as Node3D).rotation.y = yaw
	(_player.get("mesh") as Node3D).visible = true
	(_player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D).make_current()
	_lock(false)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.8)
	_hook = Node3D.new()
	_hook.set_script(load("res://interactables/cockpit_hook.gd"))
	_hook.name = "LookOutside"
	_hook.set("hook_id", "quarters_window")
	_hook.set("prompt", "Look outside")
	_hook.set("interact_range", 1.9)
	_hook.set("enabled", true)
	_hook.position = WINDOW_HOOK
	_ship.add_child(_hook)
	_hook.add_to_group("interactables")
	_hook.connect("used", func(_id: String, _p: Node) -> void: _window())


func _window() -> void:
	_hook.queue_free()
	_lock(true)
	var pcam := _player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	var from := _ship.to_local(pcam.global_position)
	var from_look := _ship.to_local(pcam.global_position - pcam.global_basis.z * 4.0)
	_place_cam(from, from_look)
	_cam.make_current()
	(_player.get("mesh") as Node3D).visible = false
	var move := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	move.tween_method(func(k: float) -> void: _place_cam(from.lerp(WINDOW_EYE, k), from_look.lerp(WINDOW_LOOK, k)), 0.0, 1.0, 3.5)
	_music_down(-14.0)
	if _melody.stream:
		_melody.volume_db = -30.0
		_melody.play()
		create_tween().tween_property(_melody, "volume_db", MUSIC_DB, 3.0)
	await move.finished
	await _wait(5.0)
	await _say("ganna", "What...? Where the hell are we?", 1.2)
	_beep()
	await _wait(0.6)
	await _say("ship_computer", "This moon is not present in our navigation database.", 1.0)
	await _say("ship_computer", "We are approximately two thousand tenets from our assigned mining route.", 1.4)
	await _say("ship_computer", "Atmospheric analysis indicates a potentially habitable ecosystem.", 1.2)
	await _say("ship_computer", "I recommend an emergency landing. Our oxygen and fuel reserves are nearly depleted.", 1.2)
	await _say("ganna", "What are the chances we'd survive a landing?", 1.0)
	# The computer pauses.
	await _wait(2.6)
	await _say("ship_computer", "...Twenty-three percent.", 2.0)
	# The music fades into the hum of the ship.
	for p in [_melody, _opening_music()]:
		if p and p.playing:
			create_tween().tween_property(p, "volume_db", -50.0, 4.0)
	await _wait(1.0)
	await _to(_fade, "color:a", 1.0, 0.8)
	(_player.get("mesh") as Node3D).visible = true
	pcam.make_current()
	_cam.queue_free()
	_lock(false)
	Game.state().set_flag("opening_window_done")
	remove_from_group("cinematic")
	await _to(_fade, "color:a", 0.0, 0.8)
	var m := _opening_music()
	if m:
		m.queue_free()
	_watch_for_leaving()


## The first time Gana steps out of the quarters: the growl, his thoughts,
## the objective.
func _watch_for_leaving() -> void:
	_watching = true


func _process(_delta: float) -> void:
	if not _watching or _player.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	var p := _ship.to_local((_player as Node3D).global_position)
	var inside := p.x > QUARTERS_X.x and p.x < QUARTERS_X.y and p.z > QUARTERS_Z.x and p.z < QUARTERS_Z.y
	if inside:
		return
	_watching = false
	_hunger()


func _hunger() -> void:
	if ResourceLoader.exists(GROWL):
		var g := AudioStreamPlayer.new()
		g.stream = load(GROWL)
		add_child(g)
		g.play()
	await _wait(0.8)
	if _hud:
		await _hud.think(["I haven't eaten in days...", "Not like these rations are gonna last forever.", "Better make something."])
	Game.state().set_flag("objective_eat")
	queue_free()


# ---------- helpers ----------

func _say(who: String, text: String, hold: float) -> void:
	await _box.show_line(who, text, {"hold": hold})


func _beep() -> void:
	_tone.volume_db = -16.0
	_tone.pitch_scale = 0.85
	_tone.play()


func _opening_music() -> AudioStreamPlayer:
	return get_tree().root.get_node_or_null("OpeningMusic") as AudioStreamPlayer


func _music_down(db: float) -> void:
	var m := _opening_music()
	if m and m.playing:
		create_tween().tween_property(m, "volume_db", db, 2.0)


func _place_cam(eye: Vector3, look: Vector3) -> void:
	_cam.position = eye
	_cam.look_at(_ship.to_global(look))


func _to(obj: Object, prop: String, to: Variant, secs: float) -> void:
	var tw := create_tween()
	tw.tween_property(obj, prop, to, secs)
	await tw.finished


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, false).timeout
