shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never;

// Soft shaft of light slanting through the canopy.

uniform vec3 color : source_color = vec3(1.0, 0.95, 0.7);
uniform float strength = 0.11;

void fragment() {
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	float along = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.6, UV.y);
	float flicker = 0.85 + 0.15 * sin(TIME * 0.7 + UV.y * 3.0);
	ALBEDO = color * across * across * along * strength * flicker;
}
