// Locker / Shop icon of an energy cell with a moving pattern (params.fx): the
// cell's body (a rounded capsule standing upright) glowing in `color_a`, with
// the same pattern the weapon's cell shows (cell_fx.gdshaderinc).
shader_type canvas_item;

#include "res://art/shaders/cell_fx.gdshaderinc"

uniform int fx = 0;
uniform vec4 color_a : source_color = vec4(0.3, 0.95, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Height over width of the rect.
uniform float aspect = 2.6;

void fragment() {
	vec2 span = vec2(1.0, aspect);
	vec2 p = vec2(UV.x, 1.0 - UV.y) * span;
	vec4 o = cell_fx_over(fx, p, span, TIME, color_a.rgb, color_b.rgb);
	vec3 c = mix(color_a.rgb, o.rgb, clamp(o.a, 0.0, 1.0));
	// Capsule mask, a glassy highlight down the left and two dark bands.
	vec2 q = vec2(abs(UV.x - 0.5), abs(UV.y - 0.5) * aspect);
	float d = length(max(q - vec2(0.0, aspect * 0.5 - 0.5), 0.0)) - 0.5;
	float inside = clamp(0.5 - d / fwidth(d), 0.0, 1.0);
	float shine = smoothstep(0.06, 0.0, abs(UV.x - 0.3)) * step(0.14, UV.y) * step(UV.y, 0.74);
	c = mix(c, vec3(1.0), shine * 0.55);
	float band = step(abs(fract(UV.y * 3.0) - 0.0), 0.03) + step(0.97, fract(UV.y * 3.0));
	c = mix(c, vec3(0.11, 0.09, 0.19), clamp(band, 0.0, 1.0) * 0.8 * step(0.1, UV.y) * step(UV.y, 0.9));
	COLOR = vec4(c, inside);
}
