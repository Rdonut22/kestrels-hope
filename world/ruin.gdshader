shader_type spatial;
render_mode fog_disabled, cull_disabled;

// Ancient sci-fi ruins far off in the forest. Colour comes from vertex
// colours (a palette set per greeble); vertex alpha < 0.5 marks glowing
// windows. Pixel-art texels, toon lighting, and our own distance haze so
// the ruins stay readable beyond the forest fog.

uniform vec3 world_tint : source_color = vec3(1.0);
uniform vec3 haze : source_color = vec3(0.52, 0.7, 0.66);
uniform float haze_amount = 0.3;
uniform float texel = 0.35;
uniform vec3 rust : source_color = vec3(0.62, 0.33, 0.18);

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
	// Rust and grime streaks running down from seams.
	float streak = hash(vec3(cell.x, 0.0, cell.z));
	float drip = step(0.8, streak) * step(0.35, hash(vec3(cell.x, floor(cell.y / 6.0), cell.z)));
	float bright = dot(vcol.rgb, vec3(0.33));
	col = mix(col, mix(col * 0.7, rust * (0.8 + 0.3 * h), step(0.5, bright)), drip * 0.75);
	// Occasional rust patches on light plating.
	float patch = hash(floor(wpos / (texel * 7.0)));
	col = mix(col, rust * (0.75 + 0.35 * h), step(0.93, patch) * step(0.5, bright) * 0.8);
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
