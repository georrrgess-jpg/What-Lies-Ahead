shader_type spatial;
// Series 2 Epic "Liquid Neon": glossy black glass with tubes of neon that
// flow like poured liquid, the lines bending and drifting along the weapon
// and shifting from shell_color pink through color_b violet to trim_color
// cyan. A kill makes every tube flare. The trim is dark chrome lit by them.
#include "res://art/shaders/finish_common.gdshaderinc"
#include "res://art/shaders/finish_s2.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(1.0, 0.2, 0.65);
uniform vec3 trim_color : source_color = vec3(0.2, 0.9, 1.0);
uniform bool is_trim = false;
uniform vec3 color_b : source_color = vec3(0.55, 0.3, 1.0);
uniform float flow = 1.0;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

void fragment() {
	float t = s2_time(TIME, 4.0) * flow;
	vec2 uv = fplane(lp, ln);
	vec2 q = uv * vec2(6.0, 9.0) + vec2(t * 0.18, 0.0);
	vec2 warp = vec2(ffbm2(q * 0.8 + vec2(0.0, t * 0.11)), ffbm2(q * 0.8 + vec2(5.2, -t * 0.09)));
	float field = ffbm2(q + warp * 1.6);
	float lines = field * 7.0;
	float d = abs(fract(lines) - 0.5);
	float aa = fwidth(lines) * 1.2;
	float core = 1.0 - smoothstep(0.035, 0.035 + aa, d);
	float halo = exp(-d * d * 60.0);
	float hue = fract(field * 1.7 + floor(lines) * 0.31 + t * 0.03);
	vec3 neon = hue < 0.33 ? mix(shell_color, color_b, hue * 3.0)
		: (hue < 0.66 ? mix(color_b, trim_color, (hue - 0.33) * 3.0) : mix(trim_color, shell_color, (hue - 0.66) * 3.0));
	float flare = 1.0 + pulse * 1.6;
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	ALBEDO = mix(vec3(0.015, 0.012, 0.03), neon * 0.6, core);
	METALLIC = 0.0;
	ROUGHNESS = 0.08;
	EMISSION = neon * (core * 1.3 + halo * 0.35) * flare + s2_coat(NORMAL, VIEW, 0.8) + vec3(1.0) * pow(fres, 4.0) * 0.1;
	if (is_trim) {
		// The trim wears the same scene a shade deeper, with a metal sheen.
		ALBEDO *= 0.8;
		EMISSION = EMISSION * 0.85 + fstudio(reflect(-VIEW, NORMAL), trim_color) * 0.12;
		METALLIC = max(METALLIC, 0.35);
	}
	PRINT_LAYER
}
