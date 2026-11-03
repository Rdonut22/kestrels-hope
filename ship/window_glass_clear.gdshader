// See-through variant of ship/window_glass.gdshader (canopy, real windows).
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx, depth_draw_never;
#define CLEAR
#include "res://ship/window_glass.gdshaderinc"
