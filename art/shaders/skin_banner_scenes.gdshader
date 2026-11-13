shader_type canvas_item;
// Illustrated player-card banners (scripts/cosmetics/banner_view.gd: banner
// styles 14 and up, passed here as style - 14). Each is its own animated
// scene or pattern drawn with distance fields; colours come from the item.
// The main subject sits towards the right, clear of the portrait and title.
//   0 ferris night   1 neon downtown  2 kelp forest   3 liftoff
//   4 alpine lodge   5 coaster loop   6 peekaboo      7 duck parade
//   8 sparky         9 ghost party   10 hypno spiral 11 comic pop
//  12 wave scales   13 argyle        14 kaleidoscope 15 picnic plaid
//  16 memphis       17 equalizer     18 pixel hills  19 balloon sky
//  20 prize wheel   21 ticket storm  22 thunderhead  23 desert mirage
//  24 spiral galaxy 25 blossom drift
uniform int style = 0;
uniform vec3 color_a : source_color = vec3(1.0, 0.48, 0.35);
uniform vec3 color_b : source_color = vec3(1.0, 0.25, 0.62);
uniform vec3 color_c : source_color = vec3(0.24, 0.12, 0.45);
uniform vec2 rect_size = vec2(600.0, 160.0);
uniform float radius = 18.0;
uniform float speed = 1.0;

const vec3 INK = vec3(0.1, 0.06, 0.16);
const vec3 CREAM = vec3(1.0, 0.96, 0.88);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1) * 0.3 + noise(p * 4.3) * 0.15;
}

// Scattered round dots of radius r (in cells), `density` of the cells lit.
float dots(vec2 p, float r, float density, float seed) {
	vec2 id = floor(p);
	vec2 f = fract(p);
	vec2 c = vec2(hash(id + seed + 3.1), hash(id + seed + 7.7)) * 0.6 + 0.2;
	return step(1.0 - density, hash(id + seed)) * smoothstep(r, r * 0.4, length(f - c));
}

// Anti-aliased coverage of a distance field (aa = one pixel).
float fill(float d, float aa) {
	return clamp(0.5 - d / aa, 0.0, 1.0);
}

vec2 rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float sd_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sd_round_box(vec2 p, vec2 b, float r) {
	return sd_box(p, b - vec2(r)) - r;
}

float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// n-pointed star of radius r; m (2..n) sets how fat the points are. Points up.
float sd_star(vec2 p, float r, float n, float m) {
	p.y = -p.y;
	float an = 3.141593 / n;
	float en = 3.141593 / m;
	vec2 acs = vec2(cos(an), sin(an));
	vec2 ecs = vec2(cos(en), sin(en));
	float bn = mod(atan(p.x, p.y), 2.0 * an) - an;
	p = length(p) * vec2(cos(bn), abs(sin(bn)));
	p -= r * acs;
	p += ecs * clamp(-dot(p, ecs), 0.0, r * acs.y / ecs.y);
	return length(p) * sign(p.x);
}

// Triangle pointing up (y grows downwards on the card).
float sd_tri(vec2 p, float r) {
	p.y = -p.y;
	float k = sqrt(3.0);
	p.x = abs(p.x) - r;
	p.y = p.y + r / k;
	if (p.x + k * p.y > 0.0) {
		p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
	}
	p.x -= clamp(p.x, -2.0 * r, 0.0);
	return -length(p) * sign(p.y);
}

// --- scenes ------------------------------------------------------------------

vec3 ferris_night(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(color_a, mix(color_a, color_c, 0.45), uv.y);
	col += vec3(dots(p * vec2(22.0, 22.0), 0.12, 0.25, 1.0)) * 0.6 * (1.0 - uv.y) * (0.6 + 0.4 * sin(t * 3.0 + p.x * 9.0));
	vec2 c = vec2(fx, 0.46);
	vec2 q = p - c;
	float r = length(q);
	float R = 0.36;
	// Legs, spokes, rim and hub.
	float legs = min(sd_segment(p, c, c + vec2(-0.2, 0.5)), sd_segment(p, c, c + vec2(0.2, 0.5))) - 0.012;
	col = mix(col, color_c * 0.55, fill(legs, aa));
	float a = atan(q.y, q.x) - t * 0.25;
	float spoke = abs(sin(a * 6.0)) * r - 0.004;
	col = mix(col, color_c * 0.8, fill(max(spoke, r - R), aa) * 0.9);
	col = mix(col, color_c, fill(abs(r - R) - 0.014, aa));
	col = mix(col, color_b, fill(r - 0.035, aa));
	// Bulbs chasing round the rim.
	float k = floor(a / 6.28318 * 24.0 + 0.5);
	vec2 bulb = c + vec2(cos(k / 24.0 * 6.28318 + t * 0.25), sin(k / 24.0 * 6.28318 + t * 0.25)) * R;
	float lit = step(0.5, fract(k / 3.0 + t * 1.5));
	float db = length(p - bulb);
	col = mix(col, mix(color_b * 0.5, color_b * 1.3, lit), fill(db - 0.014, aa));
	col += color_b * smoothstep(0.05, 0.0, db) * lit * 0.35;
	// Gondolas hang straight down from 8 points of the rim.
	for (int i = 0; i < 8; i++) {
		float ga = float(i) / 8.0 * 6.28318 + t * 0.25;
		vec2 g = c + vec2(cos(ga), sin(ga)) * R + vec2(0.0, 0.045);
		float car = sd_round_box(p - g, vec2(0.038, 0.032), 0.014);
		col = mix(col, mix(color_c, color_b, float(i % 2) * 0.6), fill(car, aa));
	}
	// Pier stalls and the sea.
	float stall = 0.86 - 0.06 * step(0.5, fract(p.x * 2.3)) - 0.03 * step(0.75, fract(p.x * 5.1));
	col = mix(col, color_a * 0.6, step(stall, uv.y));
	if (uv.y > 0.9) {
		float sh = step(0.55, noise(vec2(p.x * 14.0 - t, uv.y * 60.0)));
		col = mix(color_a * 0.8, color_b, sh * 0.35 * smoothstep(0.5, 0.0, abs(p.x - fx)));
	}
	return col;
}

vec3 neon_downtown(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(color_a, mix(color_a, color_b, 0.5), smoothstep(0.1, 1.0, uv.y));
	vec2 mc = vec2(fx + 0.1, 0.3);
	float md = length(p - mc);
	col = mix(col, mix(color_b, CREAM, 0.55), fill(md - 0.19, aa));
	col += color_b * smoothstep(0.45, 0.19, md) * 0.25;
	// Far towers, then near towers with windows.
	for (int layer = 0; layer < 2; layer++) {
		float fl = float(layer);
		float w = 0.22 - fl * 0.06;
		float id = floor(p.x / w + fl * 7.0);
		float h = 0.3 + 0.45 * hash(vec2(id, fl)) + fl * 0.05;
		float top = 1.0 - h + fl * 0.12;
		float lx = fract(p.x / w + fl * 7.0);
		float body = step(top, uv.y) * step(0.06, lx) * step(lx, 0.94);
		vec3 tone = mix(color_a * 1.3, color_a * 0.55, fl);
		col = mix(col, tone, body);
		if (layer == 1 && body > 0.5) {
			vec2 win = vec2(fract(lx * 4.0), fract((uv.y - top) * 18.0));
			vec2 wid = vec2(floor(lx * 4.0), floor((uv.y - top) * 18.0)) + id * 13.0;
			float on = step(0.45, hash(wid + floor(t * 0.4 + hash(wid) * 5.0)));
			float pane = step(0.25, win.x) * step(win.x, 0.75) * step(0.3, win.y) * step(win.y, 0.8);
			col = mix(col, mix(color_c, CREAM, 0.3 * hash(wid)), pane * on * step(top + 0.04, uv.y));
		}
	}
	// A neon sign on a rooftop: a pink outline that buzzes.
	vec2 sp = p - vec2(fx - 0.35, 0.42);
	float sign_d = abs(sd_round_box(sp, vec2(0.13, 0.05), 0.03)) - 0.006;
	float buzz = 0.75 + 0.25 * step(0.2, fract(sin(floor(t * 9.0)) * 4375.85));
	col = mix(col, color_b * 1.2 * buzz, fill(sign_d, aa));
	col += color_b * smoothstep(0.05, 0.0, sign_d) * 0.4 * buzz;
	return col;
}

vec3 kelp_forest(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(mix(color_a, color_c, 0.45), color_a * 0.7, uv.y);
	float ray = pow(0.5 + 0.5 * sin((p.x + uv.y * 0.45) * 9.0 + sin(t * 0.4) * 0.6), 6.0);
	col += color_c * ray * (1.0 - uv.y) * 0.35;
	// Sand.
	float sand = 0.88 + 0.04 * sin(p.x * 5.0) + 0.02 * noise(vec2(p.x * 20.0, 0.0));
	col = mix(col, mix(color_c, CREAM, 0.5) * 0.75, step(sand, uv.y));
	// Kelp strands.
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		float x0 = (fi + 0.5) / 7.0 * ar + (hash(vec2(fi, 2.0)) - 0.5) * 0.25;
		float top = 0.15 + 0.35 * hash(vec2(fi, 5.0));
		float sway = sin(uv.y * 6.0 + t * 1.2 + fi) * 0.05 * (1.0 - uv.y);
		float d = abs(p.x - x0 - sway) - 0.016 * (0.6 + 0.4 * uv.y);
		float leaf = abs(p.x - x0 - sway - 0.03 * sin(uv.y * 40.0 + fi)) - 0.012;
		float strand = min(d, leaf * 1.2) ;
		col = mix(col, color_b * (0.7 + 0.3 * hash(vec2(fi, 9.0))), fill(strand, aa) * step(top, uv.y));
	}
	// A school of fish crossing.
	for (int j = 0; j < 7; j++) {
		float fj = float(j);
		float x = mod(t * 0.18 + fj * 0.13 + hash(vec2(fj, 1.0)) * 0.1, ar + 0.6) - 0.3;
		vec2 f = p - vec2(x, 0.35 + 0.12 * sin(fj * 2.1) + 0.02 * sin(t * 2.0 + fj));
		float body = length(f / vec2(0.04, 0.018)) - 1.0;
		float tail = sd_tri(rot(f + vec2(0.045, 0.0), 1.5708), 0.018);
		col = mix(col, color_c, fill(min(body * 0.018, tail), aa));
	}
	col += vec3(dots(vec2(p.x * 16.0, p.y * 16.0 + t * 1.5), 0.15, 0.12, 3.0)) * 0.5 * color_c;
	return col;
}

vec3 liftoff(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(color_a, mix(color_a, color_b, 0.55), smoothstep(0.2, 1.0, uv.y));
	col += vec3(dots(vec2(p.x, p.y - t * 0.3) * 20.0, 0.1, 0.2, 2.0)) * 0.7 * (1.0 - uv.y);
	// Launch tower.
	float tx = fx - 0.24;
	float tower = step(abs(p.x - tx), 0.035) * step(0.3, uv.y);
	float lattice = step(0.5, fract((p.x - tx + uv.y) * 25.0)) + step(0.5, fract((p.x - tx - uv.y) * 25.0));
	col = mix(col, color_a * 0.45, tower * clamp(lattice, 0.0, 1.0));
	// Smoke billowing at the bottom.
	float smoke = fbm(vec2(p.x * 4.0 + sin(t) * 0.1, uv.y * 3.0 + t * 0.6));
	float top = 0.92 - 0.2 * exp(-abs(p.x - fx) * 5.0) - (smoke - 0.5) * 0.2;
	float cloud = smoothstep(top - 0.02, top + 0.02, uv.y);
	// The rocket rattles in place while the stars stream past.
	vec2 rc = vec2(fx + 0.01 * sin(t * 40.0), 0.38 + 0.01 * sin(t * 23.0));
	vec2 q = (p - rc) / 1.35;
	float flame_len = 0.22 + 0.04 * sin(t * 30.0);
	float flame = length((q - vec2(0.0, 0.2)) / vec2(0.045, flame_len)) - 1.0;
	col = mix(col, color_b, fill(flame * 0.04, aa));
	col = mix(col, vec3(1.0, 0.95, 0.6), fill((length((q - vec2(0.0, 0.17)) / vec2(0.025, flame_len * 0.6)) - 1.0) * 0.025, aa));
	float hull = sd_round_box(q, vec2(0.045, 0.12), 0.04);
	float nose = sd_tri(q + vec2(0.0, 0.14), 0.05);
	float fins = sd_tri(vec2(abs(q.x) - 0.05, q.y - 0.1), 0.035);
	col = mix(col, color_b * 0.9, fill(min(nose, fins), aa));
	col = mix(col, color_c, fill(hull, aa));
	col = mix(col, color_a * 0.8, fill(abs(length(q + vec2(0.0, 0.03)) - 0.022) - 0.005, aa));
	col = mix(col, mix(color_c, color_a, 0.35), fill(length(q + vec2(0.0, 0.03)) - 0.017, aa));
	col = mix(col, mix(color_c, color_a, 0.2) * 0.95, cloud);
	return col;
}

vec3 alpine_lodge(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(color_a * 0.8, mix(color_a, color_b, 0.35), uv.y);
	// Two ranges of peaks with snow caps.
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		float x = p.x * (2.2 + fi * 1.3) + fi * 3.0;
		float ridge = 0.55 + fi * 0.12 - abs(fract(x) - 0.5) * (0.5 - fi * 0.1) - noise(vec2(x * 3.0, fi)) * 0.06;
		float hill = step(ridge, uv.y);
		vec3 rock = mix(color_a * 0.55, color_a * 0.4, fi);
		float snow = step(uv.y, ridge + 0.07 - fi * 0.03);
		col = mix(col, mix(rock, color_c, snow * 0.9), hill);
	}
	// Pines.
	for (int k = 0; k < 2; k++) {
		float fk = float(k);
		float w = 0.11 + fk * 0.04;
		float id = floor(p.x / w + fk * 0.5);
		float lx = (fract(p.x / w + fk * 0.5) - 0.5) * w;
		float base = 0.97 - fk * 0.0;
		float h = 0.16 + 0.1 * hash(vec2(id, fk)) + fk * 0.06;
		float tree = sd_tri(vec2(lx, uv.y - base + h * 0.45) * vec2(1.0, 0.55), h * 0.4);
		col = mix(col, mix(vec3(0.08, 0.25, 0.2), vec3(0.05, 0.16, 0.14), fk), fill(tree, aa) * step(0.5, hash(vec2(id, 3.0 + fk)) + fk));
	}
	// The lodge with a warm window and chimney smoke.
	vec2 lp = p - vec2(fx, 0.78);
	float house = sd_box(lp, vec2(0.13, 0.09));
	float roof = sd_tri((lp + vec2(0.0, 0.14)) * vec2(0.7, 1.0), 0.13);
	col = mix(col, vec3(0.42, 0.24, 0.16), fill(house, aa));
	col = mix(col, color_c, fill(roof, aa));
	float win = sd_box(lp - vec2(0.05, 0.0), vec2(0.035, 0.03));
	float glow = 0.85 + 0.15 * sin(t * 7.0) * sin(t * 3.1);
	col = mix(col, color_b * glow, fill(win, aa));
	col += color_b * smoothstep(0.12, 0.0, length(lp - vec2(0.05, 0.0))) * 0.25 * glow;
	col = mix(col, color_b * 0.6, fill(sd_box(lp + vec2(0.06, -0.03), vec2(0.025, 0.06)), aa));
	float smoke = fbm(vec2(p.x * 8.0, uv.y * 6.0 + t * 0.8));
	col = mix(col, CREAM, smoothstep(0.55, 0.75, smoke) * smoothstep(0.08, 0.0, abs(p.x - fx + 0.08 - (0.6 - uv.y) * 0.3)) * step(uv.y, 0.62) * 0.6);
	// Snow.
	for (int s = 0; s < 2; s++) {
		float fs = float(s);
		vec2 q = p * (9.0 + fs * 6.0) + vec2(sin(t * 0.5 + fs + p.y * 3.0) * 0.4, -t * (0.8 + fs * 0.5));
		col = mix(col, color_c, dots(q, 0.18 - fs * 0.04, 0.35, fs * 4.0) * 0.9);
	}
	return col;
}

vec3 coaster_loop(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(color_c, color_a, smoothstep(0.0, 0.9, uv.y));
	vec2 sun = vec2(fx - 0.3, 0.55);
	col = mix(col, mix(color_c, CREAM, 0.6), fill(length(p - sun) - 0.18, aa));
	// Track: y(x) with rails, sleepers and supports.
	float y = 0.5 + 0.2 * sin(p.x * 2.3 + 0.6) + 0.07 * sin(p.x * 5.3);
	float dy = 0.2 * 2.3 * cos(p.x * 2.3 + 0.6) + 0.07 * 5.3 * cos(p.x * 5.3);
	float dline = abs(uv.y - y) / sqrt(1.0 + dy * dy);
	float support = step(abs(fract(p.x * 7.0) - 0.5), 0.04) * step(y, uv.y);
	float brace = step(abs(fract(p.x * 7.0 + (uv.y - y) * 7.0) - 0.5), 0.03) * step(y, uv.y);
	col = mix(col, color_b * 0.8, clamp(support + brace * 0.7, 0.0, 1.0));
	col = mix(col, color_b, fill(dline - 0.012, aa));
	col = mix(col, color_b * 0.6, fill(abs(uv.y - y - 0.03) - 0.006, aa));
	// The car rides along, tilted to the track.
	float cx = mod(t * 0.4, ar + 0.6) - 0.3;
	float cy = 0.5 + 0.2 * sin(cx * 2.3 + 0.6) + 0.07 * sin(cx * 5.3);
	float cdy = 0.2 * 2.3 * cos(cx * 2.3 + 0.6) + 0.07 * 5.3 * cos(cx * 5.3);
	vec2 q = rot(p - vec2(cx, cy - 0.04), -atan(cdy));
	float car = sd_round_box(q, vec2(0.07, 0.03), 0.015);
	col = mix(col, color_c * 0.95, fill(car, aa));
	col = mix(col, color_b, fill(sd_round_box(q - vec2(0.0, 0.012), vec2(0.07, 0.008), 0.005), aa));
	for (int h = 0; h < 2; h++) {
		col = mix(col, color_b * 0.5, fill(length(q - vec2(-0.03 + float(h) * 0.05, -0.045)) - 0.014, aa));
	}
	return col;
}

vec3 peekaboo(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(color_a, mix(color_a, CREAM, 0.5), uv.y);
	col += CREAM * smoothstep(0.6, 0.75, fbm(vec2(p.x * 2.0 - t * 0.05, uv.y * 4.0))) * 0.4 * (1.0 - uv.y);
	// The head bobs up behind the hedge.
	float rise = 0.62 + 0.05 * sin(t * 1.6);
	vec2 hc = vec2(fx, rise);
	vec2 q = p - hc;
	float head = length(q / vec2(1.0, 0.95)) - 0.34;
	col = mix(col, color_b * 0.55, fill(head - 0.012, aa));
	col = mix(col, color_b, fill(head, aa));
	// Stitches on the forehead.
	float stitch = sd_segment(q, vec2(-0.12, -0.22), vec2(0.04, -0.25)) - 0.006;
	for (int i = 0; i < 4; i++) {
		float sx = -0.1 + float(i) * 0.045;
		stitch = min(stitch, sd_segment(q, vec2(sx, -0.255), vec2(sx + 0.01, -0.21)) - 0.005);
	}
	col = mix(col, INK, fill(stitch, aa));
	// Eyes that look around and blink.
	vec2 look = vec2(sin(t * 0.7) * 0.025, cos(t * 0.9) * 0.012);
	float blink = step(0.94, fract(t * 0.31));
	for (int e = 0; e < 2; e++) {
		vec2 ec = q - vec2(-0.11 + float(e) * 0.22, -0.06);
		float white = length(ec / vec2(1.0, 1.0 - blink * 0.9)) - 0.075;
		col = mix(col, CREAM, fill(white, aa));
		col = mix(col, INK, fill(length(ec - look) - 0.035, aa) * (1.0 - blink));
		col = mix(col, color_c, fill(length(ec - vec2(0.0, 0.1)) - 0.035, aa) * 0.6);
	}
	// A grin with one tooth.
	float mouth = abs(length(q - vec2(0.0, 0.0)) - 0.17) - 0.012;
	mouth = max(mouth, -(q.y - 0.07));
	col = mix(col, INK, fill(mouth, aa));
	col = mix(col, CREAM, fill(sd_box(q - vec2(0.04, 0.185), vec2(0.018, 0.02)), aa));
	// Hands on the hedge and the hedge itself.
	float hedge = 0.82 + 0.03 * sin(p.x * 25.0) + 0.02 * sin(p.x * 61.0);
	col = mix(col, vec3(0.2, 0.55, 0.3), step(hedge, uv.y));
	for (int h = 0; h < 2; h++) {
		vec2 hp = p - vec2(fx - 0.28 + float(h) * 0.56, 0.83);
		col = mix(col, color_b, fill(length(hp / vec2(1.0, 0.7)) - 0.06, aa));
	}
	return col;
}

vec3 duck_parade(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(color_a, mix(color_a, CREAM, 0.6), uv.y);
	col += CREAM * smoothstep(0.6, 0.7, fbm(vec2(p.x * 2.0 - t * 0.04, uv.y * 3.0))) * 0.45 * (1.0 - uv.y);
	float water = 0.66 + 0.02 * sin(p.x * 14.0 - t * 2.0);
	float cell = floor((p.x + t * 0.12) / 0.5);
	float lx = fract((p.x + t * 0.12) / 0.5) * 0.5 - 0.25;
	float bob = 0.02 * sin(t * 3.0 + cell * 1.7);
	vec2 q = vec2(lx, uv.y - 0.6 - bob);
	float body = length(q / vec2(1.0, 0.65)) - 0.1;
	body = max(body, q.y - 0.04);
	float head = length(q - vec2(0.06, -0.09)) - 0.055;
	float tail = sd_tri(rot(q + vec2(0.1, 0.03), -0.6), 0.03);
	float duck = min(min(body, head), tail);
	col = mix(col, color_b * 0.7, fill(duck - 0.008, aa));
	col = mix(col, color_b, fill(duck, aa));
	col = mix(col, mix(color_b, CREAM, 0.5), fill(length((q - vec2(-0.01, 0.0)) / vec2(1.0, 0.6)) - 0.045, aa));
	col = mix(col, color_c, fill(sd_round_box(q - vec2(0.12, -0.085), vec2(0.03, 0.012), 0.01), aa));
	col = mix(col, INK, fill(length(q - vec2(0.075, -0.1)) - 0.011, aa));
	// Water in front.
	vec3 sea = mix(color_a * 0.85, color_a * 0.6, (uv.y - water) * 3.0);
	sea += CREAM * step(0.75, noise(vec2(p.x * 18.0 - t, uv.y * 40.0))) * 0.25;
	col = mix(col, sea, step(water, uv.y));
	col = mix(col, CREAM, fill(abs(uv.y - water) - 0.005, aa) * 0.7);
	return col;
}

vec3 sparky(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec2 c = vec2(fx, 0.5);
	float r = length(p - c);
	vec3 col = mix(color_a * 1.5, color_a, smoothstep(0.0, 1.2, r));
	float rays = step(0.0, sin(atan(p.y - c.y, p.x - c.x) * 10.0 + t * 0.4));
	col = mix(col, color_a * 1.25, rays * 0.5);
	// Little star friends twinkling.
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		vec2 sp = vec2(fx - 0.9 + fi * 0.33 + 0.1 * sin(fi * 3.0), 0.25 + 0.5 * hash(vec2(fi, 4.0)));
		float tw = 0.6 + 0.4 * sin(t * 3.0 + fi * 2.0);
		col = mix(col, color_c, fill(sd_star(rot(p - sp, t * 0.5 + fi), 0.04 * tw, 5.0, 3.0), aa));
	}
	// Sparky bounces with a squash on landing.
	float b = abs(sin(t * 2.2));
	float squash = 1.0 + 0.15 * (1.0 - smoothstep(0.0, 0.25, b));
	vec2 q = p - vec2(fx, 0.6 - b * 0.12);
	q = vec2(q.x / squash, q.y * squash);
	q = rot(q, sin(t * 2.2) * 0.12);
	q /= 1.25;
	float star = sd_star(q, 0.3, 5.0, 3.2);
	col = mix(col, INK, fill(star - 0.015, aa));
	col = mix(col, color_b, fill(star, aa));
	col = mix(col, mix(color_b, CREAM, 0.5), fill(sd_star(q + vec2(0.03, 0.04), 0.16, 5.0, 3.2), aa) * 0.5);
	for (int e = 0; e < 2; e++) {
		vec2 ec = q - vec2(-0.06 + float(e) * 0.12, -0.02);
		col = mix(col, INK, fill(length(ec / vec2(0.8, 1.2)) - 0.03, aa));
		col = mix(col, CREAM, fill(length(ec - vec2(0.008, -0.012)) - 0.01, aa));
	}
	float smile = max(abs(length(q - vec2(0.0, 0.0)) - 0.07) - 0.01, -(q.y - 0.03));
	col = mix(col, INK, fill(smile, aa));
	return col;
}

vec3 ghost_party(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(color_a, color_a * 1.6, uv.y);
	col = mix(col, mix(color_b, color_c, 0.15), fill(length(p - vec2(fx + 0.2, 0.28)) - 0.15, aa) * 0.9);
	// A sagging string of party lights.
	float sag = 0.1 + 0.06 * (1.0 - pow(abs(fract(p.x * 0.8) - 0.5) * 2.0, 2.0));
	col = mix(col, INK, fill(abs(uv.y - sag) - 0.004, aa));
	float bi = floor(p.x * 6.0);
	vec2 bp = vec2((bi + 0.5) / 6.0, 0.0);
	bp.y = 0.1 + 0.06 * (1.0 - pow(abs(fract(bp.x * 0.8) - 0.5) * 2.0, 2.0)) + 0.025;
	float on = step(0.5, fract(bi * 0.5 + t * 0.8));
	col = mix(col, mix(color_c * 0.5, color_c * 1.2, on), fill(length(p - bp) - 0.018, aa));
	// Ghosts.
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 gc = vec2(fx - 0.7 + fi * 0.55, 0.56 + 0.05 * sin(t * 1.5 + fi * 2.0) - 0.06 * fi * (2.0 - fi));
		vec2 q = p - gc;
		q = rot(q, sin(t * 1.3 + fi) * 0.1);
		float s = 1.15 + 0.3 * fi * (2.0 - fi);
		q /= s;
		float top = length(q) - 0.13;
		float skirt = sd_box(q - vec2(0.0, 0.1), vec2(0.13, 0.1));
		float hem = q.y - (0.18 + 0.025 * sin(q.x * 60.0 + t * 4.0));
		float ghost = max(min(top, skirt), hem);
		col = mix(col, INK, fill(ghost * s - 0.008, aa) * 0.6);
		col = mix(col, color_b, fill(ghost * s, aa));
		for (int e = 0; e < 2; e++) {
			col = mix(col, INK, fill((length((q - vec2(-0.045 + float(e) * 0.09, -0.01)) / vec2(0.8, 1.2)) - 0.022) * s, aa));
		}
		col = mix(col, INK, fill((length(q - vec2(0.0, 0.05)) - 0.018) * s, aa));
	}
	return col;
}

vec3 hypno_spiral(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec2 q = p - vec2(fx, 0.5);
	float r = length(q);
	float a = atan(q.y, q.x);
	float v = fract(a / 6.28318 * 2.0 + r * 3.2 - t * 0.6);
	vec3 col = mix(color_a, color_b, smoothstep(0.48, 0.52, v) * smoothstep(1.0, 0.96, v));
	col = mix(col, color_c, smoothstep(0.8, 2.5, r) * 0.7);
	col = mix(col, color_c, fill(r - 0.05, aa));
	col = mix(col, CREAM, fill(r - 0.02, aa));
	return col;
}

vec3 comic_pop(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec2 c = vec2(fx, 0.5);
	vec2 g = rot(p, 0.4) * 28.0;
	float dr = 0.15 + 0.3 * smoothstep(1.8, 0.0, length(p - c));
	float dot_ = fill(length(fract(g) - 0.5) - dr, 1.5 / rect_size.y * 28.0);
	vec3 col = mix(color_a, color_a * 0.72, dot_);
	// Speed lines.
	float a = atan(p.y - c.y, p.x - c.x);
	float lines = step(0.92, fract(a * 6.0 + floor(t * 6.0) * 0.37)) * smoothstep(0.35, 0.7, length(p - c));
	col = mix(col, CREAM, lines * 0.7);
	float pulse = 1.0 + 0.06 * sin(t * 6.0);
	vec2 q = rot(p - c, 0.15) / pulse;
	float burst = sd_star(q, 0.38, 12.0, 6.0);
	col = mix(col, INK, fill(burst - 0.02, aa));
	col = mix(col, color_b, fill(burst, aa));
	col = mix(col, color_c, fill(sd_star(q, 0.22, 12.0, 6.0), aa));
	// A white glint.
	col = mix(col, CREAM, fill(length((q - vec2(-0.07, -0.08)) / vec2(1.5, 1.0)) - 0.03, aa));
	return col;
}

vec3 wave_scales(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec2 q = vec2(p.x + t * 0.06, p.y) * 5.0;
	vec3 col = color_a;
	// Each row overlaps the one above; draw from the top row down.
	for (int k = 0; k < 2; k++) {
		vec2 g = q + vec2(float(k) * 0.5, float(k) * 0.5);
		vec2 id = floor(g);
		vec2 f = fract(g) - vec2(0.5, 1.0);
		float r = length(f);
		float inside = step(r, 0.72) * step(f.y, 0.0);
		float rings = step(0.5, fract(r * 5.0));
		vec3 sc = mix(color_b, color_c, rings);
		col = mix(col, sc, inside);
		col = mix(col, color_a, fill(abs(r - 0.72) - 0.02, aa * 5.0) * step(f.y, 0.0));
	}
	return col;
}

vec3 argyle(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec2 q = vec2(p.x - t * 0.04, p.y) * vec2(3.0, 2.0);
	vec2 d = rot(q, 0.785398);
	vec3 col = mix(color_a, color_b, mod(floor(d.x * 1.414) + floor(d.y * 1.414), 2.0));
	// Stitched diagonals.
	vec2 s = fract(vec2(q.x + q.y, q.x - q.y) * 0.707 * 1.414 + 0.5) - 0.5;
	float stitch = min(abs(s.x), abs(s.y));
	float dash = step(0.5, fract((q.x) * 8.0));
	col = mix(col, color_c, step(stitch, 0.02) * dash);
	return col;
}

vec3 kaleidoscope(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec2 c = vec2(floor(p.x) + 0.5, 0.5);
	vec2 q = p - c;
	float r = length(q);
	float a = atan(q.y, q.x) + t * 0.2;
	float seg = 3.14159 / 3.0;
	a = abs(mod(a, 2.0 * seg) - seg);
	vec2 k = vec2(cos(a), sin(a)) * r;
	float n = fbm(k * 3.5 + vec2(t * 0.25, -t * 0.1));
	float bands = fract(n * 2.0 + r * 1.5);
	vec3 col = mix(color_a, color_b, smoothstep(0.3, 0.35, bands));
	col = mix(col, color_c, smoothstep(0.7, 0.75, bands));
	col = mix(col, CREAM, smoothstep(0.92, 0.95, bands) * 0.8);
	col *= 1.0 - smoothstep(0.42, 0.52, r) * 0.45;
	return col;
}

vec3 picnic_plaid(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec2 q = (p + vec2(t * 0.03, 0.0)) * 6.0;
	float h = step(0.5, fract(q.y));
	float v = step(0.5, fract(q.x));
	vec3 col = color_a;
	col = mix(col, mix(color_a, color_b, 0.55), max(h, v));
	col = mix(col, color_b, h * v);
	float pin = step(abs(fract(q.x * 0.5) - 0.25), 0.012) + step(abs(fract(q.y * 0.5) - 0.25), 0.012);
	col = mix(col, color_c, clamp(pin, 0.0, 1.0) * 0.6);
	return col;
}

vec3 memphis(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = color_a;
	col = mix(col, color_a * 0.92, dots(p * 30.0, 0.18, 0.5, 9.0));
	vec2 g = (p + vec2(t * 0.03, 0.0)) * 2.2;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	f = rot(f, h * 6.28 + t * (h - 0.5) * 0.6);
	float d;
	vec3 sc;
	if (h < 0.3) {
		d = abs(sd_tri(f, 0.18)) - 0.025;
		sc = color_b;
	} else if (h < 0.55) {
		d = abs(f.y - 0.06 * sin(f.x * 25.0)) - 0.025;
		d = max(d, abs(f.x) - 0.3);
		sc = color_c;
	} else if (h < 0.75) {
		d = length(f) - 0.14;
		sc = mix(color_b, color_c, 0.5);
	} else {
		d = abs(sd_box(f, vec2(0.13))) - 0.02;
		sc = INK;
	}
	col = mix(col, sc, fill(d / 2.2, aa));
	return col;
}

vec3 equalizer(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(color_a, color_a * 1.8, uv.y);
	float w = 0.09;
	float id = floor(p.x / w);
	float lx = fract(p.x / w);
	float beat = pow(0.5 + 0.5 * sin(t * 6.283 * 1.6), 4.0);
	float level = 0.25 + 0.55 * noise(vec2(id * 0.7, t * 2.2)) + 0.2 * beat * hash(vec2(id, 1.0));
	float cell = fract(uv.y * 16.0);
	float led = step(0.12, lx) * step(lx, 0.88) * step(0.2, cell) * step(1.0 - level, uv.y);
	vec3 bar = mix(color_c, color_b, smoothstep(0.85, 0.3, uv.y));
	col = mix(col, bar, led);
	float peak = 1.0 - level - 0.06 - 0.04 * fract(t);
	col = mix(col, CREAM, step(0.12, lx) * step(lx, 0.88) * step(abs(uv.y - peak), 0.015));
	return col;
}

vec3 pixel_hills(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	float px = 1.0 / 26.0;
	vec2 g = floor(p / px) * px;
	vec3 col = mix(color_a, mix(color_a, CREAM, 0.4), floor(g.y * 6.0) / 6.0);
	// Blocky sun.
	vec2 sc = vec2(fx, 0.3);
	col = mix(col, color_c, step(length(g - sc), 0.16));
	col = mix(col, mix(color_c, CREAM, 0.5), step(length(g - sc), 0.09));
	// Clouds drifting.
	vec2 cg = vec2(g.x + t * 0.05, g.y);
	float cloud = step(0.62, noise(vec2(cg.x * 4.0, cg.y * 9.0))) * step(g.y, 0.4);
	col = mix(col, CREAM, cloud);
	// Two layers of hills.
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		float x = g.x + t * (0.04 + fi * 0.06);
		float hy = 0.6 + fi * 0.15 - 0.12 * sin(x * (2.0 + fi * 1.5) + fi) - 0.05 * sin(x * 7.0);
		hy = floor(hy / px) * px;
		vec3 grass = mix(color_b * 0.75, color_b, fi);
		col = mix(col, grass, step(hy, g.y));
		col = mix(col, grass * 1.25, step(hy, g.y) * step(g.y, hy + px * 0.99));
	}
	col = mix(col, vec3(0.55, 0.35, 0.2), step(0.93, g.y));
	return col;
}

vec3 balloon_sky(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(color_a * 0.9, mix(color_a, CREAM, 0.6), uv.y);
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		float n = fbm(vec2(p.x * (2.0 + fi) - t * (0.04 + fi * 0.03), uv.y * 3.0 + fi * 5.0));
		col = mix(col, mix(CREAM, color_a, 0.15 * fi), smoothstep(0.58, 0.62, n + uv.y * 0.15 * (1.0 + fi)) * (0.7 + 0.3 * fi));
	}
	vec2 c = vec2(fx, 0.4 + 0.04 * sin(t * 0.9));
	vec2 q = p - c;
	q = rot(q, sin(t * 0.7) * 0.05);
	float env = length(q / vec2(1.0, 1.1)) - 0.24;
	env = min(env, max(sd_tri(vec2(q.x, q.y - 0.16) * vec2(1.0, -1.0), 0.17), q.y - 0.36));
	float stripe = step(0.5, fract(atan(q.x, 0.3 - q.y) * 3.0));
	col = mix(col, INK, fill(env - 0.01, aa) * 0.5);
	col = mix(col, mix(color_b, color_c, stripe), fill(env, aa));
	col = mix(col, CREAM, fill(length((q - vec2(-0.09, -0.12)) / vec2(0.6, 1.0)) - 0.03, aa) * 0.5);
	vec2 bk = q - vec2(0.0, 0.46);
	col = mix(col, vec3(0.5, 0.3, 0.18), fill(sd_round_box(bk, vec2(0.045, 0.035), 0.01), aa));
	for (int r = 0; r < 2; r++) {
		float sx = float(r) * 2.0 - 1.0;
		col = mix(col, INK, fill(sd_segment(q, vec2(0.05 * sx, 0.36), vec2(0.04 * sx, 0.43)) - 0.003, aa));
	}
	return col;
}

vec3 prize_wheel(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec2 c = vec2(fx, 0.52);
	vec2 q = p - c;
	float r = length(q);
	vec3 col = mix(color_a * 1.4, color_a, smoothstep(0.0, 1.5, r));
	col = mix(col, color_a * 1.2, step(0.0, sin(atan(q.y, q.x) * 14.0 - t * 0.3)) * 0.5);
	// Spins up, slows, settles, rests, every 6 seconds.
	float cyc = fract(t / 6.0);
	float spin = (1.0 - pow(1.0 - min(cyc / 0.7, 1.0), 3.0)) * 6.28318 * 2.25 + floor(t / 6.0) * 6.28318 * 0.25;
	float a = atan(q.y, q.x) + spin;
	float seg = floor(mod(a, 6.28318) / 6.28318 * 12.0);
	vec3 sc = mod(seg, 3.0) < 0.5 ? color_b : (mod(seg, 3.0) < 1.5 ? color_c : CREAM);
	float R = 0.4;
	col = mix(col, INK, fill(r - R - 0.035, aa));
	col = mix(col, sc, fill(r - R, aa));
	float edge = abs(fract(mod(a, 6.28318) / 6.28318 * 12.0 + 0.5) - 0.5) * r * 0.52;
	col = mix(col, INK, fill(edge - 0.004, aa) * fill(r - R, aa));
	// Rim bulbs and hub.
	float k = floor(mod(a, 6.28318) / 6.28318 * 24.0) + 0.5;
	float ba = k / 24.0 * 6.28318 - spin;
	float bd = length(q - vec2(cos(ba), sin(ba)) * (R + 0.018));
	col = mix(col, mix(color_c, CREAM, step(0.5, fract(k * 0.5 + t * 2.0))), fill(bd - 0.011, aa));
	col = mix(col, INK, fill(r - 0.06, aa));
	col = mix(col, color_c, fill(sd_star(rot(q, -spin), 0.05, 5.0, 3.0), aa));
	// The pointer at the top.
	float pointer = sd_tri(vec2(q.x, -(q.y + R + 0.02)) * vec2(1.0, 1.4), 0.04);
	col = mix(col, INK, fill(pointer - 0.008, aa));
	col = mix(col, CREAM, fill(pointer, aa));
	return col;
}

vec3 ticket_storm(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(color_a * 1.2, color_a * 0.8, uv.y);
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		float s = 3.0 + fi * 2.0;
		vec2 g = (p + vec2(t * (0.25 + fi * 0.15), -t * (0.1 + fi * 0.05))) * s;
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float h = hash(id + fi * 7.0);
		if (h > 0.45) {
			f = rot(f, (h - 0.7) * 2.0 + sin(t * 2.0 + h * 9.0) * 0.3);
			float tk = sd_box(f, vec2(0.3, 0.15));
			tk = max(tk, -(length(vec2(abs(f.x) - 0.3, f.y)) - 0.05));
			vec3 tc = mix(color_b, color_b * 0.8, fi);
			col = mix(col, INK, fill(tk - 0.02, aa * s) * 0.4);
			col = mix(col, tc, fill(tk, aa * s));
			col = mix(col, color_c, fill(abs(sd_box(f, vec2(0.22, 0.09))) - 0.012, aa * s));
			col = mix(col, color_c, fill(sd_star(f, 0.06, 5.0, 3.0), aa * s));
		}
	}
	return col;
}

vec3 thunderhead(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	float cycle = floor(t / 2.7);
	float ft = fract(t / 2.7) * 2.7;
	float flash = smoothstep(0.25, 0.0, ft) * (0.6 + 0.4 * step(0.06, ft) * step(ft, 0.1));
	vec3 col = mix(color_a * 1.3, color_a * 0.6, uv.y);
	col += color_b * flash * 0.35;
	// Rain.
	float lane = floor((p.x + uv.y * 0.25) * 80.0);
	float drop = step(0.85, fract(uv.y * 2.0 + t * 3.0 + hash(vec2(lane, 0.0)) * 10.0)) * step(0.6, hash(vec2(lane, 1.0)));
	col = mix(col, color_b, drop * 0.45);
	// The bolt: a jagged path down from the cloud.
	float x0 = fx - 0.4 + hash(vec2(cycle, 3.0)) * 0.6;
	float j = floor(uv.y * 9.0);
	float jx = (hash(vec2(j, cycle)) - 0.5) * 0.12;
	float jx2 = (hash(vec2(j + 1.0, cycle)) - 0.5) * 0.12;
	float bx = x0 + mix(jx, jx2, fract(uv.y * 9.0));
	float bolt = abs(p.x - bx) - 0.008;
	float vis = step(ft, 0.9) * step(0.5, fract(ft * 7.0) + step(0.35, ft)) * step(0.2, uv.y);
	col = mix(col, color_c, fill(bolt, aa) * vis);
	col += color_c * smoothstep(0.06, 0.0, bolt) * vis * 0.5;
	// Clouds over the top.
	float n = fbm(vec2(p.x * 2.5 - t * 0.08, uv.y * 3.0));
	float cl = smoothstep(0.3, 0.32, n - uv.y * 1.4 + 0.08);
	vec3 cc = mix(color_a * 1.6, color_b * 0.8, n) + color_c * flash * 0.3;
	col = mix(col, cc, cl);
	return col;
}

vec3 desert_mirage(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	float horizon = 0.7;
	vec2 sp = p;
	sp.x += sin(uv.y * 90.0 + t * 5.0) * 0.004 * smoothstep(0.25, 0.0, abs(uv.y - horizon));
	vec3 col = mix(color_a * 1.15, mix(color_a, CREAM, 0.5), smoothstep(0.0, horizon, uv.y));
	col = mix(col, mix(CREAM, color_a, 0.3), fill(length(sp - vec2(fx - 0.2, 0.52)) - 0.16, aa));
	// Mesas.
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float mx = fx - 1.4 + fi * 0.9 + hash(vec2(fi, 2.0)) * 0.3;
		float top = 0.42 + 0.12 * hash(vec2(fi, 5.0));
		float half_w = 0.2 + 0.1 * hash(vec2(fi, 8.0)) + (uv.y - top) * 0.6;
		float mesa = step(top, uv.y) * step(abs(sp.x - mx), half_w);
		col = mix(col, color_b * (0.8 + 0.1 * fi), mesa);
	}
	col = mix(col, mix(color_b, color_a, 0.4) * 0.8, step(horizon, uv.y));
	col = mix(col, mix(color_b, color_a, 0.6), step(horizon, uv.y) * step(0.6, noise(vec2(p.x * 10.0, uv.y * 30.0))) * 0.3);
	// Saguaros.
	for (int k = 0; k < 2; k++) {
		vec2 q = p - vec2(fx + 0.1 + float(k) * 0.42, 0.88 - float(k) * 0.08);
		float s = 1.0 - float(k) * 0.3;
		q /= s;
		float trunk = sd_round_box(q - vec2(0.0, -0.14), vec2(0.03, 0.2), 0.03);
		float arm1 = min(sd_round_box(q - vec2(-0.07, -0.12), vec2(0.045, 0.022), 0.022), sd_round_box(q - vec2(-0.1, -0.2), vec2(0.022, 0.08), 0.022));
		float arm2 = min(sd_round_box(q - vec2(0.07, -0.08), vec2(0.045, 0.02), 0.02), sd_round_box(q - vec2(0.1, -0.14), vec2(0.02, 0.07), 0.02));
		col = mix(col, color_c, fill(min(trunk, min(arm1, arm2)) * s, aa));
	}
	return col;
}

vec3 spiral_galaxy(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = color_a;
	col += vec3(dots(p * 30.0, 0.1, 0.25, 1.0)) * (0.5 + 0.5 * sin(t * 3.0 + p.x * 20.0)) * 0.7;
	col += vec3(dots(p * 14.0 + 3.0, 0.08, 0.15, 2.0)) * 0.5;
	vec2 q = p - vec2(fx, 0.5);
	q = rot(q, 0.35);
	q.y /= 0.45;
	float r = length(q);
	float a = atan(q.y, q.x);
	float arms = pow(0.5 + 0.5 * cos(2.0 * (a - log(r + 0.001) * 2.6 + t * 0.25)), 3.0);
	float falloff = exp(-r * 2.8);
	float dust = fbm(q * 6.0 + vec2(t * 0.1, 0.0));
	col += color_b * arms * falloff * (0.6 + 0.8 * dust) * 1.5;
	col += vec3(dots(rot(q, t * 0.25) * 22.0, 0.12, 0.3, 4.0)) * arms * falloff * 2.0;
	col += color_c * exp(-r * 9.0) * 1.6;
	return col;
}

vec3 blossom_drift(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(color_a * 1.05, mix(color_a, CREAM, 0.6), uv.y);
	col = mix(col, mix(CREAM, color_b, 0.15), fill(length(p - vec2(fx - 0.55, 0.55)) - 0.2, aa) * 0.7);
	// Soft hills far away.
	float hill = 0.82 - 0.08 * sin(p.x * 2.2 + 1.0) - 0.04 * sin(p.x * 5.0);
	col = mix(col, mix(color_a, color_c, 0.25), step(hill, uv.y) * 0.6);
	// A branch in from the top right with two twigs.
	vec2 b0 = vec2(ar + 0.1, 0.02);
	vec2 b1 = vec2(fx, 0.32);
	vec2 b2 = vec2(fx - 0.85, 0.46);
	vec2 b3 = vec2(fx + 0.2, 0.7);
	vec2 bj = mix(b0, b1, 0.35);
	float br = min(sd_segment(p, b0, b1) - 0.04 + 0.02 * (p.x - fx) / ar, sd_segment(p, b1, b2) - 0.022);
	br = min(br, sd_segment(p, bj, b3) - 0.018);
	col = mix(col, color_c, fill(br, aa));
	// Blossoms along it.
	for (int i = 0; i < 11; i++) {
		float fi = float(i);
		vec2 fp;
		if (i < 4) { fp = mix(b0, b1, 0.15 + fi * 0.27); }
		else if (i < 8) { fp = mix(b1, b2, 0.15 + (fi - 4.0) * 0.27); }
		else { fp = mix(bj, b3, 0.3 + (fi - 8.0) * 0.33); }
		fp += vec2(hash(vec2(fi, 1.0)) - 0.5, hash(vec2(fi, 2.0)) - 0.5) * 0.08;
		vec2 q = rot(p - fp, fi + sin(t + fi) * 0.15);
		float pa = atan(q.y, q.x);
		float size = 0.06 + 0.02 * hash(vec2(fi, 3.0));
		float petals = length(q) - size * (0.72 + 0.28 * cos(pa * 5.0));
		col = mix(col, color_b * 0.8, fill(petals - 0.006, aa));
		col = mix(col, color_b, fill(petals, aa));
		col = mix(col, mix(color_b, CREAM, 0.7), fill(length(q) - size * 0.3, aa));
		col = mix(col, vec3(1.0, 0.85, 0.35), fill(length(q) - size * 0.12, aa));
	}
	// Petals drifting down and across.
	for (int k = 0; k < 2; k++) {
		float fk = float(k);
		float s = 3.5 + fk * 2.5;
		vec2 g = (p + vec2(-t * (0.12 + fk * 0.06), -t * (0.08 + fk * 0.04))) * s;
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float h = hash(id + fk * 5.0);
		f = rot(f, t * (h - 0.5) * 3.0 + h * 6.0);
		float petal = length(f / vec2(1.0, 0.55)) - 0.13;
		col = mix(col, mix(color_b, CREAM, 0.2 * fk), fill(petal / s, aa) * step(0.5, h));
	}
	return col;
}

void fragment() {
	float t = TIME * speed;
	vec2 uv = UV;
	float ar = rect_size.x / max(rect_size.y, 1.0);
	vec2 p = vec2(uv.x * ar, uv.y);
	// The focal point: towards the right on wide cards, centred on narrow ones.
	float fx = max(ar - 0.75, ar * 0.62);
	float aa = 1.5 / max(rect_size.y, 1.0);
	vec3 col;
	if (style == 0) { col = ferris_night(uv, p, t, ar, fx, aa); }
	else if (style == 1) { col = neon_downtown(uv, p, t, ar, fx, aa); }
	else if (style == 2) { col = kelp_forest(uv, p, t, ar, fx, aa); }
	else if (style == 3) { col = liftoff(uv, p, t, ar, fx, aa); }
	else if (style == 4) { col = alpine_lodge(uv, p, t, ar, fx, aa); }
	else if (style == 5) { col = coaster_loop(uv, p, t, ar, fx, aa); }
	else if (style == 6) { col = peekaboo(uv, p, t, ar, fx, aa); }
	else if (style == 7) { col = duck_parade(uv, p, t, ar, fx, aa); }
	else if (style == 8) { col = sparky(uv, p, t, ar, fx, aa); }
	else if (style == 9) { col = ghost_party(uv, p, t, ar, fx, aa); }
	else if (style == 10) { col = hypno_spiral(uv, p, t, ar, fx, aa); }
	else if (style == 11) { col = comic_pop(uv, p, t, ar, fx, aa); }
	else if (style == 12) { col = wave_scales(uv, p, t, ar, fx, aa); }
	else if (style == 13) { col = argyle(uv, p, t, ar, fx, aa); }
	else if (style == 14) { col = kaleidoscope(uv, p, t, ar, fx, aa); }
	else if (style == 15) { col = picnic_plaid(uv, p, t, ar, fx, aa); }
	else if (style == 16) { col = memphis(uv, p, t, ar, fx, aa); }
	else if (style == 17) { col = equalizer(uv, p, t, ar, fx, aa); }
	else if (style == 18) { col = pixel_hills(uv, p, t, ar, fx, aa); }
	else if (style == 19) { col = balloon_sky(uv, p, t, ar, fx, aa); }
	else if (style == 20) { col = prize_wheel(uv, p, t, ar, fx, aa); }
	else if (style == 21) { col = ticket_storm(uv, p, t, ar, fx, aa); }
	else if (style == 22) { col = thunderhead(uv, p, t, ar, fx, aa); }
	else if (style == 23) { col = desert_mirage(uv, p, t, ar, fx, aa); }
	else if (style == 24) { col = spiral_galaxy(uv, p, t, ar, fx, aa); }
	else { col = blossom_drift(uv, p, t, ar, fx, aa); }
	// Rounded corners.
	vec2 half_size = rect_size * 0.5;
	vec2 q = abs(uv * rect_size - half_size) - (half_size - vec2(radius));
	float sd = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	COLOR = vec4(col, clamp(0.5 - sd, 0.0, 1.0));
}
