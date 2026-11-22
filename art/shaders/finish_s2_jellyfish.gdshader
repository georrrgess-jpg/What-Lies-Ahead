shader_type spatial;
// Series 2 Epic "Jelly Ballroom": a night aquarium. Deep water (shell_color)
// with rippling caustics and drifting motes, and glowing jellyfish rising
// through it, bells pulsing as they swim and tentacles trailing and waving
// behind them (color_b pink, color_c violet, color_d cyan). A kill makes them
// all flash. The trim is the tank's dark bronze frame catching the glow.
#include "res://art/shaders/finish_common.gdshaderinc"
#include "res://art/shaders/finish_s2.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.01, 0.06, 0.16);
uniform vec3 trim_color : source_color = vec3(0.35, 0.25, 0.15);
uniform bool is_trim = false;
uniform vec3 color_b : source_color = vec3(1.0, 0.4, 0.75);
uniform vec3 color_c : source_color = vec3(0.6, 0.4, 1.0);
uniform vec3 color_d : source_color = vec3(0.3, 0.95, 1.0);

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

// One layer of jellyfish: rgb glow, a = body coverage.
vec4 jellies(vec2 uv, float cell, float t, float layer) {
	vec2 q = uv / cell;
	float colx = floor(q.x);
	float h0 = fh21(vec2(colx, layer));
	q.y -= t * (0.18 + 0.12 * h0) + h0 * 4.0;
	vec2 id = floor(q);
	vec3 h = fh33(vec3(id, layer + 4.0));
	if (h.x > 0.55) {
		return vec4(0.0);
	}
	vec2 f = fract(q) - vec2(0.5 + (h.y - 0.5) * 0.3, 0.62);
	float beat = 0.5 + 0.5 * sin(t * (2.2 + h.z) + h.x * 20.0);
	float w = 0.26 + 0.05 * beat;
	float hgt = 0.2 - 0.05 * beat;
	// Bell: the top half of an ellipse with a scalloped skirt.
	vec2 b = vec2(f.x / w, f.y / hgt);
	float skirt = 0.06 * sin(f.x * 60.0 + t * 3.0);
	float bell = (1.0 - smoothstep(0.92, 1.0, length(b))) * step(skirt, f.y);
	float rim = bell * smoothstep(0.55, 1.0, length(b));
	float inner = bell * (1.0 - smoothstep(0.0, 0.45, length(b - vec2(0.0, 0.35))));
	// Tentacles: wavy lines hanging below the bell, fading out.
	float ten = 0.0;
	float below = -f.y;
	if (below > 0.0 && below < 0.55) {
		for (int i = 0; i < 4; i++) {
			float x0 = (float(i) - 1.5) * w * 0.42;
			float wave = sin(below * 22.0 - t * 4.0 + float(i) * 1.7) * 0.03 * (below * 3.0);
			ten += s2_band(f.x - x0 - wave, 0.012) * (1.0 - below / 0.55);
		}
	}
	vec3 ink = h.z < 0.33 ? color_b : (h.z < 0.66 ? color_c : color_d);
	vec3 glow = ink * (rim * 1.4 + inner * 0.9 + bell * 0.35 + min(ten, 1.0) * 0.8) * (0.7 + 0.5 * beat);
	return vec4(glow, max(bell, min(ten, 1.0) * 0.6));
}

void fragment() {
	float t = s2_time(TIME, 5.0);
	vec2 uv = fplane(lp, ln);
	vec2 c = uv * 45.0;
	float caus = abs(sin(c.x + sin(c.y * 1.3 + t * 0.7) + t * 0.4)) * abs(sin(c.y * 1.1 + sin(c.x * 0.8 - t * 0.5) - t * 0.3));
	caus = pow(1.0 - caus, 6.0);
	vec3 water = shell_color * (0.75 + 0.5 * smoothstep(-0.1, 0.1, uv.y)) + color_d * caus * 0.08;
	float mote = step(0.993, fh21(floor((uv + vec2(0.0, t * 0.004)) * 500.0)));
	vec4 far = jellies(uv, 0.05, t * 0.7, 1.0);
	vec4 near = jellies(uv, 0.085, t, 2.0);
	vec3 r = reflect(-VIEW, NORMAL);
	float flash = 1.0 + pulse * 1.5;
	vec3 col = mix(water, water + far.rgb * 0.3, far.a);
	col = mix(col, near.rgb * 0.35 + col * 0.5, near.a);
	ALBEDO = col;
	METALLIC = 0.0;
	ROUGHNESS = 0.1;
	EMISSION = (far.rgb * 0.7 + near.rgb * 1.5) * flash + color_d * caus * 0.06 + vec3(0.6, 0.9, 1.0) * mote * 0.4 + s2_coat(NORMAL, VIEW, 0.7);
	if (is_trim) {
		// The trim wears the same scene a shade deeper, with a metal sheen.
		ALBEDO *= 0.8;
		EMISSION = EMISSION * 0.85 + fstudio(reflect(-VIEW, NORMAL), trim_color) * 0.12;
		METALLIC = max(METALLIC, 0.35);
	}
	PRINT_LAYER
}
