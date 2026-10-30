shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, skip_vertex_transform, fog_disabled, shadows_disabled;

// One of the two sky moons (world/sky_moons.gd). A unit sphere placed far out
// along `direction` from wherever the camera is, so it hangs in the sky and
// can't be walked up to. Directions are in the sky's frame (`sky_rot` turns
// world directions into it, as in the descent sky).
//
// Surface: procedural craters (three sizes, with raised rims), maria, ridges
// and fine fbm, bump-lit from `key_light`. `kind` 0 = the giant icy-blue
// moon with a faint pearl sheen, 1 = the small silver-blue one. The lit side
// shows its detail and a soft atmospheric rim; the shadowed side is only a
// slightly deeper blue in daylight. Low down the giant sinks into the
// atmosphere (haze_top..haze_bottom); clouds pass in front; the mountains
// (the same skyline the sky paints) hide it.

#include "res://world/sky_common.gdshaderinc"

uniform int kind = 0;
uniform vec3 direction = vec3(0.0, 0.5, -1.0);
uniform float angular_radius = 0.2;      // radians
uniform float distance_m = 3000.0;       // set from the camera's far plane
uniform mat3 orient = mat3(1.0);         // spin of the surface
uniform float seed = 1.0;
// Direction the moons are lit from (sky frame): the same for both, so their
// crescents agree.
uniform vec3 key_light = vec3(-0.8, 0.3, 0.5);
uniform float iridescence : hint_range(0.0, 1.5) = 1.0;
uniform float crater_depth : hint_range(0.0, 3.0) = 1.0;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.6;
// How much of the shadowed body shows against the day sky.
uniform float dark_alpha : hint_range(0.0, 1.0) = 0.3;
// Elevations (radians) where the atmosphere starts to swallow it and where
// it's gone.
uniform float haze_top = -10.0;
uniform float haze_bottom = -11.0;

// From the sky / day-night cycle.
uniform float day = 1.0;
uniform float dusk = 0.0;
uniform vec3 sun_dir = vec3(0.6, 0.6, 0.3);
uniform mat3 sky_rot = mat3(1.0);
uniform float mountains = 1.0;
uniform float space = 0.0;
uniform float pixel = 0.004;

varying vec3 v_local;
varying vec3 v_pos;   // sky frame, relative to the camera
varying vec3 v_nrm;   // sky frame

vec3 hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash3(i).x;
	float b = hash3(i + vec3(1, 0, 0)).x;
	float c = hash3(i + vec3(0, 1, 0)).x;
	float d = hash3(i + vec3(1, 1, 0)).x;
	float e = hash3(i + vec3(0, 0, 1)).x;
	float g = hash3(i + vec3(1, 0, 1)).x;
	float h = hash3(i + vec3(0, 1, 1)).x;
	float k = hash3(i + vec3(1, 1, 1)).x;
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y), mix(mix(e, g, f.x), mix(h, k, f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise3(p);
		p = p * 2.03 + 17.1;
		a *= 0.5;
	}
	return v;
}

// Craters on a jittered 3D grid: a bowl inside, a raised rim, flat beyond.
float craters(vec3 q, float s, float density) {
	vec3 cell = floor(q);
	float h = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 c = cell + vec3(float(x), float(y), float(z));
				vec3 r = hash3(c + s * 13.7);
				if (r.x > density) {
					continue;
				}
				vec3 centre = c + 0.25 + 0.5 * hash3(c + s * 7.3 + 3.1);
				float rad = mix(0.15, 0.48, r.y * r.y);
				float d = length(q - centre) / rad;
				if (d < 1.7) {
					float bowl = d < 1.0 ? (d * d - 1.0) * 0.7 : 0.0;
					float rim = exp(-pow((d - 1.0) / 0.2, 2.0)) * 0.3;
					h += (bowl + rim) * rad * (0.6 + 0.6 * r.z);
				}
			}
		}
	}
	return h;
}

float relief(vec3 p) {
	float h = craters(p * 2.6 + seed, seed, 0.45) * 0.9;
	h += craters(p * 6.5 + seed * 2.0, seed + 1.0, 0.32) * 0.4;
	h += craters(p * 15.0 + seed * 3.0, seed + 2.0, 0.45) * 0.16;
	// Ridges and valleys.
	float ridge = 1.0 - abs(noise3(p * 3.0 + seed * 5.0) * 2.0 - 1.0);
	h += (ridge * ridge - 0.4) * 0.08;
	h += (fbm3(p * 9.0 + seed) - 0.5) * 0.06;
	return h * crater_depth;
}

void vertex() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	mat3 to_world = transpose(sky_rot);
	vec3 dir = normalize(direction);
	float rad = distance_m * sin(angular_radius);
	vec3 local = orient * VERTEX;
	v_local = VERTEX;
	v_pos = dir * distance_m + local * rad;
	v_nrm = local;
	vec3 wpos = cam + to_world * v_pos;
	VERTEX = (VIEW_MATRIX * vec4(wpos, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(to_world * local, 0.0)).xyz);
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
	vec3 p = normalize(v_local);
	float h = relief(p);
	// Bump: surface gradient from screen-space derivatives of the relief.
	vec3 n = normalize(v_nrm);
	vec3 dpx = dFdx(v_pos);
	vec3 dpy = dFdy(v_pos);
	vec3 r1 = cross(dpy, n);
	vec3 r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	float rad = distance_m * sin(angular_radius);
	vec3 grad = (dFdx(h) * r1 + dFdy(h) * r2) / (abs(det) > 1e-9 ? det : 1e-9);
	vec3 nb = normalize(n - grad * rad * 1.1);

	vec3 to_cam = -d;
	float ndv = clamp(dot(n, to_cam), 0.0, 1.0);
	float night = 1.0 - day;
	// Low down it sinks into the atmosphere: haze by elevation (a horizontal
	// layer, broken up by soft cloud), not a circular mask.
	float wisps = fbm3(d * 9.0 + vec3(TIME * 0.002, 0.0, 0.0));
	float haze = smoothstep(haze_top, haze_bottom, el + (wisps - 0.5) * 0.09);
	nb = normalize(mix(nb, n, haze * 0.8));
	vec3 l = normalize(key_light);
	float ndl = dot(nb, l);
	float lit = smoothstep(-0.05, 0.45, ndl) * (0.8 + 0.2 * clamp(ndl * 2.0, 0.0, 1.0));
	// The terminator follows the sphere, not the bumps: no lit crater rims
	// scattered across the night side.
	lit *= smoothstep(-0.12, 0.12, dot(n, l));

	float maria = smoothstep(0.42, 0.62, fbm3(p * 1.7 + seed * 9.0));
	float speck = fbm3(p * 30.0 + seed);
	vec3 col;
	if (kind == 0) {
		// Pale icy blue: bright highlands, bluer lowland plains, and a faint
		// pearl sheen (cyan to lavender to violet) following the minerals.
		vec3 rock = mix(vec3(0.84, 0.91, 0.98), vec3(0.6, 0.7, 0.86), maria);
		rock *= 0.92 + 0.16 * speck + h * 0.6;
		float film = fbm3(p * 1.4 + seed * 4.0) + h * 0.8 + (1.0 - ndv) * 0.25;
		vec3 pearl = mix(vec3(0.78, 0.95, 1.0), vec3(0.86, 0.8, 1.0), 0.5 + 0.5 * sin(film * 6.2831));
		pearl = mix(pearl, vec3(0.74, 0.68, 0.98), smoothstep(0.65, 0.95, fract(film * 0.7)) * 0.35);
		col = rock * mix(vec3(1.0), pearl * 1.08, clamp(iridescence, 0.0, 1.5) * 0.5);
	} else {
		vec3 rock = mix(vec3(0.84, 0.86, 0.9), vec3(0.52, 0.56, 0.62), maria);
		col = rock * (0.9 + 0.2 * speck + h * 0.7);
	}
	vec3 light = mix(vec3(1.0, 0.99, 0.97), vec3(1.0, 0.86, 0.76), dusk * 0.5);
	vec3 shade = col * light * lit;
	// The shadowed side: a slightly deeper blue than the sky by day, a dark
	// disc hiding the stars at night.
	vec3 body = mix(vec3(0.035, 0.05, 0.1), vec3(0.32, 0.46, 0.74), day);
	shade = mix(body, shade, smoothstep(0.0, 0.3, lit));
	// Delicate cyan-white rim of sunlit atmosphere along the lit limb.
	float rim = pow(1.0 - ndv, 4.0) * smoothstep(-0.2, 0.5, dot(n, l));
	shade += vec3(0.75, 0.92, 1.0) * rim * rim_strength * (kind == 0 ? 1.0 : 0.4);
	// Detail softens into the haze.
	vec3 mist = mix(vec3(0.06, 0.08, 0.14), vec3(0.8, 0.88, 0.96), day);
	shade = mix(shade, mist, haze * 0.5);
	ALBEDO = shade;

	float lit_a = smoothstep(0.0, 0.35, dot(n, l));
	float a = mix(mix(0.82, dark_alpha, day), 1.0, lit_a);
	a *= mix(1.0, 0.9, day);
	// Soft edge where the shadowed limb meets the sky.
	a *= mix(smoothstep(0.0, 0.3, ndv), 1.0, lit_a);
	a *= 1.0 - haze;
	a *= 1.0 - sky_cloud(saz, sel) * 0.85;
	ALPHA = clamp(a * (1.0 - space), 0.0, 1.0);
}
