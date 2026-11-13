shader_type spatial;
// Weapon finish "Cathedral Glass": jewel-toned panes of leaded glass (ruby,
// sapphire, emerald, amber, amethyst) with seeded texture in each pane. A
// beam of light slowly passes along the weapon, setting the panes it crosses
// aglow. On the trim the panes sit in heavier pewter lead.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.7, 0.05, 0.12);
uniform vec3 trim_color : source_color = vec3(0.18, 0.18, 0.2);
uniform bool is_trim = false;
uniform float pane = 0.045;
uniform float sweep = 0.12;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

vec3 jewel(float h) {
	if (h < 0.22) {
		return shell_color;
	} else if (h < 0.42) {
		return vec3(0.08, 0.2, 0.85);
	} else if (h < 0.6) {
		return vec3(0.05, 0.6, 0.25);
	} else if (h < 0.8) {
		return vec3(1.0, 0.62, 0.08);
	}
	return vec3(0.5, 0.12, 0.75);
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	// 2D Voronoi panes: nearest and second-nearest jittered centre (3x3).
	vec2 uv = fplane(lp, ln) / pane;
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 best = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = fh22(i + g) * 0.8 + 0.1;
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				best = i + g;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float lead = smoothstep(0.05, 0.11, d2 - d1);
	float h = fh21(best);
	vec3 glass = jewel(h) * (0.85 + 0.3 * fnoise2(uv * 6.0 + h * 10.0));
	// The light beam: a soft band travelling along the barrel and back.
	float pos = sin(TIME * sweep * 6.2831) * 0.45 - 0.15;
	float beam = exp(-pow((lp.z - pos + lp.y * 0.5) * 7.0, 2.0));
	float pane_lit = 0.35 + 0.65 * beam + 0.15 * sin(TIME * 1.3 + h * 20.0) * (1.0 - beam);
	// Trim: darker panes in heavier pewter lead.
	float came = is_trim ? smoothstep(0.1, 0.18, d2 - d1) : lead;
	float k = is_trim ? 0.55 : 1.0;
	ALBEDO = mix(trim_color * 0.6, glass * 0.5, came);
	METALLIC = (1.0 - came) * 0.6;
	ROUGHNESS = mix(0.45, 0.08, came);
	EMISSION = (glass * came * pane_lit * 1.5 + vec3(1.0, 0.95, 0.8) * came * beam * 0.25) * k
		+ fstudio(r, vec3(0.6)) * came * pow(fres, 2.0) * 0.4 + fstudio(r, trim_color * 2.0) * (1.0 - came) * 0.2;
}
