// Shared by the day/descent skies and the moons (world/sky_moons.gd): noise
// and the painted mountain skyline, so the moons can set behind the peaks.

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

// Skyline of individual peaks. Each azimuth cell may hold one mountain
// with its own centre, width and height; neighbours overlap a little.
// Returns height in .x and the side of the peak (-1 left, +1 right) in .y.
vec2 skyline(float az, float cell, float seed, float min_h, float max_h) {
	float best = 0.0;
	float side = 0.0;
	float c0 = floor(az / cell);
	for (int k = -2; k <= 2; k++) {
		float c = c0 + float(k);
		vec2 id = vec2(c, seed);
		if (hash(id) < 0.3) {
			continue;
		}
		float centre = (c + 0.2 + 0.6 * hash(id + 1.0)) * cell;
		float width = cell * (0.55 + 0.9 * hash(id + 2.0));
		float h = mix(min_h, max_h, pow(hash(id + 3.0), 1.5));
		float t = (az - centre) / width;
		// Steeper on one side, with jagged ridges.
		float slope = t < 0.0 ? 1.0 + 0.6 * hash(id + 4.0) : 1.0 + 0.6 * hash(id + 5.0);
		float profile = max(0.0, 1.0 - pow(abs(t) * slope, 1.15));
		profile *= 0.92 + 0.12 * fbm(vec2(az * 14.0, seed + c));
		profile += 0.012 * (noise(vec2(az * 60.0, seed)) - 0.5) / max(h, 0.1);
		float y = h * profile;
		if (y > best) {
			best = y;
			side = t + (noise(vec2(az * 25.0, seed + c)) - 0.5) * 0.35;
		}
	}
	return vec2(best, side);
}

// Elevation (radians) of the mountain tops at a snapped azimuth, as drawn by
// the skies: the far range (0.55, 3.0) and the near range (0.8, 11.0).
float skyline_top(float saz, float height_scale) {
	return max(skyline(saz, 0.55, 3.0, 0.16, 0.42).x, skyline(saz, 0.8, 11.0, 0.12, 0.5).x) * height_scale;
}

// The skies' cloud cover (0..1) at a snapped direction.
float sky_cloud(float saz, float sel) {
	vec2 cl = vec2(saz * 1.2, sel * 3.0);
	return smoothstep(0.55, 0.8, fbm(cl * 2.5 + vec2(TIME * 0.003, 0.0))) * 0.8 * step(0.05, sel);
}
