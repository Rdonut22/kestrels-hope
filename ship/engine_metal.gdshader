shader_type spatial;
render_mode cull_disabled;

// Bare engine metal for the Kestrel's turbines, after the Razor Crest
// reference: dark brushed gunmetal with worn, shinier patches and edges,
// and (polished = true) mirror-like chrome for the intake hub and rings.
// The game's reflections are off (GL Compatibility), so the sky / ground
// reflection that makes metal read as metal is faked here from the
// reflection vector, stronger at grazing angles.
// Wear comes from the Razor Crest roughness tile (ship/textures/hull_wear.png),
// projected triplanar in metres.

uniform vec3 base_color : source_color = vec3(0.5, 0.49, 0.47);
uniform bool polished = false;
uniform sampler2D wear_map : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float wear_size = 2.5;
uniform float wear_strength : hint_range(0.0, 1.0) = 0.8;
uniform vec3 sky_top : source_color = vec3(0.45, 0.6, 0.85);
uniform vec3 sky_horizon : source_color = vec3(0.85, 0.88, 0.9);
uniform vec3 ground : source_color = vec3(0.3, 0.32, 0.25);
uniform float reflect_strength : hint_range(0.0, 2.0) = 0.8;

varying vec3 v_pos;
varying vec3 v_nrm;

void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	v_pos = VERTEX * sc;
	v_nrm = normalize(NORMAL);
}

float wear(vec2 uv) {
	vec2 q = uv / wear_size;
	q = 1.0 - abs(1.0 - mod(q, 2.0));
	return texture(wear_map, q).r;
}

void fragment() {
	vec3 n = normalize(v_nrm);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float wr = wear(v_pos.zy) * w.x + wear(v_pos.xz + 7.0) * w.y + wear(v_pos.xy + 3.0) * w.z;
	// Fine brushing along the engine's length (z).
	float brush = fract(sin(dot(floor(v_pos.xy * 180.0), vec2(12.9898, 78.233))) * 43758.5453);

	vec3 nv = normalize(NORMAL);
	if (!FRONT_FACING) {
		nv = -nv;
		NORMAL = nv;
	}
	vec3 v = normalize(VIEW);
	float fres = pow(1.0 - clamp(dot(nv, v), 0.0, 1.0), 3.0);
	vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-v, nv), 0.0)).xyz;
	vec3 env = r.y > 0.0 ? mix(sky_horizon, sky_top, smoothstep(0.0, 0.6, r.y)) : mix(sky_horizon, ground, smoothstep(0.0, 0.25, -r.y));

	if (polished) {
		ALBEDO = vec3(0.75, 0.76, 0.78);
		METALLIC = 1.0;
		ROUGHNESS = 0.12 + 0.15 * wr;
		EMISSION = env * reflect_strength * (0.55 + 0.45 * fres);
	} else {
		// Worn smooth (dark in the map) = brighter, shinier steel;
		// dusty (bright) = duller, a little lighter and greyer.
		vec3 col = base_color * (0.92 + 0.12 * brush);
		col = mix(col, col * vec3(1.05, 1.0, 0.92) * 0.8, smoothstep(0.55, 0.95, wr) * wear_strength);
		ALBEDO = col;
		METALLIC = mix(0.85, 0.55, wr * wear_strength);
		ROUGHNESS = mix(0.32, 0.75, wr * wear_strength);
		EMISSION = env * reflect_strength * (0.18 + 0.82 * fres) * mix(1.0, 0.35, wr * wear_strength) * 0.6;
	}
}
