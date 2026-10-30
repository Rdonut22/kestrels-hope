// Shared wind for the redwood bark and foliage (world/redwood.gd).
// UV2.x = how far out along a branch (0 trunk .. 1 tip), UV2.y = a random
// phase per branch, so each branch sways on its own while the trunk barely
// moves. Gusts roll across the forest in world space, like the grass.

uniform vec2 wind_direction = vec2(1.0, 0.35);
uniform float sway : hint_range(0.0, 2.0) = 0.4;          // metres at a branch tip
uniform float sway_speed : hint_range(0.0, 4.0) = 0.8;
uniform float gust_strength : hint_range(0.0, 3.0) = 0.7;
uniform float gust_scale : hint_range(10.0, 400.0) = 120.0;
uniform float gust_speed : hint_range(0.0, 20.0) = 6.0;
uniform float trunk_sway : hint_range(0.0, 2.0) = 0.35;   // metres at the very top
uniform float tree_height = 64.0;

float rw_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rw_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(rw_hash(i), rw_hash(i + vec2(1.0, 0.0)), f.x),
			mix(rw_hash(i + vec2(0.0, 1.0)), rw_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// World-space offset for a vertex at mesh-space `v`.
vec3 rw_wind(vec3 v, vec2 data, mat4 model, float t) {
	vec3 root = model[3].xyz;
	vec2 dir = normalize(wind_direction);
	float gust = smoothstep(0.5, 0.85, rw_noise(root.xz / gust_scale - dir * t * gust_speed / gust_scale));
	float h = clamp(v.y / tree_height, 0.0, 1.0);
	float lean = (sin(t * 0.3 + root.x * 0.05) * 0.5 + 0.5 + gust) * trunk_sway * h * h;
	float b = data.x * data.x;
	float phase = data.y * 6.283;
	float bob = sin(t * sway_speed + phase) * 0.6 + sin(t * sway_speed * 2.3 + phase * 1.7) * 0.25;
	vec3 disp = vec3(dir.x, 0.0, dir.y) * (lean + b * sway * (0.5 + gust * gust_strength * 2.0));
	disp += vec3(-dir.y, 0.0, dir.x) * b * sway * bob * 0.5;
	disp.y += b * sway * 0.35 * sin(t * sway_speed * 1.3 + phase);
	return disp;
}
