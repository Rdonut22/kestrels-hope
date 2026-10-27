shader_type spatial;

// Forest moon seen from orbit: pixel-art continents of forest green with
// lakes, drifting cloud bands, toon-stepped day/night shading. Works in
// object space so it sticks to the sphere.

uniform vec3 forest_dark : source_color = vec3(0.12, 0.36, 0.16);
uniform vec3 forest : source_color = vec3(0.24, 0.52, 0.22);
uniform vec3 forest_light : source_color = vec3(0.5, 0.64, 0.3);
uniform vec3 rock : source_color = vec3(0.52, 0.48, 0.46);
uniform vec3 water : source_color = vec3(0.18, 0.5, 0.86);
uniform vec3 cloud : source_color = vec3(0.95, 0.96, 1.0);
uniform vec3 night_tint : source_color = vec3(0.03, 0.05, 0.12);
uniform float texel = 0.0012;
// Scales the continents and clouds up for close views where only a small
// cap of the sphere is on screen.
uniform float zoom = 1.0;

varying vec3 opos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
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
	opos = normalize(VERTEX);
}

void fragment() {
	vec3 p = floor(opos * zoom / texel) * texel;
	float land = fbm(p * 4.0);
	float detail = fbm(p * 22.0);
	vec3 col;
	if (land < 0.42) {
		col = water * (0.85 + 0.3 * detail);
	} else if (land > 0.68) {
		col = mix(rock, vec3(0.92), step(0.78, land));
	} else {
		float t = detail + (land - 0.5) * 0.6;
		col = t < 0.42 ? forest_dark : (t < 0.55 ? forest : forest_light);
	}
	vec3 cp = p * 3.0 + vec3(TIME * 0.004, 0.0, TIME * 0.002);
	float c = smoothstep(0.5, 0.6, fbm(cp + fbm(cp * 2.0)));
	col = mix(col, cloud, c * 0.95);
	// Hazy blue toward the limb, like Earth from orbit.
	col = mix(col, vec3(0.62, 0.85, 1.0), pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 6.0) * 0.6);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float d = dot(NORMAL, LIGHT);
	float lit = d > 0.2 ? 1.0 : (d > 0.0 ? 0.75 : (d > -0.12 ? 0.35 : 0.0));
	DIFFUSE_LIGHT += mix(night_tint / max(ALBEDO, vec3(0.01)), vec3(1.0), lit) * lit * LIGHT_COLOR * ATTENUATION / PI + night_tint * (1.0 - lit);
}
