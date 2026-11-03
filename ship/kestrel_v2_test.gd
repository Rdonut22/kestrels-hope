@tool
extends Node3D

## Blockout test for the reworked Kestrel exterior (the user's sketches):
## the stripped marauder fuselage around the cockpit, kitchen and lounge on
## the starboard (+X) side, the existing hull to port, two big fan turbines at
## the back and a solar collector panel on posts across the top.
## The current interior (ship/ship_interior.tscn) is placed inside so the
## fit can be checked. Kestrel frame: forward is -Z, floor at y = 0.

## Fuselage size: model units -> metres.
@export var fuselage_scale := 26.0
## Fuselage centre line (x) and where its nose tip sits (z).
@export var fuselage_x := 4.75
@export var nose_z := -14.5
@export var fuselage_floor_y := -0.7
@export var show_interior := true
@export var show_old_exterior := false


func _ready() -> void:
	var parts := MarauderParts.parts()
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.86, 0.87, 0.88)
	hull_mat.roughness = 0.75
	hull_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	if show_interior:
		var ship: Node3D = (load("res://ship/ship_interior.tscn") as PackedScene).instantiate()
		add_child(ship)
		var ext := ship.get_node_or_null("Exterior")
		if ext:
			ext.visible = show_old_exterior

	# The model's nose is +Z; turn it to face -Z (forward) and scale to metres.
	var s := fuselage_scale
	var xf := Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * s),
		Vector3(fuselage_x, fuselage_floor_y, nose_z + 0.687 * s))
	_mesh("Fuselage", parts["fuselage"], xf, hull_mat)
	# Close the slots left where the nacelle mounts were cut away: flat side
	# plates (model frame, so they follow the fuselage's placement).
	for side in [-1.0, 1.0]:
		var plate := BoxMesh.new()
		plate.size = Vector3(0.004, 0.12, 0.76)
		_mesh("SidePlate", plate, xf * Transform3D(Basis.IDENTITY, Vector3(0.092 * side, 0.11, -0.08)), hull_mat)

	# Two big fans at the back (reusing the model's rear nacelles), facing aft:
	# one in the port hull, one under the rear of the fuselage.
	var fs := 34.0
	for f in [["FanPort", "nacelle_rear_left", Vector3(-3.6, 1.7, 10.2)],
			["FanStarboard", "nacelle_rear_right", Vector3(fuselage_x, 0.6, 10.2)]]:
		var m: Mesh = parts[f[1]]
		var c := m.get_aabb().get_center()
		var b := Basis(Vector3.UP, PI).scaled(Vector3.ONE * fs)
		_mesh(f[0], m, Transform3D(b, f[2] - b * c), hull_mat)

	# Top wing on struts (the sketch's "tilted wing"): tapered, thicker at the
	# root next to the fuselage, rising towards starboard and overhanging port.
	var wing := _wing(Vector3(2.2, 5.6, 0.5), 18.0, 0.55, Vector3(-11.5, 3.9, 2.5), 9.0, 0.22, 3.0)
	_mesh("TopWing", wing, Transform3D.IDENTITY, hull_mat)
	for p in [Vector3(-5.0, 0, -3.5), Vector3(0.2, 0, -5.0), Vector3(-5.0, 0, 6.0), Vector3(0.2, 0, 7.0)]:
		# Struts from the hull roof (y = 3.2) up to the wing's underside.
		var t: float = (2.2 - p.x) / (2.2 + 11.5)
		var top: float = lerpf(5.6, 3.9, t) - lerpf(0.55, 0.22, t) * 0.5
		var cm := CylinderMesh.new()
		cm.top_radius = 0.16
		cm.bottom_radius = 0.22
		cm.height = top - 3.2
		_mesh("Strut", cm, Transform3D(Basis.IDENTITY, p + Vector3(0, 3.2 + cm.height * 0.5, 0)), hull_mat)


## A tapered wing slab from a root (centre of its chord, chord length,
## thickness) out to a tip, the tip's leading edge swept back by `sweep`.
func _wing(root: Vector3, root_chord: float, root_t: float, tip: Vector3, tip_chord: float, tip_t: float, sweep: float) -> ArrayMesh:
	var pts := []
	for e in [[root, root_chord, root_t, 0.0], [tip, tip_chord, tip_t, sweep]]:
		var c: Vector3 = e[0]
		var hc: float = e[1] * 0.5
		var ht: float = e[2] * 0.5
		var sw: float = e[3]
		# Leading edge thinner than the trailing box: a simple wedge section.
		pts.append([c + Vector3(0, ht * 0.4, -hc + sw), c + Vector3(0, ht, -hc * 0.4 + sw),
			c + Vector3(0, ht * 0.8, hc + sw), c + Vector3(0, -ht * 0.8, hc + sw),
			c + Vector3(0, -ht, -hc * 0.4 + sw), c + Vector3(0, -ht * 0.4, -hc + sw)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r: Array = pts[0]
	var t: Array = pts[1]
	var n := r.size()
	for i in n:
		var j := (i + 1) % n
		for q in [r[i], t[i], t[j], r[i], t[j], r[j]]:
			st.add_vertex(q)
	for ring in [r, t]:
		for i in range(1, n - 1):
			for q in [ring[0], ring[i], ring[i + 1]]:
				st.add_vertex(q)
	st.generate_normals()
	return st.commit()


func _mesh(n: String, m: Mesh, xf: Transform3D, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = m
	mi.transform = xf
	mi.material_override = mat
	add_child(mi)
	return mi
