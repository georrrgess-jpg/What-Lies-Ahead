shader_type spatial;
// Static painted-graphic family for weapon finishes, picked by `pattern`:
//   0 tent stripes        1 harlequin diamonds   2 rings and dots
//   3 racing stripes      4 roll-pattern quarters   5 ticket roll
//   6 hex tiles           7 stencil bands        8 riveted plates
//   9 arcade carpet       10 spray-paint splats
// Colours: shell_color (ground), color_b, color_c, color_d (lines / ink).
// The trim draws the same graphic on trim_color; trim_pin > 0 adds thin
// color_c pinstripes to it.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.85, 0.1, 0.12);
uniform vec3 trim_color : source_color = vec3(0.1, 0.12, 0.3);
uniform bool is_trim = false;
uniform int pattern = 0;
uniform vec3 color_b : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 color_c : source_color = vec3(1.0, 0.75, 0.2);
uniform vec3 color_d : source_color = vec3(0.05, 0.04, 0.06);
uniform float scale = 1.0;
uniform float roughness = 0.3;
uniform float metallic = 0.05;
uniform float trim_pin = 0.0;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

float hexd(vec2 p) {
	p = abs(p);
	return max(dot(p, vec2(0.866025, 0.5)), p.y);
}

// Distance to the nearest hex-cell edge (0 at the edge, 0.5 at the centre), and the cell id.
vec3 hexgrid(vec2 uv) {
	vec2 s = vec2(1.0, 1.7320508);
	vec2 a = mod(uv, s) - s * 0.5;
	vec2 b = mod(uv - s * 0.5, s) - s * 0.5;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 id = uv - g;
	return vec3(0.5 - hexd(g), id);
}

float star5(vec2 p, float r) {
	float a = atan(p.y, p.x) + 1.5708;
	float k = 0.5 + 0.5 * cos(a * 5.0);
	return smoothstep(r * (0.5 + 0.5 * k) + 0.02, r * (0.5 + 0.5 * k), length(p));
}

vec3 tent(vec3 g, vec2 uv) {
	float w = 0.032;
	float t = uv.y / w;
	float stripe = step(0.5, fract(t * 0.5));
	float edge = smoothstep(0.43, 0.46, abs(fract(t) - 0.5));
	vec3 col = mix(g, color_b, stripe);
	return mix(col, color_c, edge);
}

vec3 harlequin(vec3 g, vec2 uv) {
	vec2 q = vec2(uv.x / 0.05 + uv.y / 0.032, uv.x / 0.05 - uv.y / 0.032);
	vec2 c = floor(q);
	float idx = mod(c.x + 2.0 * c.y, 3.0);
	vec3 col = idx < 0.5 ? g : (idx < 1.5 ? color_b : color_c);
	vec2 f = abs(fract(q) - 0.5);
	float line = smoothstep(0.44, 0.47, max(f.x, f.y));
	return mix(col, color_d, line);
}

vec3 rings(vec3 g, vec2 uv) {
	vec2 q = uv / 0.036;
	q.x += mod(floor(q.y), 2.0) * 0.5;
	vec2 c = floor(q);
	float d = length(fract(q) - 0.5);
	float h = fh21(c);
	vec3 col = g;
	if (h < 0.5) {
		float ring = smoothstep(0.04, 0.0, abs(d - 0.3) - 0.06);
		col = mix(col, color_b, ring);
	} else {
		col = mix(col, color_c, smoothstep(0.24, 0.21, d));
	}
	return col;
}

vec3 racing(vec3 g, vec3 p, vec3 n) {
	vec3 col = g;
	float side = fside(n);
	// Twin stripes down the spine on top, one body-line stripe on the sides.
	float top = (1.0 - side) * step(abs(p.x), 0.02) * step(0.005, abs(p.x));
	float topin = (1.0 - side) * step(abs(abs(p.x) - 0.0235), 0.0015);
	float body = side * step(abs(p.y + 0.01), 0.011);
	float bodypin = side * step(abs(abs(p.y + 0.01) - 0.016), 0.0016);
	col = mix(col, color_b, max(top, body));
	return mix(col, color_c, max(topin, bodypin));
}

vec3 quarters(vec3 g, vec3 p) {
	float s = 0.14;
	float parity = mod(floor(p.z / s) + floor((p.y + 0.05) / s) + step(0.0, p.x), 2.0);
	return mix(g, color_b, parity);
}

vec3 tickets(vec3 g, vec2 uv) {
	float len = 0.075;
	float t = uv.x / len;
	vec2 f = vec2(fract(t) - 0.5, uv.y / len);
	float perf = step(abs(f.x), 0.5) * smoothstep(0.47, 0.49, abs(f.x)) * step(0.5, fract(uv.y / 0.007));
	float border = smoothstep(0.36, 0.38, abs(f.x)) * (1.0 - smoothstep(0.42, 0.44, abs(f.x)));
	vec2 sp = vec2(f.x, fract(f.y + 0.5) - 0.5);
	float star = star5(sp * 1.0, 0.16);
	vec3 col = mix(g, color_b, border);
	col = mix(col, color_c, star);
	return mix(col, color_d, perf);
}

vec3 hextiles(vec3 g, vec2 uv) {
	vec3 h = hexgrid(uv / 0.04);
	float grout = smoothstep(0.02, 0.045, h.x);
	float v = fh21(floor(h.yz * 10.0));
	vec3 tile = g * (0.85 + 0.25 * v);
	return mix(color_d, tile, grout);
}

vec3 stencil(vec3 g, vec3 p, vec3 n) {
	float z = mod(p.z + 0.4, 0.3);
	float bands = step(z, 0.02) + step(0.035, z) * step(z, 0.045);
	// Two stencil chevrons on the sides, pointing at the muzzle.
	vec2 uv = fplane(p, n);
	vec2 a = vec2(mod(uv.x + 0.4, 0.3) - 0.15, uv.y - 0.02);
	float chev = 0.0;
	for (int k = 0; k < 2; k++) {
		float x = a.x - float(k) * 0.014 - abs(a.y) * 0.8;
		chev = max(chev, step(abs(x), 0.0035) * step(abs(a.y), 0.014));
	}
	vec3 col = mix(g, color_d, min(bands, 1.0));
	return mix(col, color_b, chev * fside(n));
}

vec3 rivets(vec3 g, vec2 uv) {
	vec2 size = vec2(0.08, 0.05);
	vec2 f = fract(uv / size);
	// Distance to the nearest vertical and horizontal seam, in model units.
	float du = min(f.x, 1.0 - f.x) * size.x;
	float dv = min(f.y, 1.0 - f.y) * size.y;
	float seam = smoothstep(0.0014, 0.0008, min(du, dv));
	// Rivets every 9 mm, 4 mm in from each seam.
	vec2 rv = vec2(du - 0.004, (fract(uv.y / 0.009) - 0.5) * 0.009);
	vec2 rh = vec2(dv - 0.004, (fract(uv.x / 0.009) - 0.5) * 0.009);
	float rivet = max(smoothstep(0.0019, 0.0014, length(rv)), smoothstep(0.0019, 0.0014, length(rh)));
	vec3 col = mix(g, color_b, seam);
	return mix(col, color_c, rivet);
}

vec3 carpet(vec3 g, vec2 uv) {
	vec2 q = uv / 0.03;
	vec2 c = floor(q);
	vec2 f = fract(q) - 0.5;
	float h = fh21(c);
	float a = h * 6.2831;
	f = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * f;
	float pick = fh21(c + 3.0);
	vec3 ink = pick < 0.33 ? color_b : (pick < 0.66 ? color_c : color_d);
	float shape = 0.0;
	if (h < 0.3) {
		shape = smoothstep(0.035, 0.0, abs(length(f) - 0.22) - 0.04);
	} else if (h < 0.55) {
		vec2 t = f * 2.2;
		float tri = max(abs(t.x) * 0.866 + t.y * 0.5, -t.y) - 0.3;
		shape = smoothstep(0.05, 0.0, abs(tri) - 0.05);
	} else if (h < 0.85) {
		float wave = f.y - sin(f.x * 14.0) * 0.1;
		shape = smoothstep(0.03, 0.0, abs(wave) - 0.035) * step(abs(f.x), 0.4);
	} else {
		shape = smoothstep(0.1, 0.07, length(f));
	}
	// Tiny star dust between the shapes.
	float dust = step(0.92, fh21(floor(uv / 0.004))) * 0.6;
	return mix(g, ink, max(shape, dust * (1.0 - shape) * 0.5));
}

vec3 spray(vec3 g, vec2 uv, float side) {
	float conc = fnoise2(uv * 220.0) * 0.5 + fnoise2(uv * 40.0) * 0.5;
	vec3 col = g * (0.85 + 0.25 * conc);
	float m = ffbm2(uv * 14.0);
	float region = fnoise2(uv * 5.0 + 3.0);
	vec3 paint = region < 0.4 ? color_b : (region < 0.62 ? color_c : color_d);
	float splat = smoothstep(0.56, 0.58, m);
	// Overspray: speckles around the splat edge.
	float speck = step(0.72, fh21(floor(uv / 0.0025))) * smoothstep(0.5, 0.6, m) * (1.0 - splat);
	// Drips run down from the splats on the side faces.
	float col_id = floor(uv.x / 0.005);
	float hd = fh21(vec2(col_id, 2.0));
	float drip_len = 0.01 + hd * 0.04;
	float above = max(smoothstep(0.6, 0.62, ffbm2(vec2(uv.x, uv.y + drip_len * 0.5) * 14.0)), smoothstep(0.6, 0.62, ffbm2(vec2(uv.x, uv.y + drip_len) * 14.0)));
	float drip = step(0.7, hd) * above * smoothstep(0.5, 0.2, abs(fract(uv.x / 0.005) - 0.5)) * side;
	return mix(col, paint, max(max(splat, speck), drip));
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	vec2 uv = fplane(lp, ln) * scale;
	vec3 ground = is_trim ? trim_color : shell_color;
	vec3 col;
	if (pattern == 0) {
		col = tent(ground, uv);
	} else if (pattern == 1) {
		col = harlequin(ground, uv);
	} else if (pattern == 2) {
		col = rings(ground, uv);
	} else if (pattern == 3) {
		col = racing(ground, lp, ln);
	} else if (pattern == 4) {
		col = quarters(ground, lp);
	} else if (pattern == 5) {
		col = tickets(ground, uv);
	} else if (pattern == 6) {
		col = hextiles(ground, uv);
	} else if (pattern == 7) {
		col = stencil(ground, lp, ln);
	} else if (pattern == 8) {
		col = rivets(ground, uv);
	} else if (pattern == 9) {
		col = carpet(ground, uv);
	} else {
		col = spray(ground, uv, fside(ln));
	}
	float pin = is_trim ? trim_pin * smoothstep(0.42, 0.46, abs(fract(uv.y * 22.0) - 0.5)) : 0.0;
	col = mix(col, color_c, pin);
	ALBEDO = col;
	METALLIC = metallic + pin * 0.4;
	ROUGHNESS = roughness;
	EMISSION = fstudio(r, col) * (0.07 + pin * 0.2) + vec3(1.0) * pow(fres, 4.0) * 0.08 * (1.0 - roughness);
}
