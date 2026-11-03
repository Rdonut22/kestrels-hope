shader_type spatial;
render_mode cull_disabled;

// Worn hull paint for the reworked Kestrel, after the marauder reference:
// big areas of faded off-white and pale blue (no plate grid), chipped down
// to bare metal, broad rust swipes and rust streaks running down the hull,
// and grime underneath. No textures: everything is procedural, in
// metres of object space (so parts at any scale get the same plate size), and
// projected triplanar so it works on any mesh, imported or procedural.

uniform vec3 paint_white : source_color = vec3(0.74, 0.73, 0.69);
uniform vec3 paint_blue : source_color = vec3(0.4, 0.56, 0.72);
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
uniform float rust : hint_range(0.0, 1.0) = 0.45;
uniform float streaks : hint_range(0.0, 1.0) = 0.6;
uniform float underside_grime : hint_range(0.0, 1.0) = 0.5;
// Surface relief (bump): dents, hammered metal, scratches, chipped paint edges.
uniform float bump_strength : hint_range(0.0, 3.0) = 1.0;
uniform float scratches : hint_range(0.0, 1.0) = 0.5;
// Hull plating detail (Venator roughness tiles 1008 / 1063 / 1064 in R/G/B): relief,
// plate-to-plate tone and roughness. Repeats every plating_size metres,
// mirrored so the tile's edges meet seamlessly.
uniform sampler2D plating : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float plating_size = 5.0;
uniform float plating_tone : hint_range(0.0, 1.0) = 0.5;
uniform float plating_relief : hint_range(0.0, 0.05) = 0.012;
// Grime from the Venator colour tiles 1038 / 1026 (desaturated, R/G): stains, dirty and
// darker replacement plates, laid over the paint.
uniform sampler2D grime_map : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float grime_size = 6.5;
uniform float grime_strength : hint_range(0.0, 1.0) = 0.6;
uniform vec3 grime_tint : source_color = vec3(0.42, 0.38, 0.32);
// Base colour: a Venator colour tile (ship/textures/hull_color_*.png),
// repeating every color_size metres, mirrored at the edges. When set it
// replaces the white / blue paint.
uniform sampler2D hull_color : source_color, filter_linear_mipmap, repeat_enable, hint_default_black;
uniform bool use_hull_color = false;
uniform float color_size = 8.0;
// How much the inside faces (seen from within) turn to bare dark metal.
uniform float inside_metal : hint_range(0.0, 1.0) = 0.85;
// Wear from the Razor Crest roughness tile 1027 (ship/textures/hull_wear.png):
// dark = worn smooth bare-ish metal, bright = dull, dusty paint. Drives
// roughness, a little shine and tone, and fine scratch relief.
uniform sampler2D wear_map : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float wear_size = 3.5;
uniform float wear_strength : hint_range(0.0, 1.0) = 0.7;
// Seed per part so repeated parts don't wear identically.
uniform float seed = 0.0;

varying vec3 v_pos;
varying vec3 v_nrm;

// Each part uses one of the packed tiles (by its seed) so neighbours differ.
float pick(vec4 t, float k) {
	float c = mod(floor(k), 3.0);
	return c < 0.5 ? t.r : (c < 1.5 ? t.g : t.b);
}

float plate(vec2 uv) {
	vec2 q = uv / plating_size + seed * 0.37;
	q = 1.0 - abs(1.0 - mod(q, 2.0));
	return pick(texture(plating, q), seed);
}

float grime_at(vec2 uv) {
	vec2 q = uv / grime_size + vec2(0.29, 0.61) + seed * 0.53;
	q = 1.0 - abs(1.0 - mod(q, 2.0));
	return mod(seed, 2.0) < 1.0 ? texture(grime_map, q).r : texture(grime_map, q).g;
}

float wear_at(vec2 uv) {
	vec2 q = uv / wear_size + vec2(0.71, 0.17) + seed * 0.29;
	q = 1.0 - abs(1.0 - mod(q, 2.0));
	return texture(wear_map, q).r;
}

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
vec4 layer(vec2 uv, float facing_down, out float rough, out float metal, out float height) {
	float n_big = fbm2(uv * 0.18);
	float n_mid = fbm2(uv * 0.9);
	float n_fine = noise2(uv * 6.0);

	// Big irregular areas of white and pale blue.
	float zone = fbm2(uv / zone_size + vec2(seed * 3.7, 0.0));
	float blue = smoothstep(0.02, -0.02, zone - (0.32 + blue_share * 0.36));
	vec3 col = mix(paint_white, paint_blue, blue);
	col *= 0.95 + 0.08 * n_mid;
	if (use_hull_color) {
		vec2 cq = uv / color_size + vec2(0.13, 0.71) + seed * 0.41;
		cq = 1.0 - abs(1.0 - mod(cq, 2.0));
		col = texture(hull_color, cq).rgb;
	}
	// Plating: each plate a slightly different tone of the same paint.
	float pl = plate(uv);
	col *= mix(1.0, 0.78 + 0.32 * pl, plating_tone);
	// Venator grime: darker areas of the map become dirt and stained plates.
	float gr = grime_at(uv);
	float dirt = smoothstep(0.62, 0.15, gr) * grime_strength;
	col = mix(col, col * grime_tint * 1.6, dirt);

	// Chips down to bare metal, in scattered patches.
	float chip = smoothstep(0.66, 0.72, n_mid + n_fine * 0.3 - (1.0 - chips) * 0.45);
	col = mix(col, bare_metal * (0.85 + 0.3 * n_fine), chip);

	// Scratches: fine bright lines through the paint, in loose clusters.
	vec2 su = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv;
	float sn = noise2(vec2(su.x * 18.0, su.y * 0.7));
	float scratch = (1.0 - smoothstep(0.0, 0.025, abs(sn - 0.5)))
			* smoothstep(0.5, 0.7, fbm2(uv * 0.5 + 4.0)) * scratches;
	col = mix(col, bare_metal * 1.15, scratch * 0.8);

	// Rust: broad swipes, plus long streaks running down the hull.
	float swipe = smoothstep(0.5, 0.78, n_big + n_mid * 0.4 - (1.0 - rust) * 0.4);
	float streak = smoothstep(0.6, 0.85, noise2(vec2(uv.x * 2.5, uv.y * 0.18))) * smoothstep(0.35, 0.65, n_big) * streaks;
	float r = clamp(max(swipe, streak * 0.8) * (0.6 + 0.6 * n_fine), 0.0, 1.0);
	col = mix(col, mix(rust_dark, rust_light, n_mid), r);

	// Grime gathers underneath.
	col = mix(col, grime, facing_down * underside_grime * (0.6 + 0.4 * n_mid));

	// Relief (metres): soft dents, hammered texture, paint standing proud of
	// chips and scratches, crusty rust.
	float dents = (fbm2(uv * 0.7 + 9.0) - 0.5) * 0.02;
	float hammer = (noise2(uv * 14.0) - 0.5) * 0.0015;
	height = dents + hammer - chip * 0.0012 - scratch * 0.0008 + r * (noise2(uv * 25.0) - 0.3) * 0.002
			+ (pl - 0.5) * plating_relief;

	rough = mix(mix(0.62, 0.42, chip), 0.92, r);
	rough = clamp(rough + (0.5 - pl) * 0.2, 0.05, 1.0);
	// Razor Crest wear: worn smooth patches shine, dusty ones go dull and
	// a touch lighter.
	float wr = wear_at(uv);
	rough = mix(rough, mix(0.28, 0.95, wr), wear_strength);
	col *= mix(1.0, 0.88 + 0.22 * wr, wear_strength);
	height += (wr - 0.5) * 0.004 * wear_strength;
	rough = mix(rough, 0.3, scratch * 0.7);
	metal = max(chip, scratch) * (1.0 - r) * 0.7;
	metal = max(metal, (1.0 - wr) * 0.45 * wear_strength * (1.0 - r));
	return vec4(col, 1.0);
}

void fragment() {
	// Two-sided: light back faces as if they faced the camera.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	// The inside of the hull (seen from within the cockpit): darker,
	// unpainted metal.
	float inside = FRONT_FACING ? 0.0 : 1.0;
	vec3 n = normalize(v_nrm);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float down = smoothstep(0.0, -0.8, n.y);
	float r1, r2, r3, m1, m2, m3, h1, h2, h3;
	// Side planes use y as "down the hull" so streaks run downward.
	vec4 cx = layer(vec2(v_pos.z, -v_pos.y), down, r1, m1, h1);
	vec4 cz = layer(vec2(v_pos.x, -v_pos.y), down, r2, m2, h2);
	vec4 cy = layer(v_pos.xz + vec2(31.0, 17.0), down, r3, m3, h3);
	ALBEDO = cx.rgb * w.x + cy.rgb * w.y + cz.rgb * w.z;
	ALBEDO = mix(ALBEDO, vec3(0.2, 0.21, 0.22) * (0.8 + 0.4 * dot(ALBEDO, vec3(0.33))), inside * inside_metal);
	ROUGHNESS = r1 * w.x + r3 * w.y + r2 * w.z;
	METALLIC = m1 * w.x + m3 * w.y + m2 * w.z;
	// Bump from the relief (surface-gradient method, view space).
	float h = (h1 * w.x + h3 * w.y + h2 * w.z) * bump_strength;
	vec3 nn = normalize(NORMAL);
	vec3 dpx = dFdx(VERTEX);
	vec3 dpy = dFdy(VERTEX);
	vec3 rr1 = cross(dpy, nn);
	vec3 rr2 = cross(nn, dpx);
	float det = dot(dpx, rr1);
	vec3 grad = sign(det) * (dFdx(h) * rr1 + dFdy(h) * rr2);
	NORMAL = normalize(abs(det) * nn - grad);
}
