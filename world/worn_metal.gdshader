shader_type spatial;
render_mode fog_disabled, cull_disabled;

// Weathered industrial metal for the Great Ring (tools/build_scenes.gd
// _restyle_great_ring): orange paint chipped and worn through to bare
// steel, big pale patches of primer, sun-faded areas, rust and grime
// streaking down the walls, gathering low down and on the undersides. COLOR
// picks the base (saturated colours are paint, grey ones are bare steel,
// near-black is machinery); alpha < 0.5 marks a glowing light. Smooth
// lighting; like the other ruins it ignores the scene fog (it stands beyond
// it) and fades into its own haze with distance.

uniform vec3 world_tint : source_color = vec3(1.0);
uniform vec3 haze : source_color = vec3(0.52, 0.7, 0.66);
uniform float haze_amount : hint_range(0.0, 1.0) = 0.25;
uniform float haze_near = 40.0;
uniform float haze_far = 260.0;
uniform vec3 bare_metal : source_color = vec3(0.5, 0.49, 0.46);
uniform vec3 rust : source_color = vec3(0.42, 0.2, 0.09);
uniform vec3 grime : source_color = vec3(0.16, 0.13, 0.1);
uniform vec3 primer : source_color = vec3(0.66, 0.64, 0.58);
uniform float wear : hint_range(0.0, 1.0) = 0.6;

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

void vertex() {
	v_obj = VERTEX;
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_col = COLOR;
}

void fragment() {
	vec3 base = v_col.rgb;
	float sat = max(base.r, max(base.g, base.b)) - min(base.r, min(base.g, base.b));
	float paint = smoothstep(0.2, 0.4, sat);
	vec3 p = v_obj;
	vec3 n = normalize(v_wnrm);
	float vertical = 1.0 - abs(n.y);

	// Paint: sun-faded patches, then chipped and worn through to steel.
	float fade = fbm(p * 0.08);
	vec3 col = mix(base, base * vec3(1.12, 1.18, 1.25) + vec3(0.06), smoothstep(0.5, 0.75, fade) * 0.6 * paint);
	float chips = fbm(p * 0.35 + 5.0) * 0.7 + noise(p * 2.5) * 0.3;
	float worn = smoothstep(0.72 - wear * 0.25, 0.78 - wear * 0.25, chips) * paint;
	vec3 steel = bare_metal * (0.8 + 0.35 * noise(p * 6.0));
	col = mix(col, steel, worn);
	// Large blotches where the paint has flaked off down to pale primer.
	float blotch = fbm(p * 0.05 + 3.0) * 0.75 + noise(p * 0.9) * 0.25;
	float bare = smoothstep(0.6, 0.66, blotch) * paint;
	col = mix(col, primer * (0.85 + 0.3 * noise(p * 3.0)), bare * 0.85);
	// Rust and grime streaking down the walls from seams and edges.
	vec3 w = v_wpos;
	float streak = noise(vec3(w.x * 1.7, w.y * 0.07, w.z * 1.7)) * 0.6 + noise(vec3(w.x * 5.0, w.y * 0.2, w.z * 5.0)) * 0.4;
	float drip = smoothstep(0.45, 0.8, streak) * vertical;
	col = mix(col, mix(rust, grime, 0.5) * (0.8 + 0.4 * noise(w * 3.0)), drip * 0.8);
	// Undersides and the inner trench stay in grimy shadow.
	col = mix(col, col * 0.45 + grime * 0.2, smoothstep(0.2, 0.8, -n.y));
	// Grime gathering low down and in patches; rust blooms where it's worn.
	float low = 1.0 - smoothstep(0.0, 25.0, w.y);
	col = mix(col, grime, clamp(low * 0.5 + smoothstep(0.6, 0.85, fbm(p * 0.15 + 21.0)) * 0.35, 0.0, 0.7));
	col = mix(col, rust * (0.7 + 0.5 * noise(p * 4.0)), smoothstep(0.62, 0.8, fbm(p * 0.22 + 9.0)) * 0.6 * (paint + 0.3));

	float glow = 1.0 - step(0.5, v_col.a);
	float dist = distance(v_wpos, CAMERA_POSITION_WORLD);
	float h = haze_amount * smoothstep(haze_near, haze_far, dist) * (1.0 - glow);
	ALBEDO = mix(col * world_tint, haze * world_tint, h);
	EMISSION = v_col.rgb * glow * 2.5;
	ROUGHNESS = mix(0.75, 0.45, worn);
	METALLIC = worn * 0.3;
	SPECULAR = 0.35;
}
