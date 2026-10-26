extends Interactable

## Shows a line of text when used. Good for flavor objects.

@export_multiline var message := ""


func interact(_player: Node) -> void:
	hud().show_message(message, 4.0)
