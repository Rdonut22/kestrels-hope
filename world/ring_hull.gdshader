shader_type spatial;
render_mode fog_disabled, cull_disabled;

// Large hull plates for the Great Ring. Each plate shows one whole block of
// the Sci-Fi Kit 08 orange panel atlas stretched across it (UV 0..1 over the
// plate), so the painted panels read big and clean. UV2 = two random numbers
// per plate: which block, flips, repaints and how rusty it is, from nearly
// clean to badly corroded. Darker, rust-prone edges with a row of bolts.

uniform sampler2D panel_albedo : source_color, filter_linear_mipmap;
uniform sampler2D panel_roughness : hint_default_white, filter_linear_mipmap;
uniform sampler2D panel_metallic : hint_default_black, filter_linear_mipmap;
uniform sampler2D panel_ao : hint_default_white, filter_linear_mipmap;

uniform vec3 world_tint : source_color = vec3(1.0);
uniform vec3 haze : source_color = vec3(0.52, 0.7, 0.66);
uniform float haze_amount : hint_range(0.0, 1.0) = 0.25;
uniform float haze_near = 40.0;
uniform float haze_far = 260.0;
uniform vec3 paint_tint : source_color = vec3(1.0, 0.9, 0.82);
uniform vec3 rust : source_color = vec3(0.36, 0.16, 0.07);
uniform vec3 grime : source_color = vec3(0.14, 0.12, 0.1);
uniform float rust_override : hint_range(-1.0, 1.0) = -1.0;  // >= 0 forces a rust amount (testing)
uniform float clean_share : hint_range(0.0, 1.0) = 0.35;
// No reflections in this world, so real metalness just goes dark.
uniform float metal_strength : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_obj;
varying vec3 v_wpos;
varying vec3 v_wnrm;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.07 + 11.3;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_obj = VERTEX;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 r = UV2;
	vec2 uv = clamp(UV, 0.0, 1.0);
	if (r.x > 0.5) uv.x = 1.0 - uv.x;
	// The atlas's big block of painted panels.
	vec2 a = vec2(0.0, 0.0) + uv * vec2(0.815, 0.635);
	vec3 col = texture(panel_albedo, a).rgb * paint_tint;
	float rough = texture(panel_roughness, a).r;
	float metal = texture(panel_metallic, a).r;
	float ao = texture(panel_ao, a).r;

	// Edges: grime and a row of bolts.
	float ex = min(UV.x, 1.0 - UV.x);
	float ey = min(UV.y, 1.0 - UV.y);
	float edge = 1.0 - smoothstep(0.0, 0.035, min(ex, ey));
	col *= 1.0 - edge * 0.35;
	float bx = length(vec2((fract(UV.x * 14.0) - 0.5) / 14.0, ey - 0.022));
	float by = length(vec2((fract(UV.y * 11.0) - 0.5) / 11.0, ex - 0.017));
	float bolt = 1.0 - smoothstep(0.006, 0.009, min(bx, by));
	col = mix(col, col * 0.45, bolt);

	// Rust: per plate, from nearly clean to badly corroded, worst at edges.
	float rustiness = rust_override >= 0.0 ? rust_override : smoothstep(clean_share, 1.0, fract(r.x * 5.3 + r.y * 2.1));
	vec3 p = v_obj;
	float blotch = fbm(p * 0.35 + r.x * 40.0) * 0.7 + noise(p * 3.0) * 0.3;
	blotch += edge * 0.25 + bolt * 0.3;
	float rusted = smoothstep(0.8 - rustiness * 0.45, 0.85 - rustiness * 0.45, blotch);
	vec3 rust_col = mix(rust, rust * 1.6 + vec3(0.05, 0.02, 0.0), noise(p * 5.0));
	col = mix(col, rust_col, rusted * 0.9);
	rough = mix(rough, 0.95, rusted);
	metal *= 1.0 - rusted;
	// Rust streaks running down from the rusty spots.
	vec3 w = v_wpos;
	vec3 n = normalize(v_wnrm);
	float streak = noise(vec3(w.x * 1.7, w.y * 0.07, w.z * 1.7)) * 0.6 + noise(vec3(w.x * 5.0, w.y * 0.2, w.z * 5.0)) * 0.4;
	float drip = smoothstep(0.66 - rustiness * 0.2, 0.88, streak) * (1.0 - abs(n.y));
	col = mix(col, mix(rust, grime, 0.5), drip * (0.2 + rustiness * 0.55));

	float dist = distance(v_wpos, CAMERA_POSITION_WORLD);
	float h = haze_amount * smoothstep(haze_near, haze_far, dist);
	ALBEDO = mix(col * mix(1.0, ao, 0.5) * world_tint, haze * world_tint, h);
	ROUGHNESS = clamp(rough, 0.3, 1.0);
	METALLIC = metal * metal_strength;
	SPECULAR = 0.4;
}
