shader_type spatial;
render_mode unshaded, cull_disabled, world_vertex_coords, shadows_disabled;

// A far tree as a flat cut-out of its outline (world/render_budget.gd),
// turned to face the camera about its trunk. Only drawn where the fog is
// solid, so all that shows is the fog colour in the tree's shape: the fog
// does the colouring. Within `near_cut` (and past `far_cut`, when set) of
// the camera it isn't drawn; the real tree is there.

uniform sampler2D mask : hint_default_transparent, filter_linear_mipmap, repeat_disable;
uniform float half_side = 30.0;   // the outline's square, in the tree's units
uniform float centre_y = 30.0;
uniform float near_cut = 115.0;
uniform float far_cut = 0.0;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 centre = origin + vec3(0.0, centre_y * s, 0.0);
	float d = distance(cam, centre);
	vec2 to = cam.xz - origin.xz;
	vec2 f = to / max(length(to), 0.001);
	vec3 right = vec3(-f.y, 0.0, f.x);
	vec2 corner = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0) * half_side;
	VERTEX = centre + (right * corner.x + vec3(0.0, corner.y, 0.0)) * s;
	if (d < near_cut || (far_cut > 0.0 && d > far_cut)) {
		VERTEX = origin;  // collapsed: nothing drawn
	}
}

void fragment() {
	if (texture(mask, UV).a < 0.5) {
		discard;
	}
	ALBEDO = vec3(0.5);
}
