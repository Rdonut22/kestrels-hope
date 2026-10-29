class_name GrassTuft

## Low-poly grass tufts for world/grass.gdshader: a clump of tapered,
## gently curved blades of different heights, angles and shades. Each blade
## is 5 triangles. About 1 m tall at scale 1 (the field scales them).

const SHADES := [
	Color(0.45, 0.72, 0.2),    # fresh green
	Color(0.28, 0.55, 0.17),   # deep forest green
	Color(0.66, 0.82, 0.26),   # yellow-green highlight
	Color(0.5, 0.65, 0.3),     # muted
	Color(0.38, 0.66, 0.18),
]


## `blades` blades in a clump `spread` metres across; `seed` picks the shape.
static func build(blades := 14, spread := 0.36, seed := 1, short := false) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in blades:
		var ang := rng.randf() * TAU
		var r := sqrt(rng.randf()) * spread * 0.5
		var base := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		# Taller in the middle of the clump, shorter round the edge.
		var height := rng.randf_range(0.45, 1.0) * lerpf(1.0, 0.7, r / (spread * 0.5 + 0.001))
		if short:
			height *= 0.55
		var width := rng.randf_range(0.045, 0.075)
		# Leans outwards from the clump centre, curving over towards the tip.
		var out := Vector3(cos(ang), 0.0, sin(ang)).rotated(Vector3.UP, rng.randf_range(-0.6, 0.6))
		var lean := rng.randf_range(0.18, 0.55) * height
		var facing := out.rotated(Vector3.UP, PI / 2.0 + rng.randf_range(-0.5, 0.5))
		var shade: Color = SHADES[rng.randi() % SHADES.size()]
		shade = shade.lightened(rng.randf_range(-0.08, 0.08))
		var rnd := rng.randf()
		var rows := [0.0, 0.38, 0.72, 1.0]
		var pts := []
		for k in rows.size():
			var f: float = rows[k]
			var centre := base + Vector3(0.0, f * height, 0.0) + out * lean * f * f
			var w := width * pow(1.0 - f, 0.8) if k < rows.size() - 1 else 0.0
			pts.append([centre - facing * w, centre + facing * w, f * height])
		var normal := out.cross(facing).normalized()
		if normal.y < 0.0:
			normal = -normal
		for k in rows.size() - 1:
			var a: Array = pts[k]
			var c: Array = pts[k + 1]
			if k < rows.size() - 2:
				_tri(st, a[0], a[1], c[1], a[2], a[2], c[2], shade, rnd, normal)
				_tri(st, a[0], c[1], c[0], a[2], c[2], c[2], shade, rnd, normal)
			else:
				_tri(st, a[0], a[1], c[0], a[2], a[2], c[2], shade, rnd, normal)
	return st.commit()


static func _tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, h0: float, h1: float, h2: float,
		col: Color, rnd: float, n: Vector3) -> void:
	for v in [[p0, h0], [p1, h1], [p2, h2]]:
		st.set_color(col)
		st.set_normal(n)
		st.set_uv(Vector2(rnd, v[1]))
		st.add_vertex(v[0])
