shader_type spatial;
// Series 2 Epic "Hypnotist": op-art spirals in shell_color black and color_b
// white wind along the weapon, neighbours turning opposite ways, a violet
// (color_c) glow breathing at each eye. A kill spins them faster for a
// moment. The trim is black lacquer with thin white rings.
#include "res://art/shaders/finish_common.gdshaderinc"
#include "res://art/shaders/finish_s2.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.02, 0.02, 0.03);
uniform vec3 trim_color : source_color = vec3(0.04, 0.03, 0.06);
uniform bool is_trim = false;
uniform vec3 color_b : source_color = vec3(0.95, 0.93, 1.0);
uniform vec3 color_c : source_color = vec3(0.65, 0.3, 1.0);

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

void fragment() {
	float t = s2_time(TIME, 0.6) + pulse * pulse * 1.5;
	vec2 uv = fplane(lp, ln);
	float cell = 0.16;
	float ci = floor(uv.x / cell + 0.5);
	vec2 p = uv - vec2(ci * cell, -0.015);
	float dir = mod(ci, 2.0) < 0.5 ? 1.0 : -1.0;
	float a = atan(p.y, p.x) / 6.2832;
	float d = length(p);
	float arms = 2.0;
	float s = fract(d * 38.0 + a * arms * dir - t * 0.8);
	float aa = fwidth(d * 38.0 + a * arms * dir) * 1.5;
	float stripe = smoothstep(0.5 - aa, 0.5 + aa, s) * (1.0 - smoothstep(1.0 - aa, 1.0, s)) + (1.0 - smoothstep(0.0, aa, s));
	stripe = clamp(stripe, 0.0, 1.0);
	if (is_trim) {
		stripe = 1.0 - stripe;
	}
	float breathe = 0.5 + 0.5 * sin(t * 2.0 + ci);
	float eye = exp(-d * d / (0.0004 + 0.0003 * breathe));
	vec3 col = mix(shell_color, color_b, stripe);
	vec3 r = reflect(-VIEW, NORMAL);
	ALBEDO = mix(col, color_c, eye * 0.7);
	METALLIC = 0.0;
	ROUGHNESS = 0.12;
	EMISSION = color_c * (eye * (1.5 + breathe) + stripe * 0.06 * (1.0 - d * 4.0)) + color_b * stripe * 0.08 + s2_coat(NORMAL, VIEW, 0.7);
	if (is_trim) {
		// The trim wears the same scene a shade deeper, with a metal sheen.
		ALBEDO *= 0.8;
		EMISSION = EMISSION * 0.85 + fstudio(reflect(-VIEW, NORMAL), trim_color) * 0.12;
		METALLIC = max(METALLIC, 0.35);
	}
	PRINT_LAYER
}
