shader_type spatial;
render_mode cull_disabled;

// The middle corridor bulkhead (tools/build_scenes.gd): one worn metal
// plate (the user's texture) stretched once across each face, read the
// right way round from either side. Its own shader, not a surface of
// corridor.gdshader: that one already uses as many textures as the
// Compatibility renderer allows on a Mac (16 units, some kept by Godot).

uniform sampler2D plate_albedo : source_color, filter_linear_mipmap;
uniform sampler2D plate_nor : hint_normal, filter_linear_mipmap;
uniform sampler2D plate_rm : hint_default_white, filter_linear_mipmap;  // r roughness, g metal
// The face: x from..to (ship x) and its height.
uniform vec3 span = vec3(-2.3, 2.0, 3.0);
uniform float relief : hint_range(0.0, 2.0) = 0.3;

varying vec3 v_pos;
varying vec3 v_nrm;

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
}

void fragment() {
	vec3 n = normalize(v_nrm);
	float u = (v_pos.x - span.x) / (span.y - span.x);
	if (n.z < 0.0) {
		u = 1.0 - u;
	}
	vec2 puv = clamp(vec2(u, 1.0 - v_pos.y / span.z), 0.0, 1.0);
	vec3 tn = texture(plate_nor, puv).xyz * 2.0 - 1.0;
	tn.xy *= relief;
	tn = normalize(tn);
	ALBEDO = texture(plate_albedo, puv).rgb;
	vec2 rm = texture(plate_rm, puv).rg;
	ROUGHNESS = clamp(rm.r + 0.12, 0.0, 1.0);
	METALLIC = rm.g * 0.45;
	// Tangent frame for a face looking along +/-Z (uv.x runs along -x on
	// the fore face).
	vec3 T = n.z > 0.0 ? vec3(1, 0, 0) : vec3(-1, 0, 0);
	vec3 B = vec3(0, 1, 0);
	vec3 pn = normalize(T * tn.x + B * tn.y + n * tn.z);
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(pn, 0.0)).xyz);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
