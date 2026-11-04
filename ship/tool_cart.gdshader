shader_type spatial;

// Tool cart (ship/tool_cart.gd): the user's tool-cart texture set on a
// procedural cart. UVs point into the set's atlas. With the colour map:
// it's used as is; without it, paint vs bare steel comes from the metal map
// and the worn, rusty patches from the roughness map.

uniform sampler2D albedo_map : source_color, filter_linear_mipmap, hint_default_black;
uniform bool has_albedo = false;
uniform sampler2D metal_map : hint_default_black, filter_linear_mipmap;
uniform sampler2D rough_map : hint_default_white, filter_linear_mipmap;
uniform vec3 paint : source_color = vec3(0.32, 0.44, 0.37);
uniform vec3 rust : source_color = vec3(0.3, 0.17, 0.1);
uniform vec3 steel : source_color = vec3(0.62, 0.63, 0.64);

void fragment() {
	float m = texture(metal_map, UV).r;
	float r = texture(rough_map, UV).r;
	vec3 col;
	if (has_albedo) {
		col = texture(albedo_map, UV).rgb;
	} else {
		col = mix(paint, rust, smoothstep(0.72, 0.95, r) * 0.8);
		col = mix(col, steel, m);
	}
	ALBEDO = col;
	METALLIC = m;
	ROUGHNESS = r;
}
