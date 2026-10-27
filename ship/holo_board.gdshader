shader_type spatial;
render_mode unshaded;

// Holo-table top: a radial game board in dark and light segments with a
// faint blue glow, like a dejarik table.

uniform vec3 dark : source_color = vec3(0.08, 0.09, 0.11);
uniform vec3 light : source_color = vec3(0.75, 0.76, 0.78);
uniform vec3 glow : source_color = vec3(0.35, 0.7, 1.0);

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	vec2 p = lpos.xz / 0.6;
	float r = length(p);
	float a = atan(p.y, p.x);
	float seg = step(0.5, fract(a / (PI / 6.0)));
	float ring = r < 0.35 ? 0.0 : 1.0;
	float pick = mod(seg + ring, 2.0);
	vec3 col = mix(dark, light, pick);
	if (r < 0.12) col = vec3(0.12, 0.14, 0.18);
	col += glow * 0.25 * smoothstep(0.96, 1.0, r);
	ALBEDO = col;
}
