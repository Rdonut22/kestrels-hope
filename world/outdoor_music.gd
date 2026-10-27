extends Node

## Music outside the crashed ship. Silent until the player first steps out
## of the wreck, then plays on loop while outside and fades down inside.

@export var stream: AudioStream = preload("res://audio/outside_theme.ogg")
@export var outside_db := -4.0
@export var inside_db := -30.0
@export var fade_speed := 12.0  # dB per second

var _player: Node3D
var _ship: Node3D
var _music: AudioStreamPlayer
var _started := false


func _ready() -> void:
	_player = get_parent().get_node("Player")
	_ship = get_parent().get_node("Ship")
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	if "loop" in stream:
		stream.loop = true
	_music.volume_db = -60.0
	add_child(_music)


func is_outside() -> bool:
	var p := _ship.to_local(_player.global_position)
	return p.x > 7.0 or p.x < -7.7 or p.z < -14.4 or p.z > 11.3 or p.y > 4.5


func _process(delta: float) -> void:
	var outside := is_outside()
	if outside and not _started:
		_started = true
		_music.play()
	if not _started:
		return
	var target := outside_db if outside else inside_db
	_music.volume_db = move_toward(_music.volume_db, target, fade_speed * delta)
