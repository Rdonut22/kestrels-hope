class_name Interactable
extends Node3D

## Base for anything the player can use with the interact key (E).
## Make a script that extends this and override interact().

@export var prompt := "Use"
## How close (in meters, ignoring height) the player must be.
@export var interact_range := 2.0
## Dead until Meki brings the ship's power back (see GameState).
@export var needs_power := false
## What lights up with a glowing outline while Gana looks at this: paths to
## nodes (from the scene this was saved in); every mesh under each one is
## outlined. Empty = this node's own meshes.
@export var highlight: PackedStringArray = []

const OUTLINE := preload("res://interactables/outline.gdshader")
var _outlines: Array[MeshInstance3D] = []
var _outline_tween: Tween


func _enter_tree() -> void:
	add_to_group("interactables")


func get_prompt() -> String:
	return prompt


func can_interact(_player: Node) -> bool:
	return true


func interact(_player: Node) -> void:
	pass


func hud() -> Node:
	return get_tree().get_first_node_in_group("hud")


## Turn the glowing outline on or off (the player calls this when it
## starts or stops looking at this object).
func set_highlighted(on: bool) -> void:
	if on and _outlines.is_empty():
		_build_outlines()
	if _outlines.is_empty():
		return
	if _outline_tween:
		_outline_tween.kill()
	_outline_tween = create_tween()
	for o in _outlines:
		if on:
			o.visible = true
		_outline_tween.parallel().tween_method(func(v: float): (o.material_override as ShaderMaterial).set_shader_parameter("fade", v),
			(o.material_override as ShaderMaterial).get_shader_parameter("fade"), 1.0 if on else 0.0, 0.18)
	if not on:
		_outline_tween.tween_callback(func():
			for o in _outlines:
				o.visible = false)


func _targets() -> Array[Node]:
	var out: Array[Node] = []
	if highlight.is_empty():
		out.append(self)
		return out
	var base: Node = owner if owner else get_tree().current_scene
	for p in highlight:
		var n := base.get_node_or_null(NodePath(p)) if base else null
		if n:
			out.append(n)
	return out


func _build_outlines() -> void:
	for t in _targets():
		var meshes: Array[Node] = t.find_children("*", "MeshInstance3D", true, false)
		if t is MeshInstance3D:
			meshes.append(t)
		for m: MeshInstance3D in meshes:
			if m.mesh == null or m.mesh is QuadMesh or m.mesh is PlaneMesh or m.name.begins_with("Outline"):
				continue
			var mat := ShaderMaterial.new()
			mat.shader = OUTLINE
			mat.set_shader_parameter("center", m.mesh.get_aabb().get_center())
			mat.set_shader_parameter("fade", 0.0)
			var o := MeshInstance3D.new()
			o.name = "Outline"
			o.mesh = m.mesh
			o.material_override = mat
			o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			o.visible = false
			m.add_child(o)
			_outlines.append(o)
