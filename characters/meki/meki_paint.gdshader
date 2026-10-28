shader_type spatial;

// Worn paint for the ship's drone: beige paint over the model's own metal
// detail, dark rust patches and grime in seams and on the underside. Noise
// is in the mesh's own space so it stays put as the drone moves.

uniform sampler2D detail : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform vec3 paint : source_color = vec3(0.78, 0.71, 0.58);
uniform vec3 rust : source_color = vec3(0.32, 0.14, 0.07);
uniform vec3 grime_col : source_color = vec3(0.12, 0.1, 0.08);
uniform float rust_amount = 0.45;
uniform float grime_amount = 0.6;
uniform float noise_scale = 18.0;

varying vec3 lpos;
varying vec3 lnrm;

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
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
}

void fragment() {
	vec3 base = texture(detail, UV).rgb;
	float lum = dot(base, vec3(0.3, 0.55, 0.15));
	// Paint keeps the metal's light/dark detail so panels and scratches show.
	vec3 col = paint * mix(0.55, 1.15, lum);
	vec3 p = lpos * noise_scale;
	float r = smoothstep(0.55 - rust_amount * 0.25, 0.75, fbm(p * 0.7 + 3.0));
	float pits = smoothstep(0.6, 0.8, fbm(p * 3.0));
	col = mix(col, rust * mix(0.7, 1.3, fbm(p * 2.0)), clamp(r + pits * r * 0.5, 0.0, 1.0));
	// Grime: darker texture areas are crevices; the underside collects more.
	float crevice = smoothstep(0.45, 0.1, lum);
	float under = smoothstep(0.2, -0.8, normalize(lnrm).y);
	float smudge = smoothstep(0.4, 0.8, fbm(p * 1.3 + 9.0));
	col = mix(col, grime_col, clamp((crevice * 0.6 + under * 0.5 + smudge * 0.35) * grime_amount, 0.0, 0.85));
	ALBEDO = col;
	// Paint is matte, rust rougher, worn bare spots a bit metallic.
	ROUGHNESS = mix(0.55, 0.9, r);
	METALLIC = mix(0.15, 0.0, r);
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
