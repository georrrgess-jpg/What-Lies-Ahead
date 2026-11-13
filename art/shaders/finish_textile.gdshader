shader_type spatial;
// Static woven and knitted family for weapon finishes, picked by `pattern`:
//   0 buffalo check (shell + color_b)
//   1 tartan (sett of shell, color_b, color_c, color_d threads)
//   2 fair-isle knit (bands of zigzags, diamonds and snowflake crosses
//     knitted stitch by stitch in shell, color_b, color_c, color_d)
//   3 carbon-fibre twill (shell tows with a color_b sheen under clear coat)
// The trim draws the same cloth on trim_color; trim_glow > 0 adds glowing
// color_c pinstripes to it.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.7, 0.06, 0.08);
uniform vec3 trim_color : source_color = vec3(0.08, 0.06, 0.06);
uniform bool is_trim = false;
uniform int pattern = 0;
uniform vec3 color_b : source_color = vec3(0.05, 0.04, 0.05);
uniform vec3 color_c : source_color = vec3(0.1, 0.15, 0.4);
uniform vec3 color_d : source_color = vec3(0.95, 0.75, 0.2);
uniform float scale = 1.0;
uniform float trim_glow = 0.0;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

vec3 buffalo(vec3 g, vec2 uv) {
	float s = 0.028;
	float a = step(0.5, fract(uv.x / s));
	float b = step(0.5, fract(uv.y / s));
	vec3 col = mix(g, color_b, a * b);
	col = mix(col, mix(g, color_b, 0.55), abs(a - b));
	float twill = step(0.5, fract((uv.x + uv.y) / 0.0018));
	float fuzz = fnoise2(uv * 900.0);
	return col * (0.9 + 0.06 * twill + 0.08 * fuzz);
}

// One axis of the tartan sett: the thread colour at position x.
vec3 sett(vec3 g, float x) {
	float t = fract(x / 0.1) * 2.0;
	t = t > 1.0 ? 2.0 - t : t; // mirrored sett
	if (t < 0.36) {
		return g;
	} else if (t < 0.44) {
		return color_b;
	} else if (t < 0.48) {
		return color_c;
	} else if (t < 0.7) {
		return color_b;
	} else if (t < 0.74) {
		return color_d;
	}
	return t < 0.9 ? g : color_b;
}

vec3 tartan(vec3 g, vec2 uv) {
	vec3 warp = sett(g, uv.x);
	vec3 weft = sett(g, uv.y + 0.013);
	float twill = step(0.5, fract((uv.x + uv.y) / 0.002));
	return mix(warp, weft, 0.5) * (0.92 + 0.08 * twill) + (fnoise2(uv * 800.0) - 0.5) * 0.04;
}

vec3 fairisle(vec3 g, vec2 uv) {
	vec2 st = vec2(0.0055, 0.0045);
	vec2 id = floor(uv / st);
	vec2 f = fract(uv / st);
	float band_rows = 11.0;
	float band = floor(id.y / band_rows);
	float y = mod(id.y, band_rows);
	float kind = mod(band, 3.0);
	float x = id.x;
	float on = 0.0;
	vec3 ground = mod(band, 2.0) < 1.0 ? g : color_c;
	vec3 ink = mod(band, 2.0) < 1.0 ? color_b : g;
	if (y < 1.0 || y > 9.0) {
		// Border rows: alternating dots in the accent colour.
		on = step(0.5, mod(x + y, 2.0));
		ink = color_d;
	} else if (kind < 0.5) {
		on = step(abs(y - 5.0 - (abs(mod(x, 8.0) - 4.0) - 2.0)), 0.5);
	} else if (kind < 1.5) {
		float dd = abs(mod(x, 10.0) - 5.0) + abs(y - 5.0);
		on = step(dd, 3.5) * (1.0 - step(dd, 1.5)) + step(dd, 0.5);
	} else {
		vec2 c = vec2(mod(x, 9.0) - 4.0, y - 5.0);
		on = max(step(abs(c.x), 0.5) * step(abs(c.y), 3.5), step(abs(c.y), 0.5) * step(abs(c.x), 3.5));
		on = max(on, step(abs(abs(c.x) - abs(c.y)), 0.5) * step(abs(c.x), 2.5) * step(1.5, abs(c.x)));
	}
	vec3 col = mix(ground, ink, on);
	// Each stitch is a little V: two slanted lobes, darker in the gap.
	float lobe = abs(f.x - 0.5) * 2.0;
	float vee = smoothstep(0.0, 0.25, abs(f.y - lobe * 0.6 - 0.2));
	float shade = 0.75 + 0.25 * vee * (1.0 - smoothstep(0.85, 1.0, lobe));
	return col * shade;
}

vec3 carbon(vec3 g, vec2 uv, vec3 r) {
	float s = 0.0045;
	vec2 id = floor(uv / s);
	vec2 f = fract(uv / s);
	// 2x2 twill: tows run along u or v in a stepped diagonal.
	float horiz = step(mod(id.x + id.y, 4.0), 1.5);
	float across = horiz > 0.5 ? f.y : f.x;
	float tow = sin(across * 3.14159);
	float sheen = horiz > 0.5 ? abs(r.y) : abs(r.x);
	vec3 col = g * (0.6 + 0.4 * tow);
	return col + color_b * pow(sheen, 1.5) * tow * 0.6;
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	vec2 uv = fplane(lp, ln) * scale;
	vec3 ground = is_trim ? trim_color : shell_color;
	vec3 col;
	float rough = 0.8;
	if (pattern == 0) {
		col = buffalo(ground, uv);
	} else if (pattern == 1) {
		col = tartan(ground, uv);
	} else if (pattern == 2) {
		col = fairisle(ground, uv);
	} else {
		col = carbon(ground, uv, r);
		rough = 0.2;
	}
	float pin = is_trim ? smoothstep(0.42, 0.46, abs(fract(uv.y * 22.0) - 0.5)) * step(0.001, trim_glow) : 0.0;
	ALBEDO = mix(col, color_c, pin);
	METALLIC = 0.0;
	ROUGHNESS = rough;
	// Clear coat on the carbon; a soft fabric sheen on the rest.
	EMISSION = (pattern == 3 ? fstudio(r, vec3(0.4)) * (0.08 + 0.3 * fres) : col * pow(fres, 2.0) * 0.15)
		+ color_c * pin * trim_glow;
}
