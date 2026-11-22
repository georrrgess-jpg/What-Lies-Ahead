shader_type spatial;
// Series 2 Epic "Firefly Field": a midsummer midnight. Layered silhouettes
// of grass and leaves in shell_color over a deep color_b dusk, and fireflies
// drifting on lazy loops, each glowing up and fading on its own rhythm
// (color_c, with a warmer core). A kill wakes them all at once. Trim: dark
// bronze lit by them.
#include "res://art/shaders/finish_common.gdshaderinc"
#include "res://art/shaders/finish_s2.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.01, 0.05, 0.04);
uniform vec3 trim_color : source_color = vec3(0.3, 0.22, 0.12);
uniform bool is_trim = false;
uniform vec3 color_b : source_color = vec3(0.04, 0.08, 0.2);
uniform vec3 color_c : source_color = vec3(0.75, 1.0, 0.3);

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

// Fireflies of one grid: the glow at uv.
float flies(vec2 uv, float cell, float t, float layer) {
	vec2 q = uv / cell;
	vec2 base = floor(q);
	float glow = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = base + vec2(float(x), float(y));
			vec3 h = fh33(vec3(id, layer));
			vec2 pos = id + 0.5 + 0.35 * vec2(sin(t * (0.3 + h.x * 0.4) + h.y * 6.28), sin(t * (0.25 + h.y * 0.3) + h.z * 6.28));
			float d = length(q - pos) * cell;
			float blink = smoothstep(0.2, 1.0, sin(t * (0.7 + h.z) + h.x * 30.0));
			blink = max(blink, pulse);
			glow += (exp(-d * d / 0.000006) * 1.8 + exp(-d * d / 0.00008) * 0.5) * blink;
		}
	}
	return glow;
}

void fragment() {
	float t = s2_time(TIME, 3.3);
	vec2 uv = fplane(lp, ln);
	vec3 sky = color_b * (0.6 + 0.7 * smoothstep(-0.12, 0.08, uv.y));
	// Three layers of leaves and grass blades, nearer ones darker.
	float l1 = step(0.52, ffbm2(uv * vec2(18.0, 40.0)));
	float l2 = step(0.55, ffbm2(uv * vec2(30.0, 70.0) + 5.0));
	float blades = step(0.75, fract(uv.x * 140.0 + ffbm2(uv * 20.0) * 3.0)) * step(0.45, fnoise2(uv * vec2(10.0, 30.0)));
	vec3 col = mix(sky, shell_color * 2.2, l1 * 0.7);
	col = mix(col, shell_color * 1.4, l2);
	col = mix(col, shell_color, blades);
	float g = flies(uv, 0.022, t, 1.0) + flies(uv, 0.04, t * 0.8, 2.0) * 0.8;
	vec3 fly = mix(color_c, vec3(1.0, 0.95, 0.6), clamp(g - 0.8, 0.0, 1.0));
	vec3 r = reflect(-VIEW, NORMAL);
	ALBEDO = col + fly * min(g, 1.0) * 0.3;
	METALLIC = 0.0;
	ROUGHNESS = 0.55;
	EMISSION = fly * g * 1.6 + sky * 0.15;
	if (is_trim) {
		// The trim wears the same scene a shade deeper, with a metal sheen.
		ALBEDO *= 0.8;
		EMISSION = EMISSION * 0.85 + fstudio(reflect(-VIEW, NORMAL), trim_color) * 0.12;
		METALLIC = max(METALLIC, 0.35);
	}
	PRINT_LAYER
}
