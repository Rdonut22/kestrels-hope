extends Node

## Acoustic music cues at the crash site (autoload AmbientMusic). Never in
## space or the menus: only in a scene with OutdoorMusic (crash_site.tscn),
## and only once Gana has first stepped out of the wreck.
##
## The music is one long acoustic mix. Each cue plays a random stretch of
## it, from the part of the mix that belongs to the area Gana is in, so
## areas keep their own feel without ever repeating exactly. A cue fades
## in, plays CUE_SECS, fades out, then the site is quiet (wind only) for
## QUIET_SECS. Walking into another area during a cue crossfades to a new
## stretch for that area; walking into one during the quiet starts a cue
## a little early. Inside the wreck it plays faintly.

## Off for now (the user's call): set true to bring the music back.
const ENABLED := false

const STREAM := "res://audio/music/acoustic_chill.mp3"
## Which slice of the mix (0..1) each area draws from.
const AREAS := {
	"wreck": Vector2(0.0, 0.25),
	"clearing": Vector2(0.25, 0.5),
	"ruins": Vector2(0.5, 0.75),
	"forest": Vector2(0.75, 1.0),
}
const CUE_SECS := Vector2(90.0, 180.0)
const QUIET_SECS := Vector2(60.0, 150.0)
const OUTSIDE_DB := -13.0
const INSIDE_DB := -24.0
const FADE_IN := 6.0
const FADE_OUT := 8.0

var _stream: AudioStream
var _cue: AudioStreamPlayer
var _cue_area := ""
var _cue_end := 0.0
var _cue_start := 0.0
var _quiet_until := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	# The first cue comes soon after Gana first steps outside.
	_quiet_until = 0.0


## Game time (stops while paused, like the music).
var _clock := 0.0


func _now() -> float:
	return _clock


func _site() -> Node:
	var scene := get_tree().current_scene
	return scene if scene and scene.has_node("OutdoorMusic") and scene.has_node("Player") else null


## Which area Gana is in: the wreck, the clearing round it, the ruins, or
## the forest beyond.
func _area(site: Node) -> String:
	var om := site.get_node("OutdoorMusic")
	if not om.is_outside():
		return "wreck"
	var p: Vector3 = (site.get_node("Player") as Node3D).global_position
	var ship := site.get_node("Ship") as Node3D
	if Vector2(p.x - ship.global_position.x, p.z - ship.global_position.z).length() < 40.0:
		return "clearing"
	var ruins := site.get_node_or_null("CrashSite/Ruins") as Node3D
	if ruins:
		for r in ruins.get_children():
			if r is Node3D and Vector2(p.x - r.global_position.x, p.z - r.global_position.z).length() < 35.0:
				return "ruins"
	return "forest"


func _process(delta: float) -> void:
	_clock += delta
	var site := _site()
	if not ENABLED or site == null or not site.get_node("OutdoorMusic").get("_started"):
		if _cue:
			_fade_out()
		return
	var t := _now()
	var area := _area(site)
	var target := INSIDE_DB if area == "wreck" else OUTSIDE_DB
	if _cue:
		if t > _cue_end:
			_fade_out()
			_quiet_until = t + _rng.randf_range(QUIET_SECS.x, QUIET_SECS.y)
		elif area != _cue_area and (area == "wreck") != (_cue_area == "wreck") and t - _cue_start > 25.0:
			# In or out of the wreck: just follow the volume, same music.
			_cue_area = area
			_ramp(_cue, target, 3.0)
		elif area != _cue_area and t - _cue_start > 25.0:
			_start(area, target)
		return
	if _quiet_until == 0.0:
		_quiet_until = t + 8.0
	if t > _quiet_until:
		_start(area, target)


func _start(area: String, target_db: float) -> void:
	if _stream == null:
		_stream = load(STREAM)
		if "loop" in _stream:
			_stream.set("loop", false)
	if _cue:
		_fade_out()
	var p := AudioStreamPlayer.new()
	p.stream = _stream
	p.volume_db = -60.0
	add_child(p)
	var slice: Vector2 = AREAS[area]
	var length := _stream.get_length()
	var span := CUE_SECS.y + FADE_OUT + 5.0
	var from := lerpf(slice.x, slice.y, _rng.randf()) * length
	p.play(clampf(from, 0.0, maxf(length - span, 0.0)))
	_ramp(p, target_db, FADE_IN)
	_cue = p
	_cue_area = area
	_cue_start = _now()
	_cue_end = _cue_start + _rng.randf_range(CUE_SECS.x, CUE_SECS.y)


func _fade_out() -> void:
	var p := _cue
	_cue = null
	_cue_area = ""
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -60.0, FADE_OUT)
	tw.tween_callback(p.queue_free)


func _ramp(p: AudioStreamPlayer, db: float, secs: float) -> void:
	create_tween().tween_property(p, "volume_db", db, secs)
