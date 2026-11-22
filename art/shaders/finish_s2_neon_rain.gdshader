shader_type spatial;
// Series 2 Epic "Neon Rain": the city after midnight seen through a wet
// window. Big soft bokeh of neon signs (color_b pink, color_c cyan, color_d
// amber) drift and pulse behind dark glass, while raindrops bead, run down
// it and leave streaks that brighten the lights behind them. A kill flashes
// the signs. The trim is wet black chrome.
#include "res://art/shaders/finish_common.gdshaderinc"
#include "res://art/shaders/finish_s2.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.02, 0.02, 0.05);
uniform vec3 trim_color : source_color = vec3(0.06, 0.06, 0.08);
uniform bool is_trim = false;
uniform vec3 color_b : source_color = vec3(1.0, 0.25, 0.65);
uniform vec3 color_c : source_color = vec3(0.2, 0.85, 1.0);
uniform vec3 color_d : source_color = vec3(1.0, 0.65, 0.2);

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

vec3 bokeh(vec2 uv, float t) {
	vec2 q = (uv + vec2(t * 0.004, 0.0)) / 0.045;
	vec2 base = floor(q);
	vec3 acc = vec3(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = base + vec2(float(x), float(y));
			vec3 h = fh33(vec3(id, 11.0));
			vec2 pos = id + 0.5 + (h.xy - 0.5) * 0.8;
			float d = length(q - pos);
			float rad = 0.35 + h.z * 0.5;
			float disc = 1.0 - smoothstep(rad * 0.8, rad, d);
			float k = fract(h.x * 7.0);
			vec3 c = k < 0.4 ? color_b : (k < 0.75 ? color_c : color_d);
			float flick = 0.7 + 0.3 * sin(t * (1.0 + h.y * 2.0) + h.z * 20.0);
			acc += c * disc * (0.35 + 0.25 * smoothstep(rad * 0.6, rad, d)) * flick;
		}
	}
	return acc;
}

void fragment() {
	float t = s2_time(TIME, 7.0);
	vec2 uv = fplane(lp, ln);
	// Running drops: in columns, each drop slides down with a trail above it.
	vec2 q = uv / vec2(0.012, 0.06);
	float colx = floor(q.x);
	vec3 h = fh33(vec3(colx, 1.0, 2.0));
	float y = q.y + t * (0.5 + h.x * 0.9) + h.y * 10.0;
	float fy = fract(y);
	float fx = fract(q.x) - 0.5 + sin(q.y * 4.0 + h.z * 6.0) * 0.08;
	float live = step(0.4, h.z);
	float drop = live * (1.0 - smoothstep(0.16, 0.24, length(vec2(fx, (fy - 0.15) * 0.25) * vec2(1.0, 4.0))));
	float trail = live * s2_band(fx, 0.06) * smoothstep(0.2, 1.0, fy) * 0.6;
	// Static beads on the glass.
	vec2 bq = uv / 0.006;
	vec2 bh = fh22(floor(bq));
	float bead = step(0.82, bh.x) * (1.0 - smoothstep(0.15, 0.3, length(fract(bq) - 0.5 - (bh - 0.5) * 0.3)));
	float wet = max(max(drop, trail), bead);
	vec2 refr = vec2(fx, fy - 0.5) * 0.01 * drop + (fract(bq) - 0.5) * 0.004 * bead;
	vec3 lights = bokeh(uv + refr, t) * (1.0 + pulse * 1.4);
	vec3 r = reflect(-VIEW, NORMAL);
	ALBEDO = shell_color + lights * 0.15;
	METALLIC = 0.0;
	ROUGHNESS = mix(0.2, 0.04, wet);
	EMISSION = lights * (0.55 + wet * 1.3) + vec3(0.8, 0.9, 1.0) * drop * 0.25 + s2_coat(NORMAL, VIEW, 0.5 + wet);
	if (is_trim) {
		// The trim wears the same scene a shade deeper, with a metal sheen.
		ALBEDO *= 0.8;
		EMISSION = EMISSION * 0.85 + fstudio(reflect(-VIEW, NORMAL), trim_color) * 0.12;
		METALLIC = max(METALLIC, 0.35);
	}
	PRINT_LAYER
}
