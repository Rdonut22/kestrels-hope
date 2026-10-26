shader_type sky;

// Daytime sky with pixel-art granite mountains rising above the trees,
// soft clouds and two pale moons. Directions are snapped to a coarse
// grid so everything reads as chunky pixels.

uniform vec3 top_color : source_color = vec3(0.3, 0.55, 0.88);
uniform vec3 horizon_color : source_color = vec3(0.7, 0.82, 0.88);
uniform vec3 haze_color : source_color = vec3(0.6, 0.72, 0.8);
uniform vec3 granite_lit : source_color = vec3(0.7, 0.69, 0.7);
uniform vec3 granite_mid : source_color = vec3(0.5, 0.51, 0.58);
uniform vec3 granite_dark : source_color = vec3(0.33, 0.35, 0.45);
uniform vec3 snow : source_color = vec3(0.96, 0.97, 1.0);
uniform vec3 moon_a_dir = vec3(-0.55, 0.62, -0.55);
uniform vec3 moon_b_dir = vec3(-0.25, 0.5, -0.83);
uniform float pixel = 0.0045;

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

// Ridge-line height (elevation, radians) of a mountain range at azimuth az.
float ridge(float az, float seed, float base, float amp) {
	float x = az * 1.3 + seed;
	float n = fbm(vec2(x, seed));
	float r = 1.0 - abs(noise(vec2(x * 2.7, seed + 9.0)) * 2.0 - 1.0);
	return base + amp * (n * 0.85 + r * 0.25);
}

vec3 mountain(float az, float el, float h, float seed, float haze) {
	float e = 0.02;
	float slope = ridge(az + e, seed, 0.0, 1.0) - ridge(az - e, seed, 0.0, 1.0);
	float tex = noise(vec2(az * 60.0, el * 45.0)) + (hash(vec2(floor(az / pixel), floor(el / pixel))) - 0.5) * 0.3;
	vec3 col = slope > 0.0 ? (tex > 0.55 ? granite_lit : granite_mid) : (tex > 0.6 ? granite_mid : granite_dark);
	// Vertical streaks on the cliff faces.
	if (noise(vec2(az * 140.0, seed)) > 0.78) {
		col = mix(col, granite_dark, 0.5);
	}
	if (h > 0.52 && el > h - 0.06 - 0.04 * noise(vec2(az * 30.0, seed))) {
		col = snow;
	}
	// Bases fade into the valley haze.
	float fade = haze + (1.0 - haze) * smoothstep(0.25, 0.0, el);
	return mix(col, haze_color, clamp(fade, 0.0, 1.0));
}

void sky() {
	vec3 d = EYEDIR;
	float az = atan(d.x, -d.z);
	float el = asin(clamp(d.y, -1.0, 1.0));
	float saz = floor(az / pixel) * pixel;
	float sel = floor(el / pixel) * pixel;

	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.9, el));
	float far_h = ridge(saz, 3.0, 0.34, 0.4);
	float near_h = ridge(saz, 11.0, 0.22, 0.4);
	if (sel < near_h) {
		col = mountain(saz, sel, near_h, 11.0, 0.18);
	} else if (sel < far_h) {
		col = mountain(saz, sel, far_h, 3.0, 0.45);
	} else {
		vec2 uv = vec2(saz * 1.2, sel * 3.0);
		float c = smoothstep(0.55, 0.8, fbm(uv * 2.5 + vec2(TIME * 0.003, 0.0)));
		col = mix(col, vec3(1.0), c * 0.8);
		float ma = distance(d, normalize(moon_a_dir));
		float mb = distance(d, normalize(moon_b_dir));
		col = mix(col, vec3(0.93, 0.92, 0.9), smoothstep(0.042, 0.038, ma) * 0.8);
		col = mix(col, vec3(0.88, 0.85, 0.92), smoothstep(0.024, 0.021, mb) * 0.8);
		float sun = distance(d, LIGHT0_DIRECTION);
		col += LIGHT0_COLOR * (smoothstep(0.045, 0.035, sun) * 4.0 + smoothstep(0.6, 0.0, sun) * 0.2);
	}
	if (el < 0.0) {
		col = haze_color;
	}
	COLOR = col;
}
