extends Node3D

## The reactor column by the cockpit door: its glass band glows and pulses,
## dimmer while the ship is on emergency power.

var _glass: Array[StandardMaterial3D] = []
var _light: OmniLight3D


func _ready() -> void:
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if m and m.resource_name == "Glass":
				var own := m.duplicate() as StandardMaterial3D
				own.emission_enabled = true
				own.emission = Color(0.35, 0.75, 1.0)
				mi.set_surface_override_material(i, own)
				_glass.append(own)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.4, 0.75, 1.0)
	_light.omni_range = 2.6
	_light.position = Vector3(0.4, 1.1, 0)
	add_child(_light)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var gs := Game.state()
	var level := 1.0 if gs.power_restored else (0.5 if gs.meki_online else 0.3)
	var pulse := (0.75 + 0.25 * sin(t * 2.2)) * level
	for m in _glass:
		m.emission_energy_multiplier = 2.2 * pulse
	_light.light_energy = 0.55 * pulse
