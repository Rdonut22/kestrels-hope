shader_type sky;

// Daytime sky: separate pixel-art mountain peaks (two hazy layers with
// valleys between them), soft clouds and two pale daytime moons.
// Directions are snapped to a coarse grid so everything reads as pixels.

uniform vec3 top_color : source_color = vec3(0.3, 0.55, 0.88);
uniform vec3 horizon_color : source_color = vec3(0.7, 0.82, 0.88);
uniform vec3 haze_color : source_color = vec3(0.62, 0.74, 0.82);
uniform vec3 rock_lit : source_color = vec3(0.62, 0.6, 0.62);
uniform vec3 rock_mid : source_color = vec3(0.44, 0.45, 0.52);
uniform vec3 rock_dark : source_color = vec3(0.3, 0.32, 0.42);
uniform vec3 snow : source_color = vec3(0.95, 0.96, 1.0);
uniform vec3 moon_a_dir = vec3(-0.8, 0.5, 0.35);
uniform vec3 moon_b_dir = vec3(-0.85, 0.42, -0.2);
uniform float pixel = 0.004;

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

vec3 rock(float az, float el, vec2 sk, float seed, float haze, float snow_line) {
	float tex = noise(vec2(az * 70.0, el * 55.0)) + (hash(vec2(floor(az / pixel), floor(el / pixel))) - 0.5) * 0.3;
	// Sun from the right: right-hand faces lit.
	vec3 col = sk.y > 0.0 ? (tex > 0.5 ? rock_lit : rock_mid) : (tex > 0.62 ? rock_mid : rock_dark);
	if (noise(vec2(az * 90.0, el * 20.0 + seed)) > 0.82) {
		col = mix(col, rock_dark, 0.3);
	}
	float snow_at = snow_line + 0.03 * noise(vec2(az * 35.0, seed));
	if (sk.x > snow_line && el > snow_at && el > sk.x * 0.78 && el < sk.x) {
		col = sk.y > 0.0 ? snow : mix(snow, rock_mid, 0.25);
	}
	float fade = haze + (1.0 - haze) * smoothstep(0.12, 0.0, el);
	return mix(col, haze_color, clamp(fade, 0.0, 1.0));
}

vec3 moon(vec3 d, vec3 dir, float size, vec3 sky_col, float lit_side) {
	vec3 m = normalize(dir);
	float dist = distance(d, m);
	if (dist > size) {
		return sky_col;
	}
	vec3 right = normalize(cross(m, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(right, m);
	vec2 p = vec2(dot(d - m, right), dot(d - m, up)) / size;
	float z = sqrt(max(0.0, 1.0 - dot(p, p)));
	vec3 n = vec3(p, z);
	float light = clamp(dot(n, normalize(vec3(lit_side, 0.3, 0.6))), 0.0, 1.0);
	float craters = fbm(p * 4.0 + size * 100.0);
	vec3 surface = mix(vec3(0.72, 0.72, 0.76), vec3(0.98, 0.97, 0.95), smoothstep(0.35, 0.65, craters));
	vec3 lit = mix(sky_col, surface, smoothstep(0.05, 0.3, light));
	// Daytime moons are washed out by the sky.
	return mix(sky_col, lit, 0.85);
}

void sky() {
	vec3 d = EYEDIR;
	float az = atan(d.x, -d.z);
	float el = asin(clamp(d.y, -1.0, 1.0));
	float saz = floor(az / pixel) * pixel;
	float sel = floor(el / pixel) * pixel;
	vec3 sd = vec3(sin(saz) * cos(sel), sin(sel), -cos(saz) * cos(sel));

	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.9, el));
	vec2 cl = vec2(saz * 1.2, sel * 3.0);
	col = mix(col, vec3(1.0), smoothstep(0.55, 0.8, fbm(cl * 2.5 + vec2(TIME * 0.003, 0.0))) * 0.8 * step(0.05, sel));
	col = moon(sd, moon_a_dir, 0.09, col, 1.0);
	col = moon(sd, moon_b_dir, 0.055, col, 0.6);
	float sun = distance(d, LIGHT0_DIRECTION);
	col += LIGHT0_COLOR * (smoothstep(0.045, 0.035, sun) * 4.0 + smoothstep(0.6, 0.0, sun) * 0.2);

	vec2 far = skyline(saz, 0.55, 3.0, 0.16, 0.42);
	vec2 near = skyline(saz, 0.8, 11.0, 0.12, 0.5);
	if (sel < near.x) {
		col = rock(saz, sel, near, 11.0, 0.22, 0.34);
	} else if (sel < far.x) {
		col = rock(saz, sel, far, 3.0, 0.5, 0.3);
	}
	if (el < 0.0) {
		col = haze_color;
	}
	COLOR = col;
}
