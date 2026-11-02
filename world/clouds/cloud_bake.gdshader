shader_type canvas_item;
render_mode blend_disabled, unshaded;

// Towering cumulus, raymarched into a sky panorama (world/clouds/sky_clouds.gd).
//
// One texel per sky direction: u = azimuth (atan(x, -z), -PI..PI),
// v = elevation (EL_MIN at the bottom row, PI/2 at the top). The panorama is
// refreshed a band of rows per frame, so the raymarching costs a small,
// fixed amount every frame however big the view. The day sky
// (world/day_sky.gdshader) and the moons sample it.
//
// Output: rgb = in-scattered cloud light * 0.5 (premultiplied, room for
// highlights above 1), a = cloud opacity (1 - transmittance).
//
// Units: kilometres. The viewer stands at the origin on a planet of radius
// planet_radius_km; the cloud layer is a spherical shell above it.
//
// Shape, from large to small:
//   1. weather map (2D noise + an optional "hero" tower) -> cloud masses and
//      how high each one towers (dense centres tower, edges stay low)
//   2. shape noise (3D inverted Worley) -> the medium rounded billows
//   3. detail noise (3D inverted Worley) -> small lobes carved into the edges
// Lighting: a short light march towards the sun (self-shadowing between lobes),
// multiple-scattering octaves (luminous interiors), a cool cyan / pale-blue /
// grey ambient by height, then a painterly ramp from shadow tint to warm white.

const float EL_MIN = -0.03;

// Set by sky_clouds.gd.
uniform float band_start = 0.0;   // first row of this band, 0..1 from the top
uniform float band_height = 1.0;  // rows in this band, 0..1
uniform float time_s = 0.0;

// Time of day (copied from the day sky).
uniform float day = 1.0;
uniform float dusk = 0.0;
uniform vec3 sun_dir = vec3(0.6, 0.6, 0.3);
uniform vec3 sky_top : source_color = vec3(0.3, 0.55, 0.88);
uniform vec3 sky_horizon : source_color = vec3(0.7, 0.82, 0.88);

// Shape.
uniform float coverage = 0.45;
uniform float bottom_km = 1.6;
uniform float thickness_km = 9.0;
uniform float density = 1.0;
uniform float scale = 1.0;
uniform float softness = 0.2;
uniform float tower_strength = 0.85;
uniform float billow_strength = 0.75;
uniform float detail_strength = 0.45;
uniform float planet_radius_km = 2500.0;
uniform vec2 wind = vec2(0.0);    // accumulated wind offset, km
uniform vec2 wind_dir_n = vec2(1.0, 0.0); // normalised wind direction
uniform float anvil_chance = 0.4; // fraction of tall towers with an anvil
uniform float weather_tile_km = 44.0;
uniform float shape_tile_km = 7.0;
uniform float detail_tile_km = 1.8;
uniform vec4 hero = vec4(0.0, -30.0, 9.0, 1.0); // x, z (km), radius (km), strength
// Clouds thin out within this distance (km) so the sky overhead stays open
// and the towers stand around the horizon, as in the references.
uniform float clear_radius_km = 9.0;

// Lighting.
uniform float extinction = 30.0;  // per km at density 1
uniform float light_absorption = 0.35; // how far sunlight soaks into the lobes (lower = deeper)
uniform float sun_strength = 1.0;
uniform float ambient_strength = 1.0;
uniform vec3 lit_tint : source_color = vec3(1.0, 0.97, 0.91);
uniform vec3 shadow_tint : source_color = vec3(0.58, 0.76, 0.86);
uniform vec3 base_tint : source_color = vec3(0.6, 0.66, 0.76);
uniform float shadow_lift = 0.5;
uniform float silver_lining = 0.5;
uniform float brightness = 1.0;
uniform float aerial_km = 90.0;
uniform float aerial_strength = 0.75;

// Quality.
uniform int debug_view = 0;
uniform int max_steps = 220;
uniform int light_steps = 6;
uniform float fine_step_km = 0.12;

uniform sampler2D weather_noise : filter_linear, repeat_enable;
uniform sampler3D shape_noise : filter_linear, repeat_enable;
uniform sampler3D detail_noise : filter_linear, repeat_enable;

float remap01(float v, float lo, float hi) {
	return clamp((v - lo) / max(hi - lo, 1e-5), 0.0, 1.0);
}

vec2 ray_sphere(vec3 ro, vec3 rd, float r) {
	float b = dot(ro, rd);
	float c = dot(ro, ro) - r * r;
	float h = b * b - c;
	if (h < 0.0) {
		return vec2(-1.0);
	}
	h = sqrt(h);
	return vec2(-b - h, -b + h);
}

float hg(float c, float g) {
	float g2 = g * g;
	return (1.0 - g2) / pow(max(1.0 + g2 - 2.0 * g * c, 1e-4), 1.5);
}

vec4 hash4(vec2 c) {
	vec4 p = fract(vec4(c.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p += dot(p, p.wzxy + 33.33);
	return fract((p.xxyz + p.yzzw) * p.zywx);
}

// Smooth union of two "inside" values (km).
float smax_k(float a, float b, float k) {
	float h = max(k - abs(a - b), 0.0) / k;
	return max(a, b) + h * h * k * 0.25;
}

// One cumulus, inside-ness in km (> 0 inside). q = position relative to the
// centre of its flat base. A wide mound, then a stack of rising, shrinking,
// slightly leaning billow-spheres: the towering cauliflower silhouette.
float cumulus(vec3 q, float r, float tiers, vec2 lean) {
	vec3 e = q / vec3(r * 0.9, r * 0.7, r * 0.9);
	float f = (1.0 - length(e)) * r * 0.65;
	float rk = r * 0.8;
	float y = r * 0.38;
	for (int k = 1; k <= 5; k++) {
		float fk = float(k);
		if (fk > tiers + 0.999) {
			break;
		}
		// The last tier grows in with `tiers`' fraction.
		float grow = clamp(tiers - fk + 1.0, 0.0, 1.0);
		float rr = rk * mix(0.55, 1.0, grow);
		y += rk * 0.95;
		vec3 c = vec3(lean.x * fk * r * 0.16, y - rk * (1.0 - grow) * 0.8, lean.y * fk * r * 0.16);
		f = smax_k(f, rr - length(q - c), r * 0.35);
		rk *= 0.8;
	}
	return f;
}

// Cumulus scattered on a grid: each cell may hold one cloud.
// cell_km: cell size; r_min/r_max: base radius; tiers_max: tower tiers.
float cumulus_layer(vec2 xz, float z, float cell_km, float chance, float r_min, float r_max, float tiers_max, float seed) {
	vec2 id = floor(xz / cell_km);
	vec4 h = hash4(id + seed);
	vec2 centre = (id + 0.5 + (h.yz - 0.5) * 0.3) * cell_km;
	// Clusters: the weather map makes some regions busier than others.
	float w = texture(weather_noise, (centre + wind) / (weather_tile_km * scale)).r;
	float p = chance * mix(0.15, 1.9, smoothstep(0.3, 0.75, w));
	p *= smoothstep(clear_radius_km * 0.7, clear_radius_km * 1.3, length(centre - wind));
	if (h.x > p) {
		return -cell_km;
	}
	vec4 g = hash4(id + seed + 17.0);
	float r = mix(r_min, r_max, g.x) * scale;
	float tiers = tiers_max * tower_strength * mix(0.35, 1.0, g.y);
	vec2 lean = (g.zw - 0.5) * 1.2;
	vec3 q = vec3(xz.x - centre.x, z, xz.y - centre.y);
	float f = cumulus(q, r, tiers, lean);
	// Some of the tallest grow into cumulonimbus: a soft, wide anvil on top.
	if (tiers > 3.0 && fract(g.x * 13.7) < anvil_chance) {
		vec3 a = q - vec3(lean.x * 4.5 * r * 0.16, r * 0.38 + r * 0.8 * 0.95 * 3.4, lean.y * 4.5 * r * 0.16);
		a.xz -= wind_dir_n * r * 0.5;
		float fa = (1.0 - length(a / vec3(r * 1.5, r * 0.32, r * 1.3))) * r * 0.32;
		f = smax_k(f, fa, r * 0.4);
	}
	return f;
}

// The smooth cloud shape (km, > 0 inside) before billows.
float cloud_shape(vec2 xz, float z) {
	// Positions drift with the wind (clouds move, the grid moves with them).
	vec2 m = xz + wind;
	// Big towers, and a bank of smaller fair-weather cumulus.
	float f = cumulus_layer(m, z, 16.0 * scale, coverage, 2.4, 4.6, 4.0, 0.0);
	f = max(f, cumulus_layer(m + vec2(3.1, 1.7) * scale, z, 6.5 * scale, coverage * 0.9, 0.9, 1.9, 1.3, 41.0));
	// The hero tower: a giant, art-directed cumulus that does not drift.
	if (hero.w > 0.0) {
		vec2 hq = xz - hero.xy;
		float hr = hero.z * 0.5 * clamp(hero.w, 0.3, 1.5);
		f = max(f, cumulus(vec3(hq.x, z, hq.y), hr, 4.8 * hero.w, vec2(-0.25, 0.15)));
	}
	return f;
}

// Upper bound on the billow displacement, for skipping empty air.
float billow_reach() {
	return (1.0 * billow_strength + 0.3 * detail_strength) * scale + 0.1;
}

float envelope(vec3 p, float h01, out vec2 wt) {
	wt = vec2(0.0);
	return cloud_shape(p.xz, h01 * thickness_km) + billow_reach();
}

// Signed field (km, positive inside): the shape's surface pushed out by
// rounded billows at two scales (inverted Worley = bulges), so every cloud is
// a heap of round lobes. Returns a large negative value in empty air.
float cloud_field(vec3 p, float h01, bool detail) {
	float z = h01 * thickness_km;
	float f = cloud_shape(p.xz, z);
	if (f + billow_reach() <= 0.0) {
		return -10.0;
	}
	vec3 q = p + vec3(wind.x, 0.0, wind.y);
	float sn = texture(shape_noise, (q + vec3(0.0, -time_s * 0.0004, 0.0)) / (shape_tile_km * scale)).r;
	f += (sn - 0.45) * 1.9 * billow_strength * scale;
	if (detail && f > -0.35 * scale && f < 0.5 * scale) {
		float dn = texture(detail_noise, (q + vec3(time_s * 0.0002, 0.0, 0.0)) / (detail_tile_km * scale)).r;
		f += (dn - 0.5) * 0.6 * detail_strength * scale;
	}
	// Flat-ish bases, broken into soft lobes rather than one flat lid.
	return min(f, z * 1.6 - 0.05 + (sn - 0.5) * 0.7 * billow_strength * scale);
}

float cloud_density(vec3 p, float h01, bool detail) {
	float f = cloud_field(p, h01, detail);
	return f <= 0.0 ? 0.0 : smoothstep(0.0, softness * scale, f) * density;
}

// Outward surface normal of the lobes (tetrahedral gradient of the field).
vec3 cloud_normal(vec3 p, vec3 centre, float r_in) {
	float e = 0.12 * scale;
	vec2 k = vec2(1.0, -1.0);
	vec3 g = vec3(0.0);
	vec3 o;
	o = k.xyy * e; g += k.xyy * cloud_field(p + o, (length(p + o - centre) - r_in) / thickness_km, true);
	o = k.yyx * e; g += k.yyx * cloud_field(p + o, (length(p + o - centre) - r_in) / thickness_km, true);
	o = k.yxy * e; g += k.yxy * cloud_field(p + o, (length(p + o - centre) - r_in) / thickness_km, true);
	o = k.xxx * e; g += k.xxx * cloud_field(p + o, (length(p + o - centre) - r_in) / thickness_km, true);
	return -normalize(g + vec3(1e-6));
}

float light_depth(vec3 p, vec3 l, vec3 centre, float r_in, float thick) {
	float od = 0.0;
	float st = 0.06 * scale;
	vec3 x = p;
	for (int i = 0; i < light_steps; i++) {
		x += l * st;
		float h01 = (length(x - centre) - r_in) / thick;
		if (h01 > 1.0) {
			break;
		}
		od += cloud_density(x, clamp(h01, 0.0, 1.0), i < 3) * st;
		st *= 1.9;
	}
	return od;
}

void fragment() {
	float v = band_start + UV.y * band_height;   // 0 at the top row
	if (debug_view > 0) {
		// Left half: texture xy plane, right half: xz plane (2x2 tiles each).
		vec2 g = vec2(fract(UV.x * 2.0) * 2.0, v * 2.0);
		vec3 c3 = UV.x < 0.5 ? vec3(g, 0.37) : vec3(g.x, 0.37, g.y);
		float nv = debug_view == 1 ? texture(shape_noise, c3).r : texture(detail_noise, c3).r;
		COLOR = vec4(vec3(nv) * 0.5, 1.0);
	} else {
	float el = mix(PI * 0.5, EL_MIN, v);
	float az = (UV.x * 2.0 - 1.0) * PI;
	vec3 rd = vec3(sin(az) * cos(el), sin(el), -cos(az) * cos(el));

	vec3 centre = vec3(0.0, -planet_radius_km, 0.0);
	float r_in = planet_radius_km + bottom_km;
	float r_out = r_in + thickness_km;
	vec3 ro = vec3(0.0, 0.002, 0.0);
	vec2 si = ray_sphere(ro - centre, rd, r_in);
	vec2 so = ray_sphere(ro - centre, rd, r_out);
	float t0 = max(si.y, 0.0);
	float t1 = min(so.y, t0 + 140.0);

	vec3 l = normalize(sun_dir);
	float sun_up = smoothstep(-0.06, 0.2, l.y);
	// Light from just below the horizon still skims the tops at dusk.
	vec3 lm = normalize(vec3(l.x, max(l.y, 0.04), l.z));
	vec3 sun_col = mix(vec3(1.0, 0.5, 0.28), vec3(1.0, 0.96, 0.88), smoothstep(0.0, 0.4, l.y));
	sun_col *= lit_tint * sun_strength * mix(0.0, 1.0, sun_up);
	float night = 1.0 - day;
	vec3 top = mix(vec3(0.015, 0.025, 0.07), sky_top, day);
	vec3 hor = mix(vec3(0.04, 0.06, 0.13), sky_horizon, day);
	hor = mix(hor, vec3(1.0, 0.6, 0.45), dusk * 0.4);
	float amb_level = mix(0.08, 1.0, day) * ambient_strength;

	float mu = dot(rd, lm);
	float phase = mix(1.0, 0.55 * hg(mu, 0.6) + 0.45 * hg(mu, -0.2), 0.5);
	phase += silver_lining * pow(max(mu, 0.0), 10.0);

	vec3 col = vec3(0.0);
	float T = 1.0;
	float dist_w = 0.0;
	float w_sum = 0.0;
	float fine = fine_step_km * scale;
	float coarse = fine * 3.0;
	// Per-texel jitter of the first step hides step banding.
	float t = t0 + fine * fract(52.9829189 * fract(dot(UV * vec2(4096.0, 1024.0), vec2(0.06711056, 0.00583715))));
	int empty = 99;
	for (int i = 0; i < max_steps; i++) {
		if (t > t1 || T < 0.01) {
			break;
		}
		vec3 p = ro + rd * t;
		float h01 = (length(p - centre) - r_in) / thickness_km;
		if (h01 < 0.0 || h01 > 1.0) {
			t += coarse;
			continue;
		}
		if (empty > 2) {
			vec2 wt;
			if (envelope(p, h01, wt) <= 0.0) {
				t += coarse * (1.0 + t * 0.01);
				continue;
			}
		}
		float d = cloud_density(p, h01, true);
		if (d > 0.002) {
			if (empty > 2) {
				// Back up so lobe surfaces stay crisp.
				empty = 0;
				t = max(t0, t - coarse * 0.8);
				continue;
			}
			empty = 0;
			// Large-scale shadow: other lobes and towers between here and the sun.
			float od = light_depth(p, lm, centre, r_in, thickness_km) * extinction * light_absorption;
			float sh = exp(-od) + 0.35 * exp(-od * 0.2);   // + multiple scattering
			sh = clamp(sh, 0.0, 1.0);
			// Lobe shading: the surface normal gives every billow a sunlit
			// top and a cool shadowed underside (computed near the surface only).
			vec3 n = T > 0.25 ? cloud_normal(p, centre, r_in) : -rd;
			float ndl = dot(n, lm);
			float wrap = smoothstep(-0.45, 0.7, ndl);
			float direct = wrap * mix(sh, 1.0, 0.15) * phase;
			direct = clamp(direct, 0.0, 1.6);
			// Ambient: cool grey-blue under the bases, pale cyan up the towers,
			// sky-blue on lobes facing up. Kept light: the shadows of a sunny
			// cumulus are luminous blues, never storm grey.
			float hh = smoothstep(0.0, 0.85, h01);
			vec3 shadow = mix(base_tint, shadow_tint, hh);
			shadow = mix(shadow, top * 1.5 + 0.3, 0.3 * clamp(n.y, 0.0, 1.0));
			shadow *= mix(0.9, 1.05, 0.5 + 0.5 * n.y);
			vec3 amb = shadow * amb_level * mix(shadow_lift, 1.0, 0.5 + 0.5 * sh);
			// Painterly turn: a band of clear cyan where light gives way to shadow.
			float turn = wrap * (1.0 - wrap) * 4.0 * mix(sh, 1.0, 0.4);
			amb += shadow_tint * vec3(0.55, 0.95, 1.1) * turn * 0.25 * amb_level;
			vec3 s = (amb + sun_col * direct) * brightness;

			float sig = d * extinction;
			float tr = exp(-sig * fine);
			col += T * s * (1.0 - tr);
			dist_w += t * T * (1.0 - tr);
			w_sum += T * (1.0 - tr);
			T *= tr;
			t += fine * (1.0 + t * 0.006);
		} else {
			empty++;
			t += (empty > 2 ? coarse : fine) * (1.0 + t * 0.006);
		}
	}

	float a = 1.0 - T;
	if (w_sum > 0.0) {
		// Aerial perspective: far clouds melt into the horizon haze.
		float dist = dist_w / w_sum;
		float haze = (1.0 - exp(-dist / aerial_km)) * aerial_strength;
		haze *= 1.0 - smoothstep(0.0, 0.5, el) * 0.6;
		col = mix(col, hor * a, haze);
	}
	// Fade the very bottom rows into the horizon.
	float hf = smoothstep(EL_MIN, 0.01, el);
	COLOR = vec4(col * 0.5 * hf, a * hf);
	}
}
