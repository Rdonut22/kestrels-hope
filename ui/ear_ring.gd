extends AudioStreamPlayer

## The high whine in your ears after a big hit (landing impact, waking up at
## the crash site). Set `level` 0..1; it's generated, so no sound file.

var level := 0.0

var _phase := 0.0
var _gen: AudioStreamGeneratorPlayback


func _ready() -> void:
	var g := AudioStreamGenerator.new()
	g.mix_rate = 22050.0
	g.buffer_length = 0.2
	stream = g
	volume_db = -8.0
	play()
	_gen = get_stream_playback()


func _process(_delta: float) -> void:
	if not _gen:
		return
	var rate := 22050.0
	for i in _gen.get_frames_available():
		_phase = fmod(_phase + 3150.0 / rate, 1.0)
		var wobble := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.003)
		var v := sin(_phase * TAU) * 0.22 * level * wobble
		_gen.push_frame(Vector2(v, v))
