shader_type spatial;
// Weapon finish "Aurora": a polar night sky with tiny stars, and two aurora
// curtains (green with a pink fringe, and violet) rippling along the weapon,
// their vertical rays shimmering. On the trim it shows through frosted glass.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.01, 0.02, 0.07);
uniform vec3 trim_color : source_color = vec3(0.7, 0.78, 0.85);
uniform bool is_trim = false;
uniform vec3 curtain_a : source_color = vec3(0.15, 1.0, 0.55);
uniform vec3 curtain_b : source_color = vec3(0.6, 0.3, 1.0);
uniform vec3 fringe : source_color = vec3(1.0, 0.3, 0.6);
uniform float speed = 0.5;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

// A curtain whose lower edge waves along u; it hangs upward from the edge.
vec2 curtain(vec2 uv, float base, float seed) {
	float t = TIME * speed;
	float edge = base + sin(uv.x * 9.0 + t * 0.8 + seed) * 0.025 + (fnoise2(vec2(uv.x * 4.0 - t * 0.3, seed)) - 0.5) * 0.08;
	float d = uv.y - edge;
	float rays = 0.55 + 0.45 * fnoise2(vec2(uv.x * 90.0 + fnoise2(vec2(uv.x * 6.0, t)) * 8.0, t * 0.7 + seed));
	float body = smoothstep(-0.006, 0.004, d) * exp(-max(d, 0.0) * 16.0) * rays;
	float top = smoothstep(0.03, 0.08, d) * exp(-max(d, 0.0) * 14.0) * rays;
	return vec2(body, top);
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	vec2 uv = fplane(lp, ln);
	vec2 a = curtain(uv, -0.09, 0.0);
	vec2 b = curtain(uv, 0.0, 4.0);
	vec3 light = curtain_a * a.x * 1.6 + fringe * a.y * 0.7 + curtain_b * b.x * 0.9 + fringe * b.y * 0.3;
	vec3 q = lp * 120.0;
	vec3 c = floor(q);
	float h = fh31(c);
	float star = step(0.93, h) * smoothstep(0.2, 0.0, length(fract(q) - 0.5)) * (0.6 + 0.4 * sin(TIME * 3.0 + h * 50.0));
	vec3 sky = shell_color + vec3(0.0, 0.03, 0.05) * smoothstep(-0.1, 0.1, uv.y);
	if (is_trim) {
		// The same sky seen through frosted silver glass, rime sparkling.
		float frost = fnoise3(lp * 160.0);
		float rime = step(0.9, fh31(floor(lp * 260.0)));
		ALBEDO = mix(sky, trim_color, 0.3) * (0.8 + 0.2 * frost);
		METALLIC = 0.4;
		ROUGHNESS = 0.35;
		EMISSION = mix(sky, trim_color, 0.15) * 0.5 + light * 0.75 + vec3(0.9, 0.95, 1.0) * rime * 0.5
			+ fstudio(r, trim_color) * 0.15 + curtain_a * fres * 0.2;
	} else {
		ALBEDO = sky + light * 0.1;
		METALLIC = 0.1;
		ROUGHNESS = 0.25;
		EMISSION = sky * 0.5 + light + vec3(0.9, 0.95, 1.0) * star * 1.5;
	}
}
