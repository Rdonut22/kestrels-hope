shader_type spatial;
render_mode cull_disabled;

// The corridor (central deck) materials: walls, floor and ceiling, after the
// interior art direction (painted aluminium and composite panels, warm
// off-white / muted olive / gunmetal, wear only where people touch things).
// Projected in ship space (the hull is CSG, no UVs). The user's PBR sets
// are applied with their own colour, normal, roughness (and metal) maps.
//
//   surface 0: wall: smooth dark metal in large sections with seams,
//              grooves and inset panels (procedural relief)
//   surface 9: the cockpit's walls and ceiling: the user's panelled metal
//              wall texture
//   surface 8: the bulkhead across the middle of the corridor: one worn
//              metal plate (the user's texture) across each face
//   surface 1: floor: dark anti-slip (worn shutter set, fine ribs), darker
//              border along the walls, a worn walking line down the middle
//   surface 2: ceiling: dark glossy quilted padding
//   surface 7: frames and beams: the wall metal with seams only
//   surface 3: a single painted panel in `panel_color` (plate set)
//   surface 4: a rubber tile mat (rubber_tiles set)
//   surface 5: blue metal plate in its own colour
//   surface 6: rusty metal in its own colour

uniform int surface = 0;

uniform vec3 off_white : source_color = vec3(0.773, 0.725, 0.647);   // #C5B9A5 aged ivory
uniform vec3 olive : source_color = vec3(0.42, 0.447, 0.365);        // #6B725D
uniform vec3 gunmetal : source_color = vec3(0.282, 0.275, 0.255);    // #484641 charcoal
uniform vec3 floor_color : source_color = vec3(0.24, 0.24, 0.23);
uniform vec3 panel_color : source_color = vec3(0.714, 0.702, 0.643);

// Wall zone heights (metres, ship space).
uniform float kick_top = 0.12;
uniform float olive_top = 1.0;
uniform float rail_top = 1.06;
uniform float panel_top = 3.6;

uniform sampler2D plate_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D plate_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D plate_detail : hint_default_white, filter_linear_mipmap, repeat_enable;
// The texture sets' real colour maps, applied as they are.
// (Kept to as few textures as possible: GPUs, Macs especially, cap how
// many one shader may sample, and over the cap it draws nothing.)
uniform sampler2D plate_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rusty_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rusty_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rusty_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D rusty_metal : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float rusty_tile = 1.5;
// The cockpit (ship/nose_cockpit.gd sets these): the user's panelled metal
// wall texture, one copy every cockpit_tile metres (width, height).
uniform sampler2D cockpit_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cockpit_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D cockpit_rm : hint_default_white, filter_linear_mipmap, repeat_enable;  // r roughness, g metal
uniform vec2 cockpit_tile = vec2(2.6, 1.46);
// The middle bulkhead: one worn metal plate (the user's texture), stretched
// once across each face so its rusty border frames the whole wall.
uniform sampler2D plate_albedo_big : source_color, filter_linear_mipmap;
uniform sampler2D plate_nor_big : hint_normal, filter_linear_mipmap;
uniform sampler2D plate_rm_big : hint_default_white, filter_linear_mipmap;  // r roughness, g metal
// The bulkhead face: x from..to (ship x) and its height.
uniform vec3 bulkhead_span = vec3(-2.3, 2.0, 3.0);
uniform float plate_relief : hint_range(0.0, 2.0) = 0.3;
// Ceiling: the user's metal_plate_02 set (normal, metalness, roughness): dark,
// gunmetal steel plates. Colour from its metal map.
uniform sampler2D ceil_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ceil_metal : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D ceil_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float ceil_tile = 2.2;
uniform vec3 ceil_steel : source_color = vec3(0.34, 0.36, 0.4);
uniform vec3 ceil_rust : source_color = vec3(0.25, 0.26, 0.29);
// Reference look (Outlaws-style): light worn metal deck plates, dark worn
// painted metal walls and frames with brighter worn edges, dark quilted
// insulation on the ceiling.
uniform vec3 deck_light : source_color = vec3(0.78, 0.73, 0.63);
uniform vec3 deck_dark : source_color = vec3(0.55, 0.51, 0.44);
uniform vec3 dark_paint : source_color = vec3(0.2, 0.195, 0.185);
uniform vec3 worn_edge : source_color = vec3(0.46, 0.44, 0.4);
uniform vec3 quilt : source_color = vec3(0.05, 0.048, 0.046);
// Walls and frames: smooth dark metal in large sections, with seams,
// grooves and inset panels (procedural relief), no rust or paint colour.
uniform vec3 wall_metal : source_color = vec3(0.085, 0.08, 0.074);
uniform float bay = 1.6;
uniform float quilt_size = 0.55;
// Rubber tile mats (the user's rubber_tiles set) over the aft third of the
// floor, from the boarding ramp in: z > mat_start.
uniform sampler2D rubber_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rubber_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float mat_start = 4.3;
uniform float rubber_tile = 1.3;
uniform vec3 rubber_color : source_color = vec3(0.3, 0.31, 0.32);

// Texture tile sizes (metres).
uniform float plate_tile = 3.0;
uniform float green_tile = 1.6;
uniform float shutter_tile = 1.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.3;
uniform float detail_amount : hint_range(0.0, 1.0) = 0.6;

// Doorway jambs on the walls, where hands and shoulders wear the paint:
// (wall x, door centre z, half width, 0). Corridor-local (ship space).
uniform vec4 doors[4];
uniform float hand_wear : hint_range(0.0, 1.0) = 0.6;

varying vec3 v_pos;
varying vec3 v_nrm;

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
}

vec3 unpack_n(vec4 t, float strength) {
	vec3 n = t.xyz * 2.0 - 1.0;
	n.xy *= strength;
	return normalize(n);
}

float h(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}

// Relief of the smooth wall metal: 0 flat, negative in grooves, positive
// on raised panels. p = (along the wall, height).
float groove(float d, float w) {
	return 1.0 - smoothstep(w * 0.3, w, d);
}

float wall_relief(vec2 p, bool panels) {
	float r = 0.0;
	// Vertical seams between the large sections.
	float du = abs(fract(p.x / bay + 0.5) - 0.5) * bay;
	r -= groove(du, 0.022);
	if (!panels) {
		return r;
	}
	// Horizontal grooves: above the kick band, a pair framing the rail
	// band, and a high one.
	r -= groove(abs(p.y - 0.16), 0.018);
	r -= groove(abs(p.y - 0.9), 0.022);
	r -= groove(abs(p.y - 1.16), 0.022);
	r -= groove(abs(p.y - 2.3), 0.018);
	// An inset rounded panel in each section, with a soft bevelled edge,
	// and a second, slimmer one below the rail band.
	vec2 c = vec2((floor(p.x / bay) + 0.5) * bay, 1.72);
	vec2 q = abs(p - c) - vec2(bay * 0.5 - 0.16, 0.38) + 0.08;
	float sd = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 0.08;
	r += 0.6 * (1.0 - smoothstep(-0.03, 0.0, sd)) - 0.6 * groove(abs(sd), 0.018);
	vec2 c2 = vec2(c.x, 0.53);
	vec2 q2 = abs(p - c2) - vec2(bay * 0.5 - 0.22, 0.22) + 0.05;
	float sd2 = length(max(q2, 0.0)) + min(max(q2.x, q2.y), 0.0) - 0.05;
	r -= 0.5 * groove(abs(sd2), 0.016);
	return r;
}

void fragment() {
	vec3 n = normalize(v_nrm);
	vec3 an = abs(n);
	// Projection axes, chosen so (T, B, N) is right-handed for each facing.
	vec3 T;
	vec3 B;
	vec2 uv;
	if (an.y >= an.x && an.y >= an.z) {
		T = vec3(1, 0, 0);
		B = n.y > 0.0 ? vec3(0, 0, -1) : vec3(0, 0, 1);
		uv = vec2(v_pos.x, n.y > 0.0 ? -v_pos.z : v_pos.z);
	} else if (an.x >= an.z) {
		T = n.x > 0.0 ? vec3(0, 0, -1) : vec3(0, 0, 1);
		B = vec3(0, 1, 0);
		uv = vec2(n.x > 0.0 ? -v_pos.z : v_pos.z, v_pos.y);
	} else {
		T = n.z > 0.0 ? vec3(1, 0, 0) : vec3(-1, 0, 0);
		B = vec3(0, 1, 0);
		uv = vec2(n.z > 0.0 ? v_pos.x : -v_pos.x, v_pos.y);
	}
	float y = v_pos.y;

	vec3 col;
	vec3 tn = vec3(0, 0, 1);
	float rough = 0.6;
	float metal = 0.15;
	int s = surface;

	if (s == 1 && v_pos.z > mat_start) {
		// Under the rubber mats: bare dark deck shows in the gaps.
		col = gunmetal * 0.55;
		rough = 0.7;
		metal = 0.4;
	} else if (s == 4) {
		// A rubber tile mat (corridor_dressing.gd lays them, gaps between).
		vec2 ruv = vec2(v_pos.x, v_pos.z) / rubber_tile;
		tn = unpack_n(texture(rubber_nor, ruv), normal_strength * 1.6);
		float r0 = texture(rubber_rough, ruv).r;
		col = rubber_color * (0.85 + 0.3 * vnoise(ruv * 7.0));
		// The set's tile seams read darker; boots polish the middle a little.
		col *= mix(0.45, 1.0, smoothstep(0.55, 0.8, r0));
		rough = mix(0.4, 0.85, r0);
		float path = 1.0 - smoothstep(0.25, 0.8, abs(v_pos.x + 0.15));
		rough = mix(rough, 0.45, path * 0.35);
		metal = 0.0;
	} else if (s == 1) {
		// Floor: light, worn, slightly glossy metal deck plates (the
		// metal_plate_02 set's plates), scuffed darker along the walls.
		vec2 fuv = vec2(v_pos.x, v_pos.z) / 2.4;
		tn = unpack_n(texture(ceil_nor, fuv), normal_strength * 1.2);
		float m = texture(ceil_metal, fuv).r;
		float g = texture(rusty_albedo, fuv * 1.3).g;
		col = mix(deck_dark, deck_light, m) * (0.82 + 0.35 * g);
		rough = mix(0.25, 0.75, texture(ceil_rough, fuv).r);
		metal = 0.35 + 0.35 * m;
		float edge = min(v_pos.x + 2.3, 2.0 - v_pos.x);
		col = mix(col * 0.55, col, smoothstep(0.05, 0.45, edge));
		// Boot-polished walking line.
		float path = 1.0 - smoothstep(0.3, 0.9, abs(v_pos.x + 0.15));
		rough = mix(rough, 0.2, path * 0.5);
		col = mix(col, col * 1.1, path * 0.4);
	} else if (s == 2) {
		// Ceiling: dark glossy quilted padding: diamond-stitched puffs,
		// creases pulled toward the stitched seams, dark seams.
		vec2 q = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * uv / quilt_size;
		vec2 f = fract(q) - 0.5;
		vec2 c = cos(f * 3.14159);
		float puff = c.x * c.y;                       // 1 at the centre, 0 at seams
		vec2 grad = -vec2(sin(f.x * 3.14159) * c.y, c.x * sin(f.y * 3.14159)) * 1.4;
		// Creases: ridges running across each puff toward its corners,
		// wobbled per cell so no two puffs match.
		vec2 cell = floor(q);
		float ph = h(cell) * 6.28;
		float wob = vnoise(q * 3.0 + cell * 1.7) * 2.0;
		float along = (f.x + f.y) * 0.7071;
		float across = (f.x - f.y) * 0.7071;
		float cr = sin(across * 26.0 + wob * 2.5 + ph) * smoothstep(0.0, 0.25, puff);
		float cr2 = sin(along * 18.0 + wob * 3.0 + ph * 1.3) * smoothstep(0.1, 0.5, puff) * 0.5;
		vec2 crease = vec2(0.7071, -0.7071) * cr * 0.45 + vec2(0.7071, 0.7071) * cr2 * 0.35;
		grad = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * (grad + crease);
		tn = normalize(vec3(grad, 1.0));
		float seam = 1.0 - smoothstep(0.0, 0.08, min(0.5 - abs(f.x), 0.5 - abs(f.y)));
		col = quilt * (0.55 + 0.7 * puff) * (0.9 + 0.2 * cr) * mix(1.0, 0.35, seam);
		rough = mix(0.5, 0.14, puff);
		metal = 0.0;
	} else if (s == 8) {
		// One solid worn metal plate across the whole face, read the right
		// way round from either side.
		float u = (v_pos.x - bulkhead_span.x) / (bulkhead_span.y - bulkhead_span.x);
		if (n.z < 0.0) {
			u = 1.0 - u;
		}
		vec2 puv = clamp(vec2(u, 1.0 - y / bulkhead_span.z), 0.0, 1.0);
		tn = unpack_n(texture(plate_nor_big, puv), plate_relief);
		col = texture(plate_albedo_big, puv).rgb;
		vec2 rm = texture(plate_rm_big, puv).rg;
		rough = clamp(rm.r + 0.12, 0.0, 1.0);
		metal = rm.g * 0.45;
	} else if (s == 9) {
		// Cockpit walls and ceiling: panelled grey-blue metal with seams,
		// bevelled cut corners and a bolted inset plate.
		vec2 puv = vec2(uv.x, -uv.y) / cockpit_tile;
		tn = unpack_n(texture(cockpit_nor, puv), 1.0);
		col = texture(cockpit_albedo, puv).rgb * 1.15;
		vec2 rm = texture(cockpit_rm, puv).rg;
		rough = rm.r;
		metal = rm.g * 0.4;   // painted metal: keeps its colour in dim light
	} else if (s == 7 || s == 0) {
		// Smooth dark metal in large sections (walls, frames, beams):
		// seams, grooves and inset panels as relief, soft sheen, faint
		// smudges. Frames get only the seams.
		vec2 p = vec2(uv.x, y);
		bool panels = s == 0;
		float e = 0.004;
		float r0 = wall_relief(p, panels);
		float rx = wall_relief(p + vec2(e, 0.0), panels);
		float ry = wall_relief(p + vec2(0.0, e), panels);
		vec2 grad = vec2(rx - r0, ry - r0) / e;
		tn = normalize(vec3(-grad * 0.012, 1.0));
		float smudge = vnoise(uv * 1.3) * 0.6 + vnoise(uv * 5.0 + 9.0) * 0.4;
		float big = vnoise(uv * 0.35 + 4.0);
		col = wall_metal * (0.85 + 0.35 * big);
		col *= mix(1.0, 0.3, clamp(-r0, 0.0, 1.0));    // grooves darker
		col *= 1.0 + 0.25 * clamp(r0, 0.0, 1.0);       // raised panels lighter
		if (panels && y <= kick_top + 0.04) {
			col *= 0.7;                                  // darker kick band
		}
		rough = 0.28 + 0.22 * smudge;
		metal = 0.6;
	} else if (s == 5) {
		// Blue metal plate, its own colour (equipment housings, cabinets).
		vec2 puv = uv / 1.2;
		tn = unpack_n(texture(plate_nor, puv), normal_strength);
		col = texture(plate_albedo, puv).rgb * 1.2;
		rough = mix(0.35, 0.8, texture(plate_rough, puv).r);
		metal = 0.3;
	} else if (s == 6) {
		// Rusty metal, its own colour, metalness and roughness (kick strip,
		// ramp door, worn and damaged spots).
		vec2 ruv = uv / rusty_tile;
		tn = unpack_n(texture(rusty_nor, ruv), normal_strength);
		col = texture(rusty_albedo, ruv).rgb;
		rough = texture(rusty_rough, ruv).r;
		metal = texture(rusty_metal, ruv).r;
	} else if (s == 3) {
		// Painted aluminium panels (plate set): off-white walls / ceiling.
		vec2 puv = uv / plate_tile;
		tn = unpack_n(texture(plate_nor, puv), normal_strength);
		float d = texture(plate_detail, puv).r;
		vec3 base = s == 3 ? panel_color : off_white;
		col = base * mix(1.0, 0.8 + d * 0.4, detail_amount);
		// Aged paint: faint warm grime gathering low, cleaner high up.
		col *= mix(0.9, 1.0, smoothstep(0.1, 1.2, y)) * (0.96 + 0.06 * vnoise(uv * 0.8));
		rough = mix(0.45, 0.8, texture(plate_rough, puv).r);
		metal = 0.1;
		if (s == 2) {
			col *= 0.92;
		}
	} else {
		// Gunmetal structure: kick strip, rail band, upper band.
		vec2 puv = uv / plate_tile;
		tn = unpack_n(texture(plate_nor, puv * 2.0), normal_strength * 0.5);
		col = gunmetal * (0.9 + 0.2 * vnoise(uv * 4.0));
		rough = mix(0.4, 0.7, texture(plate_rough, puv).r);
		metal = 0.55;
	}

	// Hands wear the paint beside doorways (walls only).
	if (s == 0 && hand_wear > 0.0) {
		for (int i = 0; i < 4; i++) {
			vec4 d = doors[i];
			if (d.z <= 0.0 || abs(v_pos.x - d.x) > 0.2) {
				continue;
			}
			float dz = abs(abs(v_pos.z - d.y) - d.z);
			float wz = 1.0 - smoothstep(0.05, 0.4, dz);
			float wy = smoothstep(0.75, 1.0, y) * (1.0 - smoothstep(1.45, 1.75, y));
			float w = wz * wy * hand_wear * (0.5 + 0.5 * vnoise(v_pos.zy * 14.0));
			col = mix(col, col * vec3(0.78, 0.76, 0.72), w * 0.6);
			rough = mix(rough, 0.3, w * 0.5);
			metal = mix(metal, 0.4, w * 0.4);
		}
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = s == 2 ? 0.8 : 0.5;
	vec3 pn = normalize(T * tn.x + B * tn.y + n * tn.z);
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(pn, 0.0)).xyz);
}
