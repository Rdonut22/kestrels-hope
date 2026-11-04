shader_type spatial;

// The lounge-entrance rug (ship/models/rug/rug.fbx; its own fabric textures
// weren't included, so the pattern is drawn here from the model's UVs):
// a woven mid-century rug in the interior palette: a walnut field, an
// off-white border band, olive and muted-rust geometric bands, wool fibre
// and slight wear down the middle where people walk.

uniform vec3 field : source_color = vec3(0.36, 0.25, 0.18);
uniform vec3 border : source_color = vec3(0.66, 0.62, 0.53);
uniform vec3 band_a : source_color = vec3(0.3, 0.36, 0.28);
uniform vec3 band_b : source_color = vec3(0.55, 0.3, 0.22);
uniform float wear : hint_range(0.0, 1.0) = 0.4;

float h(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	// Distance in from the edge (UV units, both axes).
	vec2 e = min(uv, 1.0 - uv);
	float edge = min(e.x, e.y);
	vec3 col = field;
	// Border band, a thin dark line inside it.
	col = mix(col, border, step(0.035, edge) * (1.0 - step(0.085, edge)));
	col = mix(col, field * 0.6, step(0.095, edge) * (1.0 - step(0.105, edge)));
	// Stepped geometric bands across the field.
	float y = fract(uv.y * 4.0);
	float x = abs(uv.x - 0.5);
	float diamond = step(abs(y - 0.5) + x * 1.4, 0.32) - step(abs(y - 0.5) + x * 1.4, 0.22);
	col = mix(col, band_a, diamond * step(0.12, edge));
	float bar = step(0.46, y) * (1.0 - step(0.54, y)) * step(x, 0.12);
	col = mix(col, band_b, bar * step(0.12, edge));
	// Wool: fine fibre noise and a woven grid.
	float fibre = vn(uv * vec2(900.0, 700.0)) * 0.5 + vn(uv * vec2(260.0, 200.0)) * 0.5;
	float weave = 0.5 + 0.5 * sin(uv.x * 2600.0) * sin(uv.y * 2000.0);
	col *= 0.82 + 0.25 * fibre + 0.06 * weave;
	// Worn and flattened down the middle of the walking line.
	float path = 1.0 - smoothstep(0.1, 0.32, abs(uv.x - 0.5));
	col = mix(col, col * 1.12 + 0.02, path * wear * vn(uv * 18.0));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
