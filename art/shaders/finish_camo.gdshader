shader_type spatial;
// Static camouflage family for weapon finishes, picked by `pattern`:
//   0 splinter (sharp angular shards)   1 tiger stripe   2 organic blots
//   3 fleck (clustered dots)
// Four colours: shell_color (ground), color_b, color_c, color_d. The trim
// wears the same camo on trim_color. Contract: weapon_cosmetics.gd.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.8, 0.7, 0.5);
uniform vec3 trim_color : source_color = vec3(0.15, 0.13, 0.1);
uniform bool is_trim = false;
uniform int pattern = 0;
uniform vec3 color_b : source_color = vec3(0.5, 0.45, 0.3);
uniform vec3 color_c : source_color = vec3(0.6, 0.3, 0.1);
uniform vec3 color_d : source_color = vec3(0.1, 0.1, 0.08);
uniform float scale = 1.0;
uniform float roughness = 0.6;
uniform float metallic = 0.1;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

vec2 rot(vec2 p, float a) {
	return mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * p;
}

// Angular shards: rotated, sheared blocks from two crossing grids.
vec3 splinter(vec3 g, vec2 uv) {
	vec2 a = rot(uv, 0.5) * vec2(9.0, 26.0);
	vec2 b = rot(uv, -0.35) * vec2(14.0, 7.0);
	vec2 c = rot(uv, 1.1) * vec2(20.0, 11.0);
	float ha = fh21(floor(a + vec2(floor(a.y) * 0.37, 0.0)));
	float hb = fh21(floor(b + vec2(0.0, floor(b.x) * 0.53)) + 9.0);
	float hc = fh21(floor(c) + 21.0);
	vec3 col = g;
	col = mix(col, color_b, step(0.55, ha));
	col = mix(col, color_c, step(0.62, hb));
	col = mix(col, color_d, step(0.78, hc) * step(0.4, ha));
	return col;
}

// Tiger stripe: tapered bands across the weapon with ragged edges.
vec3 tiger(vec3 g, vec2 uv) {
	float warp = ffbm2(uv * vec2(8.0, 5.0)) * 2.0;
	float band = sin(uv.x * 55.0 + warp * 3.0 + uv.y * 12.0);
	float thick = 0.45 + 0.35 * fnoise2(uv * vec2(6.0, 20.0) + 4.0);
	float s1 = smoothstep(thick, thick + 0.06, band);
	float band2 = sin(uv.x * 55.0 + warp * 3.0 + uv.y * 12.0 + 1.6);
	float s2 = smoothstep(0.82, 0.88, band2) * step(0.45, fnoise2(uv * 9.0 + 2.0));
	float edge = smoothstep(thick - 0.12, thick - 0.04, band) * (1.0 - s1);
	vec3 col = mix(g, color_b, s1);
	col = mix(col, color_d, edge * 0.8);
	return mix(col, color_c, s2);
}

// Organic blots: three thresholded noise layers in 3D (wraps every face).
vec3 blots(vec3 g, vec3 p) {
	float n1 = ffbm3(p * 14.0);
	float n2 = ffbm3(p * 16.0 + 17.0);
	float n3 = ffbm3(p * 22.0 + 33.0);
	vec3 col = g;
	col = mix(col, color_b, smoothstep(0.5, 0.52, n1));
	col = mix(col, color_c, smoothstep(0.56, 0.58, n2));
	return mix(col, color_d, smoothstep(0.6, 0.62, n3));
}

// Flecks: overlapping dots in clusters (two jittered grids).
vec3 fleck(vec3 g, vec2 uv) {
	vec3 col = g;
	for (int k = 0; k < 2; k++) {
		float s = k == 0 ? 0.026 : 0.017;
		vec2 q = uv / s + float(k) * 7.3;
		vec2 c = floor(q);
		vec2 o = fh22(c + float(k) * 3.0) * 0.5 + 0.25;
		float d = length(fract(q) - o);
		float h = fh21(c + 11.0 + float(k));
		float cluster = fnoise2(uv * 10.0 + float(k) * 5.0);
		float on = step(1.0 - cluster * 1.1, h) * smoothstep(0.42, 0.36, d);
		vec3 pick = h > 0.85 ? color_d : (h > 0.6 ? color_c : color_b);
		col = mix(col, pick, on);
	}
	return col;
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	vec3 ground = is_trim ? trim_color : shell_color;
	vec2 uv = fplane(lp, ln) * scale;
	vec3 col;
	if (pattern == 0) {
		col = splinter(ground, uv);
	} else if (pattern == 1) {
		col = tiger(ground, uv);
	} else if (pattern == 2) {
		col = blots(ground, lp * scale);
	} else {
		col = fleck(ground, uv);
	}
	ALBEDO = col;
	METALLIC = metallic + (is_trim ? 0.15 : 0.0);
	ROUGHNESS = roughness * (is_trim ? 0.8 : 1.0);
	EMISSION = fstudio(r, col) * 0.06;
}
