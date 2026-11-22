shader_type spatial;
// Series 2 Legendary chase print "Event Horizon": black holes set along the
// weapon in a deep starfield. Each wears a tilted accretion disc that swirls
// round it, white-hot within (color_c) through shell_color orange to color_b
// violet, brighter on its approaching side; the far side of the disc is
// lensed up over the hole as a glowing arc, a thin photon ring circles the
// black core and the stars behind bend round it. A kill flares the discs
// and sends a shock ring out. The trim is dark gunmetal with a violet sheen.
#include "res://art/shaders/finish_common.gdshaderinc"
#include "res://art/shaders/finish_s2.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(1.0, 0.5, 0.12);
uniform vec3 trim_color : source_color = vec3(0.08, 0.07, 0.11);
uniform bool is_trim = false;
uniform vec3 color_b : source_color = vec3(0.55, 0.25, 1.0);
uniform vec3 color_c : source_color = vec3(1.0, 0.95, 0.85);
uniform float spacing = 0.21;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

vec3 disc_ramp(float k) {
	vec3 c = mix(color_c, shell_color, smoothstep(0.0, 0.45, k));
	return mix(c, color_b, smoothstep(0.45, 1.0, k));
}

void fragment() {
	float t = s2_time(TIME, 2.5);
	vec2 uv = fplane(lp, ln);
	float ci = floor(uv.x / spacing + 0.5);
	float hs = fh21(vec2(ci, 3.0));
	vec2 p = uv - vec2(ci * spacing + (hs - 0.5) * 0.04, -0.012 + (hs - 0.5) * 0.02);
	float rh = 0.02;
	float d = length(p);
	// Stars, pulled round the hole (gravitational lensing).
	vec2 sp = p * (1.0 + 0.0006 / max(d * d, 0.0001)) + vec2(ci * 3.1, 0.0);
	vec2 sq = sp * 500.0;
	vec2 sid = floor(sq);
	vec3 sh = fh33(vec3(sid, 1.0));
	float star = step(0.985, sh.x) * (1.0 - smoothstep(0.1, 0.4, length(fract(sq) - 0.5))) * (0.5 + 0.5 * sin(t * 2.0 + sh.y * 40.0));
	vec3 space = vec3(0.006, 0.004, 0.018) + color_b * 0.16 * smoothstep(0.3, 0.8, ffbm2(uv * 7.0 + 3.0)) + vec3(0.9, 0.9, 1.0) * star;
	// The disc: an ellipse (tilted towards the viewer), swirling.
	vec2 dp = vec2(p.x, p.y * 2.4);
	float dr = length(dp);
	float da = atan(dp.y, dp.x);
	// Inner rings turn faster than outer ones, winding the gas into streaks.
	vec2 rq = s2_rot(t * 0.5 + 0.006 / max(dr, 0.006)) * dp;
	float swirl = ffbm2(rq * 45.0 + 7.0);
	float streaks = 0.6 + 0.4 * sin(da * 6.0 - t * 3.0 + dr * 400.0 + swirl * 5.0);
	float inner = rh * 1.25;
	float outer = 0.12 + 0.02 * hs;
	float ring = smoothstep(inner, inner * 1.3, dr) * (1.0 - smoothstep(outer * 0.6, outer, dr));
	float k = clamp((dr - inner) / (outer - inner), 0.0, 1.0);
	float doppler = 0.55 + 0.45 * cos(da);
	float flare = 1.0 + pulse * 2.0;
	vec3 disc = disc_ramp(k) * ring * (0.4 + swirl * 1.2) * streaks * doppler * flare;
	// The front half of the disc passes in front of the hole; the back half
	// is hidden by it but lensed up over the top as an arc.
	float front = step(p.y, 0.0);
	float shadow = 1.0 - smoothstep(rh * 0.95, rh * 1.05, d);
	float arc_r = length(vec2(p.x, (p.y - rh * 0.2) * 1.1));
	float arc = exp(-pow((arc_r - rh * 1.55) / (rh * 0.28), 2.0)) * smoothstep(-0.2, 0.6, p.y / max(d, 1e-4));
	vec3 lensed = disc_ramp(0.15 + 0.3 * (0.5 + 0.5 * sin(p.x / max(d, 1e-4) * 3.0 - t * 1.2))) * arc * 1.4 * flare;
	float photon = exp(-pow((d - rh * 1.08) / (rh * 0.07), 2.0));
	float shock = pulse > 0.0 ? exp(-pow((d - (1.0 - pulse) * 0.14) / 0.004, 2.0)) * pulse : 0.0;
	vec3 col = space * (1.0 - shadow);
	col += lensed * (1.0 - shadow);
	col += color_c * photon * 1.6;
	col = mix(col, disc + col * 0.3, ring * max(front, 1.0 - shadow));
	col *= 1.0 - shadow * (1.0 - front * ring);
	col += mix(color_c, color_b, 0.4) * shock * 2.0;
	vec3 r = reflect(-VIEW, NORMAL);
	ALBEDO = col * 0.25;
	METALLIC = 0.0;
	ROUGHNESS = 0.08;
	EMISSION = col + s2_coat(NORMAL, VIEW, 0.5);
	if (is_trim) {
		// The trim wears the same scene a shade deeper, with a metal sheen.
		ALBEDO *= 0.8;
		EMISSION = EMISSION * 0.85 + fstudio(reflect(-VIEW, NORMAL), trim_color) * 0.12;
		METALLIC = max(METALLIC, 0.35);
	}
	PRINT_LAYER
}
