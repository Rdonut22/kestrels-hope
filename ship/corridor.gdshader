shader_type spatial;

// The corridor (central deck) materials: walls, floor and ceiling, after the
// interior art direction (painted aluminium and composite panels, warm
// off-white / muted olive / gunmetal, wear only where people touch things).
// Projected in ship space (the hull is CSG, no UVs); the user's PBR sets
// supply normal and roughness detail, their colour maps only light/dark
// detail (the palette sets the hue).
//
//   surface 0: wall: a charcoal kick strip, then aged-ivory painted panels
//              (blue metal plate set); the panel layout itself is geometry
//              (corridor_dressing.gd). The olive band / upper band zones are
//              still there (olive_top, rail_top, panel_top) but off by default.
//   surface 1: floor: dark anti-slip (worn shutter set, fine ribs), darker
//              border along the walls, a worn walking line down the middle
//   surface 2: ceiling: off-white panels (plate set)
//   surface 3: a single painted panel in `panel_color` (plate set)
//   surface 4: a rubber tile mat (rubber_tiles set)

uniform int surface = 0;

uniform vec3 off_white : source_color = vec3(0.773, 0.725, 0.647);   // #C5B9A5 aged ivory
uniform vec3 olive : source_color = vec3(0.42, 0.447, 0.365);        // #6B725D
uniform vec3 gunmetal : source_color = vec3(0.282, 0.275, 0.255);    // #484641 charcoal
uniform vec3 floor_color : source_color = vec3(0.24, 0.24, 0.23);
uniform vec3 panel_color : source_color = vec3(0.714, 0.702, 0.643);

// Wall zone heights (metres, ship space).
uniform float kick_top = 0.12;
uniform float olive_top = 0.12;
uniform float rail_top = 0.12;
uniform float panel_top = 3.6;

uniform sampler2D plate_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D plate_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D plate_detail : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D green_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D green_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D green_detail : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D shutter_nor : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D shutter_rough : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D shutter_detail : hint_default_white, filter_linear_mipmap, repeat_enable;
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
		// Floor: dark anti-slip ribs across the walkway.
		vec2 fuv = vec2(v_pos.z, v_pos.x) / shutter_tile;
		tn = unpack_n(texture(shutter_nor, fuv), normal_strength * 0.8);
		float d = texture(shutter_detail, fuv).r;
		col = floor_color * mix(1.0, 0.7 + d * 0.6, detail_amount);
		rough = mix(0.55, 0.9, texture(shutter_rough, fuv).r);
		metal = 0.35;
		// Darker gunmetal border along the walls; a polished walking line
		// down the middle where boots go.
		float edge = min(v_pos.x + 2.3, 2.0 - v_pos.x);
		col = mix(gunmetal * 0.85, col, smoothstep(0.18, 0.32, edge));
		float path = 1.0 - smoothstep(0.25, 0.75, abs(v_pos.x + 0.15));
		path *= 0.6 + 0.4 * vnoise(v_pos.xz * 1.7);
		col = mix(col, col * 1.18, path * 0.5);
		rough = mix(rough, 0.35, path * 0.45);
	} else if (s == 2 || s == 3 || (s == 0 && y > rail_top && y < panel_top)) {
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
	} else if (s == 0 && y > kick_top && y <= olive_top) {
		// Olive utility panels low on the walls (green metal set).
		vec2 guv = uv / green_tile;
		tn = unpack_n(texture(green_nor, guv), normal_strength);
		float d = texture(green_detail, guv).r;
		col = olive * mix(1.0, 0.7 + d * 0.6, detail_amount);
		rough = mix(0.4, 0.85, texture(green_rough, guv).r);
		metal = 0.15;
		// Boots scuff the bottom of the panels.
		float scuff = (1.0 - smoothstep(kick_top, kick_top + 0.25, y)) * vnoise(uv * vec2(3.0, 9.0));
		col = mix(col, gunmetal * 0.9, scuff * 0.35);
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
	SPECULAR = 0.45;
	vec3 pn = normalize(T * tn.x + B * tn.y + n * tn.z);
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(pn, 0.0)).xyz);
}
