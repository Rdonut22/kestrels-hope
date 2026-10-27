shader_type spatial;

// Corrugated flex hose. The ribs come from UV.x (metres along the hose) so
// the mesh can stay low-poly; the tint comes from the vertex colour, and
// grime and dust are laid on in world space.

uniform float rib_spacing = 0.03;
uniform float rib_depth = 0.7;
uniform float grime = 0.45;
uniform vec3 grime_color : source_color = vec3(0.2, 0.16, 0.11);
uniform vec3 dust_color : source_color = vec3(0.6, 0.57, 0.5);

varying vec3 wpos;
varying vec3 wnrm;

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
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float ph = UV.x / rib_spacing * 6.2831853;
	float h = sin(ph);
	// Fade the ribs out once they get smaller than a pixel or two.
	float fade = 1.0 - smoothstep(0.25, 0.7, fwidth(UV.x) / rib_spacing);
	// Grooves between the ribs collect dirt and shadow.
	float groove = smoothstep(0.3, -0.9, h) * fade;
	vec3 col = COLOR.rgb * (1.0 - groove * 0.22);
	float blotch = smoothstep(0.38, 0.72, fbm(wpos * 5.0));
	float streak = smoothstep(0.55, 0.8, fbm(wpos * vec3(18.0, 3.0, 18.0) + 7.0));
	col = mix(col, grime_color, clamp((blotch * 0.55 + streak * 0.3 + groove * 0.15) * grime, 0.0, 0.85));
	// Dust settles on the tops of the hoses.
	float top = clamp(wnrm.y, 0.0, 1.0);
	col = mix(col, dust_color, top * top * smoothstep(0.45, 0.75, fbm(wpos * 22.0 + 3.0)) * 0.35);
	ALBEDO = col;
	ROUGHNESS = 0.7 + blotch * 0.25;
	SPECULAR = 0.35;
	NORMAL_MAP = normalize(vec3(-cos(ph) * rib_depth * fade, 0.0, 1.0)) * 0.5 + 0.5;
}
