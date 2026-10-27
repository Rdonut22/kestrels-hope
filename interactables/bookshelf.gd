extends Interactable

## The lounge bookshelf: pick a book to carry, then read it anywhere with R
## (best on the couch).


func get_prompt() -> String:
	return "Browse books"


func interact(player: Node) -> void:
	hud().open_shelf(func(id: String) -> void:
		player.held_book = id
		hud().show_message("You take %s off the shelf.   [R] to read" % Library.find(id).title))
