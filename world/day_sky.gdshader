shader_type sky;

// Daytime alien sky: gradient, sun disc (from the scene's sun), soft
// clouds and two pale moons.

uniform vec3 top_color : source_color = vec3(0.32, 0.55, 0.85);
uniform vec3 horizon_color : source_color = vec3(0.78, 0.84, 0.86);
uniform vec3 ground_color : source_color = vec3(0.35, 0.4, 0.33);
uniform vec3 moon_a_dir = vec3(-0.55, 0.42, -0.72);
uniform vec3 moon_b_dir = vec3(-0.32, 0.3, -0.9);

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
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

vec3 moon(vec3 d, vec3 dir, float size, vec3 col, vec3 sky_col) {
	float m = smoothstep(size, size * 0.92, distance(d, normalize(dir)));
	float shade = 0.75 + 0.25 * fbm(d.xy * 60.0);
	return mix(sky_col, col * shade, m * 0.8);
}

void sky() {
	vec3 d = EYEDIR;
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.55, d.y));
	if (d.y < 0.0) {
		col = mix(horizon_color, ground_color, smoothstep(0.0, -0.15, d.y));
	}
	if (d.y > 0.0) {
		vec2 uv = d.xz / (d.y + 0.15) * 1.6;
		float c = smoothstep(0.5, 0.8, fbm(uv + TIME * 0.004));
		col = mix(col, vec3(1.0), c * 0.75 * smoothstep(0.0, 0.2, d.y));
		col = moon(d, moon_a_dir, 0.045, vec3(0.92, 0.9, 0.86), col);
		col = moon(d, moon_b_dir, 0.025, vec3(0.86, 0.82, 0.9), col);
	}
	float sun = distance(d, LIGHT0_DIRECTION);
	col += LIGHT0_COLOR * (smoothstep(0.045, 0.035, sun) * 4.0 + smoothstep(0.6, 0.0, sun) * 0.25);
	COLOR = col;
}
