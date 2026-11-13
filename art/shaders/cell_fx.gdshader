// Pattern pass of an energy-cell cosmetic (params.fx): drawn over the cell's
// glow as the next pass of its material (WeaponCosmetics.cell_fx_material).
// The pattern lives on the cell's own box (box_pos, box_size: the surface's
// bounds in mesh space), so it fits any weapon's cell.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

#include "res://art/shaders/cell_fx.gdshaderinc"

uniform int fx = 0;
uniform vec4 color_a : source_color = vec4(0.3, 0.95, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3 box_pos = vec3(0.0);
uniform vec3 box_size = vec3(1.0);
// How far the pass stands off the glow surface (mesh units).
uniform float grow = 0.0005;
uniform float energy = 1.5;

varying vec3 local;

void vertex() {
	local = VERTEX;
	VERTEX += NORMAL * grow;
}

void fragment() {
	vec3 n = (local - box_pos) / max(box_size, vec3(1e-5));
	bool wide_x = box_size.x >= box_size.z;
	float side = wide_x ? box_size.x : box_size.z;
	float unit = max(min(side, box_size.y), 1e-5);
	vec2 span = vec2(side, box_size.y) / unit;
	vec2 p = vec2(wide_x ? n.x : n.z, n.y) * span;
	vec4 o = cell_fx(fx, p, span, TIME, color_a.rgb, color_b.rgb);
	ALBEDO = o.rgb * energy;
	ALPHA = clamp(o.a, 0.0, 1.0);
}
