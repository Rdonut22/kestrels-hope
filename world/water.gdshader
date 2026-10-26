shader_type spatial;
render_mode unshaded;

// Pixel-art pond: bands of blue with drifting shimmer pixels.

uniform vec3 deep : source_color = vec3(0.16, 0.36, 0.5);
uniform vec3 shallow : source_color = vec3(0.35, 0.6, 0.72);
uniform vec3 shine : source_color = vec3(0.85, 0.95, 1.0);
uniform float texel = 0.12;

// Set by day_night.gd so these materials darken at night.
uniform vec3 world_tint : source_color = vec3(1.0);

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = floor(wpos.xz / texel);
	float wave = sin(cell.x * 0.35 + TIME * 1.2) * 0.5 + sin(cell.y * 0.5 - TIME * 0.8) * 0.5;
	vec3 col = wave > 0.2 ? shallow : deep;
	float h = hash(cell + floor(TIME * 2.0));
	if (h > 0.985) {
		col = shine;
	}
	ALBEDO = col * world_tint;
}
