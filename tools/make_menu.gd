extends SceneTree
func _init() -> void:
	var root := Node3D.new()
	root.name = "Menu"
	root.set_script(load("res://menu.gd"))
	var w: Node = (load("res://crash_site.tscn") as PackedScene).instantiate()
	w.name = "World"
	root.add_child(w)
	w.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	print("save ", ResourceSaver.save(ps, "res://menu.tscn"))
	quit()
