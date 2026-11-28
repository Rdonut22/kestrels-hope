class_name CookSfx
extends AudioStreamPlayer3D

## Placeholder kitchen sounds, made as they play (no sound files yet; see
## cooking/README.md): "sizzle" (food in a hot pan), "bubble" (water
## coming to the boil), "burner" (the gas hiss of a lit burner) and "pour"
## (a pouring stream). Set `level` 0..1; at 0 it falls silent.

@export_enum("sizzle", "bubble", "burner", "pour") var kind := "sizzle"
var level := 0.0

const RATE := 22050.0
var _gen: AudioStreamGeneratorPlayback
var _lp := 0.0
var _lp2 := 0.0
var _pop := 0.0
var _pop_f := 0.0
var _phase := 0.0
var _shown := 0.0


func _ready() -> void:
	var g := AudioStreamGenerator.new()
	g.mix_rate = RATE
	g.buffer_length = 0.12
	stream = g
	unit_size = 1.5
	max_db = 0.0
	volume_db = -6.0


func _process(delta: float) -> void:
	_shown = move_toward(_shown, level, delta * 2.0)
	if _shown <= 0.001:
		if playing:
			stop()
			_gen = null
		return
	if not playing:
		play()
		_gen = get_stream_playback()
	if _gen == null:
		return
	for i in _gen.get_frames_available():
		var v := _sample() * _shown
		_gen.push_frame(Vector2(v, v))


func _sample() -> float:
	var n := randf() * 2.0 - 1.0
	match kind:
		"sizzle":
			# Bright crackle: high-passed noise with random spits.
			_lp += (n - _lp) * 0.35
			var hiss := (n - _lp) * 0.35
			if randf() < 0.0015:
				_pop = 0.6
			_pop *= 0.985
			return hiss + _pop * (randf() * 2.0 - 1.0) * 0.5
		"bubble":
			# Low rumble and bubbles: short rising blips.
			_lp += (n - _lp) * 0.02
			if _pop <= 0.001 and randf() < 0.0009:
				_pop = 1.0
				_pop_f = randf_range(180.0, 420.0)
			_pop *= 0.996
			_pop_f *= 1.0004
			_phase = fmod(_phase + _pop_f / RATE, 1.0)
			return _lp * 0.6 + sin(_phase * TAU) * _pop * 0.25
		"burner":
			_lp += (n - _lp) * 0.08
			_lp2 += (_lp - _lp2) * 0.08
			return (_lp - _lp2) * 1.6
		"pour":
			_lp += (n - _lp) * 0.12
			return _lp * 0.8 * (0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.03))
	return 0.0
