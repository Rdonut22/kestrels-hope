extends Interactable

enum State { IDLE, BREWING, READY }

@export var brew_time := 4.0

var state := State.IDLE

@onready var lamp: MeshInstance3D = $Lamp


func _ready() -> void:
	lamp.material_override = StandardMaterial3D.new()
	lamp.material_override.emission_enabled = true
	_set_lamp(Color(0.2, 0.2, 0.2))


func get_prompt() -> String:
	match state:
		State.BREWING:
			return "Brewing..."
		State.READY:
			return "Take coffee"
	return "Make coffee"


func can_interact(_player: Node) -> bool:
	return state != State.BREWING


func interact(player: Node) -> void:
	match state:
		State.IDLE:
			if player.has_coffee:
				hud().show_message("You've already got a mug going.")
				return
			state = State.BREWING
			_set_lamp(Color(1.0, 0.45, 0.1))
			hud().show_message("The machine gurgles to life.")
			await get_tree().create_timer(brew_time).timeout
			state = State.READY
			_set_lamp(Color(0.2, 1.0, 0.3))
			hud().show_message("Coffee's ready.")
		State.READY:
			state = State.IDLE
			_set_lamp(Color(0.2, 0.2, 0.2))
			player.has_coffee = true
			hud().show_message("Hot, black, recycled water. Perfect.")


func _set_lamp(color: Color) -> void:
	lamp.material_override.albedo_color = color
	lamp.material_override.emission = color
