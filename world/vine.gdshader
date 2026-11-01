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
uniform vec3 leaf_tint : source_color = vec3(0.86, 0.92, 0.8);
// How much of the photo's colour to keep (it's a saturated variegated ivy).
uniform float leaf_saturation : hint_range(0.0, 1.0) = 0.78;
uniform float translucency : hint_range(0.0, 1.0) = 0.45;
uniform vec3 stem_tint : source_color = vec3(1.1, 1.0, 0.85);
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
		col = t.rgb;
		// Calm the pale variegated rim and the saturation a little.
		float l = dot(col, vec3(0.3, 0.55, 0.15));
		col = mix(vec3(l), col, leaf_saturation);
		col = mix(col, col * vec3(0.86, 0.92, 0.78), smoothstep(0.35, 0.6, l) * 0.6);
		col *= leaf_tint;
		a = t.a;
		// Light through the leaf from behind, warmer and softer.
		BACKLIGHT = col * vec3(1.05, 1.0, 0.7) * translucency;
	} else {
		col = texture(stem_texture, UV).rgb * stem_tint;
	}
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = col * COLOR.rgb * world_tint;
	// Ivy is a little waxy: a soft sheen, never glossy.
	ROUGHNESS = v_leaf > 0.5 ? 0.62 : 0.9;
	SPECULAR = v_leaf > 0.5 ? 0.3 : 0.15;
}
