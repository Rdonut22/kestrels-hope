shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, shadows_disabled;

// Thin atmospheric halo around the planet: a slightly larger sphere drawn
// from the inside, brightest at the limb on the sunlit side.

uniform vec3 color : source_color = vec3(0.55, 0.85, 1.0);
uniform vec3 sun_dir = vec3(0.25, 0.85, 0.45);
uniform float strength = 5.0;

varying vec3 wnrm;

void vertex() {
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(-NORMAL), VIEW)), 6.0);
	float day = clamp(dot(-wnrm, normalize(sun_dir)) * 0.7 + 0.5, 0.15, 1.0);
	ALBEDO = color * rim * day * strength;
}
