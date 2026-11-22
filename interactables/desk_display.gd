extends Interactable

## The desk display in Gana's quarters: plays his recorded emergency
## transmission (a piece of the past, not a conversation) in the dialogue
## box.

const TRANSMISSION := [
	"Ushida Mining, this is the Kestrel. We've been attacked by pirates on the outer rim. The ship is badly damaged, and Hale is missing.",
	"Requesting immediate rescue and reconnaissance.",
]

var _playing := false


func _ready() -> void:
	if prompt == "Use":
		prompt = "Desk display"


func can_interact(_player: Node) -> bool:
	return not _playing


func interact(_player: Node) -> void:
	_playing = true
	var box: DialogueBox = hud().dialogue()
	var blip := AudioStreamPlayer.new()
	blip.stream = load("res://audio/sfx/beep.ogg")
	blip.volume_db = -14.0
	add_child(blip)
	blip.play()
	for line in TRANSMISSION:
		await box.show_line("ganna_recording", line, {"hold": 0.8})
	blip.queue_free()
	_playing = false
