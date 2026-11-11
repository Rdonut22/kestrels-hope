shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

// Glowing silhouette for the object Gana is looking at (interactable.gd):
// an inverted hull, the mesh pushed outwards a few millimetres and only its
// back faces drawn, so a bright rim shows around the object's edge.
// Vertices move away from the mesh's centre on each axis, which keeps box
// corners closed.

uniform vec3 center = vec3(0.0);
// Outline width in metres at 1 m from the camera; it grows with distance so
// it stays about the same width on screen.
uniform float width = 0.0035;
uniform vec4 color : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform float energy = 1.6;
uniform float fade = 1.0;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(CAMERA_POSITION_WORLD - world);
	vec3 d = VERTEX - center;
	vec3 push = sign(d) * step(vec3(0.0005), abs(d));
	// Undo the node's scale so the outline is the same in every direction.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	VERTEX += push * width * clamp(dist, 0.6, 6.0) / max(scale, vec3(0.0001));
}

void fragment() {
	float pulse = 0.85 + 0.15 * sin(TIME * 3.0);
	ALBEDO = color.rgb * energy * pulse;
	ALPHA = fade;
}
