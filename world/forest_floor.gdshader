shader_type spatial;

// Forest floor: the user's forest_leaves_02 set (colour, normal, roughness,
// height): moss, cracked earth, twigs and fallen leaves. On all exposed
// ground: the clearing, the forest, and (tinted earthier) the crash trail's
// dirt and mounds. Mapped in world space (the ground has no UVs): from
// above on gentle ground, triplanar on steep faces, with anti-tiling: a second,
// rotated and larger sample is blended in by low-frequency noise, and a
// broad colour variation runs across the ground, so the repeat doesn't show
// over the clearing. The height map darkens the hollows. world_tint is set
// by world/day_night.gd (every res://world/ shader material is), so the
// ground darkens at night like before.

uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D height_map : hint_default_white, filter_linear_mipmap, repeat_enable;
// Metres one copy of the texture covers.
uniform float tile = 2.6;
// How strongly the second, rotated sample breaks up the repeat (0..1).
uniform float breakup : hint_range(0.0, 1.0) = 0.6;
// Broad light/dark and green/brown variation across the ground (0..1).
uniform float macro : hint_range(0.0, 1.0) = 0.5;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
// How much the hollows (low in the height map) darken.
uniform float hollow_shade : hint_range(0.0, 1.0) = 0.35;

// Overall colour multiplier (the bare dirt of the crash trail and mounds is
// a touch earthier than the forest floor).
uniform vec3 tint : source_color = vec3(1.0);

// Set by day_night.gd.
uniform vec3 world_tint : source_color = vec3(1.0);

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// The normal map is imported in normal-map mode (RGTC: red and green
// only), so its blue channel reads empty: rebuild z from x and y.
vec3 unpack_normal(vec4 t) {
	vec2 xy = t.xy * 2.0 - 1.0;
	return vec3(xy, sqrt(max(0.0, 1.0 - dot(xy, xy))));
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// One side projection (for steep faces: the mounds' flanks, banks):
// colour, height, roughness, and the world-space normal.
void side(vec2 uv, vec3 axis, vec3 t, vec3 b, out vec3 c, out float h, out float r, out vec3 wn) {
	c = texture(color_map, uv).rgb;
	h = texture(height_map, uv).r;
	r = texture(rough_map, uv).r;
	vec3 tn = unpack_normal(texture(normal_map, uv));
	tn.xy *= normal_strength;
	wn = normalize(t * tn.x + b * tn.y + axis * tn.z);
}

void fragment() {
	vec3 N = normalize(wnrm);

	// ---- From above (most of the ground), with anti-tiling ----
	vec2 p = wpos.xz;
	// Two samples: the base one, and one rotated ~40 degrees and 1.7x larger.
	const float A = 0.7;
	mat2 rot = mat2(vec2(cos(A), sin(A)), vec2(-sin(A), cos(A)));
	vec2 uv1 = p / tile;
	vec2 uv2 = rot * p / (tile * 1.7) + vec2(0.37, 0.71);
	float w = smoothstep(0.3, 0.7, noise(p * 0.11)) * breakup;

	vec3 col = mix(texture(color_map, uv1).rgb, texture(color_map, uv2).rgb, w);
	float h = mix(texture(height_map, uv1).r, texture(height_map, uv2).r, w);
	float r = mix(texture(rough_map, uv1).r, texture(rough_map, uv2).r, w);
	vec3 n1 = unpack_normal(texture(normal_map, uv1));
	vec3 n2 = unpack_normal(texture(normal_map, uv2));
	// The second sample's normal back into the base orientation.
	n2.xy = transpose(rot) * n2.xy;
	vec3 tn = normalize(mix(n1, n2, w));
	tn.xy *= normal_strength;
	// Tangent space for the map projected from above, on a sloping ground.
	// GL normal map: green points to the image's top, i.e. towards -v; v
	// runs along +z here, so the bitangent is -z on flat ground.
	vec3 T = normalize(vec3(1.0, 0.0, 0.0) - N * N.x);
	vec3 B = normalize(cross(N, T));
	vec3 wn = normalize(T * tn.x + B * tn.y + N * tn.z);

	// ---- Steep faces: blend in projections from the sides (triplanar) ----
	vec3 bw = pow(abs(N), vec3(4.0));
	bw /= bw.x + bw.y + bw.z;
	if (bw.y < 0.98) {
		vec3 cx; float hx; float rx; vec3 nx;
		vec3 cz; float hz; float rz; vec3 nz;
		float sx = sign(N.x);
		float sz = sign(N.z);
		side(vec2(wpos.z * sx, wpos.y) / tile + 0.5, vec3(sx, 0.0, 0.0), vec3(0.0, 0.0, sx), vec3(0.0, 1.0, 0.0), cx, hx, rx, nx);
		side(vec2(-wpos.x * sz, wpos.y) / tile + 0.25, vec3(0.0, 0.0, sz), vec3(-sz, 0.0, 0.0), vec3(0.0, 1.0, 0.0), cz, hz, rz, nz);
		col = col * bw.y + cx * bw.x + cz * bw.z;
		h = h * bw.y + hx * bw.x + hz * bw.z;
		r = r * bw.y + rx * bw.x + rz * bw.z;
		wn = normalize(wn * bw.y + nx * bw.x + nz * bw.z);
	}

	// Broad variation: lighter/darker and greener/browner patches.
	float m1 = noise(p * 0.035);
	float m2 = noise(p * 0.013 + 17.0);
	col *= mix(1.0, 0.8 + 0.4 * m1, macro);
	col = mix(col, col * vec3(0.92, 1.05, 0.88), smoothstep(0.4, 0.8, m2) * macro);
	col = mix(col, col * vec3(1.06, 0.97, 0.9), smoothstep(0.6, 0.2, m2) * macro);
	// Hollows darker.
	col *= mix(1.0 - hollow_shade, 1.0, smoothstep(0.15, 0.7, h));

	ALBEDO = col * tint * world_tint;
	ROUGHNESS = mix(0.75, 1.0, r);
	METALLIC = 0.0;
	SPECULAR = 0.3;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
