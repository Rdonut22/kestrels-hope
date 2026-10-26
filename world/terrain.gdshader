shader_type spatial;

// Pixel-art meadow ground: chunky texels, a small palette of greens,
// flower specks and dirt patches, stepped toon lighting.
// dirt_amount 1 makes it bare earth.

uniform vec3 g_dark : source_color = vec3(0.13, 0.33, 0.1);
uniform vec3 g_mid : source_color = vec3(0.24, 0.5, 0.13);
uniform vec3 g_light : source_color = vec3(0.36, 0.6, 0.16);
uniform vec3 g_high : source_color = vec3(0.5, 0.7, 0.2);
uniform vec3 d_dark : source_color = vec3(0.22, 0.14, 0.09);
uniform vec3 d_light : source_color = vec3(0.4, 0.27, 0.16);
uniform float dirt_amount = 0.0;
uniform float flowers = 1.0;
uniform float texel = 0.12;

// Set by day_night.gd so these materials darken at night.
uniform vec3 world_tint : source_color = vec3(1.0);

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
	for (int i = 0; i < 4; i++) {
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
	vec2 cell = floor(wpos.xz / texel);
	vec2 p = cell * texel;
	float h = hash(cell);
	float t = fbm(p * 0.18) + (h - 0.5) * 0.35;
	vec3 col = t < 0.35 ? g_dark : (t < 0.52 ? g_mid : (t < 0.68 ? g_light : g_high));
	float dirt = clamp(smoothstep(0.62, 0.66, fbm(p * 0.07 + 7.0)) + dirt_amount, 0.0, 1.0);
	vec3 earth = (fbm(p * 1.1) + (h - 0.5) * 0.3) < 0.5 ? d_dark : d_light;
	col = mix(col, earth, step(0.5, dirt));
	if (dirt < 0.5 && flowers > 0.0 && h > 1.0 - 0.025 * flowers) {
		float k = hash(cell + 31.0);
		col = k < 0.25 ? vec3(0.95, 0.3, 0.25) : (k < 0.5 ? vec3(0.98, 0.95, 0.9) : (k < 0.75 ? vec3(1.0, 0.82, 0.25) : vec3(0.55, 0.65, 1.0)));
	}
	ALBEDO = col * world_tint;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float d = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	d = d > 0.45 ? 1.0 : (d > 0.12 ? 0.6 : 0.3);
	DIFFUSE_LIGHT += d * LIGHT_COLOR / PI;
}
