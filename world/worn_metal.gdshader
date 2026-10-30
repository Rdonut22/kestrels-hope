shader_type spatial;
render_mode fog_disabled, cull_disabled;

// Weathered industrial plating for the Great Ring (tools/build_scenes.gd
// _restyle_great_ring), textured from the Sci-Fi Kit 08 sheets: orange
// painted panels (tube atlas), corrugated steel and dark stamped strips
// (cable trim sheet), with the odd replaced panel in another colour. Every
// box (UV2 = two random numbers per box, UV = metres across each face) gets
// its own texture offset and its own amount of rust, from nearly clean to
// heavily corroded with streaks running down. COLOR picks the material:
// saturated = paint, near-black = machinery, grey = steel; alpha < 0.5 marks
// a glowing light. Like the other ruins it ignores the scene fog (it stands
// beyond it) and fades into its own haze with distance.

uniform sampler2D panel_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D panel_roughness : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D panel_metallic : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D panel_ao : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D trim_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D trim_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D trim_roughness : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D trim_metallic : hint_default_black, filter_linear_mipmap, repeat_enable;

uniform vec3 world_tint : source_color = vec3(1.0);
uniform vec3 haze : source_color = vec3(0.52, 0.7, 0.66);
uniform float haze_amount : hint_range(0.0, 1.0) = 0.25;
uniform float haze_near = 40.0;
uniform float haze_far = 260.0;
uniform vec3 rust : source_color = vec3(0.36, 0.16, 0.07);
uniform vec3 grime : source_color = vec3(0.14, 0.12, 0.1);
uniform vec3 primer : source_color = vec3(0.62, 0.6, 0.55);
// Pulls the kit's bright yellow-orange paint towards a burnt orange.
uniform vec3 paint_tint : source_color = vec3(0.92, 0.62, 0.48);
// Share of boxes left nearly clean (the rest rust more and more).
uniform float clean_share : hint_range(0.0, 1.0) = 0.35;
// Metres one repeat of each sheet covers.
uniform vec2 panel_tile = vec2(18.0, 14.0);
uniform vec2 steel_tile = vec2(6.0, 1.8);
uniform vec2 strip_tile = vec2(9.0, 0.7);
uniform float metal_strength : hint_range(0.0, 1.0) = 0.35;

varying vec3 v_obj;
varying vec3 v_wpos;
varying vec3 v_wnrm;
varying vec4 v_col;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.07 + 11.3;
		a *= 0.5;
	}
	return v;
}

// Repeat a sub-rectangle of a texture sheet across `t` (in repeats), with
// mip levels taken from the unwrapped coordinates so the seams don't shimmer.
vec4 sheet(sampler2D s, vec2 t, vec2 rect_min, vec2 rect_size) {
	vec2 a = rect_min + fract(t) * rect_size;
	return textureGrad(s, a, dFdx(t) * rect_size, dFdy(t) * rect_size);
}

void vertex() {
	v_obj = VERTEX;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_col = COLOR;
}

void fragment() {
	vec3 base = v_col.rgb;
	float sat = max(base.r, max(base.g, base.b)) - min(base.r, min(base.g, base.b));
	float lum = dot(base, vec3(0.33));
	float paint = step(0.2, sat);
	float dark = (1.0 - paint) * step(lum, 0.15);
	vec2 r = UV2;
	vec2 offset = vec2(r.x * 17.0, r.y * 5.0);
	vec3 n = normalize(v_wnrm);

	vec3 col;
	float rough;
	float metal;
	float ao = 1.0;
	vec3 nmap = vec3(0.5, 0.5, 1.0);
	float patched = paint * step(fract(r.y * 7.1), 0.08);
	if (paint > 0.5 && patched < 0.5) {
		// Orange painted panels from the tube atlas (its top-left block).
		vec2 t = UV / panel_tile + offset;
		vec2 rmin = vec2(0.0, 0.0);
		vec2 rsz = vec2(0.84, 0.66);
		col = sheet(panel_albedo, t, rmin, rsz).rgb * (0.75 + lum * 0.6);
		col = mix(vec3(dot(col, vec3(0.3, 0.55, 0.15))), col, 0.8) * paint_tint;
		rough = sheet(panel_roughness, t, rmin, rsz).r;
		metal = sheet(panel_metallic, t, rmin, rsz).r;
		ao = sheet(panel_ao, t, rmin, rsz).r;
	} else {
		// Trim sheet: corrugated steel, dark stamped strips, or a coloured
		// replacement panel.
		vec2 rmin = vec2(0.0, 0.695);
		vec2 rsz = vec2(1.0, 0.305);
		vec2 tile = steel_tile;
		if (dark > 0.5) {
			rmin = vec2(0.0, 0.082);
			rsz = vec2(1.0, 0.07);
			tile = strip_tile;
		} else if (patched > 0.5) {
			float pick = fract(r.x * 3.7);
			rmin = vec2(0.0, pick < 0.4 ? 0.236 : (pick < 0.7 ? 0.548 : 0.392));
			rsz = vec2(1.0, 0.065);
			tile = strip_tile;
		}
		vec2 t = UV / tile + offset;
		col = sheet(trim_albedo, t, rmin, rsz).rgb;
		rough = sheet(trim_roughness, t, rmin, rsz).r;
		metal = sheet(trim_metallic, t, rmin, rsz).r;
		nmap = sheet(trim_normal, t, rmin, rsz).rgb;
	}

	// Big patches where the paint has flaked away to pale primer.
	float flake = fbm(v_obj * 0.05 + 3.0) * 0.75 + noise(v_obj * 0.9) * 0.25;
	col = mix(col, primer * (0.8 + 0.35 * noise(v_obj * 3.0)), smoothstep(0.6, 0.66, flake) * paint * 0.8);
	// How rusty this box is: some nearly clean, others badly corroded.
	float rustiness = smoothstep(clean_share, 1.0, fract(r.x * 5.3 + r.y * 2.1));
	vec3 p = v_obj;
	float blotch = fbm(p * 0.35 + r.x * 40.0) * 0.7 + noise(p * 3.0) * 0.3;
	float rusted = smoothstep(0.75 - rustiness * 0.45, 0.8 - rustiness * 0.45, blotch);
	vec3 rust_col = mix(rust, rust * 1.6 + vec3(0.05, 0.02, 0.0), noise(p * 5.0));
	col = mix(col, rust_col, rusted * 0.9);
	rough = mix(rough, 0.95, rusted);
	metal *= 1.0 - rusted;
	// Rust and grime streaking down the walls below the rusty patches.
	vec3 w = v_wpos;
	float vertical = 1.0 - abs(n.y);
	float streak = noise(vec3(w.x * 1.7, w.y * 0.07, w.z * 1.7)) * 0.6 + noise(vec3(w.x * 5.0, w.y * 0.2, w.z * 5.0)) * 0.4;
	float drip = smoothstep(0.62 - rustiness * 0.2, 0.85, streak) * vertical;
	col = mix(col, mix(rust, grime, 0.5) * (0.8 + 0.4 * noise(w * 3.0)), drip * (0.35 + rustiness * 0.5));
	// Undersides and the inner trench stay in grimy shadow; grime low down.
	col = mix(col, col * 0.45 + grime * 0.2, smoothstep(0.2, 0.8, -n.y));
	col = mix(col, grime, (1.0 - smoothstep(0.0, 25.0, w.y)) * 0.4);

	float glow = 1.0 - step(0.5, v_col.a);
	float dist = distance(v_wpos, CAMERA_POSITION_WORLD);
	float h = haze_amount * smoothstep(haze_near, haze_far, dist) * (1.0 - glow);
	ALBEDO = mix(col * ao * world_tint, haze * world_tint, h);
	EMISSION = v_col.rgb * glow * 2.5;
	NORMAL_MAP = nmap;
	ROUGHNESS = clamp(rough, 0.3, 1.0);
	METALLIC = metal * metal_strength;
	SPECULAR = 0.4;
}
