class_name OutlineSet
extends RefCounted

## A thin glowing silhouette round every mesh under a node, using the
## interactables' outline shader (interactables/outline.gdshader): white for
## what the cursor is on or holding, amber for where a held thing can go.

const SHADER := preload("res://interactables/outline.gdshader")
const WHITE := Color(1.0, 0.98, 0.95)
const AMBER := Color(1.0, 0.62, 0.2)

var _shells: Array[MeshInstance3D] = []
var _mats: Array[ShaderMaterial] = []


func _init(target: Node, width := 0.0028) -> void:
	var meshes: Array[Node] = target.find_children("*", "MeshInstance3D", true, false)
	if target is MeshInstance3D:
		meshes.append(target)
	for m: MeshInstance3D in meshes:
		if m.mesh == null or m.name.begins_with("Outline") or m.mesh is QuadMesh:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("center", m.mesh.get_aabb().get_center())
		mat.set_shader_parameter("width", width)
		mat.set_shader_parameter("energy", 1.3)
		var o := MeshInstance3D.new()
		o.name = "Outline"
		o.mesh = m.mesh
		o.material_override = mat
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		o.visible = false
		m.add_child(o)
		_shells.append(o)
		_mats.append(mat)


## Show it in a colour, or hide it (`on` false).
func show(on: bool, color := WHITE) -> void:
	for i in _shells.size():
		if not is_instance_valid(_shells[i]):
			continue
		_shells[i].visible = on
		if on:
			_mats[i].set_shader_parameter("color", color)
