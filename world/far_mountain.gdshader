shader_type spatial;
render_mode fog_disabled, specular_disabled;

// Distant mountains on the horizon (tools/build_scenes.gd
// _build_far_mountains): forested lower slopes, bare rock on the steep and
// high ground, the odd pale scree, all fading into the sky's haze with
// distance. Like the ruins they ignore the scene fog (they're far beyond
// it); world_tint and haze are set by day_night.gd.

uniform vec3 forest : source_color = vec3(0.16, 0.27, 0.15);
uniform vec3 rock : source_color = vec3(0.46, 0.44, 0.45);
uniform vec3 scree : source_color = vec3(0.62, 0.6, 0.56);
uniform vec3 haze : source_color = vec3(0.52, 0.7, 0.66);
uniform vec3 world_tint : source_color = vec3(1.0);
uniform float haze_start = 600.0;
uniform float haze_end = 4200.0;
uniform float haze_max : hint_range(0.0, 1.0) = 0.55;
// Far-off haze leans towards the sky's blue rather than the forest fog's green.
uniform vec3 sky_haze : source_color = vec3(0.6, 0.72, 0.84);
uniform float tree_line = 380.0;    // metres above the mountain's base

varying vec3 v_obj;
varying vec3 v_wpos;
varying vec3 v_wnrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	v_obj = VERTEX;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(v_wnrm);
	float slope = 1.0 - n.y;
	float h = v_obj.y + (noise(v_obj.xz * 0.01) - 0.5) * 120.0;
	float wood = (1.0 - smoothstep(tree_line - 60.0, tree_line + 60.0, h)) * (1.0 - smoothstep(0.35, 0.6, slope));
	vec3 col = mix(rock * (0.85 + 0.3 * noise(v_obj.xz * 0.03)), forest * (0.8 + 0.4 * noise(v_obj.xz * 0.02)), wood);
	col = mix(col, scree, smoothstep(0.7, 0.85, noise(v_obj.xz * 0.006 + 3.0)) * (1.0 - wood) * 0.5);
	float d = distance(v_wpos, CAMERA_POSITION_WORLD);
	float k = smoothstep(haze_start, haze_end, d) * haze_max;
	// Thicker haze low down, where the mountains meet the forest.
	k = max(k, (1.0 - smoothstep(-40.0, 180.0, v_wpos.y)) * haze_max);
	vec3 hz = mix(haze, sky_haze * dot(haze, vec3(0.33)) / 0.72, 0.6);
	ALBEDO = mix(col * world_tint, hz * world_tint, k);
	ROUGHNESS = 1.0;
}
