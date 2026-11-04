// Clear window glass for the galley's panoramic windows: genuinely
// transparent with a very slight blue-grey tint, nearly clear head-on and
// more reflective toward grazing angles, with sharp highlights from the
// sun and cabin lights. The renderer's reflections are off (GL
// Compatibility), so the faint sky reflection is faked from the
// reflection vector, kept subtle.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(0.78, 0.84, 0.88);
uniform float clear_alpha : hint_range(0.0, 1.0) = 0.07;
uniform float edge_alpha : hint_range(0.0, 1.0) = 0.45;
uniform vec3 sky_top : source_color = vec3(0.5, 0.62, 0.78);
uniform vec3 sky_horizon : source_color = vec3(0.78, 0.82, 0.85);
uniform vec3 ground : source_color = vec3(0.25, 0.28, 0.22);
uniform float reflect_strength : hint_range(0.0, 1.0) = 0.22;
uniform float dust : hint_range(0.0, 1.0) = 0.15;

varying vec3 v_obj;

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	v_obj = VERTEX;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	if (!FRONT_FACING) {
		n = -n;
		NORMAL = n;
	}
	vec3 v = normalize(VIEW);
	float fres = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 5.0);
	vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-v, n), 0.0)).xyz;
	vec3 env = r.y > 0.0 ? mix(sky_horizon, sky_top, smoothstep(0.0, 0.6, r.y))
		: mix(sky_horizon, ground, smoothstep(0.0, 0.25, -r.y));
	// Faint dust, mostly toward the bottom of each pane.
	float d = n2(v_obj.xy * 9.0) * n2(v_obj.xy * 31.0 + 4.0) * dust;

	ALBEDO = tint * 0.25;
	ROUGHNESS = 0.04 + d * 0.3;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	EMISSION = env * reflect_strength * fres;
	ALPHA = clamp(clear_alpha + fres * edge_alpha + d * 0.08, 0.0, 0.8);
}
