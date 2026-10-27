shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Faint light fanning up from the table's projector to the holo-pad.
// UV.y runs 0 at the projector to 1 at the screen.

uniform vec3 color : source_color = vec3(0.35, 0.7, 1.0);
uniform float strength = 0.12;

void fragment() {
	float t = TIME;
	float streak = 0.75 + 0.25 * sin(UV.y * 40.0 - t * 3.0);
	ALBEDO = color * strength * smoothstep(0.0, 0.6, UV.y) * streak * (0.9 + 0.1 * sin(t * 17.0));
}
