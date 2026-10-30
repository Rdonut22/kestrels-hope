shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled, shadows_disabled;

// Thin glow of sunlit atmosphere just outside the giant moon's lit limb
// (world/sky_moons.gd): a camera-facing quad behind it. Fades into the haze
// low down and hides behind the mountains, like the moon.

#include "res://world/sky_common.gdshaderinc"

uniform vec3 direction = vec3(0.0, 0.5, -1.0);
uniform float angular_radius = 0.2;
uniform float distance_m = 3000.0;
uniform float halo_size = 1.25;         // quad radius in moon radii
uniform float strength : hint_range(0.0, 2.0) = 0.5;
uniform vec3 key_light = vec3(-0.8, 0.3, 0.5);
uniform float haze_top = -10.0;
uniform float haze_bottom = -11.0;
uniform float day = 1.0;
uniform float dusk = 0.0;
uniform mat3 sky_rot = mat3(1.0);
uniform float mountains = 1.0;
uniform float space = 0.0;
uniform float pixel = 0.004;

varying vec3 v_pos;
varying vec2 v_q;
varying vec2 v_light;

void vertex() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	mat3 to_world = transpose(sky_rot);
	vec3 dir = normalize(direction);
	float rad = distance_m * sin(angular_radius);
	vec3 centre = to_world * dir * distance_m * 1.002;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 wpos = cam + centre + (right * VERTEX.x + up * VERTEX.y) * rad * halo_size;
	v_pos = sky_rot * (wpos - cam);
	v_q = VERTEX.xy * halo_size;
	vec3 lw = to_world * normalize(key_light);
	v_light = normalize(vec2(dot(lw, right), dot(lw, up)) + vec2(0.0001));
	VERTEX = (VIEW_MATRIX * vec4(wpos, 1.0)).xyz;
}

void fragment() {
	vec3 d = normalize(v_pos);
	float az = atan(d.x, -d.z);
	float el = asin(clamp(d.y, -1.0, 1.0));
	float saz = floor(az / pixel) * pixel;
	float sel = floor(el / pixel) * pixel;
	if (el < 0.0 || sel < skyline_top(saz, mountains)) {
		discard;
	}
	float r = length(v_q);
	float g = smoothstep(0.985, 1.01, r) * exp(-(r - 1.0) * 14.0);
	float side = smoothstep(-0.2, 0.7, dot(v_q / max(r, 0.001), v_light));
	float haze = smoothstep(haze_top, haze_bottom, el);
	float amount = strength * mix(0.6, 0.35, day) * (1.0 - haze) * (1.0 - space);
	ALBEDO = vec3(0.72, 0.9, 1.0) * g * side * amount;
}
