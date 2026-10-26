shader_type spatial;

// Worn surface: grime, scuffs, scratches and chipped paint, in world
// space so it needs no UVs. Used on the cockpit seats.

uniform vec3 base_color : source_color = vec3(0.7);
uniform vec3 chip_color : source_color = vec3(0.18, 0.18, 0.19);
uniform float grime = 0.35;
uniform float chips = 0.25;
uniform float scratches = 0.4;
uniform float fade = 0.0;
uniform float noise_scale = 6.0;
uniform float roughness_amount = 0.6;
uniform float metallic_amount = 0.2;

varying vec3 wpos;
varying vec3 wnrm;

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
		p *= 2.07;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(wnrm);
	vec2 uv = n.y > max(n.x, n.z) ? wpos.xz : (n.x > n.z ? wpos.zy : wpos.xy);
	uv *= noise_scale;

	vec3 col = base_color;
	// Faded, uneven patches (sun and hands).
	col *= 1.0 + (fbm(uv * 0.35 + 3.7) - 0.5) * 0.35;
	col = mix(col, col * vec3(1.08, 1.04, 0.95), fade * fbm(uv * 0.5));

	// Grime gathers low down and in blotches.
	float dirt = smoothstep(0.45, 0.85, fbm(uv * 0.8 + 11.0)) * grime;
	dirt += (1.0 - smoothstep(0.0, 0.6, wpos.y)) * grime * 0.4;
	col *= 1.0 - clamp(dirt, 0.0, 1.0) * 0.55;

	// Thin scratches running mostly one way.
	float sc = noise(vec2(uv.x * 0.6, uv.y * 14.0) + 5.0);
	float scratch = smoothstep(0.93, 0.97, sc) * step(0.55, noise(uv * 0.9 + 2.0)) * scratches;
	col = mix(col, col * 1.25 + 0.05, scratch);

	// Chipped paint showing dark metal underneath.
	float chip = smoothstep(0.72, 0.76, fbm(uv * 1.6 + 19.0)) * chips;
	col = mix(col, chip_color, chip);

	ALBEDO = col;
	ROUGHNESS = clamp(roughness_amount + dirt * 0.3 - chip * 0.2, 0.0, 1.0);
	METALLIC = mix(metallic_amount, 0.7, chip);
}
