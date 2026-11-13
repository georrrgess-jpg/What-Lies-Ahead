shader_type spatial;
// Static natural-material family for weapon finishes, picked by `pattern`:
//   0 oiled wood grain (shell, color_b grain)
//   1 brass with verdigris (shell brass, color_b patina, color_c tarnish)
//   2 etched meteoric iron (shell, color_b lamellae, color_c lines)
//   3 iridescent fish scales (shell to color_b with the angle, color_c rims)
//   4 abalone nacre (shell, color_b, color_c bands, dark seams)
//   5 candy paint with metal flake (shell paint, color_b flakes)
// The trim draws the same material with trim_color as its ground.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.35, 0.18, 0.09);
uniform vec3 trim_color : source_color = vec3(0.85, 0.65, 0.3);
uniform bool is_trim = false;
uniform int pattern = 0;
uniform vec3 color_b : source_color = vec3(0.15, 0.07, 0.03);
uniform vec3 color_c : source_color = vec3(0.6, 0.4, 0.2);
uniform float scale = 1.0;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

// Each pattern returns its colour and writes roughness, metallic and the
// strength of the studio reflection through out parameters.
vec3 wood(vec3 g, vec3 p, out float rough, out float metal, out float refl) {
	vec3 q = p * scale;
	float warp = ffbm3(q * vec3(6.0, 6.0, 1.2)) * 1.4;
	float rings = length(q.xy - vec2(0.35, -0.6)) * 55.0 + warp * 4.0;
	float ring = fract(rings);
	float late = smoothstep(0.55, 0.95, ring) + smoothstep(0.08, 0.0, ring);
	float pores = fnoise3(q * vec3(500.0, 500.0, 18.0));
	vec3 col = mix(g, color_b, late * 0.75);
	col *= 0.85 + 0.25 * pores;
	rough = 0.38;
	metal = 0.0;
	refl = 0.12;
	return col;
}

vec3 brass(vec3 g, vec3 p, out float rough, out float metal, out float refl) {
	float n = ffbm3(p * scale * 18.0);
	float fine = fnoise3(p * scale * 160.0);
	float patina = smoothstep(0.62, 0.66, n + fine * 0.1);
	float tarnish = smoothstep(0.45, 0.55, n) * (1.0 - patina);
	vec3 col = mix(g, color_c, tarnish * 0.7);
	col = mix(col, color_b * (0.85 + 0.3 * fine), patina);
	rough = mix(0.22, 0.9, patina);
	metal = mix(0.85, 0.0, patina);
	refl = mix(0.85, 0.0, patina);
	return col;
}

vec3 meteor(vec3 g, vec3 p, out float rough, out float metal, out float refl) {
	vec3 q = p * scale;
	float region = fnoise3(q * 9.0);
	float jitter = fnoise3(q * 40.0) * 0.4;
	float t1 = fract(dot(q, vec3(0.6, 0.5, 0.62)) * 70.0 + jitter);
	float t2 = fract(dot(q, vec3(-0.5, 0.7, 0.5)) * 58.0 + jitter);
	float t3 = fract(dot(q, vec3(0.3, -0.4, 0.86)) * 64.0 + jitter);
	float l1 = smoothstep(0.0, 0.06, t1) * smoothstep(0.45, 0.38, t1);
	float l2 = smoothstep(0.0, 0.06, t2) * smoothstep(0.4, 0.33, t2);
	float l3 = smoothstep(0.0, 0.06, t3) * smoothstep(0.5, 0.42, t3);
	float lam = max(max(l1 * step(region, 0.62), l2 * step(0.38, region)), l3 * step(abs(region - 0.5), 0.2));
	float lines = 1.0 - max(max(smoothstep(0.02, 0.0, t1), smoothstep(0.02, 0.0, t2)), smoothstep(0.02, 0.0, t3));
	vec3 col = mix(g, color_b, lam);
	col = mix(color_c, col, lines);
	rough = mix(0.45, 0.25, lam);
	metal = 0.8;
	refl = mix(0.25, 0.45, lam);
	return col;
}

vec3 scales(vec3 g, vec2 uv, float fres, out float rough, out float metal, out float refl) {
	float s = 0.02;
	vec2 q = uv / vec2(s, s * 0.7);
	// Discs on a staggered lattice; where they overlap, the one centred
	// furthest back (larger u) is on top. Four candidates cover every point.
	float best = -1e6;
	float best_d = 1.0;
	for (int k = 0; k < 4; k++) {
		float row = floor(q.y) + float(k / 2);
		float shift = 0.5 * mod(row, 2.0);
		vec2 centre = vec2(floor(q.x - shift) + shift + float(k % 2), row);
		float d = length((q - centre) * vec2(1.0, 0.8));
		if (d < 0.8 && centre.x > best) {
			best = centre.x;
			best_d = d;
		}
	}
	float rim = smoothstep(0.62, 0.78, best_d);
	float shade = 0.75 + 0.25 * (1.0 - best_d);
	vec3 irid = mix(g, color_b, clamp(fres * 1.5 + best_d * 0.4, 0.0, 1.0));
	rough = 0.25;
	metal = 0.5;
	refl = 0.25;
	return mix(irid * shade, color_c, rim * 0.8);
}

vec3 nacre(vec3 g, vec3 p, float fres, out float rough, out float metal, out float refl) {
	vec3 q = p * scale;
	float t = ffbm3(q * 9.0 + ffbm3(q * 3.0) * 2.5) * 9.0 + q.z * 10.0;
	float band = fract(t);
	float seam = smoothstep(0.1, 0.0, band) * 0.9;
	float shift = fract(t * 0.37 + fres * 0.6);
	vec3 col = shift < 0.33 ? mix(g, color_b, shift * 3.0) : (shift < 0.66 ? mix(color_b, color_c, shift * 3.0 - 1.0) : mix(color_c, g, shift * 3.0 - 2.0));
	rough = 0.12;
	metal = 0.3;
	refl = 0.3;
	return col * (1.0 - seam) * (0.55 + 0.6 * band);
}

// Metal flake: sparse tiny flakes, each tilted its own way, that glint when
// the reflection lines up with them (so they twinkle as the weapon turns).
float flake_glint(vec3 p, vec3 r) {
	vec3 q = p * scale * 650.0;
	vec3 c = floor(q);
	vec3 dir = normalize(fh33(c) - 0.5);
	float on = step(0.7, fh31(c + 4.0)) * smoothstep(0.5, 0.3, length(fract(q) - 0.5));
	return on * (0.04 + pow(max(dot(dir, normalize(r + vec3(0.0, 0.0, 0.3))), 0.0), 24.0));
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 2.5);
	vec3 ground = is_trim ? trim_color : shell_color;
	float rough;
	float metal;
	float refl;
	float glint = 0.0;
	vec3 col;
	if (pattern == 0) {
		col = wood(ground, lp, rough, metal, refl);
	} else if (pattern == 1) {
		col = brass(ground, lp, rough, metal, refl);
	} else if (pattern == 2) {
		col = meteor(ground, lp, rough, metal, refl);
	} else if (pattern == 3) {
		col = scales(ground, fplane(lp, ln) * scale, fres, rough, metal, refl);
	} else if (pattern == 4) {
		col = nacre(ground, lp, fres, rough, metal, refl);
	} else {
		glint = flake_glint(lp, r);
		col = ground + color_b * glint * 0.5;
		rough = 0.15;
		metal = 0.2;
		refl = 0.35;
	}
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = rough;
	// Metals reflect their own colour; paints and coats a white clear coat.
	vec3 tint = metal > 0.4 ? col : vec3(0.6);
	EMISSION = fstudio(r, tint) * refl * (0.7 + 0.6 * fres) + color_b * glint * 2.5
		+ (pattern == 5 ? ground * 0.12 : vec3(0.0));
}
