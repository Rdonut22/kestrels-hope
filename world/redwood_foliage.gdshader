shader_type spatial;
render_mode cull_disabled, specular_disabled;

// Redwood foliage (world/redwood.gd): flat needle sprays on cards, cut out
// of `spray`. The cards' normals point out from the crown rather than along
// the card, so the whole canopy shades like one soft, painted mass instead of
// a pile of separate planes. COLOR = spray shade (darker deep in the crown).

#include "res://world/redwood_wind.gdshaderinc"

uniform sampler2D spray : filter_linear_mipmap, repeat_disable;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.45;
// Lighter, warmer where the crown faces the sun; light glowing through.
uniform float sun_tint : hint_range(0.0, 1.0) = 0.3;
uniform float translucency : hint_range(0.0, 1.0) = 0.35;
// Set by day_night.gd so the trees darken at night.
uniform vec3 world_tint : source_color = vec3(1.0);

varying vec3 v_normal;

void vertex() {
	VERTEX += (inverse(MODEL_MATRIX) * vec4(rw_wind(VERTEX, UV2, MODEL_MATRIX, TIME), 0.0)).xyz;
	v_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 tex = texture(spray, UV);
	// Same normal on both sides of a card.
	NORMAL = normalize((VIEW_MATRIX * vec4(v_normal, 0.0)).xyz);
	vec3 col = COLOR.rgb * mix(0.7, 1.2, tex.r);
	col = mix(col, col * vec3(1.25, 1.2, 0.9), sun_tint * clamp(v_normal.y, 0.0, 1.0));
	ALBEDO = col * world_tint;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 1.0;
	BACKLIGHT = col * translucency;
}
