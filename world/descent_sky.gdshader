shader_type sky;

// Descent sky: the crash site's day sky (world/day_sky.gdshader) blended
// with the starfield (ship/space_sky.gdshader) as the Kestrel comes down
// through the atmosphere. `space` 1 = stars only, 0 = the crash site's sky.
// `sky_rot` turns view directions into the crash site's frame (the ship
// stays still during the descent and the world turns around it).
//
// Daytime sky: separate pixel-art mountain peaks (two hazy layers with
// valleys between them), soft clouds. The two moons are
// real spheres drawn by world/sky_moons.gd, which shares the skyline
// (world/sky_common.gdshaderinc) so the mountains hide them.
// Directions are snapped to a coarse grid so everything reads as pixels.

uniform vec3 top_color : source_color = vec3(0.3, 0.55, 0.88);
uniform vec3 horizon_color : source_color = vec3(0.7, 0.82, 0.88);
uniform vec3 haze_color : source_color = vec3(0.62, 0.74, 0.82);
uniform vec3 rock_lit : source_color = vec3(0.62, 0.6, 0.62);
uniform vec3 rock_mid : source_color = vec3(0.44, 0.45, 0.52);
uniform vec3 rock_dark : source_color = vec3(0.3, 0.32, 0.42);
uniform vec3 snow : source_color = vec3(0.95, 0.96, 1.0);
uniform float pixel = 0.004;
// Driven by day_night.gd: 1 = full day, 0 = night; dusk peaks near sunrise/sunset.
uniform float day = 1.0;
uniform float dusk = 0.0;
uniform vec3 sun_dir = vec3(0.6, 0.6, 0.3);
uniform float space = 1.0;
// The painted mountain ranges only belong near the ground.
uniform float mountains = 1.0;
uniform mat3 sky_rot = mat3(1.0);
uniform vec3 space_color : source_color = vec3(0.004, 0.005, 0.012);
uniform float density = 0.9985;

float star_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

#include "res://world/sky_common.gdshaderinc"

vec3 rock(float az, float el, vec2 sk, float seed, float haze, float snow_line, vec3 hz) {
	float tex = noise(vec2(az * 70.0, el * 55.0)) + (hash(vec2(floor(az / pixel), floor(el / pixel))) - 0.5) * 0.3;
	// Sun from the right: right-hand faces lit.
	vec3 col = sk.y > 0.0 ? (tex > 0.5 ? rock_lit : rock_mid) : (tex > 0.62 ? rock_mid : rock_dark);
	if (noise(vec2(az * 90.0, el * 20.0 + seed)) > 0.82) {
		col = mix(col, rock_dark, 0.3);
	}
	float snow_at = snow_line + 0.03 * noise(vec2(az * 35.0, seed));
	if (sk.x > snow_line && el > snow_at && el > sk.x * 0.78 && el < sk.x) {
		col = sk.y > 0.0 ? snow : mix(snow, rock_mid, 0.25);
	}
	col *= mix(0.16, 1.0, day);
	col = mix(col, col * vec3(1.25, 0.8, 0.7), dusk * 0.6);
	float fade = haze + (1.0 - haze) * smoothstep(0.12, 0.0, el);
	return mix(col, hz, clamp(fade, 0.0, 1.0));
}

void sky() {
	vec3 d = normalize(sky_rot * EYEDIR);
	vec3 star_cell = floor(d * 350.0);
	vec3 stars = space_color + vec3(step(density, star_hash(star_cell)) * mix(0.4, 1.6, star_hash(star_cell + 7.0)));
	if (space > 0.999) {
		// Still in space: just the stars.
		COLOR = stars;
	} else {
	float az = atan(d.x, -d.z);
	float el = asin(clamp(d.y, -1.0, 1.0));
	float saz = floor(az / pixel) * pixel;
	float sel = floor(el / pixel) * pixel;
	vec3 sd = vec3(sin(saz) * cos(sel), sin(sel), -cos(saz) * cos(sel));

	vec3 sun_flat = normalize(vec3(sun_dir.x, 0.0, sun_dir.z) + vec3(0.0001));
	float toward_sun = 0.5 + 0.5 * dot(normalize(vec3(sd.x, 0.0, sd.z) + vec3(0.0001)), sun_flat);
	vec3 top = mix(vec3(0.015, 0.025, 0.07), top_color, day);
	top = mix(top, vec3(0.32, 0.28, 0.52), dusk * 0.55);
	vec3 hor = mix(vec3(0.04, 0.06, 0.13), horizon_color, day);
	hor = mix(hor, vec3(1.0, 0.52, 0.32), dusk * (0.45 + 0.55 * toward_sun));
	vec3 hz = mix(vec3(0.05, 0.07, 0.13), haze_color, day);
	hz = mix(hz, vec3(0.78, 0.5, 0.44), dusk * 0.7);
	vec3 col = mix(hor, top, smoothstep(0.0, 0.9, el));
	// Stars.
	if (day < 0.7 && hash(vec2(floor(saz / pixel), floor(sel / pixel))) > 0.996) {
		col += vec3(0.9, 0.92, 1.0) * (1.0 - day / 0.7) * hash(vec2(floor(saz / pixel) + 3.0, floor(sel / pixel)));
	}
	vec2 cl = vec2(saz * 1.2, sel * 3.0);
	vec3 cloud = mix(vec3(1.0), vec3(1.0, 0.68, 0.58), dusk) * mix(0.12, 1.0, day);
	col = mix(col, cloud, smoothstep(0.55, 0.8, fbm(cl * 2.5 + vec2(TIME * 0.003, 0.0))) * 0.8 * step(0.05, sel));
	float sun = distance(d, normalize(sun_dir));
	vec3 sun_col = mix(vec3(1.0, 0.55, 0.3), vec3(1.0, 0.95, 0.85), smoothstep(0.0, 0.4, sun_dir.y));
	col += sun_col * (smoothstep(0.045, 0.035, sun) * 4.0 + smoothstep(0.6, 0.0, sun) * (0.2 + dusk * 0.3)) * step(-0.05, sun_dir.y);

	vec2 far = skyline(saz, 0.55, 3.0, 0.16, 0.42);
	vec2 near = skyline(saz, 0.8, 11.0, 0.12, 0.5);
	if (sel < near.x * mountains) {
		col = rock(saz, sel, near, 11.0, 0.22, 0.34, hz);
	} else if (sel < far.x * mountains) {
		col = rock(saz, sel, far, 3.0, 0.5, 0.3, hz);
	}
	if (el < 0.0) {
		col = hz;
	}
	COLOR = mix(col, stars, space);
	}
}
