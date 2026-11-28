shader_type canvas_item;

// Frosted glass for the cooking HUD (cooking/glass_panel.gd): what's behind
// it blurred and darkened, a soft sheen from the top, a thin light rim,
// and optionally an outer glow (amber when selected) and diagonal hatching
// (unavailable). Drawn on the panel's own style box, which reaches `margin`
// past its edges so the glow has room; `size` is the panel's size.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 size = vec2(100.0, 100.0);
uniform float margin = 16.0;
uniform float radius = 16.0;
uniform float blur = 3.0;
uniform vec4 tint : source_color = vec4(0.07, 0.065, 0.06, 0.62);
uniform vec4 rim : source_color = vec4(1.0, 1.0, 1.0, 0.22);
uniform float rim_width = 1.5;
uniform vec4 glow : source_color = vec4(1.0, 0.6, 0.2, 0.0);
uniform float glow_width = 10.0;
uniform float hatch = 0.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float rounded_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = local - size * 0.5;
	float d = rounded_box(p, size * 0.5, radius);
	// The blurred background: the screen's mipmaps, plus a ring of taps
	// (smooth even where mipmaps are coarse).
	vec2 px = SCREEN_PIXEL_SIZE * exp2(blur);
	vec3 bg = textureLod(screen_tex, SCREEN_UV, blur).rgb * 0.4;
	for (int i = 0; i < 6; i++) {
		float a = float(i) * 1.0472;
		bg += textureLod(screen_tex, SCREEN_UV + vec2(cos(a), sin(a)) * px * 1.5, blur).rgb * 0.1;
	}
	vec3 col = mix(bg, tint.rgb, tint.a);
	// Sheen: lighter toward the top.
	float y = (p.y + size.y * 0.5) / max(size.y, 1.0);
	col += vec3(0.05) * (1.0 - smoothstep(0.0, 0.6, y));
	if (hatch > 0.0) {
		float s = step(0.5, fract((p.x + p.y) / 9.0));
		col = mix(col, col * 0.6, s * hatch);
	}
	float inside = 1.0 - smoothstep(-0.6, 0.6, d);
	float rim_band = 1.0 - smoothstep(rim_width - 0.6, rim_width + 0.6, abs(d + rim_width * 0.5));
	vec4 c = vec4(col, inside);
	c.rgb = mix(c.rgb, rim.rgb, rim_band * rim.a * inside + rim_band * rim.a * 0.6 * (1.0 - inside));
	c.a = max(c.a, rim_band * rim.a);
	// Outer glow.
	if (glow.a > 0.0 && d > 0.0) {
		float g = exp(-d / max(glow_width, 0.001) * 2.5) * glow.a;
		c = vec4(mix(c.rgb, glow.rgb, g / max(c.a + g, 0.001)), max(c.a, g));
	}
	if (glow.a > 0.0) {
		float edge = 1.0 - smoothstep(0.0, 2.2, abs(d + 1.0));
		c.rgb = mix(c.rgb, glow.rgb, edge * glow.a);
	}
	COLOR = c;
}
