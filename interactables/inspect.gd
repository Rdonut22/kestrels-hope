extends Interactable

## Shows a line of text when used. Good for flavor objects.

@export_multiline var message := ""
## Play the message as Gana thinking out loud instead ("|" splits lines).
@export var thought := false


func interact(_player: Node) -> void:
	if thought:
		hud().think(Array(message.split("|")))
	else:
		hud().show_message(message, 4.0)
