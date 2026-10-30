shader_type spatial;
render_mode cull_disabled;

// Butterfly (world/butterfly.gd, model world/models/butterfly.res). The
// model has no animation: its wings, spread in the XZ plane either side of
// the body, flap here by turning about the body's axis. Each butterfly has
// its own rhythm, and some have their wing colours shifted round the hue
// wheel, from where they are in the world.

uniform vec3 albedo : source_color = vec3(1.0);
uniform float flap_speed = 18.0;     // radians per second
uniform float flap_angle = 0.9;      // radians up and down
uniform float hinge_x = -0.021;      // body centre line (mesh units)
uniform float body_half_width = 0.05;

varying float v_seed;

vec3 hue_shift(vec3 c, float a) {
	const vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

void vertex() {
	v_seed = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
	float x = VERTEX.x - hinge_x;
	float wing = smoothstep(body_half_width, body_half_width * 2.5, abs(x)) * sign(x);
	float a = sin(TIME * flap_speed + v_seed * 6.283) * flap_angle * wing;
	float c = cos(a);
	float s = sin(a);
	VERTEX.xy = vec2(hinge_x + c * x - s * VERTEX.y, s * x + c * VERTEX.y);
	NORMAL.xy = vec2(c * NORMAL.x - s * NORMAL.y, s * NORMAL.x + c * NORMAL.y);
}

void fragment() {
	vec3 col = albedo;
	float sat = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
	if (v_seed > 0.45 && sat > 0.3) {
		col = clamp(hue_shift(col, (v_seed - 0.45) * 9.0), 0.0, 1.0);
	}
	ALBEDO = col;
	ROUGHNESS = 0.8;
}
