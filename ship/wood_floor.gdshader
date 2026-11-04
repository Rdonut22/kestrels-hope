shader_type spatial;

// Old wooden plank floor (the user's old_wooden_floor_03 set) for the
// quarters and the kitchen. Projected from above in ship space (metres),
// planks running fore-aft. The colour map is slightly darkened and
// desaturated toward walnut so it doesn't read orange.

uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_map : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float tile = 2.4;               // metres per texture repeat
uniform float darken : hint_range(0.0, 1.0) = 0.25;
uniform float desaturate : hint_range(0.0, 1.0) = 0.3;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;

varying vec3 v_pos;

void vertex() {
	v_pos = VERTEX;
}

void fragment() {
	// Planks run along z (fore-aft): texture v along z.
	vec2 uv = vec2(v_pos.x, -v_pos.z) / tile;
	vec3 col = texture(albedo_map, uv).rgb;
	float l = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(l), desaturate) * (1.0 - darken);
	ALBEDO = col;
	ROUGHNESS = mix(0.55, 0.9, texture(rough_map, uv).r);
	METALLIC = 0.0;
	SPECULAR = 0.35;
	vec3 n = texture(normal_map, uv).xyz * 2.0 - 1.0;
	n.xy *= normal_strength;
	n = normalize(n);
	// Tangent frame for a floor facing up: T = +x, B = -z (uv.y), N = +y.
	vec3 wn = normalize(vec3(1, 0, 0) * n.x + vec3(0, 0, -1) * n.y + vec3(0, 1, 0) * n.z);
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(wn, 0.0)).xyz);
}
