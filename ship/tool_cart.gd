@tool
class_name ToolCart
extends Node3D

## A rolling tool cart built from boxes, wearing the user's tool-cart texture
## set (ship/textures/interior/tool_cart_*): each face's UVs point at the
## matching region of the set's atlas (drawer strips on the drawer front,
## side panels on the sides, a door panel below, a plain panel on top).
## Origin at floor level, front facing +X (turn the node to place it).

@export var width := 0.9      # along the wall (z)
@export var depth := 0.5      # out from the wall (x)
@export var height := 0.95

# Atlas regions (u0, v0, u1, v1) of the 2048 x 2048 tool-cart texture set.
const SIDE := Rect2(0.28, 0.215, 0.42, 0.285)
const DRAWERS := Rect2(0.28, 0.08, 0.29, 0.13)
const DOOR := Rect2(0.34, 0.52, 0.26, 0.41)
const TOP := Rect2(0.72, 0.35, 0.2, 0.29)
const BACK := Rect2(0.0, 0.06, 0.26, 0.4)
const STEEL := Rect2(0.93, 0.62, 0.04, 0.1)


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ship/tool_cart.gdshader")
	var tex := "res://ship/textures/interior/"
	mat.set_shader_parameter("metal_map", load(tex + "tool_cart_metal.png"))
	mat.set_shader_parameter("rough_map", load(tex + "tool_cart_rough.png"))
	if ResourceLoader.exists(tex + "tool_cart_color.png"):
		mat.set_shader_parameter("albedo_map", load(tex + "tool_cart_color.png"))
		mat.set_shader_parameter("has_albedo", true)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := width * 0.5
	var d := depth * 0.5
	var base := 0.14             # casters below
	var top := height - 0.04
	var mid := base + (top - base) * 0.45
	# Body: front (+x) split into a door (low) and the drawer stack (high).
	_quad(st, Vector3(d, base, w), Vector3(d, base, -w), Vector3(d, mid, -w), Vector3(d, mid, w), DOOR)
	_quad(st, Vector3(d, mid, w), Vector3(d, mid, -w), Vector3(d, top, -w), Vector3(d, top, w), DRAWERS)
	_quad(st, Vector3(-d, base, -w), Vector3(-d, base, w), Vector3(-d, top, w), Vector3(-d, top, -w), BACK)
	_quad(st, Vector3(-d, base, w), Vector3(d, base, w), Vector3(d, top, w), Vector3(-d, top, w), SIDE)
	_quad(st, Vector3(d, base, -w), Vector3(-d, base, -w), Vector3(-d, top, -w), Vector3(d, top, -w), SIDE)
	_quad(st, Vector3(-d, base, -w), Vector3(d, base, -w), Vector3(d, base, w), Vector3(-d, base, w), STEEL)
	# Top tray: a lid slightly larger than the body, with a low rim.
	var lt := height
	var o := 0.025
	_quad(st, Vector3(-d - o, lt, w + o), Vector3(d + o, lt, w + o), Vector3(d + o, lt, -w - o), Vector3(-d - o, lt, -w - o), TOP)
	for e in [[Vector3(d + o, top, w + o), Vector3(d + o, top, -w - o)], [Vector3(-d - o, top, -w - o), Vector3(-d - o, top, w + o)],
			[Vector3(-d - o, top, w + o), Vector3(d + o, top, w + o)], [Vector3(d + o, top, -w - o), Vector3(-d - o, top, -w - o)]]:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		_quad(st, a, b, b + Vector3(0, lt - top, 0), a + Vector3(0, lt - top, 0), STEEL)
	st.generate_normals()
	st.generate_tangents()
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = st.commit()
	body.material_override = mat
	add_child(body)

	# Push handle on the right side, and four casters.
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.6, 0.61, 0.62)
	steel.metallic = 0.85
	steel.roughness = 0.35
	var handle := CylinderMesh.new()
	handle.top_radius = 0.016
	handle.bottom_radius = 0.016
	handle.height = depth * 0.8
	_part("Handle", handle, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, PI * 0.5), Vector3(0, top - 0.06, -w - 0.07)), steel)
	for s in [-1.0, 1.0]:
		var post := BoxMesh.new()
		post.size = Vector3(0.02, 0.02, 0.07)
		_part("HandlePost", post, Transform3D(Basis.IDENTITY, Vector3(s * depth * 0.38, top - 0.06, -w - 0.035)), steel)
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.08, 0.08, 0.08)
	rubber.roughness = 0.9
	for cx in [-d + 0.06, d - 0.06]:
		for cz in [-w + 0.06, w - 0.06]:
			var fork := BoxMesh.new()
			fork.size = Vector3(0.05, 0.06, 0.04)
			_part("CasterFork", fork, Transform3D(Basis.IDENTITY, Vector3(cx, base - 0.03, cz)), steel)
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.045
			wheel.bottom_radius = 0.045
			wheel.height = 0.03
			_part("Caster", wheel, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(cx, 0.045, cz)), rubber)

	# Solid to walk into.
	var body_col := StaticBody3D.new()
	body_col.name = "Collision"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(depth + 0.05, height, width + 0.05)
	cs.shape = bs
	cs.position = Vector3(0, height * 0.5, 0)
	body_col.add_child(cs)
	add_child(body_col)


func _part(n: String, m: Mesh, xf: Transform3D, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = m
	mi.transform = xf
	mi.material_override = mat
	add_child(mi)


## A quad a-b-c-d (counter-clockwise seen from outside) with UVs spanning r.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, r: Rect2) -> void:
	var uv := [Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.position.y)]
	var p := [a, b, c, d]
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_uv(uv[i])
		st.add_vertex(p[i])
