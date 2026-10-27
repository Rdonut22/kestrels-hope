shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// The holo-pad screen: the player's SubViewport added on top of the scene
// (so black is see-through), tinted cyan, with scanlines, flicker, an
// occasional glitch band and soft edges.

uniform sampler2D screen : source_color, filter_linear;
uniform vec3 tint : source_color = vec3(0.55, 0.85, 1.0);
uniform float strength = 2.2;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	// Now and then a thin band of the image slips sideways.
	float band = step(0.97, hash(floor(uv.y * 30.0) + floor(t * 6.0) * 17.0));
	uv.x += band * 0.012 * sin(t * 40.0);
	vec4 c = texture(screen, uv);
	vec3 col = c.rgb * c.a;
	col = mix(col, vec3(dot(col, vec3(0.3, 0.5, 0.2))) * tint * 1.6, 0.15);
	float scan = 0.78 + 0.22 * sin(uv.y * 520.0 - t * 5.0);
	float flicker = 0.93 + 0.07 * sin(t * 21.0) * sin(t * 6.7);
	vec2 edge = smoothstep(vec2(0.0), vec2(0.025), uv) * smoothstep(vec2(0.0), vec2(0.025), 1.0 - uv);
	ALBEDO = col * scan * flicker * strength * edge.x * edge.y;
}
