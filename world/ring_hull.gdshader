shader_type spatial;
render_mode fog_disabled, cull_disabled;

// Large hull plates for the Great Ring: tiling pitted rusted iron
// (world/textures/rusted_iron) under a coat of orange paint that has
// chipped and flaked away where the iron rusted. UV = metres across the
// plate; UV2 = two random numbers per plate setting how much paint is left,
// from nearly fully painted to almost bare corroded iron. Edges get grime,
// extra rust and a row of bolts; COLOR.rg holds the plate size in tens of
// metres so bolts and textures keep a fixed scale.

uniform sampler2D iron_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D iron_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D iron_roughness : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D iron_metallic : hint_default_black, filter_linear_mipmap, repeat_enable;
// Metres one repeat of the iron texture covers.
uniform float tile = 7.0;
uniform vec3 paint : source_color = vec3(0.7, 0.32, 0.1);

uniform vec3 world_tint : source_color = vec3(1.0);
uniform vec3 haze : source_color = vec3(0.52, 0.7, 0.66);
uniform float haze_amount : hint_range(0.0, 1.0) = 0.25;
uniform float haze_near = 40.0;
uniform float haze_far = 260.0;
uniform vec3 rust : source_color = vec3(0.36, 0.16, 0.07);
uniform vec3 grime : source_color = vec3(0.14, 0.12, 0.1);
uniform float rust_override : hint_range(-1.0, 1.0) = -1.0;  // >= 0 forces the rust amount (testing)
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
	vec2 size = COLOR.rg * 10.0;            // plate size in metres
	vec2 m = UV * size;                     // metres across the plate
	// Two samples of the iron at different scales, offsets and angles,
	// blended by soft noise, so the texture's repeats don't show as a grid.
	vec2 t1 = m / tile + r * 7.0;
	vec2 t2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * m / (tile * 1.37) + r.yx * 5.0 + 0.5;
	float k = smoothstep(0.35, 0.65, fbm(vec3(m * 0.18, r.x * 9.0)));
	vec3 iron = mix(texture(iron_albedo, t1).rgb, texture(iron_albedo, t2).rgb, k);
	vec3 nmap = mix(texture(iron_normal, t1).rgb, texture(iron_normal, t2).rgb, k);
	float rough = mix(texture(iron_roughness, t1).r, texture(iron_roughness, t2).r, k);
	float bare = mix(texture(iron_metallic, t1).r, texture(iron_metallic, t2).r, k);  // 1 = bare iron, 0 = rust

	// Edges (metres from the plate's border): grime and a row of bolts.
	float ex = min(m.x, size.x - m.x);
	float ey = min(m.y, size.y - m.y);
	float edge = 1.0 - smoothstep(0.0, 0.35, min(ex, ey));
	float bx = length(vec2(fract(m.x / 0.6) - 0.5, (ey - 0.32) / 0.6));
	float by = length(vec2(fract(m.y / 0.6) - 0.5, (ex - 0.32) / 0.6));
	float bolt = 1.0 - smoothstep(0.08, 0.13, min(bx, by));

	// How rusty this plate is, and so how much paint is left.
	float rustiness = rust_override >= 0.0 ? rust_override : smoothstep(clean_share, 1.0, fract(r.x * 5.3 + r.y * 2.1));
	vec3 p = v_obj;
	float wear = fbm(p * 0.25 + r.x * 40.0) * 0.5 + (1.0 - bare) * 0.5;
	wear += edge * 0.3 + bolt * 0.4;
	float cut = 0.72 - rustiness * 0.5;
	float paint_gone = smoothstep(cut, cut + 0.04, wear);
	// Paint: faded in patches, a dark rim where it has chipped.
	// The paint keeps the metal's grain and stains showing through.
	float grain = dot(iron, vec3(0.33));
	vec3 pc = paint * (0.8 + 0.3 * fbm(p * 0.12 + 5.0)) * (0.7 + 0.6 * grain);
	pc = mix(pc, pc * vec3(0.8, 0.7, 0.6), smoothstep(cut - 0.25, cut, wear) * 0.6);
	float rim = smoothstep(cut - 0.05, cut, wear) * (1.0 - paint_gone);
	pc *= 1.0 - rim * 0.45;
	vec3 col = mix(pc, iron, paint_gone);
	rough = mix(0.6, rough, paint_gone);
	nmap = mix(mix(vec3(0.5, 0.5, 1.0), nmap, 0.35), nmap, paint_gone);
	col *= 1.0 - edge * 0.3;
	col = mix(col, col * 0.4, bolt);

	// Rust streaks running down from the rusty spots.
	vec3 w = v_wpos;
	vec3 n = normalize(v_wnrm);
	float streak = noise(vec3(w.x * 1.7, w.y * 0.07, w.z * 1.7)) * 0.6 + noise(vec3(w.x * 5.0, w.y * 0.2, w.z * 5.0)) * 0.4;
	float drip = smoothstep(0.66 - rustiness * 0.2, 0.88, streak) * (1.0 - abs(n.y)) * (1.0 - paint_gone * 0.5);
	col = mix(col, mix(rust, grime, 0.4), drip * (0.15 + rustiness * 0.5));

	float dist = distance(v_wpos, CAMERA_POSITION_WORLD);
	float h = haze_amount * smoothstep(haze_near, haze_far, dist);
	ALBEDO = mix(col * world_tint, haze * world_tint, h);
	NORMAL_MAP = nmap;
	ROUGHNESS = clamp(rough, 0.3, 1.0);
	METALLIC = bare * paint_gone * metal_strength;
	SPECULAR = 0.4;
}
