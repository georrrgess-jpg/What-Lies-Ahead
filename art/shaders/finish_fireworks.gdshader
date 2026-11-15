shader_type spatial;
// Weapon finish "Grand Finale": a night sky over the pier where fireworks
// keep bursting, each a ring of sparks that blooms, droops and fades in gold,
// pink or cyan, over twinkling stars. On the trim the show reflects in dark
// chrome with a gold rim.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.04, 0.03, 0.12);
uniform vec3 trim_color : source_color = vec3(0.1, 0.08, 0.16);
uniform bool is_trim = false;
uniform vec3 spark_a : source_color = vec3(1.0, 0.8, 0.3);
uniform vec3 spark_b : source_color = vec3(1.0, 0.35, 0.7);
uniform vec3 spark_c : source_color = vec3(0.35, 0.92, 1.0);
uniform float tile = 0.16;
uniform float rate = 0.45;

varying vec3 lp;
varying vec3 ln;

// Brightness of one burst in a cell: `f` the point from the cell centre.
float burst(vec2 f, float seed, float t) {
	vec2 at = (fh22(vec2(seed, floor(TIME * rate + seed))) - 0.5) * 0.2;
	vec2 q = f - at;
	q.y += t * t * 0.12;
	float r = 0.36 * (1.0 - pow(1.0 - t, 3.0));
	float d = length(q);
	float rays = 14.0;
	float a = atan(q.y, q.x) / 6.2831853 * rays + seed * 7.0;
	float arc = abs(fract(a) - 0.5) * 6.2831853 / rays * d;
	float spoke = smoothstep(0.016, 0.004, arc);
	float head = smoothstep(0.03, 0.0, abs(d - r)) * spoke;
	float trail = smoothstep(r, r * 0.4, d) * step(0.001, d) * spoke * 0.35;
	float flash = smoothstep(0.12, 0.0, d) * smoothstep(0.15, 0.0, t);
	return (head + trail) * pow(1.0 - t, 1.6) + flash;
}

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 2.5);
	vec2 p = fplane(lp, ln);
	vec2 uv = p / tile;
	vec2 id = floor(uv);
	vec2 f = fract(uv) - 0.5;
	float seed = fh21(id);
	float t = fract(TIME * rate + seed);
	float b = burst(f, seed, t);
	float pick = fract(seed * 3.7 + floor(TIME * rate + seed) * 0.37);
	vec3 spark = pick < 0.34 ? spark_a : (pick < 0.67 ? spark_b : spark_c);
	// Sky: a soft glow towards the top, and stars that twinkle.
	vec3 sky = mix(shell_color, shell_color * 2.2 + vec3(0.03, 0.0, 0.05), clamp(p.y * 2.0 + 0.5, 0.0, 1.0));
	vec2 sg = p * 90.0;
	float star = smoothstep(0.08, 0.0, length(fract(sg) - 0.5)) * step(0.93, fh21(floor(sg)));
	star *= 0.5 + 0.5 * sin(TIME * 3.0 + fh21(floor(sg) + 3.1) * 40.0);
	vec3 col = sky + vec3(star) * 0.6;
	col = mix(col, spark, clamp(b, 0.0, 1.0));
	vec3 glow = spark * b * 1.6;
	if (is_trim) {
		vec3 deep = mix(col, trim_color, 0.55);
		ALBEDO = deep;
		METALLIC = 0.6;
		ROUGHNESS = 0.12;
		EMISSION = glow * 0.5 + fstudio(r, vec3(0.45)) * 0.14 + spark_a * fres * 0.35;
	} else {
		ALBEDO = col;
		METALLIC = 0.1;
		ROUGHNESS = 0.3;
		EMISSION = col * 0.15 + glow + vec3(star) * 0.8;
	}
	PRINT_LAYER
}
