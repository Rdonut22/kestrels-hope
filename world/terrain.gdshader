shader_type spatial;

// Grass / dirt ground in world space. dirt_amount 1 makes it bare earth.

uniform vec3 grass_a : source_color = vec3(0.24, 0.38, 0.14);
uniform vec3 grass_b : source_color = vec3(0.36, 0.46, 0.18);
uniform vec3 dirt_color : source_color = vec3(0.3, 0.22, 0.15);
uniform float dirt_amount = 0.15;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec3 grass = mix(grass_a, grass_b, fbm(p * 0.15));
	grass *= 0.85 + 0.3 * noise(p * 3.0);
	float dirt = clamp(smoothstep(0.55, 0.75, fbm(p * 0.08 + 7.0)) + dirt_amount, 0.0, 1.0);
	vec3 earth = dirt_color * (0.75 + 0.5 * fbm(p * 1.3));
	ALBEDO = mix(grass, earth, dirt);
	ROUGHNESS = 0.95;
}
