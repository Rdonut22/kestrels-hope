class_name CockpitDetail
extends RefCounted

## The cockpit's built-up detail layer, added over the shell and fit-out
## (ship/nose_cockpit.gd, ship/cockpit_fitout.gd) without changing the
## room: the same tunnel, windows, seats, yoke and pedestal.
##
## - Walls: individually made plates between the ribs: bevelled, bolted,
##   some overlapping their neighbours, off-white or light grey paint on a
##   dark charcoal backing that shows in the seams. A few are access
##   hatches (hinges, handle, red caution stripe), vent grilles or service
##   panels; one bay is left open on exposed machinery.
## - Structure: gusset brackets where the ribs meet the walls, conduits
##   on stand-offs along the ceiling, cable bundles to junction boxes.
## - Floor: recessed grates, a cable channel with an open run, bolted
##   maintenance panels with lift handles.
## - Light: neutral ceiling fill so the materials read; the amber
##   practicals stay as accents.
##
## Wear sits where hands and boots go: bare metal on chosen plate edges,
## handles and the pedestal's top edge, a little rust low down near the
## floor, faded red markings on a few panels. Everything is built from a
## handful of shared materials into a few batched meshes per group.

const N := NoseCockpit.N
## Wall bands around the arch, as ring sample indices (fractional; the
## rings are sampled at the same angles, index 0 = the right side at the
## tunnel's centre height, counting up over the roof to the left).
const BANDS := {
	"R_low": Vector2(-5.0, -1.25), "R_mid": Vector2(-1.45, 2.75), "R_up": Vector2(2.75, 7.0),
	"ceil": Vector2(7.0, 13.0),
	"L_up": Vector2(13.4, 16.9), "L_mid": Vector2(17.25, 21.45), "L_low": Vector2(21.25, 25.0),
}
## How far each band's plates stand off the shell (mid plates overlap the
## low ones' edges).
const OFFSET := {"R_low": 0.012, "R_mid": 0.03, "R_up": 0.012, "ceil": 0.012, "L_up": 0.012, "L_mid": 0.03, "L_low": 0.012}
const PLATE_T := 0.022     # plate thickness
const BEVEL := 0.012
const RIB_CLEAR := 0.006   # plates meet across where the ribs were (a hairline seam)

var f: CockpitFitout
var rings: Array
var root: Node3D
var m := {}
var rng := RandomNumberGenerator.new()
var bolts: Array[Transform3D] = []


func build(fitout: CockpitFitout, the_rings: Array) -> void:
	f = fitout
	rings = the_rings
	rng.seed = 26041
	root = Node3D.new()
	root.name = "CockpitDetail"
	f.root.add_child(root)
	_materials()
	_restyle()
	_walls()
	_structure()
	_floor()
	_lighting()
	_bolts()


# ---------- materials ----------

func _materials() -> void:
	var panel_tex: Texture2D = load("res://ship/textures/interior/cockpit_panel_color.png")
	var paint := func(tint: Color) -> StandardMaterial3D:
		var p := StandardMaterial3D.new()
		p.albedo_texture = panel_tex
		p.albedo_color = tint
		p.uv1_triplanar = true
		p.uv1_world_triplanar = true
		p.uv1_scale = Vector3.ONE * 0.38
		p.roughness = 0.62
		p.metallic = 0.12
		return p
	# The user's panel-cut metal, lifted to the concept's light paints.
	m["paint_light"] = paint.call(Color(1.7, 1.72, 1.72))
	m["paint_off"] = paint.call(Color(1.95, 1.88, 1.72))
	var std := func(c: Color, metal: float, rough: float) -> StandardMaterial3D:
		var s := StandardMaterial3D.new()
		s.albedo_color = c
		s.metallic = metal
		s.roughness = rough
		return s
	m["charcoal"] = std.call(Color(0.1, 0.105, 0.11), 0.55, 0.55)
	m["charcoal_light"] = std.call(Color(0.19, 0.195, 0.2), 0.5, 0.5)
	m["edge"] = std.call(Color(0.6, 0.59, 0.57), 0.85, 0.3)        # paint worn back to metal
	m["rust"] = std.call(Color(0.36, 0.2, 0.11), 0.2, 0.85)
	m["red"] = std.call(Color(0.52, 0.17, 0.13), 0.05, 0.75)        # faded red paint
	m["bolt"] = std.call(Color(0.38, 0.37, 0.35), 0.85, 0.35)
	m["rubber"] = std.call(Color(0.05, 0.05, 0.05), 0.0, 0.8)
	m["cable_red"] = std.call(Color(0.35, 0.08, 0.06), 0.0, 0.6)
	m["cable_grey"] = std.call(Color(0.32, 0.32, 0.3), 0.0, 0.6)
	m["deck"] = std.call(Color(0.27, 0.27, 0.26), 0.75, 0.42)        # floor plate, a different finish
	m["pit"] = std.call(Color(0.015, 0.015, 0.015), 0.0, 0.95)
	m["bronze"] = f.mats["bronze"]
	m["frame"] = f.mats["steel"]
	var lamp := func(c: Color, e: float) -> StandardMaterial3D:
		var s := std.call(c * 0.4, 0.0, 0.5) as StandardMaterial3D
		s.emission_enabled = true
		s.emission = c
		s.emission_energy_multiplier = 0.0 if f.crashed else e
		return s
	m["btn_amber"] = lamp.call(Color(1.0, 0.6, 0.22), 1.2)
	m["btn_green"] = lamp.call(Color(0.35, 0.9, 0.55), 0.9)
	m["btn_red"] = lamp.call(Color(0.95, 0.25, 0.15), 0.9)
	m["btn_white"] = std.call(Color(0.75, 0.74, 0.7), 0.1, 0.5)


## The shell behind the plates becomes their dark backing (it shows in
## the seams).
func _restyle() -> void:
	var backing := (m["paint_light"] as StandardMaterial3D).duplicate() as StandardMaterial3D
	backing.albedo_color = Color(0.36, 0.37, 0.38)
	backing.metallic = 0.4
	m["backing"] = backing
	var liner := f.ext.get_node_or_null("CockpitLiner") as MeshInstance3D
	if liner:
		liner.set_surface_override_material(0, backing)


func _group(name: String) -> Node3D:
	var n := Node3D.new()
	n.name = name
	root.add_child(n)
	return n


func _commit(parent: Node, name: String, mb: ProcMesh.Builder) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mb.commit(m)
	parent.add_child(mi)
	return mi


# ---------- shell sampling ----------

func _ring(r: int) -> PackedVector3Array:
	return rings[r]


## A ring's point at fractional sample index u.
func _pt(r: int, u: float) -> Vector3:
	var ring := _ring(r)
	var k := floori(u)
	var t := u - k
	return ring[posmod(k, N)].lerp(ring[posmod(k + 1, N)], t)


## A point on the shell between rings ra and rb (v 0..1 along the tunnel),
## standing `off` in from it.
func _shell(ra: int, rb: int, u: float, v: float, off: float) -> Vector3:
	var p := _pt(ra, u).lerp(_pt(rb, u), v)
	return p + CockpitFitout.inward(p) * off


## A frame on the shell: x round the arch (u increasing), y along the
## tunnel toward the windshield's side of the bay, z out of the wall.
func _frame(ra: int, rb: int, u: float, v: float, off: float) -> Transform3D:
	var o := _shell(ra, rb, u, v, off)
	var n := CockpitFitout.inward(o)
	var tu := (_shell(ra, rb, u + 0.05, v, off) - _shell(ra, rb, u - 0.05, v, off))
	tu = (tu - n * tu.dot(n)).normalized()
	var ty := n.cross(tu).normalized()
	return Transform3D(Basis(tu, ty, n), o)


# ---------- walls ----------

## One plate: a bevelled slab on the shell over [u0, u1] x [v0, v1].
## Its edges take `edge_mat` (bare metal where the paint's chipped,
## rust, or the paint itself). Returns its corner frames for decoration.
func _plate(mb: ProcMesh.Builder, ra: int, rb: int, u0: float, u1: float, v0: float, v1: float, off: float, face: String, edge_mat: String) -> void:
	var zlen := absf(_pt(ra, (u0 + u1) / 2).z - _pt(rb, (u0 + u1) / 2).z)
	var seg := maxf(_pt(ra, u0).distance_to(_pt(ra, u0 + 1.0)), 0.01)
	var du := BEVEL / seg
	var dv := BEVEL / maxf(zlen, 0.01)
	# Samples across u: the ends and every whole index between.
	var ts := [0.0]
	for k in range(ceili(u0 + 0.001), floori(u1 - 0.001) + 1):
		ts.append((k - u0) / (u1 - u0))
	ts.append(1.0)
	var base := func(t: float, v: float) -> Vector3:
		return _shell(ra, rb, lerpf(u0, u1, t), lerpf(v0, v1, v), off)
	var top := func(t: float, v: float) -> Vector3:
		return _shell(ra, rb, lerpf(u0 + du, u1 - du, t), lerpf(v0 + dv, v1 - dv, v), off + PLATE_T)
	for i in ts.size() - 1:
		var ta: float = ts[i]
		var tb: float = ts[i + 1]
		var a: Vector3 = top.call(ta, 0.0)
		var b: Vector3 = top.call(tb, 0.0)
		var c: Vector3 = top.call(tb, 1.0)
		var d: Vector3 = top.call(ta, 1.0)
		var n := CockpitFitout.inward((a + c) / 2.0)
		mb.quad(face, a, b, c, d, n)
		# Bevelled long edges.
		for v in [0.0, 1.0]:
			var ba: Vector3 = base.call(ta, v)
			var bb: Vector3 = base.call(tb, v)
			var out := n + Vector3(0, 0, (_pt(rb, u0).z - _pt(ra, u0).z) * (v - 0.5) * 4.0)
			mb.quad(edge_mat, ba, bb, top.call(tb, v), top.call(ta, v), out)
	# Bevelled ends.
	for t in [0.0, 1.0]:
		var tu: Vector3 = (base.call(0.999, 0.5) - base.call(0.001, 0.5)).normalized()
		var out: Vector3 = CockpitFitout.inward(base.call(t, 0.5)) + tu * (t - 0.5) * 4.0
		mb.quad(edge_mat, base.call(t, 0.0), base.call(t, 1.0), top.call(t, 1.0), top.call(t, 0.0), out)
	# Bolts at the corners (and mid-edges on long plates).
	var us := [0.12, 0.88]
	if (u1 - u0) * seg > 0.9:
		us.append(0.5)
	for t in us:
		for v in [0.1, 0.9]:
			var fr := _frame(ra, rb, lerpf(u0, u1, t), lerpf(v0, v1, v), off + PLATE_T)
			bolts.append(fr)


func _bays() -> Array:
	# Ring pairs between the ribs: the passage mouth to the first station,
	# then station to station up to the last one before the windshield.
	var out := []
	for r in range(0, rings.size() - 2):
		out.append([r, r + 1])
	return out


## Where a band's low end must start so it clears the floor.
func _clear_floor(ra: int, rb: int, u: float, step: float) -> float:
	var guard := 0
	while guard < 40 and (_pt(ra, u).y < 0.14 or _pt(rb, u).y < 0.14):
		u += step
		guard += 1
	return u


func _walls() -> void:
	var g := _group("WallPlates")
	var mb := ProcMesh.Builder.new()
	var deco := ProcMesh.Builder.new()
	var bays := _bays()
	for bi in bays.size():
		var ra: int = bays[bi][0]
		var rb: int = bays[bi][1]
		var za := _pt(ra, 0.0).z
		var zb := _pt(rb, 0.0).z
		var bay_len := absf(zb - za)
		# Plates stop short of the ribs (there's no rib at the passage
		# mouth's side, the portal frame is there instead).
		var v0 := RIB_CLEAR / bay_len
		var v1 := 1.0 - RIB_CLEAR / bay_len
		for band in BANDS:
			# The pilot's side is the user's wall section (cockpit_fitout.gd).
			# Both sides are the user's wall section now (cockpit_fitout.gd):
			# only the ceiling keeps its plates.
			if band != "ceil":
				continue
			var r: Vector2 = BANDS[band]
			var u0 := r.x
			var u1 := r.y
			if band == "R_low":
				u0 = _clear_floor(ra, rb, u0, 0.2)
			elif band == "L_low":
				u1 = _clear_floor(ra, rb, u1, -0.2)
			if u1 - u0 < 0.6:
				continue
			var mid_z := (za + zb) / 2.0
			# The roof window takes the ceiling over its bays.
			if band == "ceil" and mid_z < CockpitFitout.ROOF_Z.y + 0.05:
				continue
			# One bay is open on its machinery (see _machinery).
			if band == "L_mid" and bi == 2:
				_machinery(ra, rb, u0, u1, v0, v1)
				continue
			var face := "paint_off" if rng.randf() < 0.45 else "paint_light"
			var low: bool = (band as String).ends_with("low")
			var roll := rng.randf()
			var edge := face
			if low and roll < 0.45:
				edge = "rust"
			elif roll < 0.55:
				edge = "edge"
			# Long ceiling and mid bands split into two plates, offset so
			# their seams don't line up bay to bay.
			var splits := [u0, u1]
			if (band == "ceil" or band.ends_with("mid")) and u1 - u0 > 3.5:
				var cut := lerpf(u0, u1, 0.42 + 0.16 * float(bi % 2))
				splits = [u0, cut - 0.01, cut + 0.01, u1]
			for s in range(0, splits.size(), 2):
				_plate(mb, ra, rb, splits[s], splits[s + 1], v0, v1, OFFSET[band], face, edge)
			_plate_feature(deco, band, bi, ra, rb, u0, u1, v0, v1)
	_commit(g, "Plates", mb)
	_commit(g, "PlateFeatures", deco)


## What a particular plate carries: hatches, vents, service panels, red
## markings, an extinguisher. Chosen per bay so the two sides differ.
func _plate_feature(mb: ProcMesh.Builder, band: String, bi: int, ra: int, rb: int, u0: float, u1: float, v0: float, v1: float) -> void:
	var off: float = OFFSET[band] + PLATE_T
	var uc := (u0 + u1) / 2.0
	var vc := (v0 + v1) / 2.0
	var key := "%s%d" % [band, bi]
	match key:
		"R_mid1", "L_mid3":
			_hatch(mb, _frame(ra, rb, uc, vc, off), Vector2(0.5, 0.36))
		"R_up2", "L_up1":
			_vent(mb, _frame(ra, rb, uc, vc, off), Vector2(0.42, 0.22))
		"R_mid3":
			_service_panel(mb, _frame(ra, rb, uc, vc, off))
		"R_mid0", "L_mid0":
			# A faded red band across the entrance plates.
			var fr := _frame(ra, rb, lerpf(u0, u1, 0.78), vc, off)
			ProcMesh.box(mb, "red", Vector3(0, 0, 0.001), Vector3(0.05, 0.36, 0.002), fr)
		"R_low2", "L_low1":
			# Stencilled marker blocks low on the wall.
			var fr := _frame(ra, rb, uc, lerpf(v0, v1, 0.25), off)
			for k in 3:
				ProcMesh.box(mb, "red", Vector3(-0.08 + k * 0.08, 0, 0.001), Vector3(0.05, 0.03, 0.002), fr)
		"L_low0":
			_extinguisher(_frame(ra, rb, uc, vc, off))


## An access hatch: a raised frame, a recessed door, two hinges, a pull
## handle worn bright, and a red caution stripe.
func _hatch(mb: ProcMesh.Builder, fr: Transform3D, s: Vector2) -> void:
	var t := 0.012
	for e in [[Vector3(0, s.y / 2, t / 2), Vector3(s.x + 0.04, 0.025, t)], [Vector3(0, -s.y / 2, t / 2), Vector3(s.x + 0.04, 0.025, t)],
			[Vector3(-s.x / 2, 0, t / 2), Vector3(0.025, s.y, t)], [Vector3(s.x / 2, 0, t / 2), Vector3(0.025, s.y, t)]]:
		ProcMesh.box(mb, "charcoal_light", e[0], e[1], fr)
	ProcMesh.box(mb, "paint_light", Vector3(0, 0, -0.004), Vector3(s.x - 0.02, s.y - 0.02, 0.006), fr)
	for y in [-s.y * 0.3, s.y * 0.3]:
		ProcMesh.box(mb, "charcoal", Vector3(-s.x / 2 - 0.018, y, 0.012), Vector3(0.022, 0.07, 0.022), fr)
		ProcMesh.box(mb, "edge", Vector3(-s.x / 2 - 0.018, y, 0.024), Vector3(0.01, 0.075, 0.008), fr)
	ProcMesh.box(mb, "charcoal", Vector3(s.x / 2 - 0.06, 0, 0.012), Vector3(0.025, 0.12, 0.018), fr)
	ProcMesh.box(mb, "edge", Vector3(s.x / 2 - 0.06, 0, 0.028), Vector3(0.018, 0.1, 0.014), fr)
	ProcMesh.box(mb, "red", Vector3(0, -s.y / 2 + 0.05, 0.0), Vector3(s.x - 0.06, 0.025, 0.004), fr)


## A vent grille: a dark recess with slats across it in a thin frame.
func _vent(mb: ProcMesh.Builder, fr: Transform3D, s: Vector2) -> void:
	ProcMesh.box(mb, "pit", Vector3(0, 0, 0.001), Vector3(s.x, s.y, 0.002), fr)
	var n := 7
	for k in n:
		var y := -s.y / 2 + (k + 0.5) * s.y / n
		ProcMesh.box(mb, "charcoal_light", Vector3(0, y, 0.008), Vector3(s.x - 0.02, 0.012, 0.012), fr * Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3.ZERO))
	for e in [[Vector3(0, s.y / 2, 0.008), Vector3(s.x + 0.03, 0.018, 0.016)], [Vector3(0, -s.y / 2, 0.008), Vector3(s.x + 0.03, 0.018, 0.016)],
			[Vector3(-s.x / 2, 0, 0.008), Vector3(0.018, s.y, 0.016)], [Vector3(s.x / 2, 0, 0.008), Vector3(0.018, s.y, 0.016)]]:
		ProcMesh.box(mb, "charcoal", e[0], e[1], fr)


## A breaker panel on a mount: a box with a hinged cover, a row of
## breaker toggles and a status lamp.
func _service_panel(mb: ProcMesh.Builder, fr: Transform3D) -> void:
	ProcMesh.box(mb, "charcoal", Vector3(0, 0, 0.035), Vector3(0.34, 0.24, 0.07), fr)
	ProcMesh.box(mb, "charcoal_light", Vector3(0, 0, 0.072), Vector3(0.3, 0.2, 0.006), fr)
	for k in 6:
		var x := -0.11 + k * 0.044
		ProcMesh.box(mb, "pit", Vector3(x, 0.02, 0.076), Vector3(0.022, 0.05, 0.004), fr)
		ProcMesh.box(mb, "btn_white" if k % 3 else "edge", Vector3(x, 0.03 if k % 2 else 0.01, 0.084), Vector3(0.012, 0.022, 0.014), fr)
	ProcMesh.box(mb, "btn_green", Vector3(0.11, -0.07, 0.078), Vector3(0.018, 0.018, 0.008), fr)
	ProcMesh.box(mb, "red", Vector3(-0.06, -0.07, 0.076), Vector3(0.12, 0.016, 0.003), fr)
	# Mounting brackets to the plate.
	for x in [-0.19, 0.19]:
		ProcMesh.box(mb, "charcoal_light", Vector3(x, 0, 0.012), Vector3(0.04, 0.2, 0.024), fr)


## A fire extinguisher in a strap bracket, low by the entrance.
func _extinguisher(fr: Transform3D) -> void:
	var node := _group("Extinguisher")
	var up := fr.basis.y if absf(fr.basis.y.y) > absf(fr.basis.x.y) else fr.basis.x
	up = Vector3.UP
	var base := fr.origin + fr.basis.z * 0.08
	var mb := ProcMesh.Builder.new()
	ProcMesh.box(mb, "charcoal", Vector3(0, 0.02, -0.06), Vector3(0.13, 0.32, 0.02), fr)
	_commit(node, "Bracket", mb)
	f._cyl(node, "Bottle", base - up * 0.12, base + up * 0.14, 0.055, m["red"], 16)
	f._cyl(node, "Valve", base + up * 0.14, base + up * 0.19, 0.022, m["edge"], 10)
	f._cyl(node, "Strap", base - up * 0.02, base + up * 0.01, 0.058, m["charcoal"], 16)


## The open bay: a pump unit with cooling fins, a manifold, pipes to the
## ceiling and floor, a junction box with its cables, all on brackets
## against the dark backing.
func _machinery(ra: int, rb: int, u0: float, u1: float, v0: float, v1: float) -> void:
	var node := _group("ExposedMachinery")
	var mb := ProcMesh.Builder.new()
	var uc := (u0 + u1) / 2.0
	var vc := (v0 + v1) / 2.0
	var fr := _frame(ra, rb, uc, vc, 0.0)
	# Back plate and stand-off rails.
	ProcMesh.box(mb, "charcoal", Vector3(0, 0, 0.01), Vector3(0.62, 0.42, 0.02), fr)
	for y in [-0.16, 0.16]:
		ProcMesh.box(mb, "charcoal_light", Vector3(0, y, 0.03), Vector3(0.64, 0.035, 0.03), fr)
	# Pump body with fins.
	ProcMesh.box(mb, "charcoal_light", Vector3(-0.1, 0, 0.09), Vector3(0.26, 0.26, 0.1), fr)
	for k in 7:
		ProcMesh.box(mb, "charcoal", Vector3(-0.1, -0.11 + k * 0.037, 0.145), Vector3(0.24, 0.012, 0.012), fr)
	ProcMesh.box(mb, "edge", Vector3(-0.1, 0.14, 0.09), Vector3(0.27, 0.012, 0.1), fr)
	# Junction box.
	ProcMesh.box(mb, "paint_light", Vector3(0.18, 0.05, 0.07), Vector3(0.14, 0.18, 0.08), fr)
	ProcMesh.box(mb, "red", Vector3(0.18, 0.12, 0.111), Vector3(0.1, 0.018, 0.002), fr)
	ProcMesh.box(mb, "btn_amber", Vector3(0.22, -0.01, 0.112), Vector3(0.016, 0.016, 0.006), fr)
	_commit(node, "Unit", mb)
	# Pipes: up from the pump and down from the junction box.
	var p0 := fr * Vector3(-0.17, 0.13, 0.09)
	var p1 := fr * Vector3(0.18, -0.04, 0.07)
	f._cyl(node, "PipeUp", p0, p0 + Vector3(0, 0.55, 0), 0.025, m["bronze"])
	f._cyl(node, "PipeUpCollar", p0 + Vector3(0, 0.05, 0), p0 + Vector3(0, 0.09, 0), 0.032, m["charcoal"])
	f._cyl(node, "Conduit", p1, Vector3(p1.x, 0.06, p1.z), 0.02, m["charcoal_light"])
	for k in 3:
		var a := fr * Vector3(0.14 + k * 0.025, -0.04, 0.05)
		f._cyl(node, "Cable%d" % k, a, Vector3(a.x, 0.04, a.z) + fr.basis.z * 0.03, 0.009, [m["cable_red"], m["rubber"], m["cable_grey"]][k], 6)


# ---------- structure ----------

func _structure() -> void:
	var g := _group("Structure")
	var mb := ProcMesh.Builder.new()
	# (The gussets that tied the ribs to the walls went with the ribs.)
	for r in []:
		for side in []:   # (both sides are the user's wall section)
			var u := 0.6 if side > 0 else 19.4
			var p := _pt(r, u)
			var n := CockpitFitout.inward(p)
			var fr := Transform3D(Basis(Vector3(0, 0, 1).cross(n).normalized(), Vector3(0, 0, 1), n), p + n * 0.1)
			for dz in [-0.11, 0.11]:
				ProcMesh.box(mb, "charcoal_light", Vector3(0, dz, -0.04), Vector3(0.22, 0.012, 0.09), fr)
			ProcMesh.box(mb, "charcoal", Vector3(0, 0, 0.0), Vector3(0.12, 0.2, 0.02), fr)
			bolts.append(fr * Transform3D(Basis(), Vector3(0.0, 0.0, 0.01)))
	_commit(g, "Gussets", mb)
	# Two conduits along the ceiling on stand-off clamps, over the first
	# bays and on into the dash.
	var z0 := _pt(0, 10.0).z + 0.05
	var z1 := CockpitFitout.ROOF_Z.y + 0.05
	for k in 2:
		var u := 8.3 + k * 3.4
		var a := _pt(1, u)
		var y := a.y - 0.15
		var x := a.x + (0.04 if k == 0 else -0.04)
		f._cyl(g, "Conduit%d" % k, Vector3(x, y, z0), Vector3(x, y, z1), 0.028 - k * 0.006, m["charcoal_light"] if k == 0 else m["bronze"])
		for r in range(1, 3):
			var z: float = _pt(r, u).z
			var c := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.08, 0.17, 0.04)
			c.mesh = bm
			c.material_override = m["charcoal"]
			c.position = Vector3(x, y + 0.07, z + 0.1)
			g.add_child(c)
	# A cable bundle from under the dash, down beside the pedestal into
	# the floor channel.
	var dash := CockpitFitout.DASH_FRONT_Z
	var cols := [m["rubber"], m["cable_red"], m["cable_grey"], m["rubber"]]
	for k in 4:
		var x := 4.37 + k * 0.03
		f._cyl(g, "DashCable%d" % k, Vector3(x, 0.42, dash + 0.02), Vector3(x, 0.04, dash + 0.1 + k * 0.015), 0.011, cols[k], 6)


# ---------- floor ----------

func _floor() -> void:
	var g := _group("Floor")
	var mb := ProcMesh.Builder.new()
	# A recessed grate down the middle (between the passage and the
	# pedestal) and one under each seat's feet: a dark pit, a frame, bars.
	for gr in [[Vector3(4.0, 0, -11.0), Vector2(0.5, 1.5), "z"], [Vector3(CockpitFitout.PILOT_X, 0, -12.43), Vector2(0.56, 0.42), "x"],
			[Vector3(CockpitFitout.COPILOT_X, 0, -12.43), Vector2(0.56, 0.42), "x"]]:
		var c: Vector3 = gr[0]
		var s: Vector2 = gr[1]
		ProcMesh.box(mb, "pit", c + Vector3(0, 0.002, 0), Vector3(s.x, 0.004, s.y))
		for e in [[Vector3(0, 0.008, s.y / 2), Vector3(s.x + 0.06, 0.016, 0.03)], [Vector3(0, 0.008, -s.y / 2), Vector3(s.x + 0.06, 0.016, 0.03)],
				[Vector3(s.x / 2, 0.008, 0), Vector3(0.03, 0.016, s.y)], [Vector3(-s.x / 2, 0.008, 0), Vector3(0.03, 0.016, s.y)]]:
			ProcMesh.box(mb, "charcoal_light", c + e[0], e[1])
		var along_z: bool = gr[2] == "z"
		var span := s.x if along_z else s.y
		var n := int(span / 0.035)
		for k in n:
			var o := -span / 2 + (k + 0.5) * span / n
			var pos := c + (Vector3(o, 0.008, 0) if along_z else Vector3(0, 0.008, o))
			var size := Vector3(0.012, 0.012, s.y) if along_z else Vector3(s.x, 0.012, 0.012)
			ProcMesh.box(mb, "charcoal", pos, size)
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			bolts.append(Transform3D(Basis(Vector3.RIGHT, -PI / 2), c + Vector3(corner.x * (s.x / 2 + 0.015), 0.017, corner.y * (s.y / 2 + 0.015))))
	# The cable channel along the co-pilot's side: lips, a bolted cover,
	# and one open length showing the cables.
	var cx := 5.05
	var z0 := -10.15
	var z1 := -12.1
	ProcMesh.box(mb, "pit", Vector3(cx, 0.002, (z0 + z1) / 2), Vector3(0.12, 0.004, z0 - z1))
	for sx in [-1.0, 1.0]:
		ProcMesh.box(mb, "charcoal_light", Vector3(cx + sx * 0.07, 0.008, (z0 + z1) / 2), Vector3(0.02, 0.016, z0 - z1))
	for seg in [[z0, -10.85], [-11.3, z1]]:
		var a: float = seg[0]
		var b: float = seg[1]
		ProcMesh.box(mb, "deck", Vector3(cx, 0.01, (a + b) / 2), Vector3(0.13, 0.008, a - b - 0.01))
		bolts.append(Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(cx, 0.016, a - 0.04)))
		bolts.append(Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(cx, 0.016, b + 0.04)))
	for k in 3:
		var x := cx - 0.03 + k * 0.03
		f._cyl(g, "ChannelCable%d" % k, Vector3(x, 0.012, -10.8), Vector3(x, 0.012, -11.35), 0.011, [m["rubber"], m["cable_red"], m["cable_grey"]][k], 6)
	# Bolted maintenance panels with recessed lift handles, a different
	# finish from the deck around them.
	for mp in [Vector3(3.15, 0, -10.6), Vector3(3.15, 0, -11.25)]:
		ProcMesh.box(mb, "deck", mp + Vector3(0, 0.004, 0), Vector3(0.5, 0.008, 0.5))
		ProcMesh.box(mb, "pit", mp + Vector3(0.14, 0.009, 0), Vector3(0.1, 0.002, 0.035))
		ProcMesh.box(mb, "edge", mp + Vector3(0.14, 0.011, 0), Vector3(0.08, 0.004, 0.012))
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			bolts.append(Transform3D(Basis(Vector3.RIGHT, -PI / 2), mp + Vector3(corner.x * 0.22, 0.011, corner.y * 0.22)))
	_commit(g, "Hardware", mb)


# ---------- light ----------

func _lighting() -> void:
	var g := _group("Lighting")
	if f.crashed:
		return
	# Neutral fill from the ceiling so the paint and metal read true.
	for z in [-10.75, -12.05]:
		var l := OmniLight3D.new()
		l.name = "Fill%d" % int(-z * 10)
		l.light_color = Color(0.95, 0.97, 1.0)
		l.light_energy = 1.25
		l.omni_range = 4.2
		l.omni_attenuation = 0.9
		l.position = Vector3(4.0, CockpitFitout.ceiling_at(rings, 4.0, z) - 0.35, z)
		g.add_child(l)
	# The amber practicals become accents.
	var lights := f.root.get_node_or_null("Lights")
	if lights:
		for c in lights.get_children():
			if c is OmniLight3D:
				(c as OmniLight3D).light_energy *= 0.5


# ---------- bolts ----------

## Every bolt head as one multimesh: a short hex cylinder facing out of
## its surface (each transform's +Z).
func _bolts() -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.009
	cm.height = 0.008
	cm.radial_segments = 6
	cm.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cm
	mm.instance_count = bolts.size()
	var turn := Basis(Vector3.RIGHT, PI / 2)   # the cylinder's +Y onto +Z
	for i in bolts.size():
		var t: Transform3D = bolts[i]
		mm.set_instance_transform(i, Transform3D(t.basis * turn, t.origin + t.basis.z * 0.004))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Bolts"
	mmi.multimesh = mm
	mmi.material_override = m["bolt"]
	root.add_child(mmi)
