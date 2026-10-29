shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

// Re-entry plasma streaming up over the cockpit glass (a quad just outside
// the windshield). `heat` 0..1; brightest along the nose (bottom edge).

uniform float heat = 0.0;
uniform vec3 hot : source_color = vec3(1.0, 0.42, 0.14);
uniform vec3 core : source_color = vec3(1.0, 0.86, 0.62);

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

void fragment() {
	vec2 p = vec2(UV.x * 14.0, UV.y * 3.0 + TIME * 7.0);
	float n = noise(p) * 0.6 + noise(p * vec2(2.3, 3.1) + 5.0) * 0.4;
	float streak = smoothstep(0.42, 0.9, n);
	// UV.y = 1 at the bottom of the glass, nearest the nose.
	float nose = mix(0.15, 1.0, pow(UV.y, 1.6));
	float sides = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	float flick = 0.8 + 0.2 * sin(TIME * 37.0) * sin(TIME * 23.0);
	ALBEDO = mix(hot, core, streak) * (streak * 0.9 + 0.25) * nose * sides * heat * flick * 1.3;
}
