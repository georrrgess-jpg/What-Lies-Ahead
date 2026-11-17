shader_type spatial;
// Weapon finish "Kintsugi": deep raku glaze broken and mended with gold. The
// cracks are the borders of a warped 3D Voronoi field (they wrap round the
// weapon like real breaks), filled with polished gold; slow pulses of molten
// light run through them, each crack on its own beat, warming the glaze
// beside them. A fine crackle sits in the glaze. Trim is burnished gold leaf
// with the same breaks showing dark.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.05, 0.08, 0.2);
uniform vec3 trim_color : source_color = vec3(1.0, 0.74, 0.3);
uniform bool is_trim = false;
uniform float scale = 9.0;
uniform float pulse_rate = 1.6;

varying vec3 lp;

// Warped Voronoi: x = distance to the nearest border (F2 - F1), y = an id of
// the nearest cell (0-1).
vec2 cracks(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = fh33(i + g);
				vec3 r = g + o - f;
				float d = dot(r, r);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					id = fh31(i + g);
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec2(sqrt(d2) - sqrt(d1), id);
}

void vertex() {
	lp = print_xform(VERTEX);
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	// Jagged breaks: the field is pushed about by a finer noise.
	vec3 q = lp * scale + (vec3(fnoise3(lp * 34.0), fnoise3(lp * 34.0 + 7.1), fnoise3(lp * 34.0 + 3.3)) - 0.5) * 0.45;
	vec2 c = cracks(q);
	float width = 0.022 + 0.04 * fnoise3(lp * 11.0 + 2.0);
	float aa = fwidth(c.x) * 0.8 + 1e-4;
	float seam = smoothstep(width + aa, width - aa, c.x);
	// Fine crackle in the glaze.
	float crackle = smoothstep(0.05, 0.0, cracks(lp * 42.0).x);
	// Molten pulses: bright bands sliding along each crack, phase per cell.
	float wave = sin(lp.z * 22.0 + lp.y * 9.0 - TIME * pulse_rate * 2.0 + c.y * 6.283);
	float molten = pow(max(wave, 0.0), 10.0);
	vec3 gold = vec3(1.0, 0.76, 0.33);
	vec3 hot = vec3(1.0, 0.55, 0.18);
	float halo = exp(-max(c.x - width, 0.0) * 28.0) * molten * (1.0 - seam);
	if (is_trim) {
		float brush = fnoise2(vec2(lp.z * 6.0, lp.y * 220.0 + lp.x * 220.0));
		vec3 leaf = trim_color * (0.86 + 0.14 * brush);
		ALBEDO = mix(leaf, vec3(0.08, 0.05, 0.04), seam * 0.85);
		METALLIC = 1.0 - seam * 0.8;
		ROUGHNESS = mix(0.26, 0.6, seam);
		// Some of the leaf's own colour glows, so it stays gold under any sky.
		EMISSION = (fstudio(r, trim_color) * (0.4 + fres * 0.3) + trim_color * 0.22) * (1.0 - seam) + hot * seam * molten * 1.6;
	} else {
		float mottle = ffbm3(lp * 14.0);
		vec3 glaze = mix(shell_color * 0.7, shell_color * 1.6 + vec3(0.0, 0.05, 0.06), mottle);
		// Pooled glaze turns iridescent at grazing angles (raku).
		glaze += fhue(mottle * 1.5 + fres * 0.6 + 0.45) * pow(fres, 2.0) * 0.18;
		glaze *= 1.0 - crackle * 0.35;
		ALBEDO = mix(glaze, gold * 0.9, seam);
		METALLIC = seam;
		ROUGHNESS = mix(0.1, 0.22, seam);
		SPECULAR = 0.7;
		EMISSION = fstudio(r, gold) * seam * 0.55 + gold * seam * 0.25
			+ fstudio(r, vec3(0.7, 0.8, 1.0)) * fres * 0.18 * (1.0 - seam)
			+ (hot * 2.2 + vec3(0.6)) * seam * molten + hot * halo * 0.6;
	}
	PRINT_LAYER
}
