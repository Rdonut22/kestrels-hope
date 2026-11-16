extends Control

## Test scene for the dialogue box (run it with F6): Meki, the farm droid,
## a long line, a speaker with no portrait, and a response choice. Not part
## of the game; tools/dialogue_playtest.gd drives it automatically.

const LINES := [
	["meki", "Systems online. One lens, one purpose: keeping you in one piece."],
	["farm_droid", "Soil moisture nominal. Seedlings at forty percent. Please do not step on the seedlings."],
	["ship_computer", "Long transmission test: the reactor is holding at forty-one percent, the starboard coolant loop is venting slowly, the long-range array is still dark, and the nav core keeps asking for a star chart we no longer have."],
	["radio", "...static... (no portrait: the text takes the full width)"],
]
const QUESTION := ["ganna", "Where to first?"]
const OPTIONS := ["The signal.", "The engine room.", "Back to sleep."]

signal done(choice: int)

var box: DialogueBox


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.1)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	box = (load("res://ui/dialogue/dialogue_box.tscn") as PackedScene).instantiate()
	add_child(box)
	run.call_deferred()


func run() -> void:
	for l in LINES:
		await box.show_line(l[0], l[1])
	var pick := await box.ask(QUESTION[0], QUESTION[1], OPTIONS)
	print("chose: ", OPTIONS[pick])
	done.emit(pick)
