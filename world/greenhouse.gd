extends Node3D

## The ruined greenhouse in the east forest (tools/build_scenes.gd
## _build_greenhouse). Gives its model a sharper material than the glTF's
## own: the colour texture sharpened and stored lossless
## (greenhouse_albedo.png), anisotropic filtering so it stays crisp at
## grazing angles, and a slightly deeper normal map.

const MATERIAL := preload("res://world/models/greenhouse/greenhouse_material.tres")


func _ready() -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = MATERIAL
