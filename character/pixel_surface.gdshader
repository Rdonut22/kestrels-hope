shader_type spatial;

// Chunky retro look: flat color broken into visible "texels" with a bit
// of random shading per texel. Works in the mesh's own space, so the
// pattern sticks to each body part as it moves.

uniform vec3 base_color : source_color = vec3(0.5);
uniform float texel_size = 0.025;
uniform float variation = 0.08;
uniform float roughness_amount = 0.85;
uniform float metallic_amount = 0.0;

varying vec3 lpos;
varying vec3 lnrm;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
}

void fragment() {
	vec3 n = abs(lnrm);
	vec3 cell = floor(lpos / texel_size);
	// Flatten along the face's axis so each face gets its own 2D grid.
	if (n.x > n.y && n.x > n.z) cell.x = sign(lnrm.x);
	else if (n.y > n.z) cell.y = sign(lnrm.y);
	else cell.z = sign(lnrm.z);
	float h = hash(cell);
	float shade = 1.0 + (h - 0.5) * 2.0 * variation;
	// Occasional darker speckle, like a hand-painted low-res texture.
	shade *= mix(1.0, 0.88, step(0.92, hash(cell + 13.0)));
	ALBEDO = base_color * shade;
	ROUGHNESS = roughness_amount;
	METALLIC = metallic_amount;
}
