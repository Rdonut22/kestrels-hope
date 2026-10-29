shader_type spatial;
render_mode cull_disabled, world_vertex_coords, specular_disabled;

// Low-poly meadow grass (world/grass_tuft.gd builds the tufts). The wind is
// worked out in world space, so whole patches lean together as waves roll
// across the field; each blade adds a little flutter of its own.
// Mesh data: UV.y = height up the tuft (0 root .. 1 tallest tip),
// UV.x = per-blade random, COLOR = blade shade (times the instance colour).

group_uniforms wind;
uniform vec2 wind_direction = vec2(1.0, 0.35);
uniform float wind_strength : hint_range(0.0, 2.0) = 0.55;  // lean in the waves
uniform float wind_speed : hint_range(0.0, 10.0) = 2.4;     // m/s the waves travel
uniform float wave_scale : hint_range(1.0, 60.0) = 14.0;    // wave size (m)
uniform float gust_strength : hint_range(0.0, 2.0) = 0.7;   // extra lean in gusts
uniform float gust_scale : hint_range(5.0, 200.0) = 45.0;   // gust size (m)
uniform float gust_speed : hint_range(0.0, 20.0) = 5.0;
uniform float flutter : hint_range(0.0, 1.0) = 0.12;        // per-blade wobble

group_uniforms look;
uniform vec3 root_shade : source_color = vec3(0.66, 0.72, 0.55);
uniform vec3 tip_tint : source_color = vec3(1.08, 1.06, 0.82);
uniform float sheen : hint_range(0.0, 1.0) = 0.22;          // waves catch the light
// Set by day_night.gd so the grass darkens at night.
uniform vec3 world_tint : source_color = vec3(1.0);

group_uniforms push;
// Set each frame by world/grass_field.gd: blades bend away from Gana.
uniform vec3 player_pos = vec3(0.0, -1000.0, 0.0);
uniform float push_radius = 1.1;

group_uniforms distance;
// Blades sink into the ground towards the edge of the grass's range.
uniform float fade_start = 34.0;
uniform float fade_end = 44.0;

varying float v_height;
varying float v_lean;
varying vec3 v_normal;

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
	float size = length(MODEL_MATRIX[1].xyz);
	float h = UV.y;
	float rnd = hash(root.xz);
	vec2 dir = normalize(wind_direction);
	vec2 side = vec2(-dir.y, dir.x);
	float t = TIME;
	// Big slow waves travelling along the wind, two layers at slightly
	// different angles so the fronts aren't ruler-straight.
	vec2 p1 = root.xz / wave_scale - dir * t * wind_speed / wave_scale;
	vec2 p2 = (root.xz + side * 9.0) / (wave_scale * 0.55) - (dir + side * 0.25) * t * wind_speed * 1.15 / (wave_scale * 0.55);
	float wave = noise(p1) * 0.65 + noise(p2) * 0.35;
	// Occasional gusts: broad bands rolling through faster.
	float g = noise(root.xz / gust_scale - dir * t * gust_speed / gust_scale);
	float gust = smoothstep(0.58, 0.85, g);
	float lean = wind_strength * (0.25 + 0.75 * wave) + gust_strength * gust;
	lean *= 0.85 + 0.3 * rnd;
	// Each blade flutters a little out of step.
	float ph = rnd * 6.283 + UV.x * 6.283;
	float fl = sin(t * (2.6 + UV.x * 1.6) + ph + dot(root.xz, dir) * 0.6) * flutter * (0.6 + wave + gust);
	// Bend: stiff at the root, most at the tips.
	float bend = h * h;
	vec2 push = dir * lean + side * fl;
	// Pushed aside where Gana walks.
	vec2 away = root.xz - player_pos.xz;
	float near = (1.0 - smoothstep(0.2, push_radius, length(away))) * step(abs(root.y - player_pos.y), 2.0);
	push += normalize(away + vec2(0.001)) * near * 1.4;
	float amount = length(push);
	VERTEX.xz += push * bend * size;
	// Keep blade length roughly constant: tips dip as they lean.
	VERTEX.y -= bend * size * min(amount * amount * 0.35, 0.7);
	// Sink into the ground towards the far edge of the grass.
	float dist = distance(root, INV_VIEW_MATRIX[3].xyz);
	float grow = 1.0 - smoothstep(fade_start, fade_end, dist);
	VERTEX = root + (VERTEX - root) * grow;
	// Soft, even shading: normals mostly up, like a carpet of grass.
	// Both sides of a blade light the same (no black back faces).
	vec3 n = NORMAL * sign(NORMAL.y + 0.0001);
	v_normal = normalize(mix(n, vec3(0.0, 1.0, 0.0), 0.7));
	v_height = h;
	v_lean = clamp(wave * 0.6 + gust, 0.0, 1.0);
}

void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(v_normal, 0.0)).xyz);
	vec3 col = COLOR.rgb;
	// Darker at the roots, sun-bleached at the tips.
	col *= mix(root_shade, tip_tint, smoothstep(0.0, 1.0, v_height));
	// Wave crests lighten as the blades tip over and catch the sky.
	col = mix(col, col * 1.35 + vec3(0.04, 0.05, 0.0), sheen * v_lean * v_height);
	ALBEDO = col * world_tint;
	ROUGHNESS = 0.85;
}
