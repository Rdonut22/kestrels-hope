extends Interactable

## A photo you can look at up close (see ui/photo_view.gd), with Gana
## thinking about it.

@export var image: Texture2D
## Gana's lines ("|" separated).
@export_multiline var lines := ""

var _view: Control


func _ready() -> void:
	if prompt == "Use":
		prompt = "Look at photo"


func interact(_player: Node) -> void:
	if not _view:
		_view = (load("res://ui/photo_view.gd") as GDScript).new()
		hud().add_overlay(_view)
	_view.open(image)
	if lines != "":
		hud().think(Array(lines.split("|")), "", true)
