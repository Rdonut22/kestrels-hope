shader_type spatial;

// The cockpit floor (ship/nose_cockpit.gd): worn bronze-brown deck plate
// perforated in offset columns of long slots and round holes, rusty dark
// recesses showing through. Drawn in ship space (x across, z along), so
// it needs no UVs. A stand-in for the user's grid texture until it's added.

uniform vec3 plate : source_color = vec3(0.36, 0.28, 0.2);
uniform vec3 rust : source_color = vec3(0.3, 0.14, 0.07);
uniform float column = 0.055;   // metres between columns
uniform float period = 0.17;    // one long slot + one round hole, along z
uniform float slot_w = 0.017;

varying vec3 wpos;

void vertex() {
	wpos = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// Signed distance to a capsule running along y, half length h, radius r.
float capsule(vec2 p, float h, float r) {
	p.y -= clamp(p.y, -h, h);
	return length(p) - r;
}

float holes(vec2 p) {
	float c = floor(p.x / column);
	float x = (fract(p.x / column) - 0.5) * column;
	float z = p.y + mod(c, 2.0) * period * 0.5;
	float zz = mod(z, period) - period * 0.5;
	// Long slot centred in the period, the round hole at its ends.
	float d = capsule(vec2(x, zz + 0.022), 0.04, slot_w * 0.5);
	float zr = mod(z + period * 0.5, period) - period * 0.5;
	d = min(d, length(vec2(x, zr - 0.06 + 0.022)) - slot_w * 0.55);
	return d;
}

void fragment() {
	vec2 p = wpos.xz;
	float d = holes(p);
	float n = noise(p * 6.0) * 0.6 + noise(p * 23.0) * 0.4;
	float hole = 1.0 - smoothstep(-0.001, 0.001, d);
	float rim = 1.0 - smoothstep(0.0, 0.004, abs(d));
	vec3 metal = plate * (0.75 + 0.5 * n);
	vec3 inside = mix(rust, rust * 0.35, noise(p * 15.0)) * 0.5;
	ALBEDO = mix(metal, inside, hole) + vec3(0.12, 0.1, 0.07) * rim * (1.0 - hole);
	METALLIC = mix(0.55, 0.1, hole);
	ROUGHNESS = mix(0.5 - 0.15 * rim, 0.95, hole);
	// Bevel: tilt the normal across the rim.
	float e = 0.001;
	vec2 g = vec2(holes(p + vec2(e, 0.0)) - d, holes(p + vec2(0.0, e)) - d) / e;
	vec3 n_obj = normalize(vec3(-g.x * rim * 0.6, 1.0, -g.y * rim * 0.6));
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(n_obj, 0.0)).xyz);
}
