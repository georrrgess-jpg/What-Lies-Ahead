shader_type spatial;
// Series 2 Legendary chase print "Opening Night": a premiere. Deep folds of
// shell_color red velvet curtain hang along the weapon with a gold fringe
// band; two searchlight beams sweep across them, lighting pools that slide
// over the folds, gold stars of fame shine in them, and press flashbulbs pop
// here and there. A kill is the red-carpet moment: a burst of flashbulbs.
// The trim is polished gold with a marquee row of chasing bulbs.
#include "res://art/shaders/finish_common.gdshaderinc"
#include "res://art/shaders/finish_s2.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.55, 0.02, 0.06);
uniform vec3 trim_color : source_color = vec3(1.0, 0.74, 0.3);
uniform bool is_trim = false;
uniform vec3 color_b : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3 color_c : source_color = vec3(1.0, 0.8, 0.35);

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

float star5(vec2 p, float r) {
	float a = atan(p.y, p.x) + 1.5708;
	float k = 0.5 + 0.5 * cos(a * 5.0);
	return 1.0 - smoothstep(r * (0.45 + 0.55 * k) - 0.01, r * (0.45 + 0.55 * k) + 0.01, length(p));
}

void fragment() {
	float t = s2_time(TIME, 2.2);
	vec2 uv = fplane(lp, ln);
	vec3 r = reflect(-VIEW, NORMAL);
	// Two searchlights sweep along the weapon at different speeds.
	float s1 = sin(t * 0.55) * 0.3;
	float s2 = sin(t * 0.37 + 2.0) * 0.32;
	float beam1 = exp(-pow((uv.x - s1 - uv.y * 0.8) / 0.035, 2.0));
	float beam2 = exp(-pow((uv.x - s2 + uv.y * 0.7) / 0.04, 2.0));
	float lit = beam1 + beam2;
	// Flashbulbs: random pops, many at once on a kill.
	vec2 fq = uv / 0.035;
	vec2 fid = floor(fq);
	vec3 fh = fh33(vec3(fid, floor(t * 1.5)));
	float pop_t = fract(t * 1.5);
	float pops = step(0.9 - pulse * 0.4, fh.x) * exp(-pop_t * 6.0) * motion;
	vec2 fp = fract(fq) - 0.5 - (fh.yz - 0.5) * 0.5;
	float bulb = exp(-dot(fp, fp) * 60.0) * pops;
	float glare = (exp(-abs(fp.x) * 40.0) * exp(-abs(fp.y) * 4.0) + exp(-abs(fp.y) * 40.0) * exp(-abs(fp.x) * 4.0)) * pops;
	float burst = pulse * pulse;
	// Velvet folds: hanging pleats with a soft sheen at grazing angles.
	float fold_x = uv.x / 0.016 + sin(uv.y * 30.0 + uv.x * 3.0) * 0.25;
	float fold = 0.5 + 0.5 * sin(fold_x * 6.2832);
	float sheen = ffres(NORMAL, VIEW, 1.8);
	vec3 velvet = shell_color * (0.35 + 0.65 * fold) * (0.8 + 0.4 * sheen) * (0.9 + 0.1 * fnoise2(uv * 900.0));
	// A gold fringe band every so often, tassels hanging off it.
	float fy = fract(uv.y / 0.085 + 0.3);
	float fringe = s2_band(fy - 0.12, 0.022);
	float tassel = step(fy, 0.22) * step(0.12, fy) * step(0.5, fract(uv.x / 0.004)) * (1.0 - smoothstep(0.17, 0.22, fy + fh21(vec2(floor(uv.x / 0.004), 1.0)) * 0.03));
	float gold = max(fringe, tassel);
	// Stars of fame, shining where the beams fall.
	vec2 sq = uv / 0.06;
	vec2 sid = floor(sq);
	vec3 sh = fh33(vec3(sid, 3.0));
	float star = star5((fract(sq) - 0.5 - (sh.xy - 0.5) * 0.3) * s2_rot(sh.z), 0.22) * step(0.5, sh.z);
	vec3 col = mix(velvet, trim_color * 0.8, gold);
	col = mix(col, color_c, star * 0.9);
	vec3 light = color_b * lit;
	ALBEDO = col;
	METALLIC = max(gold, star) * 0.85;
	ROUGHNESS = mix(0.8, 0.25, max(gold, star));
	EMISSION = col * light * 0.9 + color_b * lit * 0.22 * (0.4 + 0.6 * fold) + color_c * star * (0.15 + lit * 1.4) + fstudio(r, trim_color) * gold * (0.25 + lit * 0.5)
		+ color_b * (bulb * 4.0 + glare * 0.9) + color_b * burst * 0.35 * (0.5 + fold * 0.5);
	if (is_trim) {
		// The trim wears the same scene a shade deeper, with a metal sheen.
		ALBEDO *= 0.8;
		EMISSION = EMISSION * 0.85 + fstudio(reflect(-VIEW, NORMAL), trim_color) * 0.12;
		METALLIC = max(METALLIC, 0.35);
	}
	PRINT_LAYER
}
