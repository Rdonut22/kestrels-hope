shader_type spatial;

// Paneled, grimy metal in world space, so it works on CSG with no UVs.
// Used for the ship's walls, floors and ceilings.

uniform vec3 base_color : source_color = vec3(0.45, 0.5, 0.55);
// Walls only: a darker band along the bottom (0 turns it off).
uniform float lower_band = 0.0;
uniform vec3 lower_color : source_color = vec3(0.3, 0.32, 0.34);
uniform vec2 panel_size = vec2(1.2, 0.9);
uniform float seam_width = 0.02;
uniform float seam_dark = 0.45;
uniform float variation = 0.08;
uniform float grime = 0.35;
uniform float rivets = 1.0;
uniform float metallic_amount = 0.3;
uniform float roughness_amount = 0.65;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(wnrm);
	vec2 uv;
	bool is_wall = true;
	if (n.y > n.x && n.y > n.z) {
		uv = wpos.xz;
		is_wall = false;
	} else if (n.x > n.z) {
		uv = vec2(wpos.z, wpos.y);
	} else {
		uv = vec2(wpos.x, wpos.y);
	}

	vec2 cell = uv / panel_size;
	vec2 id = floor(cell);
	vec2 edge = min(fract(cell), 1.0 - fract(cell)) * panel_size;
	float seam = smoothstep(0.0, seam_width, min(edge.x, edge.y));
	float rivet = (1.0 - smoothstep(0.008, 0.016, length(edge - vec2(0.06)))) * rivets;

	vec3 col = base_color;
	if (is_wall && lower_band > 0.0) {
		col = mix(lower_color, base_color, step(lower_band, wpos.y));
	}
	col *= 1.0 + (hash(id) - 0.5) * 2.0 * variation;

	float near_floor = is_wall ? 1.0 - smoothstep(0.0, 1.0, wpos.y) : 0.0;
	float dirt = clamp(fbm(uv * 1.7 + id * 3.1) * grime + near_floor * grime * 0.6, 0.0, 1.0);
	col *= 1.0 - dirt * 0.5;
	col *= mix(seam_dark, 1.0, seam);
	col *= 1.0 - rivet * 0.35;

	ALBEDO = col;
	METALLIC = metallic_amount;
	ROUGHNESS = clamp(roughness_amount + dirt * 0.25, 0.0, 1.0);
}
