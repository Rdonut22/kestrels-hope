shader_type spatial;
render_mode cull_disabled;

// Vines and small plants reclaiming the wreck (world/vine_growth.gd). Stems
// are thin tubes in the ivy bark texture, leaves are cards cut out of the
// ivy leaf texture (both from world/models/source/ivy). Growth happens here:
// every vertex knows how far along its vine it sits, when the vine sprouted
// and how fast it grows, so as `age` (in-game days) rises the stems extend
// from their tips and the leaves unfurl, smoothly, with nothing rebuilt.
//
// CUSTOM0 = (distance along the vine in m, sprout day, growth m/day,
//            0 stem / 1 leaf), CUSTOM1 = (point the vertex grows out of:
//            the stem's centre or the leaf's stalk, sway).

uniform sampler2D leaf_texture : source_color, filter_linear_mipmap;
uniform sampler2D stem_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float age = 0.0;
uniform vec3 leaf_tint : source_color = vec3(0.78, 0.9, 0.7);
uniform vec3 stem_tint : source_color = vec3(0.8, 0.72, 0.62);
uniform float unfurl = 0.35;     // metres of growth over which a leaf opens
uniform float sway = 0.04;
// Set by day_night.gd so the plants darken at night.
uniform vec3 world_tint : source_color = vec3(1.0);

varying float v_leaf;

void vertex() {
	float grown = max(age - CUSTOM0.y, 0.0) * CUSTOM0.z;
	float s = smoothstep(CUSTOM0.x, CUSTOM0.x + (CUSTOM0.w > 0.5 ? unfurl : 0.12), grown);
	vec3 base = CUSTOM1.xyz;
	VERTEX = base + (VERTEX - base) * s;
	// Hanging stems and leaves stir a little in the breeze.
	vec3 w = (MODEL_MATRIX * vec4(base, 1.0)).xyz;
	VERTEX.xz += vec2(sin(TIME * 1.3 + w.x * 0.7 + w.y), cos(TIME * 1.1 + w.z * 0.6)) * CUSTOM1.w * sway * s;
	v_leaf = CUSTOM0.w;
}

void fragment() {
	vec3 col;
	float a = 1.0;
	if (v_leaf > 0.5) {
		vec4 t = texture(leaf_texture, UV);
		col = t.rgb * leaf_tint;
		a = t.a;
		BACKLIGHT = col * 0.3;
	} else {
		col = texture(stem_texture, UV).rgb * stem_tint;
	}
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = col * COLOR.rgb * world_tint;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
