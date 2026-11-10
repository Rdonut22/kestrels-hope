class_name GanaEyes
extends Node3D

## Gana's glowing eyes: two identical pale ovals laid over the painted
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

## Face reshape (applied to the body mesh by tools/import_gana_meshy.gd and
## to the eye positions here): the generated face is long with a pointed
## chin, the sheet's is shorter below the eyes with a wider jaw.
const FACE_X := -0.025
## The reshape starts just under the eyes (so the eyes stay on the face).
const EYE_Y := 1.522
const NECK_Y := 1.405
## Lower face height kept (1 = unchanged) and extra jaw width at the chin.
const LOWER_FACE := 0.76
const JAW_WIDEN := 0.2
## Squares the chin: the jaw is pushed out this much on each side (metres).
const CHIN_SQUARE := 0.011


## Where a rest-pose point of the generated head ends up after the reshape.
static func reshape_face(p: Vector3) -> Vector3:
	if p.y >= EYE_Y or p.y <= NECK_Y - 0.01:
		return p
	# Fade out at the neck and towards the back of the head.
	var w := smoothstep(NECK_Y, NECK_Y + 0.04, p.y) * smoothstep(-0.06, 0.02, p.z)
	if w <= 0.0:
		return p
	var q := p
	q.y = EYE_Y - (EYE_Y - p.y) * LOWER_FACE
	var jaw := smoothstep(EYE_Y, EYE_Y - 0.08, p.y)
	var lx := p.x - FACE_X
	q.x = FACE_X + lx * (1.0 + JAW_WIDEN * jaw) + signf(lx) * CHIN_SQUARE * jaw * smoothstep(0.0, 0.012, absf(lx))
	return p.lerp(q, w)

@export var glow := Color(0.97, 0.95, 0.84)
@export_range(0.0, 4.0) var energy := 1.6
@export var size := Vector2(0.032, 0.018)
## Tilt of each eye (degrees, outer corner up), like the sheet.
@export var tilt := 0.0
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
		var p: Vector3 = reshape_face(e[0])
		var n: Vector3 = (e[1] as Vector3).normalized()
		# Almond in the plane facing n, long axis level.
		var x := Vector3.UP.cross(n).normalized()
		var y := n.cross(x).normalized()
		# Outer corner up: the eye on +X (his left) turns one way, -X the other.
		var roll := deg_to_rad(tilt) * (-1.0 if p.x > -0.025 else 1.0)
		var rb := Basis(n, roll)
		x = rb * x
		y = rb * y
		var c := p + n * lift
		var pts := []
		# A soft oval, like the sheet.
		for k in 12:
			var a := TAU * k / 12.0
			pts.append(c + x * (size.x * 0.5 * cos(a)) + y * (size.y * 0.5 * sin(a)))
		for k in 12:
			mb.tri("Eye", c, pts[k], pts[(k + 1) % 12], n)
	var mi := MeshInstance3D.new()
	mi.name = "Almonds"
	mi.mesh = mb.commit({"Eye": m})
	mi.transform = to_head
	att.add_child(mi)
