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
## The small [E] key that floats above the object while it's targeted.
var _key: Node3D
static var _key_tex: Texture2D


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


## Turn the glowing outline and the [E] key on or off (the player calls
## this when it starts or stops looking at this object). `usable` = false
## shows the outline without the key (e.g. no power).
func set_highlighted(on: bool, usable := true) -> void:
	_show_key(on and usable)
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


## A tiny [E] keycap just above the object (or above this node when it has
## no meshes), the same size on screen at any distance.
func _show_key(on: bool) -> void:
	if not on:
		if _key:
			_key.visible = false
		return
	if _key == null:
		_key = Node3D.new()
		_key.name = "KeyHint"
		add_child(_key)
		var cap := Sprite3D.new()
		cap.texture = _keycap()
		cap.pixel_size = 0.001
		cap.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cap.fixed_size = true
		cap.no_depth_test = true
		cap.render_priority = 10
		cap.modulate = Color(1, 1, 1, 0.92)
		_key.add_child(cap)
		var e := Label3D.new()
		e.text = "E"
		e.font = preload("res://ui/fonts/JetBrainsMono-Bold.ttf")
		e.font_size = 34
		e.pixel_size = 0.001
		e.outline_size = 0
		e.modulate = Color(0.12, 0.1, 0.08)
		e.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		e.fixed_size = true
		e.no_depth_test = true
		e.render_priority = 11
		_key.add_child(e)
	_key.global_position = _key_spot()
	_key.visible = true


func _key_spot() -> Vector3:
	var box := AABB()
	var first := true
	for t in _targets():
		var meshes: Array[Node] = t.find_children("*", "MeshInstance3D", true, false)
		if t is MeshInstance3D:
			meshes.append(t)
		for m: MeshInstance3D in meshes:
			if m.mesh == null or m.name.begins_with("Outline"):
				continue
			var b: AABB = m.global_transform * m.get_aabb()
			box = b if first else box.merge(b)
			first = false
	if first:
		return global_position + Vector3(0, 0.35, 0)
	return Vector3(box.get_center().x, box.end.y + 0.12, box.get_center().z)


## A small rounded keycap: pale fill, soft edge.
static func _keycap() -> Texture2D:
	if _key_tex:
		return _key_tex
	var n := 48
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var r := 10.0
	for y in n:
		for x in n:
			var dx := maxf(maxf(r + 1.0 - x, x - (n - 2.0 - r)), 0.0)
			var dy := maxf(maxf(r + 1.0 - y, y - (n - 2.0 - r)), 0.0)
			var d := sqrt(dx * dx + dy * dy)
			var a := clampf(r + 0.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.97, 0.94, 0.86, a))
	_key_tex = ImageTexture.create_from_image(img)
	return _key_tex
