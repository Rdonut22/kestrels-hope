shader_type spatial;

// The kitchen stove (ship/models/stove, the user's textured model): its own
// colour, normal and metal/roughness maps, plus a glow map for the rings
// round the knobs and the centre display (ship/models/stove/stove_glow.png,
// traced at texture resolution so the lit edges stay crisp).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D mr_tex : hint_default_white, filter_linear_mipmap, repeat_enable;   // g roughness, b metal
uniform sampler2D glow_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float glow_energy = 1.4;

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
	vec3 mr = texture(mr_tex, UV).rgb;
	ROUGHNESS = mr.g;
	METALLIC = mr.b;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	EMISSION = texture(glow_tex, UV).rgb * glow_energy;
}
