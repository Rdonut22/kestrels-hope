shader_type sky;

// Simple procedural starfield seen through the ship's windows.

uniform vec3 space_color : source_color = vec3(0.004, 0.005, 0.012);
uniform float density = 0.9985;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 cell = floor(EYEDIR * 350.0);
	float star = step(density, hash(cell));
	float brightness = mix(0.4, 1.6, hash(cell + 7.0));
	COLOR = space_color + vec3(star * brightness);
}
