shader_type spatial;
render_mode cull_back, specular_disabled;

// Redwood bark (world/redwood.gd): soft, smooth-shaded trunk and limbs.
// COLOR carries the painted colour (red-brown, charred scar, moss); UV runs
// around (x, in metres) and up (y, metres) the bark for the fibrous streaks.

#include "res://world/redwood_wind.gdshaderinc"

uniform float streaks : hint_range(0.0, 1.0) = 0.55;
// Set by day_night.gd so the trees darken at night.
uniform vec3 world_tint : source_color = vec3(1.0);

void vertex() {
	VERTEX += (inverse(MODEL_MATRIX) * vec4(rw_wind(VERTEX, UV2, MODEL_MATRIX, TIME), 0.0)).xyz;
}

void fragment() {
	// Long vertical fibres: stretched noise, a fine layer over a broad one.
	float f = rw_noise(vec2(UV.x * 3.0, UV.y * 0.25)) * 0.6 + rw_noise(vec2(UV.x * 9.0, UV.y * 0.6)) * 0.4;
	float crease = smoothstep(0.35, 0.15, f);
	vec3 col = COLOR.rgb * mix(1.0, 0.75 + f * 0.5, streaks);
	col *= 1.0 - crease * 0.35 * streaks;
	ALBEDO = col * world_tint;
	ROUGHNESS = 1.0;
}
