extends SceneTree
func _init() -> void:
	var root := Node3D.new()
	root.name = "Intro"
	root.set_script(load("res://intro.gd"))
	var ps := PackedScene.new()
	ps.pack(root)
	print("save ", ResourceSaver.save(ps, "res://intro.tscn"))
	quit()
