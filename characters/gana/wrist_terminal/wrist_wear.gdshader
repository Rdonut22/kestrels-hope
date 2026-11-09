shader_type spatial;

// Temporary weathered paint/metal for the wrist terminal, all procedural
// (no textures, so no sampler cost on GL Compatibility / ANGLE): paint chips
// that show darker bare metal, fine speckle, and grime that collects on
// downward-facing and low-frequency patches. Noise runs in object space so
// the wear sticks to the prop when it moves with the arm.
// Swap for proper PBR textures later; every surface keeps its own material.

uniform vec3 base_color : source_color = vec3(0.7, 0.65, 0.52);
uniform vec3 chip_color : source_color = vec3(0.16, 0.14, 0.12);
uniform vec3 grime_color : source_color = vec3(0.16, 0.13, 0.09);
uniform float metallic_base : hint_range(0.0, 1.0) = 0.2;
uniform float metallic_chip : hint_range(0.0, 1.0) = 0.85;
uniform float rough_base : hint_range(0.0, 1.0) = 0.62;
uniform float rough_chip : hint_range(0.0, 1.0) = 0.38;
// 0 = factory new, 1 = badly chipped.
uniform float chip_amount : hint_range(0.0, 1.0) = 0.35;
// Noise cells per metre (the prop is ~0.2 m long).
uniform float chip_scale = 150.0;
// Extra chipping on bevels and chamfers (faces at ~45 degrees in object
// space, which is where the procedural meshes put their edge bevels).
uniform float edge_wear : hint_range(0.0, 1.0) = 0.6;
uniform float grime_amount : hint_range(0.0, 1.0) = 0.35;
// Small per-surface colour variation (mottling).
uniform float mottle : hint_range(0.0, 0.5) = 0.12;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;

varying vec3 opos;
varying vec3 onrm;

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.27, 0.43));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s;
}

void fragment() {
	vec3 p = opos * chip_scale;
	// Chips: large ragged patches plus small speckle.
	float n = fbm(p);
	vec3 an = abs(normalize(onrm));
	float edge = smoothstep(0.12, 0.26, 1.0 - max(an.x, max(an.y, an.z))) * edge_wear;
	float t = 0.76 - chip_amount * 0.22 - edge * 0.3;
	float chip = smoothstep(t, t + 0.02, n);
	float speck = smoothstep(0.92 - chip_amount * 0.08, 0.955, vnoise(p * 3.3 + vec3(5.0)));
	chip = max(chip, speck * 0.85);
	// Grime: low-frequency blotches, heavier on faces that point down.
	float g = fbm(opos * 22.0 + vec3(3.0)) * 1.5 - 0.3;
	g = clamp(g, 0.0, 1.0) * grime_amount + clamp(-onrm.y, 0.0, 1.0) * grime_amount * 0.7;
	g = clamp(g, 0.0, 0.85);
	float m = (vnoise(p * 0.35 + vec3(11.0)) - 0.5) * mottle;
	vec3 paint = base_color * (1.0 + m);
	vec3 col = mix(paint, grime_color, g);
	col = mix(col, chip_color, chip);
	ALBEDO = col;
	METALLIC = mix(metallic_base, metallic_chip, chip);
	ROUGHNESS = clamp(mix(rough_base, rough_chip, chip) + g * 0.15, 0.05, 1.0);
	EMISSION = emission_color * emission_energy;
}
