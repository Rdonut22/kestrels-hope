shader_type spatial;

// Coated pine boards (the user's coated_pine set: its normal and roughness
// maps; the colour matched to its honey-amber photo): boards ~14 cm wide
// running along the counter, per-board tone, long grain, the odd dark knot,
// a satin coat. Projected in ship space so boxed counters need no UVs; set
// along_z when the boards run along the ship's z axis.

uniform sampler2D nor_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_map : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool along_z = false;
uniform float tile = 1.2;            // metres per texture repeat
uniform float board_w = 0.14;
uniform vec3 pine : source_color = vec3(0.56, 0.34, 0.15);
uniform vec3 pine_dark : source_color = vec3(0.34, 0.19, 0.07);
uniform vec3 knot : source_color = vec3(0.2, 0.1, 0.04);

varying vec3 v_pos;
varying vec3 v_nrm;

float h1(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	v_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(v_nrm);
	vec3 an = abs(n);
	// Along the boards (L) and across them (W), on whichever face.
	float L = along_z ? v_pos.z : v_pos.x;
	float W;
	vec3 T;
	vec3 B;
	if (an.y > 0.5) {
		W = along_z ? v_pos.x : v_pos.z;
		T = along_z ? vec3(0, 0, 1) : vec3(1, 0, 0);
		B = along_z ? vec3(1, 0, 0) : vec3(0, 0, 1);
	} else {
		W = v_pos.y;
		T = along_z ? vec3(0, 0, 1) : vec3(1, 0, 0);
		B = vec3(0, 1, 0);
	}
	float bw = W / board_w;
	float id = floor(bw);
	float f = fract(bw);
	float tone = h1(id);
	vec3 col = mix(pine, pine_dark, smoothstep(0.35, 1.0, tone) * 0.8);
	// Long grain with gentle waves.
	float wav = vnoise(vec2(L * 1.5 + id * 7.0, f * 3.0)) * 2.0;
	float grain = vnoise(vec2(L * 0.8 + id * 3.0, f * 22.0 + wav));
	col *= 0.82 + 0.3 * grain;
	col *= 0.93 + 0.1 * vnoise(vec2(L * 6.0, f * 70.0 + id));
	// Knots, now and then.
	vec2 kc = vec2(floor(L / 0.45) + 0.5, id);
	float kh = h2(kc);
	if (kh > 0.72) {
		vec2 kp = vec2((L / 0.45 - kc.x) * 0.45 / 0.05, (f - (0.3 + 0.4 * h1(kh))) * board_w / 0.03);
		float kd = length(kp);
		col = mix(col, knot, (1.0 - smoothstep(0.6, 1.2, kd)) * 0.9);
		col = mix(col, col * 0.75, (1.0 - smoothstep(1.2, 2.2, kd)) * 0.5);
	}
	// Board joints.
	float edge = min(f, 1.0 - f);
	col *= mix(0.6, 1.0, smoothstep(0.0, 0.04, edge));
	ALBEDO = col;
	vec2 uv = vec2(L, W) / tile;
	vec3 tn = texture(nor_map, uv).xyz * 2.0 - 1.0;
	float r = texture(rough_map, uv).r;
	ROUGHNESS = mix(0.25, 0.6, r);
	METALLIC = 0.0;
	SPECULAR = 0.5;
	vec3 pn = normalize(T * tn.x + B * tn.y + n * max(tn.z, 0.2));
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
}
