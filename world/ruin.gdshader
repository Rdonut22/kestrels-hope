shader_type spatial;
render_mode fog_disabled, cull_disabled;

// Ancient sci-fi ruins far off in the forest. Colour comes from vertex
// colours (a palette set per greeble); vertex alpha < 0.5 marks glowing
// windows. Pixel-art texels, toon lighting, and our own distance haze so
// the ruins stay readable beyond the forest fog.

uniform vec3 world_tint : source_color = vec3(1.0);
uniform vec3 haze : source_color = vec3(0.52, 0.7, 0.66);
uniform float haze_amount = 0.42;
uniform float texel = 0.35;

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 vcol;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vcol = COLOR;
}

void fragment() {
	vec3 cell = floor(wpos / texel);
	float h = hash(cell);
	vec3 col = vcol.rgb * (0.82 + 0.3 * h);
	// Grime streaks running down the surfaces.
	float streak = hash(vec3(cell.x, 0.0, cell.z));
	col *= mix(1.0, 0.72, step(0.82, streak) * (0.5 + 0.5 * h));
	col *= world_tint;
	float glow = 1.0 - step(0.5, vcol.a);
	ALBEDO = mix(col, haze * world_tint, haze_amount * (1.0 - glow));
	EMISSION = vcol.rgb * glow * 2.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float d = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	d = d > 0.4 ? 1.0 : (d > 0.1 ? 0.6 : 0.3);
	DIFFUSE_LIGHT += d * LIGHT_COLOR / PI * (1.0 - haze_amount * 0.6);
}
