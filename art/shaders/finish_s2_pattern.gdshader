shader_type spatial;
// Prize Prints Series 2 "Midnight Marquee": the Common and Rare finishes, a
// family of painted patterns picked by `pattern`:
//   Common  0 popcorn stripe   1 velvet rope    2 film reel      3 diner checker
//           4 houndstooth      5 moon polka     6 starlit pinstripe
//   Rare    7 picture palace (art-deco fans)    8 marquee sunburst
//           9 neon zebra       10 sequins       11 fortune teller
//           12 jukebox (bubbles rise in its tubes)  13 glow leopard
//           14 high roller (card suits)  15 pop halftone  16 lobby terrazzo
//           17 blackout camo   18 neon argyle
// Colours: shell_color (ground), color_b, color_c, color_d (ink / glow).
// The trim draws the pattern on trim_color, or with trim_metal > 0.5 is
// polished metal in trim_color with an engraved line.
#include "res://art/shaders/finish_common.gdshaderinc"
#include "res://art/shaders/finish_s2.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.1, 0.08, 0.2);
uniform vec3 trim_color : source_color = vec3(1.0, 0.75, 0.3);
uniform bool is_trim = false;
uniform int pattern = 0;
uniform vec3 color_b : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 color_c : source_color = vec3(1.0, 0.75, 0.2);
uniform vec3 color_d : source_color = vec3(1.0, 0.3, 0.7);
uniform float scale = 1.0;
uniform float roughness = 0.32;
uniform float metallic = 0.05;
uniform float trim_metal = 0.0;
// How strongly color_d glows where a pattern lights it.
uniform float glow = 1.0;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

float heart(vec2 p) {
	// 1 inside a heart of about unit height centred on p = 0.
	p.y = -p.y + 0.15;
	p.x = abs(p.x);
	float a = atan(p.x, p.y) / 3.14159;
	float r = length(p);
	float h = abs(a);
	float d = (13.0 * h - 22.0 * h * h + 10.0 * h * h * h) / (6.0 - 5.0 * h);
	return 1.0 - smoothstep(d * 0.42 - 0.02, d * 0.42 + 0.02, r);
}

float star4(vec2 p, float r) {
	p = abs(p);
	float d = pow(p.x, 0.5) + pow(p.y, 0.5);
	return 1.0 - smoothstep(pow(r, 0.5) * 0.9, pow(r, 0.5) * 1.1, d);
}

void fragment() {
	vec2 uv = fplane(lp, ln) / scale;
	vec3 ground = is_trim ? trim_color : shell_color;
	vec3 col = ground;
	vec3 emit = vec3(0.0);
	float metal = metallic;
	float rough = roughness;
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	float t = s2_time(TIME, 3.0);
	if (pattern == 0) {
		// Popcorn stripe: wide candy stripes across the weapon, gold pinlines.
		float s = uv.x / 0.05;
		float f = fract(s);
		col = mix(ground, color_b, step(0.5, f));
		col = mix(col, color_c, max(s2_lines(s, 0.025), s2_band(f - 0.5, 0.025)));
	} else if (pattern == 1) {
		// Velvet rope: crimson velvet with twisted gold rope on the diagonal.
		float sheen = ffres(NORMAL, VIEW, 1.6);
		col = ground * (0.55 + 0.25 * fnoise2(uv * 900.0)) + ground * sheen * 0.9;
		float d = (uv.x + uv.y) / 0.11;
		float band = s2_band(fract(d) - 0.5, 0.11);
		float twist = 0.5 + 0.5 * sin((uv.x - uv.y) / 0.0045 + d * 6.28);
		vec3 rope = mix(color_b * 0.55, color_b, twist);
		col = mix(col, rope, band);
		metal = mix(0.0, 0.85, band);
		rough = mix(0.85, 0.3, band);
		emit += fstudio(r, color_b) * band * twist * 0.25;
	} else if (pattern == 2) {
		// Film reel: strips of film with sprocket holes and amber frames.
		float y = fract(uv.y / 0.09);
		float fx = fract(uv.x / 0.016) - 0.5;
		float hole_row = max(s2_band(y - 0.1, 0.05), s2_band(y - 0.9, 0.05));
		float hole = hole_row * s2_band(fx, 0.22);
		float frame_y = s2_band(y - 0.5, 0.27);
		float gx = fract(uv.x / 0.07);
		float frame = frame_y * s2_band(gx - 0.5, 0.44);
		float img = fnoise2(uv * 60.0 + floor(uv.x / 0.07) * 7.3);
		vec3 film = mix(color_b * 0.35, color_b, smoothstep(0.2, 0.8, img)) * (1.0 - 0.6 * length(vec2(gx - 0.5, (y - 0.5) * 1.6)));
		col = ground * (0.8 + 0.2 * fh21(floor(uv * 1500.0)));
		col = mix(col, film, frame);
		col = mix(col, color_c, hole);
		emit += film * frame * 0.08;
	} else if (pattern == 3) {
		// Diner checker: a tilted checkerboard edged in neon.
		vec2 q = s2_rot(0.785) * uv / 0.03;
		vec2 f = fract(q) - 0.5;
		float c = mod(floor(q.x) + floor(q.y), 2.0);
		col = mix(ground, color_b, c);
		float edge = s2_band(max(abs(f.x), abs(f.y)) - 0.5, 0.04);
		col = mix(col, color_d, edge);
		emit += color_d * edge * 0.6 * glow;
	} else if (pattern == 4) {
		// Houndstooth: dark and light checks joined by diagonal teeth.
		vec2 q = uv / 0.012;
		vec2 i = mod(floor(q), 2.0);
		vec2 f = fract(q);
		float c;
		if (i.x + i.y < 0.5) {
			c = 0.0;
		} else if (i.x + i.y > 1.5) {
			c = 1.0;
		} else {
			c = step(0.5, fract(f.x - f.y + 0.25));
		}
		col = mix(ground, color_b, c);
	} else if (pattern == 5) {
		// Moon polka: rows of crescent moons with tiny stars between them.
		vec2 q = uv / 0.034;
		q.x += mod(floor(q.y), 2.0) * 0.5;
		vec2 f = fract(q) - 0.5;
		float moon = smoothstep(0.31, 0.28, length(f)) * smoothstep(0.24, 0.27, length(f - vec2(0.12, 0.08)));
		vec2 sf = fract(q + 0.5) - 0.5;
		float star = star4(sf, 0.09) * step(0.5, fh21(floor(q + 0.5)));
		col = mix(ground, color_b, moon);
		col = mix(col, color_c, star);
		emit += color_c * star * 0.4 + color_b * moon * 0.05;
	} else if (pattern == 6) {
		// Starlit pinstripe: silver pinstripes and a scatter of four-point stars.
		float pin = s2_band(fract(uv.y / 0.022) - 0.5, 0.03);
		vec2 q = uv / 0.05;
		vec2 h = fh22(floor(q));
		vec2 f = fract(q) - (h * 0.6 + 0.2);
		float star = star4(f, 0.12 * h.x + 0.04) * step(0.55, h.y);
		col = mix(ground, color_b, pin);
		col = mix(col, color_c, star);
		metal = mix(metal, 0.8, pin);
		emit += color_c * star * 0.7 + fstudio(r, color_b) * pin * 0.2;
	} else if (pattern == 7) {
		// Picture palace: art-deco fans in gold on black, rows offset.
		vec2 q = uv / vec2(0.05, 0.03);
		q.x += mod(floor(q.y), 2.0) * 0.5;
		vec2 f = fract(q) - vec2(0.5, 0.0);
		f.y *= 0.6;
		float d = length(f);
		float fan = step(d, 0.5);
		float a = atan(f.x, f.y);
		float rays = s2_band(fract(a / 0.2618) - 0.5, 0.08) * step(0.18, d);
		float arcs = s2_band(fract(d * 8.0) - 0.5, 0.07);
		float rim = s2_band(d - 0.48, 0.025);
		float gold = fan * max(max(rays, arcs * step(d, 0.17)), rim);
		vec2 dia = abs(fract(q) - vec2(0.0, 1.0));
		gold = max(gold, (1.0 - fan) * step(dia.x + dia.y * 1.4, 0.22));
		col = mix(ground, mix(ground, color_b, 0.12), fan);
		col = mix(col, color_c, gold);
		metal = mix(metal, 0.9, gold);
		rough = mix(rough, 0.22, gold);
		emit += fstudio(r, color_c) * gold * 0.35;
	} else if (pattern == 8) {
		// Marquee sunburst: gold and red rays round a ring of bulbs.
		vec2 c = uv - vec2(round(uv.x / 0.3) * 0.3, -0.01);
		float a = atan(c.y, c.x);
		float d = length(c);
		float ray = step(0.5, fract(a / 6.2832 * 28.0));
		col = mix(ground, color_b, ray);
		float rings = s2_band(fract(d / 0.05) - 0.5, 0.06);
		col = mix(col, color_c, rings);
		float bulbs = smoothstep(0.35, 0.2, length(vec2(fract(a / 6.2832 * 28.0) - 0.5, (d - 0.032) / 0.006)));
		col = mix(col, color_d, bulbs);
		emit += color_d * bulbs * 1.4 * glow;
		metal = mix(metal, 0.6, rings);
	} else if (pattern == 9) {
		// Neon zebra: warped stripes of glowing ink on black.
		float x = uv.y * 70.0 + ffbm2(uv * vec2(10.0, 16.0)) * 6.0 + sin(uv.x * 30.0) * 1.4;
		float s = smoothstep(0.15, 0.4, sin(x) + 0.2 * fnoise2(uv * 80.0));
		col = mix(ground, color_b, s);
		emit += color_d * s * 0.55 * glow * (0.85 + 0.15 * sin(x * 0.5));
	} else if (pattern == 10) {
		// Sequins: overlapping discs, each tilted its own way to catch the light.
		vec2 q = uv / 0.011;
		q.x += mod(floor(q.y), 2.0) * 0.5;
		vec2 id = floor(q);
		vec2 f = fract(q) - 0.5;
		vec3 h = fh33(vec3(id, 3.0));
		float disc = smoothstep(0.5, 0.42, length(f * vec2(1.0, 0.85)));
		float hole = smoothstep(0.08, 0.12, length(f));
		vec3 dir = normalize(h - 0.5);
		float glint = pow(0.5 + 0.5 * sin(h.x * 30.0 + dot(VIEW, dir) * 9.0 + dot(NORMAL, dir) * 6.0 + t * 0.6 * h.z), 14.0);
		vec3 seq = mix(ground * 2.2, color_b, h.y * 0.35) * (0.55 + 0.45 * h.z);
		col = mix(ground * 0.4, seq, disc * hole);
		metal = mix(metal, 1.0, disc);
		rough = mix(rough, 0.15, disc);
		emit += mix(color_b, color_c, h.z) * glint * disc * hole * 1.1 + fstudio(r, seq) * disc * 0.2 + seq * disc * 0.15;
	} else if (pattern == 11) {
		// Fortune teller: gold stars, crescents and all-seeing eyes on violet.
		col = ground * (0.75 + 0.5 * ffbm2(uv * 14.0));
		vec2 q = uv / 0.045;
		vec2 id = floor(q);
		vec3 h = fh33(vec3(id, 7.0));
		vec2 f = fract(q) - 0.5 - (h.xy - 0.5) * 0.25;
		float mark = 0.0;
		if (h.z < 0.4) {
			mark = star4(f, 0.18);
		} else if (h.z < 0.65) {
			mark = smoothstep(0.24, 0.21, length(f)) * smoothstep(0.17, 0.2, length(f - vec2(0.08, 0.05)));
		} else if (h.z < 0.82) {
			float lid = smoothstep(0.03, 0.0, abs(length(f * vec2(0.55, 1.6)) - 0.17));
			float iris = smoothstep(0.07, 0.05, length(f));
			mark = max(lid, iris);
		}
		float dust = step(0.985, fh21(floor(uv * 700.0)));
		col = mix(col, color_c, max(mark, dust));
		metal = mix(metal, 0.85, mark);
		emit += color_c * (mark * 0.35 + dust * 0.6) + color_d * ffbm2(uv * 6.0 + 2.0) * 0.08;
	} else if (pattern == 12) {
		// Jukebox: chrome bands with glowing bubble tubes, bubbles rising along them.
		float band = uv.y / 0.045;
		float id = floor(band);
		float f = fract(band);
		float tube = s2_band(f - 0.5, 0.22);
		vec3 hue = fhue(fract(id * 0.23 + 0.05));
		vec3 tint = mix(color_d, hue, 0.6);
		vec2 bq = vec2((uv.x - t * 0.03 * (1.0 + fh21(vec2(id, 1.0)))) / 0.012, (f - 0.5) / 0.2);
		vec2 bh = fh22(vec2(floor(bq.x), id));
		float bubble = s2_band(length(vec2(fract(bq.x) - 0.5, bq.y - (bh.x - 0.5))) - 0.22, 0.06) * step(0.4, bh.y);
		vec3 chrome = fstudio(r, color_b);
		col = mix(color_b * 0.6, tint * 0.4, tube);
		metal = mix(0.95, 0.1, tube);
		rough = mix(0.12, 0.2, tube);
		emit += mix(chrome * 0.5, tint * (0.9 + 0.6 * bubble), tube) * glow;
	} else if (pattern == 13) {
		// Glow leopard: broken rosettes round glowing ultraviolet centres.
		vec4 v = s2_voronoi(uv / 0.03);
		float n = fnoise2(uv * 220.0);
		float rose = smoothstep(0.08, 0.0, v.y - v.x - 0.05 - n * 0.06) * step(0.3, fnoise2(uv * 140.0 + 4.0) + 0.2);
		float core = smoothstep(0.45, 0.2, v.x);
		col = mix(ground, color_b, core * 0.6);
		col = mix(col, color_c, rose);
		emit += color_d * core * 0.35 * glow * (1.0 - rose);
	} else if (pattern == 14) {
		// High roller: a card-back lattice of hearts and diamonds.
		vec2 q = s2_rot(0.785) * uv / 0.026;
		vec2 f = fract(q) - 0.5;
		vec2 id = floor(q);
		float lattice = s2_band(max(abs(f.x), abs(f.y)) - 0.5, 0.05);
		vec2 g = s2_rot(-0.785) * f;
		float suit;
		if (mod(id.x + id.y, 2.0) < 0.5) {
			suit = heart(g * 2.6);
		} else {
			suit = step(abs(g.x) * 1.35 + abs(g.y), 0.3);
		}
		vec3 ink = mod(id.x, 2.0) < 0.5 ? color_c : color_d;
		col = mix(ground, color_b, lattice);
		col = mix(col, ink, suit);
	} else if (pattern == 15) {
		// Pop halftone: dots that swell and shrink in waves, comic print style.
		vec2 q = s2_rot(0.26) * uv / 0.008;
		vec2 f = fract(q) - 0.5;
		float k = 0.5 + 0.5 * sin(uv.x * 22.0 + uv.y * 30.0 + ffbm2(uv * 9.0) * 3.0);
		float dot_r = mix(0.12, 0.48, k);
		float d = s2_band(length(f), dot_r);
		col = mix(ground, color_b, d);
		float ink = s2_band(length(f) - dot_r, 0.035) * step(0.6, k);
		col = mix(col, color_c, ink);
	} else if (pattern == 16) {
		// Lobby terrazzo: chips of colour and mother-of-pearl set in cream.
		vec4 v = s2_voronoi(uv / 0.014);
		vec3 h = fh33(vec3(v.zw, 2.0));
		float chip = smoothstep(h.x * 0.25 + 0.18, h.x * 0.25 + 0.14, v.x) * step(0.35, h.y);
		vec3 chip_col = h.z < 0.33 ? color_b : (h.z < 0.66 ? color_c : color_d);
		float fleck = step(0.93, fh21(floor(uv * 900.0)));
		col = ground * (0.92 + 0.08 * fnoise2(uv * 300.0));
		col = mix(col, chip_col, chip);
		col = mix(col, color_b * 0.5, fleck * (1.0 - chip));
		rough = 0.12;
		emit += s2_coat(NORMAL, VIEW, 0.6) + fhue(h.x + dot(NORMAL, VIEW)) * chip * step(0.85, h.z) * 0.15;
	} else if (pattern == 17) {
		// Blackout camo: pixel camo in black, violet and plum, a few neon bits.
		vec2 q = floor(uv / 0.007);
		float n = ffbm2(q * 0.09);
		float n2 = fnoise2(q * 0.21 + 9.0);
		col = ground;
		col = mix(col, color_b, step(0.5, n));
		col = mix(col, color_c, step(0.62, n) * step(0.45, n2));
		float bit = step(0.985, fh21(q)) * step(0.55, n);
		col = mix(col, color_d, bit);
		emit += color_d * bit * 0.8 * glow;
	} else {
		// Neon argyle: diamonds in two tones, stitched over in glowing thread.
		vec2 q = vec2(uv.x / 0.05 + uv.y / 0.035, uv.x / 0.05 - uv.y / 0.035);
		float c = mod(floor(q.x) + floor(q.y), 2.0);
		col = mix(ground, color_b, c);
		vec2 s = vec2(uv.x / 0.05 + uv.y / 0.035 + 0.5, uv.x / 0.05 - uv.y / 0.035 + 0.5);
		float stitch = max(s2_band(fract(s.x) - 0.5, 0.025), s2_band(fract(s.y) - 0.5, 0.025));
		stitch *= step(0.45, fract((uv.x) / 0.006));
		col = mix(col, color_d, stitch);
		emit += color_d * stitch * 0.9 * glow;
	}
	if (is_trim && trim_metal > 0.5) {
		float line = s2_band(fract(uv.y / 0.02) - 0.5, 0.04);
		col = mix(trim_color, trim_color * 0.6, line);
		metal = 0.9;
		rough = 0.24;
		emit = fstudio(r, trim_color) * 0.45 * (1.0 - line * 0.5);
	}
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = emit + fstudio(r, col) * 0.06 + vec3(1.0) * pow(fres, 4.0) * 0.08 * (1.0 - rough);
	PRINT_LAYER
}
