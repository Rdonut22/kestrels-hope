shader_type spatial;

// Floor grating: slats running across the walkway.

uniform vec3 color : source_color = vec3(0.2, 0.2, 0.21);
uniform float slat_spacing = 0.07;
uniform float gap = 0.45;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float s = fract(wpos.z / slat_spacing);
	float hole = smoothstep(1.0 - gap, 1.0 - gap + 0.08, s) * (1.0 - smoothstep(0.92, 1.0, s));
	ALBEDO = mix(color, color * 0.12, hole);
	METALLIC = 0.6;
	ROUGHNESS = mix(0.45, 0.9, hole);
}
