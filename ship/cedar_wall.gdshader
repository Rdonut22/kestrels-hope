shader_type spatial;
render_mode cull_disabled;

// Japanese cedar plank wall cladding (kitchen and quarters), after the
// user's japanese_cedar_planks set: vertical planks about 11 cm wide,
// warm orange-brown with some planks darker, fine vertical grain, dark
// seams between planks. Projected in ship space (the rooms are CSG, no
// UVs): walls get the planks running up them; ceilings (faces pointing
// down) get a soft ivory, floors are covered by the wood floor.
// Roughness from the set's roughness map.

uniform sampler2D rough_map : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float tile = 1.6;               // metres per texture repeat
uniform float planks_per_tile = 14.5;
uniform vec3 cedar : source_color = vec3(0.72, 0.4, 0.16);
uniform vec3 cedar_dark : source_color = vec3(0.45, 0.22, 0.08);
uniform vec3 seam_color : source_color = vec3(0.12, 0.06, 0.03);
uniform vec3 ceiling : source_color = vec3(0.77, 0.73, 0.65);
uniform float darken : hint_range(0.0, 1.0) = 0.15;

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
	v_pos = VERTEX;
	v_nrm = NORMAL;
}

void fragment() {
	vec3 n = normalize(v_nrm);
	if (abs(n.y) > 0.6) {
		// Ceiling (and any floor that shows): soft ivory, faintly mottled.
		ALBEDO = ceiling * (0.95 + 0.08 * vnoise(v_pos.xz * 1.5));
		ROUGHNESS = 0.8;
		METALLIC = 0.0;
	} else {
		// Along the wall (whichever axis it runs on), and up it.
		float u = abs(n.x) > abs(n.z) ? v_pos.z : v_pos.x;
		float y = v_pos.y;
		float pu = u / tile * planks_per_tile;
		float id = floor(pu);
		float f = fract(pu);
		// Each plank its own tone and grain offset.
		float tone = h1(id);
		vec3 col = mix(cedar, cedar_dark, smoothstep(0.55, 1.0, tone) * 0.9);
		col *= 0.9 + 0.2 * h1(id + 17.0);
		// Grain: long streaks up the plank, cathedral-ish waves.
		float wave = sin((f * 6.0 + vnoise(vec2(id, y * 0.6)) * 4.0) * 3.14159 + y * 2.0);
		float grain = vnoise(vec2(f * 18.0 + id * 3.1, y * 1.2)) * 0.6 + vnoise(vec2(f * 60.0 + id, y * 0.4)) * 0.4;
		col *= 0.86 + 0.18 * grain + 0.05 * wave;
		// Darker toward a plank's edges, and the seam itself.
		float edge = min(f, 1.0 - f);
		col *= mix(0.82, 1.0, smoothstep(0.0, 0.12, edge));
		float seam = 1.0 - smoothstep(0.012, 0.03, edge);
		col = mix(col, seam_color, seam);
		col *= 1.0 - darken;
		ALBEDO = col;
		float r = texture(rough_map, vec2(u, y) / tile).r;
		ROUGHNESS = mix(0.45, 0.85, r);
		METALLIC = 0.0;
		SPECULAR = 0.4;
		// The seams read as grooves.
		float sx = (edge < 0.03) ? (f < 0.5 ? 1.0 : -1.0) * 0.6 * seam : 0.0;
		vec3 t = abs(n.x) > abs(n.z) ? vec3(0, 0, 1) : vec3(1, 0, 0);
		vec3 pn = normalize(n + t * sx);
		NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(pn, 0.0)).xyz);
	}
}
