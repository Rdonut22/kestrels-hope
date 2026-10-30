shader_type spatial;
render_mode cull_back, specular_disabled;

// Giant redwood (world/redwood.gd builds the mesh). One material for the
// whole tree: COLOR carries the bark and foliage colours, UV.x how far out
// along a branch a vertex is (0 = trunk, 1 = branch tip) and UV.y a random
// phase per branch, so each branch sways on its own while the trunk stays
// put. Gusts roll across the forest in world space, like the grass.

group_uniforms wind;
uniform vec2 wind_direction = vec2(1.0, 0.35);
uniform float sway : hint_range(0.0, 2.0) = 0.35;        // metres at a branch tip
uniform float sway_speed : hint_range(0.0, 4.0) = 0.9;
uniform float gust_strength : hint_range(0.0, 3.0) = 0.6;
uniform float gust_scale : hint_range(10.0, 400.0) = 120.0;
uniform float gust_speed : hint_range(0.0, 20.0) = 6.0;
uniform float trunk_sway : hint_range(0.0, 1.0) = 0.25;  // metres at the very top
uniform float tree_height = 48.0;

group_uniforms look;
// Lighter, warmer foliage where it faces the sun; gentle light through needles.
uniform float sun_tint : hint_range(0.0, 1.0) = 0.25;
uniform float translucency : hint_range(0.0, 1.0) = 0.25;
// Set by day_night.gd so the trees darken at night.
uniform vec3 world_tint : source_color = vec3(1.0);

varying float v_flex;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	vec2 dir = normalize(wind_direction);
	float flex = UV.x;
	float phase = UV.y * 6.283;
	float t = TIME;
	float gust = smoothstep(0.5, 0.85, noise(root.xz / gust_scale - dir * t * gust_speed / gust_scale));
	// Whole tree: a slow lean at the top only.
	float h = clamp(VERTEX.y / tree_height, 0.0, 1.0);
	float lean = (sin(t * 0.35 + root.x * 0.05) * 0.5 + 0.5 + gust) * trunk_sway * h * h;
	// Branches: their own rhythm, out of step with each other.
	float b = flex * flex;
	float bob = sin(t * sway_speed + phase) * 0.6 + sin(t * sway_speed * 2.3 + phase * 1.7) * 0.25;
	vec3 disp = vec3(dir.x, 0.0, dir.y) * (lean + b * sway * (0.6 + gust * gust_strength * 2.0));
	disp += vec3(-dir.y, 0.0, dir.x) * b * sway * bob * 0.5;
	disp.y += b * sway * 0.3 * sin(t * sway_speed * 1.3 + phase);
	// Displacement is in world space; convert to the mesh's space.
	VERTEX += (inverse(MODEL_MATRIX) * vec4(disp, 0.0)).xyz;
	v_flex = flex;
}

void fragment() {
	vec3 col = COLOR.rgb;
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	// Foliage (anything that moves) catches the sun on its upper faces.
	float leafy = step(0.05, v_flex);
	col = mix(col, col * vec3(1.18, 1.15, 0.92), sun_tint * leafy * clamp(wn.y, 0.0, 1.0));
	ALBEDO = col * world_tint;
	ROUGHNESS = 0.95;
	BACKLIGHT = col * translucency * leafy;
}
