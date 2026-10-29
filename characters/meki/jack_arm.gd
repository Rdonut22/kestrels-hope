@tool
extends Node3D

## Meki's telescoping jack arm: a coil-wrapped neck, three nested square
## sleeves with grip plates and a chunky chamfered plug with an orange LED
## (the shaft from the jack socket reference). Built along +Z; set
## `extension` 0..1 to slide it out to `reach`.

@export var reach := 0.55:
	set(v):
		reach = v
		_rebuild()
@export var width := 0.04:
	set(v):
		width = v
		_rebuild()
@export var cap_size := 0.062:
	set(v):
		cap_size = v
		_rebuild()
## 0 = tucked away (hidden), 1 = fully out.
@export_range(0.0, 1.0) var extension := 0.0:
	set(v):
		extension = v
		_place()

const SLEEVES := 3
const NECK := 0.03

var _mats := {}
var _sleeves: Array[Node3D] = []
var _cap: Node3D
var _sleeve_len := 0.0
var _cap_len := 0.0


func _ready() -> void:
	_rebuild()


func _make_materials() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.55, 0.44, 0.31)
	metal.metallic = 0.45
	metal.roughness = 0.5
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.17, 0.15, 0.13)
	dark.metallic = 0.5
	dark.roughness = 0.5
	var led := StandardMaterial3D.new()
	led.albedo_color = Color(1.0, 0.6, 0.3)
	led.emission_enabled = true
	led.emission = Color(1.0, 0.55, 0.25)
	led.emission_energy_multiplier = 3.0
	_mats = {"ShaftMetal": metal, "ShaftDark": dark, "LedOrange": led}


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_sleeves.clear()
	_make_materials()
	var w := width * 0.5
	var cap := cap_size * 0.5
	_cap_len = cap_size * 0.9
	# Sleeves overlap by 15% of their length when fully out.
	_sleeve_len = (reach - NECK - _cap_len) / (SLEEVES * 0.85 + 0.15)
	# Neck with coil rings, fixed at the arm's root.
	var nb := ProcMesh.Builder.new()
	ProcMesh.loft(nb, "ShaftDark", [Vector2(0.0, NECK), Vector2(w * 0.7, NECK), Vector2(w * 0.7, 0.0), Vector2(0.0, 0.0)], ProcMesh.circle(12))
	for i in 3:
		var zc := (0.006 + i * 0.009)
		ProcMesh.loft(nb, "ShaftDark", [Vector2(w * 0.95, zc + 0.003), Vector2(w * 0.95, zc - 0.003), Vector2(w * 0.7, zc - 0.003), Vector2(w * 0.7, zc + 0.003), Vector2(w * 0.95, zc + 0.003)], ProcMesh.circle(12))
	_add_mesh(self, "Neck", nb)
	# Nested sleeves, each a little narrower than the one before.
	var sq := ProcMesh.chamfered_square(0.6)
	for s in SLEEVES:
		var sw := w * (1.0 - 0.12 * s)
		var b := ProcMesh.Builder.new()
		var L := _sleeve_len
		ProcMesh.loft(b, "ShaftMetal", [Vector2(0.0, L), Vector2(sw * 0.92, L), Vector2(sw, L - 0.004), Vector2(sw, 0.0), Vector2(0.0, 0.0)], sq)
		# Grip plates and a dark band near the front of each sleeve.
		for row in 3:
			var zc := L * (0.25 + row * 0.25)
			for side in [-1.0, 1.0]:
				for col in 2:
					var off := (col - 0.5) * sw * 0.8 + (0.15 * sw if row % 2 else -0.15 * sw)
					ProcMesh.box(b, "ShaftMetal", Vector3(side * (sw + 0.0012), off, zc), Vector3(0.0024, sw * 0.5, L * 0.12))
					ProcMesh.box(b, "ShaftMetal", Vector3(off, side * (sw + 0.0012), zc), Vector3(sw * 0.5, 0.0024, L * 0.12))
		ProcMesh.box(b, "ShaftDark", Vector3(0, 0, L - 0.012), Vector3(sw * 2.04, sw * 2.04, 0.004))
		var node := Node3D.new()
		node.name = "Sleeve%d" % s
		add_child(node)
		_add_mesh(node, "Mesh", b)
		_sleeves.append(node)
	# The plug: wider chamfered block, dark seam, LED on the end face.
	var cb := ProcMesh.Builder.new()
	var sq2 := ProcMesh.chamfered_square(0.72)
	ProcMesh.loft(cb, "ShaftMetal", [Vector2(0.0, _cap_len), Vector2(cap * 0.93, _cap_len), Vector2(cap, _cap_len - 0.006),
		Vector2(cap, 0.008), Vector2(cap * 0.8, 0.0), Vector2(0.0, 0.0)], sq2)
	ProcMesh.loft(cb, "ShaftDark", [Vector2(cap * 1.012, _cap_len - 0.012), Vector2(cap * 1.012, _cap_len - 0.017)], sq2)
	_cap = Node3D.new()
	_cap.name = "Plug"
	add_child(_cap)
	_add_mesh(_cap, "Mesh", cb)
	var led := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.005
	lm.height = 0.007
	lm.material = _mats["LedOrange"]
	led.mesh = lm
	led.name = "Led"
	led.position = Vector3(cap * 0.55, -cap * 0.55, _cap_len + 0.0005)
	_cap.add_child(led)
	_place()


func _add_mesh(parent: Node, name: String, b: ProcMesh.Builder) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = b.commit(_mats)
	parent.add_child(mi)


## Length from the root to the plug's tip at the current extension.
func tip_distance() -> float:
	return _cap.position.z + _cap_len if _cap else 0.0


func _place() -> void:
	if not _cap:
		return
	visible = extension > 0.001
	# Each sleeve slides out of the one behind it; all start nested at the neck.
	var step := _sleeve_len * 0.85 * extension
	for s in SLEEVES:
		_sleeves[s].position.z = NECK - 0.01 + step * s
	_cap.position.z = _sleeves[SLEEVES - 1].position.z + lerpf(0.02, _sleeve_len, extension)
	scale = Vector3.ONE * clampf(extension * 4.0, 0.3, 1.0)
