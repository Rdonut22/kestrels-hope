shader_type spatial;
render_mode cull_disabled;

// Worn hull paint for the reworked Kestrel, after the marauder reference:
// big areas of faded off-white and pale blue (no plate grid), chipped down
// to bare metal, broad rust swipes and rust streaks running down the hull,
// and grime underneath. No textures: everything is procedural, in
// metres of object space (so parts at any scale get the same plate size), and
// projected triplanar so it works on any mesh, imported or procedural.

uniform vec3 paint_white : source_color = vec3(0.86, 0.85, 0.81);
uniform vec3 paint_blue : source_color = vec3(0.55, 0.68, 0.79);
uniform vec3 bare_metal : source_color = vec3(0.5, 0.52, 0.55);
uniform vec3 rust_light : source_color = vec3(0.62, 0.38, 0.22);
uniform vec3 rust_dark : source_color = vec3(0.36, 0.2, 0.12);
uniform vec3 grime : source_color = vec3(0.24, 0.23, 0.22);
// How much of the hull is painted blue (vs white).
uniform float blue_share : hint_range(0.0, 1.0) = 0.38;
// Size (metres) of the big blue / white paint areas.
uniform float zone_size = 9.0;
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

// Paint, wear and rust for one projection plane. uv in metres, with +y
// running down the hull so streaks run downward. No plate grid: large paint
// areas and wear only, like the reference.
vec4 layer(vec2 uv, float facing_down, out float rough, out float metal) {
	float n_big = fbm2(uv * 0.18);
	float n_mid = fbm2(uv * 0.9);
	float n_fine = noise2(uv * 6.0);

	// Big irregular areas of white and pale blue.
	float zone = fbm2(uv / zone_size + vec2(seed * 3.7, 0.0));
	float blue = smoothstep(0.02, -0.02, zone - (0.32 + blue_share * 0.36));
	vec3 col = mix(paint_white, paint_blue, blue);
	col *= 0.95 + 0.08 * n_mid;

	// Chips down to bare metal, in scattered patches.
	float chip = smoothstep(0.66, 0.72, n_mid + n_fine * 0.3 - (1.0 - chips) * 0.45);
	col = mix(col, bare_metal * (0.85 + 0.3 * n_fine), chip);

	// Rust: broad swipes, plus long streaks running down the hull.
	float swipe = smoothstep(0.5, 0.78, n_big + n_mid * 0.4 - (1.0 - rust) * 0.4);
	float streak = smoothstep(0.6, 0.85, noise2(vec2(uv.x * 2.5, uv.y * 0.18))) * smoothstep(0.35, 0.65, n_big) * streaks;
	float r = clamp(max(swipe, streak * 0.8) * (0.6 + 0.6 * n_fine), 0.0, 1.0);
	col = mix(col, mix(rust_dark, rust_light, n_mid), r);

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
