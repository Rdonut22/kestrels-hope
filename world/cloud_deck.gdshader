shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

// Cloud layer for the descent: a curved sheet hugging the moon, broken up
// with noise. Works in object space (the sheet's origin is the moon's
// centre), so it stays put while the world turns around the ship.

uniform vec3 color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 shade : source_color = vec3(0.7, 0.76, 0.86);
uniform float opacity = 0.9;
uniform float scale = 0.0022;
uniform float cover = 0.5;
uniform float radius = 2400.0;  // sheet's ground radius; fades out at the rim

varying vec3 opos;

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
	opos = VERTEX;
}

void fragment() {
	vec2 p = opos.xz * scale + vec2(TIME * 0.004, 0.0);
	float n = fbm(p + fbm(p * 1.7) * 0.6);
	float a = smoothstep(cover - 0.08, cover + 0.12, n);
	a *= 1.0 - smoothstep(radius * 0.7, radius, length(opos.xz));
	ALBEDO = mix(shade, color, smoothstep(cover, cover + 0.3, n));
	ALPHA = a * opacity;
}
