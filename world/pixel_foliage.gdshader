shader_type spatial;

// Pixel-art foliage / bark / rock: world-space "texels" picked from a
// four-colour palette, ragged leafy silhouettes, stepped toon lighting.

uniform vec3 c_dark : source_color = vec3(0.07, 0.2, 0.1);
uniform vec3 c_mid : source_color = vec3(0.16, 0.38, 0.13);
uniform vec3 c_light : source_color = vec3(0.35, 0.6, 0.16);
uniform vec3 c_high : source_color = vec3(0.65, 0.82, 0.3);
uniform float texel = 0.16;
// Stretch texels vertically (bark grain).
uniform float grain = 1.0;
// How much of the silhouette is eaten away into leafy edges (0 = solid).
uniform float ragged = 0.0;
uniform float bands = 1.0;

// Set by day_night.gd so these materials darken at night.
uniform vec3 world_tint : source_color = vec3(1.0);

varying vec3 wpos;
varying vec3 wnrm;
varying vec3 tint;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// Wind: leafy materials (ragged > 0) sway, more the higher they are.
uniform float wind_strength = 0.6;
uniform float wind_speed = 0.9;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (ragged > 0.0) {
		float height = clamp(wpos.y / 28.0, 0.05, 1.0);
		float gust = 0.6 + 0.4 * sin(TIME * 0.23 + wpos.x * 0.011);
		float w = sin(TIME * wind_speed + wpos.x * 0.07 + wpos.z * 0.05) * gust;
		float w2 = sin(TIME * wind_speed * 1.7 + wpos.z * 0.09) * 0.35;
		vec3 offset = vec3(w, 0.0, w2 * 0.6 + w * 0.3) * wind_strength * height * (1.0 + height);
		VERTEX += (inverse(MODEL_MATRIX) * vec4(offset, 0.0)).xyz;
		wpos += offset;
	}
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tint = COLOR.rgb;
}

void fragment() {
	vec3 cell = floor(wpos / (texel * vec3(1.0, grain, 1.0)));
	float h = hash(cell);
	if (ragged > 0.0) {
		float rim = 1.0 - abs(dot(NORMAL, VIEW));
		if (rim > 1.0 - ragged * (0.4 + 0.6 * h)) {
			discard;
		}
	}
	// Up-facing and noisy texels are lighter; bark gets horizontal bands.
	float t = clamp(wnrm.y * 0.35 + 0.45 + (h - 0.5) * 0.55, 0.0, 1.0);
	t += (bands - 1.0) * 0.2 * sin(cell.y * 1.7);
	vec3 col = t < 0.3 ? c_dark : (t < 0.55 ? c_mid : (t < 0.8 ? c_light : c_high));
	ALBEDO = col * tint * world_tint;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float d = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	d = d > 0.45 ? 1.0 : (d > 0.12 ? 0.55 : 0.18);
	DIFFUSE_LIGHT += d * LIGHT_COLOR / PI;
}
