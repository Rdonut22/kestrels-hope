shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Bluish-white hologram: scanlines, wireframe-ish latitude/longitude grid,
// soft rim glow and a gentle flicker.

uniform vec3 color : source_color = vec3(0.55, 0.85, 1.0);
uniform float strength = 1.2;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	float scan = 0.6 + 0.4 * sin((lpos.y + TIME * 0.08) * 220.0);
	vec3 n = normalize(lpos);
	float lat = abs(fract(asin(n.y) / PI * 12.0) - 0.5);
	float lon = abs(fract(atan(n.z, n.x) / PI * 12.0) - 0.5);
	float grid = smoothstep(0.42, 0.5, max(lat, lon));
	float flicker = 0.85 + 0.15 * sin(TIME * 23.0) * sin(TIME * 7.0);
	float a = (0.12 + rim * 0.6 + grid * 0.5) * scan * flicker * strength;
	ALBEDO = color * a;
}
