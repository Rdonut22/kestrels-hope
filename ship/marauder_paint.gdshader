shader_type spatial;
render_mode cull_disabled;

// Worn hull paint for the reworked Kestrel, after the marauder reference:
// hull plates in faded off-white and pale blue, chipped down to bare metal
// along their edges, broad rust swipes and rust streaks running down from the
// seams, and grime underneath. No textures: everything is procedural, in
// metres of object space (so parts at any scale get the same plate size), and
// projected triplanar so it works on any mesh, imported or procedural.

uniform vec3 paint_white : source_color = vec3(0.86, 0.85, 0.81);
uniform vec3 paint_blue : source_color = vec3(0.55, 0.68, 0.79);
uniform vec3 bare_metal : source_color = vec3(0.5, 0.52, 0.55);
uniform vec3 rust_light : source_color = vec3(0.62, 0.38, 0.22);
uniform vec3 rust_dark : source_color = vec3(0.36, 0.2, 0.12);
uniform vec3 grime : source_color = vec3(0.24, 0.23, 0.22);
// Share of plates painted blue / left bare.
uniform float blue_share : hint_range(0.0, 1.0) = 0.38;
uniform float bare_share : hint_range(0.0, 1.0) = 0.04;
// Share of odd replacement plates in the other colour (hand repairs).
uniform float patch_share : hint_range(0.0, 1.0) = 0.08;
// Size (metres) of the big blue / white paint areas.
uniform float zone_size = 9.0;
// Plate size (metres) and how dark the seams between plates are.
uniform vec2 plate_size = vec2(4.2, 2.1);
uniform float seam_dark : hint_range(0.0, 1.0) = 0.18;
// Overall wear: chips, rust and grime.
uniform float chips : hint_range(0.0, 1.0) = 0.45;
uniform float rust : hint_range(0.0, 1.0) = 0.55;
uniform float streaks : hint_range(0.0, 1.0) = 0.6;
uniform float underside_grime : hint_range(0.0, 1.0) = 0.5;
// Seed per part so repeated parts don't wear identically.
uniform float seed = 0.0;

varying vec3 v_pos;
varying vec3 v_nrm;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.13) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
			mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm2(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise2(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	// Object space in metres: undo the node's scale so plate sizes are real.
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v_pos = VERTEX * sc;
	v_nrm = normalize(NORMAL);
}

// Paint, wear and rust for one projection plane. uv in metres; `up` is the
// direction of "down the hull" for streaks in this plane (y in uv).
vec4 layer(vec2 uv, float facing_down, out float rough, out float metal) {
	// Plates in staggered rows.
	vec2 q = uv / plate_size;
	q.x += 0.5 * mod(floor(q.y), 2.0);
	vec2 id = floor(q);
	vec2 f = fract(q);
	// Big irregular areas of blue and white (like the reference), with the
	// odd plate replaced in the other colour.
	float zone = fbm2(uv / zone_size + vec2(seed * 3.7, 0.0));
	bool blue = zone < 0.32 + blue_share * 0.36;
	if (hash2(id + 5.3) < patch_share) {
		blue = !blue;
	}
	vec3 col = blue ? paint_blue : paint_white;
	col *= 0.96 + 0.07 * hash2(id + 3.1);
	bool bare = hash2(id + 7.7) < bare_share;
	// Distance to the plate edge (metres): seams and edge chipping.
	vec2 e = min(f, 1.0 - f) * plate_size;
	float edge = min(e.x, e.y);

	float n_big = fbm2(uv * 0.18);
	float n_mid = fbm2(uv * 0.9);
	float n_fine = noise2(uv * 6.0);

	// Chips: bare metal near plate edges and in scattered patches.
	float chip = smoothstep(0.62, 0.7, n_mid + n_fine * 0.25 + (0.25 - min(edge, 0.25)) * 1.6 - (1.0 - chips) * 0.45);
	if (bare) {
		chip = 1.0;
	}
	col = mix(col, bare_metal * (0.85 + 0.3 * n_fine), chip);

	// Rust: broad swipes (large noise) plus streaks running down from seams.
	float swipe = smoothstep(0.5, 0.78, n_big + n_mid * 0.4 - (1.0 - rust) * 0.4);
	float streak_n = noise2(vec2(uv.x * 3.0, uv.y * 0.25));
	float below_seam = 1.0 - smoothstep(0.0, 1.2, f.y * plate_size.y);
	float streak = smoothstep(0.55, 0.85, streak_n) * below_seam * streaks;
	float r = clamp(max(swipe, streak * 0.85) * (0.6 + 0.6 * n_fine), 0.0, 1.0);
	vec3 rust_col = mix(rust_dark, rust_light, n_mid);
	col = mix(col, rust_col, r);

	// Seams: thin dark lines between plates.
	col *= 1.0 - seam_dark * (1.0 - smoothstep(0.015, 0.05, edge));
	// Grime gathers underneath.
	col = mix(col, grime, facing_down * underside_grime * (0.6 + 0.4 * n_mid));

	rough = mix(mix(0.62, 0.42, chip), 0.92, r);
	metal = chip * (1.0 - r) * 0.55;
	return vec4(col, 1.0);
}

void fragment() {
	vec3 n = normalize(v_nrm);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float down = smoothstep(0.0, -0.8, n.y);
	float r1, r2, r3, m1, m2, m3;
	// Side planes use y as "down the hull" so streaks run downward.
	vec4 cx = layer(vec2(v_pos.z, -v_pos.y), down, r1, m1);
	vec4 cz = layer(vec2(v_pos.x, -v_pos.y), down, r2, m2);
	vec4 cy = layer(v_pos.xz + vec2(31.0, 17.0), down, r3, m3);
	ALBEDO = cx.rgb * w.x + cy.rgb * w.y + cz.rgb * w.z;
	ROUGHNESS = r1 * w.x + r3 * w.y + r2 * w.z;
	METALLIC = m1 * w.x + m3 * w.y + m2 * w.z;
}
