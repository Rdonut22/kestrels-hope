@tool
extends Node3D

## Wooden plank floors (ship/wood_floor.gdshader) laid over the shared ship
## floor in the quarters and the kitchen. Purely visual (a thin quad just
## above the floor), so movement and collisions are untouched.
## Room footprints from tools/build_scenes.gd (ship space, x0, x1, z0, z1).

const ROOMS := {
	"Quarters": [-2.6, 1.8, -9.6, -5.9],
	"Kitchen": [2.4, 5.6, -6.8, -3.4],
}


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://ship/wood_floor.gdshader")
	var t := "res://ship/textures/interior/"
	mat.set_shader_parameter("albedo_map", load(t + "wood_floor_color.png"))
	mat.set_shader_parameter("normal_map", load(t + "wood_floor_nor.png"))
	mat.set_shader_parameter("rough_map", load(t + "wood_floor_rough.png"))
	for n in ROOMS:
		var r: Array = ROOMS[n]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		var y := 0.023
		var a := Vector3(r[0], y, r[2])
		var b := Vector3(r[1], y, r[2])
		var c := Vector3(r[1], y, r[3])
		var d := Vector3(r[0], y, r[3])
		for v in [a, b, c, a, c, d]:
			st.add_vertex(v)
		var mi := MeshInstance3D.new()
		mi.name = n + "WoodFloor"
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
