shader_type canvas_item;

// Full-screen camera effects: blur (passing out / waking up), darkening and
// a vignette. Used by the landing (ship/descent.gd) and the wake-up at the
// crash site (world/wake_up.gd).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur = 0.0;      // mip level, 0 = sharp
uniform float dark = 0.0;      // 0..1 towards black
uniform float vignette = 0.0;  // 0..1
uniform vec3 tint : source_color = vec3(1.0);

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur).rgb;
	// Double vision while blurred.
	c = mix(c, textureLod(screen_tex, SCREEN_UV + vec2(0.012, 0.004) * min(blur, 3.0), blur).rgb, min(blur * 0.12, 0.35));
	float v = smoothstep(0.25, 0.9, distance(UV, vec2(0.5)) * 1.3);
	c *= 1.0 - vignette * v;
	c *= tint;
	COLOR = vec4(mix(c, vec3(0.0), dark), 1.0);
}
