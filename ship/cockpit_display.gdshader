shader_type spatial;
render_mode unshaded;

// Cockpit instrument screens (ship/cockpit_fitout.gd): muted green/cyan
// line work on a near-black glass, no bloom.
//   mode 0: radar (range rings, cross-hair, slow sweep, a few contacts)
//   mode 1: terrain map (contour lines, grid, a course line)
//   mode 2: the yoke hub (a ring gauge with a heading tick)

uniform int mode = 0;
uniform vec3 ink : source_color = vec3(0.35, 0.85, 0.7);
uniform float brightness = 0.9;
uniform float aspect = 1.6;   // width / height of the screen

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float line(float d, float w) {
	return 1.0 - smoothstep(w * 0.5, w, abs(d));
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float v = 0.0;
	if (mode == 0) {
		float r = length(p);
		for (int i = 1; i <= 4; i++) {
			v += line(r - float(i) * 0.11, 0.012) * 0.55;
		}
		v += (line(p.x, 0.008) + line(p.y, 0.008)) * 0.35 * step(r, 0.45);
		float ang = atan(p.y, p.x);
		float sweep = mod(TIME * 0.8 - ang, 6.2832);
		v += smoothstep(1.2, 0.0, sweep) * 0.45 * step(r, 0.45);
		for (int k = 0; k < 4; k++) {
			vec2 c = vec2(hash(vec2(float(k), 3.0)) - 0.5, hash(vec2(float(k), 7.0)) - 0.5) * 0.7;
			v += smoothstep(0.022, 0.008, length(p - c));
		}
	} else if (mode == 1) {
		float hgt = noise(p * 3.0 + 4.0) * 0.7 + noise(p * 7.0) * 0.3;
		v += line(fract(hgt * 7.0) - 0.5, 0.12) * 0.5;
		vec2 g = fract(p * 6.0) - 0.5;
		v += (line(g.x, 0.03) + line(g.y, 0.03)) * 0.12;
		v += line(p.y - 0.25 * sin(p.x * 3.0 + 1.0), 0.02) * 0.9;
	} else {
		float r = length(p);
		v += line(r - 0.4, 0.05) * 0.8;
		float ang = atan(p.y, p.x);
		v += line(r - 0.3, 0.025) * step(0.5, fract(ang * 6.0 / 6.2832 * 6.0)) * 0.6;
		v += line(p.x, 0.04) * step(0.28, p.y) * step(p.y, 0.46);
		v += smoothstep(0.1, 0.0, r) * 0.6;
	}
	// Scan lines and edge falloff.
	v *= 0.85 + 0.15 * sin(UV.y * 400.0);
	float edge = smoothstep(0.0, 0.06, UV.x) * smoothstep(1.0, 0.94, UV.x) * smoothstep(0.0, 0.06, UV.y) * smoothstep(1.0, 0.94, UV.y);
	vec3 glass = vec3(0.015, 0.03, 0.03);
	ALBEDO = glass + ink * clamp(v, 0.0, 1.2) * brightness * edge;
}
