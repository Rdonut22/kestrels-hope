class_name GanaEyes
extends Node3D

## Gana's glowing eyes: two identical pale almonds laid over the painted
## eyes of the generated body (characters/gana/body/gana_body.glb), riding
## the head bone. (The painted ones came out different sizes.)
##
## Positions and facing are in the body's rest skeleton space (found by
## sampling the texture's white eye texels on the mesh).

const EYES := [
	[Vector3(-0.0668, 1.5444, 0.119), Vector3(-0.658, 0.11, 0.745)],
	[Vector3(0.0165, 1.5371, 0.1316), Vector3(0.408, 0.05, 0.911)],
]
const HEAD := "mixamorig_Head"

@export var glow := Color(0.97, 0.95, 0.84)
@export_range(0.0, 4.0) var energy := 1.6
@export var size := Vector2(0.028, 0.015)
## How far the almonds stand off the face (metres).
@export var lift := 0.0025


func attach(skel: Skeleton3D) -> void:
	var head := skel.find_bone(HEAD)
	if head < 0:
		return
	var att := BoneAttachment3D.new()
	att.name = "Eyes"
	att.bone_name = HEAD
	skel.add_child(att)
	var to_head := skel.get_bone_global_rest(head).affine_inverse()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = glow
	m.emission_enabled = true
	m.emission = glow
	m.emission_energy_multiplier = energy
	var mb := ProcMesh.Builder.new()
	for e in EYES:
		var p: Vector3 = e[0]
		var n: Vector3 = (e[1] as Vector3).normalized()
		# Almond in the plane facing n, long axis level.
		var x := Vector3.UP.cross(n).normalized()
		var y := n.cross(x).normalized()
		var c := p + n * lift
		var pts := []
		for k in 8:
			var a := TAU * k / 8.0
			var w := size.x * 0.5 * cos(a)
			var h := size.y * 0.5 * sin(a) * (1.0 - 0.35 * absf(cos(a)))
			pts.append(c + x * w + y * h)
		for k in 8:
			mb.tri("Eye", c, pts[k], pts[(k + 1) % 8], n)
	var mi := MeshInstance3D.new()
	mi.name = "Almonds"
	mi.mesh = mb.commit({"Eye": m})
	mi.transform = to_head
	att.add_child(mi)
