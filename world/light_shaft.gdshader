shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// A shaft of sunlight (world/greenhouse.gd): an open cylinder along the
// light, glowing softly. Brightest along its core as seen from the camera
// (the cylinder's edge-on sides fade out), fading in from the gap at its
// top and out where it lands, with a slow shimmer along it.

uniform vec3 color : source_color = vec3(1.0, 0.9, 0.7);
uniform float strength = 0.15;
instance uniform float fade = 1.0;

varying float along;
varying vec3 wpos;

void vertex() {
	along = VERTEX.y + 0.5;           // 0 where it lands, 1 at the gap
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float core = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float ends = smoothstep(0.0, 0.18, along) * smoothstep(1.0, 0.82, along);
	float shimmer = 0.8 + 0.2 * sin(wpos.y * 1.7 + TIME * 0.6 + wpos.x * 0.9);
	ALBEDO = color * strength * fade * core * ends * shimmer;
}
