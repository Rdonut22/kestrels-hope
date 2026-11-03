shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

// Ship window glass: tinted dark glass that reflects a soft sky / ground
// gradient (stronger at grazing angles), catches the sun, shows a faint
// warm glow from the cabin behind it, and is dirty towards its edges.
// The scene's reflections are off (GL Compatibility), so the sky
// reflection is faked here from the reflection vector.
// Optional frame bars ("mullions") in object space split big glass areas
// (the canopy) into panes.

uniform vec3 tint : source_color = vec3(0.04, 0.08, 0.12);
uniform vec3 sky_top : source_color = vec3(0.3, 0.5, 0.8);
uniform vec3 sky_horizon : source_color = vec3(0.75, 0.82, 0.88);
uniform vec3 ground : source_color = vec3(0.2, 0.24, 0.16);
uniform float reflect_strength : hint_range(0.0, 2.0) = 1.1;
uniform vec3 interior : source_color = vec3(1.0, 0.72, 0.42);
uniform float interior_glow : hint_range(0.0, 2.0) = 0.1;
uniform float grime : hint_range(0.0, 1.0) = 0.4;
// Mullions: bar spacing (object-space units, 0 = none), width (fraction).
uniform vec2 mullion_spacing = vec2(0.0);
uniform float mullion_width = 0.08;
uniform vec3 frame_color : source_color = vec3(0.16, 0.16, 0.17);

varying vec3 v_obj;
varying vec3 v_world_n;

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
	v_world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(NORMAL);
	if (!FRONT_FACING) {
		n = -n;
	}
	vec3 v = normalize(VIEW);
	float fres = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 4.0) * 0.85 + 0.15;
	// Reflection vector in world space -> sky / horizon / ground gradient.
	vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-v, n), 0.0)).xyz;
	vec3 env = r.y > 0.0 ? mix(sky_horizon, sky_top, smoothstep(0.0, 0.6, r.y)) : mix(sky_horizon, ground, smoothstep(0.0, 0.25, -r.y));
	// Streaky dirt.
	float dirt = n2(v_obj.xz * 40.0 + v_obj.y * 13.0) * n2(vec2(v_obj.x * 6.0, v_obj.y * 60.0));
	vec3 col = tint + interior * interior_glow * (0.4 + 0.6 * n2(v_obj.xy * 3.0));
	vec3 refl = env * reflect_strength * fres * (1.0 - grime * dirt * 0.6);

	// Frame bars.
	float bar = 0.0;
	if (mullion_spacing.x > 0.0) {
		float fx = fract(v_obj.x / mullion_spacing.x);
		bar = max(bar, 1.0 - smoothstep(mullion_width * 0.5, mullion_width * 0.5 + 0.02, min(fx, 1.0 - fx)));
	}
	if (mullion_spacing.y > 0.0) {
		float fz = fract(v_obj.z / mullion_spacing.y);
		bar = max(bar, 1.0 - smoothstep(mullion_width * 0.5, mullion_width * 0.5 + 0.02, min(fz, 1.0 - fz)));
	}

	ALBEDO = mix(col * 0.3, frame_color, bar);
	EMISSION = mix(col * 0.6 + refl, vec3(0.0), bar);
	ROUGHNESS = mix(0.08 + grime * dirt * 0.4, 0.6, bar);
	METALLIC = mix(0.0, 0.5, bar);
	SPECULAR = mix(0.9, 0.4, bar);
}
