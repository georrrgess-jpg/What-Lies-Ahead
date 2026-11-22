shader_type canvas_item;
// Update 24 player-card banners (scripts/cosmetics/banner_view.gd: banner
// styles 41 and up, passed here as style - 41). Animated scenes drawn with
// distance fields; colours come from the item. The main subject sits towards
// the right, clear of the portrait and title.
//   0 big top        1 firefly field  2 soda fizz     3 card shark
//   4 carousel       5 bumper cars    6 plasma globe  7 lantern festival
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

// n-pointed star of radius r; m (2..n) sets how fat the points are.
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

// Twinkling stars in the upper sky.
vec3 night_sky(vec2 uv, vec2 p, float t, vec3 top, vec3 low) {
	vec3 col = mix(top, low, smoothstep(0.0, 1.0, uv.y));
	vec2 g = p * 26.0;
	vec2 id = floor(g);
	float s = step(0.93, hash(id)) * smoothstep(0.12, 0.0, length(fract(g) - 0.5));
	return col + vec3(s) * (0.5 + 0.5 * sin(t * 3.0 + hash(id + 2.0) * 30.0)) * (1.0 - uv.y);
}

// --- scenes ------------------------------------------------------------------

// The big top: a striped circus tent under a night sky, its pennant flying,
// two searchlights sweeping behind it.
vec3 big_top(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = night_sky(uv, p, t, color_c * 0.45, color_c);
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		vec2 base = vec2(fx + (fi - 0.5) * 0.9, 1.05);
		float a = sin(t * 0.6 + fi * 2.4) * 0.5 + (fi - 0.5) * 0.4;
		vec2 dir = vec2(sin(a), -cos(a));
		vec2 q = p - base;
		float along = dot(q, dir);
		float across = abs(dot(q, vec2(-dir.y, dir.x)));
		col += CREAM * 0.16 * smoothstep(0.03 + along * 0.12, 0.0, across) * step(0.0, along);
	}
	vec2 q = p - vec2(fx, 0.0);
	float ground = 0.86;
	float roof_h = 0.44 - abs(q.x) * 0.55;
	float tent_top = ground - 0.32 - max(roof_h, 0.0);
	float wall = step(abs(q.x), 0.48) * step(ground - 0.32, p.y) * step(p.y, ground);
	float roof = step(abs(q.x), 0.62) * step(tent_top, p.y) * step(p.y, ground - 0.32 + 0.03);
	float stripe = step(0.5, fract(q.x * 5.0 / max(1.0 - (ground - 0.32 - p.y) * 1.6, 0.3)));
	vec3 tent = mix(color_a, CREAM, stripe);
	col = mix(col, tent * 0.85, wall);
	col = mix(col, tent, roof);
	float scallop = length(vec2(fract(q.x * 8.0) - 0.5, (p.y - (ground - 0.31)) * 8.0)) - 0.5;
	col = mix(col, color_b, fill(scallop / 8.0, aa) * step(abs(q.x), 0.6) * step(ground - 0.33, p.y));
	col = mix(col, INK, fill(sd_round_box(q - vec2(0.0, ground - 0.13), vec2(0.09, 0.14), 0.08), aa));
	float pole = sd_segment(p, vec2(fx, tent_top + 0.01), vec2(fx, tent_top - 0.16)) - 0.006;
	col = mix(col, CREAM, fill(pole, aa));
	vec2 fq = p - vec2(fx, tent_top - 0.15);
	float wave = sin(fq.x * 30.0 - t * 6.0) * 0.012 * fq.x * 8.0;
	float flag = step(0.0, fq.x) * step(fq.x, 0.12) * step(abs(fq.y - 0.03 - wave), 0.035 * (1.0 - fq.x / 0.14));
	col = mix(col, color_b, flag);
	col = mix(col, color_c * 0.35, step(ground, p.y));
	return col;
}

// A firefly field at dusk: rolling hills, a low moon, fireflies drifting
// and blinking.
vec3 firefly_field(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(color_c * 0.5, mix(color_c, color_a, 0.35), uv.y);
	vec2 mq = p - vec2(fx + 0.25, 0.3);
	col = mix(col, CREAM, fill(length(mq) - 0.12, aa));
	col += CREAM * 0.15 * exp(-length(mq) * 6.0);
	float hill1 = 0.72 + sin(p.x * 3.0 + 1.0) * 0.06;
	float hill2 = 0.82 + sin(p.x * 5.0 + 3.0) * 0.04;
	col = mix(col, color_c * 0.3, step(hill1, p.y));
	col = mix(col, color_c * 0.18, step(hill2, p.y));
	for (int k = 0; k < 2; k++) {
		vec2 g = p * (9.0 + float(k) * 5.0) + vec2(float(k) * 3.3, 0.0);
		vec2 id = floor(g);
		vec2 f = fract(g);
		vec2 c = vec2(0.5) + 0.3 * vec2(sin(t * 0.6 + hash(id) * 6.28), cos(t * 0.8 + hash(id + 1.0) * 6.28));
		float on = step(0.5, hash(id + 4.0));
		float blink = smoothstep(0.4, 1.0, sin(t * (1.0 + hash(id + 7.0)) + hash(id + 9.0) * 6.28));
		float d = length(f - c);
		col += color_b * exp(-d * 10.0) * blink * on * 0.8;
		col = mix(col, mix(color_b, CREAM, 0.6), fill(d - 0.05, aa * 9.0) * blink * on);
	}
	return col;
}

// Soda fizz: a deep soda gradient full of rising bubbles, a bottle cap
// turning on the right.
vec3 soda_fizz(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(color_a, color_a * 0.45, uv.y);
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		vec2 g = p * (10.0 + fk * 6.0);
		float colm = floor(g.x);
		g.y += t * (1.5 + hash(vec2(colm, fk)) * 2.0);
		vec2 id = vec2(colm, floor(g.y));
		vec2 f = fract(g) - 0.5;
		f.x += sin(g.y * 2.0 + colm) * 0.12;
		float r = 0.1 + hash(id) * 0.18;
		float on = step(0.55, hash(id + 3.0));
		float ring = abs(length(f) - r) - 0.03;
		col = mix(col, mix(color_b, CREAM, 0.5), fill(ring / (10.0 + fk * 6.0), aa) * on * (0.5 + fk * 0.25));
	}
	vec2 q = rot(p - vec2(fx, 0.5), t * 0.4);
	float a = atan(q.y, q.x);
	float r = length(q);
	float cap = r - (0.3 + 0.02 * smoothstep(0.0, 0.6, sin(a * 21.0)));
	col = mix(col, INK, fill(cap - 0.012, aa));
	col = mix(col, color_c, fill(cap, aa));
	col = mix(col, color_c * 0.75, fill(abs(r - 0.22) - 0.008, aa));
	col = mix(col, color_b, fill(sd_star(q, 0.15, 5.0, 2.6), aa));
	col = mix(col, CREAM, fill(length(q - vec2(-0.1, -0.12)) - 0.03, aa) * 0.6);
	return col;
}

// Card shark: green baize, a hand of five cards fanning open and shut on the
// right, a stack of chips beside it.
vec3 card_shark(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = color_a * (0.8 + 0.2 * noise(p * 60.0));
	col *= 1.0 - 0.4 * length(uv - vec2(0.7, 0.5));
	vec2 pivot = vec2(fx, 1.05);
	float spread = 0.17 + 0.05 * sin(t * 1.2);
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		vec2 q = rot(p - pivot, (fi - 2.0) * spread);
		q += vec2(0.0, 0.55);
		float card = sd_round_box(q, vec2(0.15, 0.22), 0.03);
		col = mix(col, INK * 0.6, fill(card - 0.015, aa) * 0.5);
		col = mix(col, CREAM, fill(card, aa));
		bool red = mod(fi, 2.0) < 0.5;
		vec3 ink = red ? color_b : INK;
		float pip = abs(q.x) * 0.9 + abs(q.y + 0.02) * 0.62 - 0.06;
		if (!red) {
			pip = min(length(q - vec2(-0.03, 0.0)) - 0.035, length(q - vec2(0.03, 0.0)) - 0.035);
			pip = min(pip, length(q - vec2(0.0, -0.045)) - 0.035);
		}
		col = mix(col, ink, fill(pip, aa) * fill(card, aa));
		col = mix(col, ink, fill(length(q - vec2(-0.1, -0.16)) - 0.018, aa) * fill(card, aa));
	}
	vec2 cq = p - vec2(fx - 0.55, 0.78);
	for (int k = 0; k < 4; k++) {
		vec2 s = cq + vec2(0.0, float(k) * 0.06);
		float chip = sd_round_box(s * vec2(1.0, 3.0), vec2(0.12, 0.08), 0.06) / 3.0;
		vec3 cc = mod(float(k), 2.0) < 0.5 ? color_c : color_b;
		col = mix(col, cc, fill(chip, aa));
		col = mix(col, CREAM, fill(chip, aa) * step(0.5, fract(s.x * 18.0)) * 0.5);
	}
	return col;
}

// Carousel: a scalloped canopy with chasing bulbs, horses on poles rising
// and falling as they go round.
vec3 carousel(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(color_c * 0.6, color_c, uv.y);
	float canopy = 0.26 + 0.04 * (1.0 - abs(fract(p.x * 4.0) - 0.5) * 2.0);
	float stripe = step(0.5, fract(p.x * 4.0 + 0.25));
	col = mix(col, mix(color_a, CREAM, stripe), step(p.y, canopy));
	col = mix(col, color_b, step(abs(p.y - canopy + 0.01), 0.018));
	float k = floor(p.x * 16.0);
	vec2 bq = vec2(fract(p.x * 16.0) - 0.5, (p.y - 0.06) * 16.0);
	float chase = step(0.5, fract((k - floor(t * 6.0)) / 3.0));
	col = mix(col, mix(color_b * 0.4, CREAM, chase), fill(length(bq) - 0.22, aa * 16.0));
	col += CREAM * chase * 0.25 * exp(-length(bq) * 1.6) * step(p.y, 0.2);
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float x = fx - 0.9 + fi * 0.6 + mod(t * 0.15, 0.6);
		float bob = sin(t * 2.0 + fi * 1.6) * 0.07;
		float pole = abs(p.x - x) - 0.008;
		col = mix(col, color_b * 1.1, fill(pole, aa) * step(canopy, p.y));
		vec2 hq = p - vec2(x, 0.6 + bob);
		float body = sd_round_box(hq, vec2(0.13, 0.06), 0.05);
		float head = sd_round_box(rot(hq - vec2(0.13, -0.08), 0.6), vec2(0.035, 0.08), 0.03);
		float legs = min(sd_segment(hq, vec2(-0.08, 0.04), vec2(-0.12, 0.15)), sd_segment(hq, vec2(0.08, 0.04), vec2(0.13, 0.14))) - 0.016;
		float horse = min(min(body, head), legs);
		col = mix(col, INK, fill(horse - 0.01, aa));
		col = mix(col, mod(fi, 2.0) < 0.5 ? CREAM : color_a, fill(horse, aa));
		col = mix(col, color_b, fill(sd_box(hq - vec2(0.0, -0.06), vec2(0.04, 0.012)), aa));
	}
	col = mix(col, color_a * 0.4, step(0.92, p.y));
	return col;
}

// Bumper cars: a checker floor, the grid ceiling sparking, two cars bouncing
// off each other.
vec3 bumper_cars(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(color_c * 0.35, color_c * 0.7, uv.y);
	vec2 grid = abs(fract(p * vec2(8.0, 8.0)) - 0.5);
	col = mix(col, color_c * 1.3, step(0.47, max(grid.x, grid.y)) * step(p.y, 0.3) * 0.6);
	vec2 cg = p * 6.0;
	float check = mod(floor(cg.x) + floor(cg.y), 2.0);
	col = mix(col, mix(color_c * 0.55, color_c * 1.1, check), step(0.78, p.y));
	float hit = abs(sin(t * 1.4));
	for (int i = 0; i < 2; i++) {
		float side = float(i) * 2.0 - 1.0;
		float x = fx + side * (0.12 + 0.35 * hit);
		vec2 q = (p - vec2(x, 0.66)) / 1.35;
		q.x *= -side;
		float body = sd_round_box(q, vec2(0.2, 0.08), 0.07);
		float seat = sd_round_box(q - vec2(-0.05, -0.1), vec2(0.06, 0.06), 0.03);
		float bumper = sd_round_box(q - vec2(0.0, 0.07), vec2(0.23, 0.03), 0.03);
		vec3 cc = i == 0 ? color_a : color_b;
		col = mix(col, INK, fill(bumper, aa));
		col = mix(col, cc * 0.75, fill(seat, aa));
		col = mix(col, cc, fill(body, aa));
		col = mix(col, CREAM, fill(sd_round_box(q - vec2(0.08, -0.02), vec2(0.06, 0.015), 0.01), aa) * 0.7);
		float pole = sd_segment(p, vec2(x - side * 0.1, 0.0), vec2(x - side * 0.1, 0.52)) - 0.006;
		col = mix(col, CREAM * 0.8, fill(pole, aa));
		float spark = step(0.6, hash(vec2(floor(t * 12.0), float(i))));
		col += CREAM * spark * exp(-length(p - vec2(x - side * 0.1, 0.02)) * 18.0) * 1.4;
	}
	float flash = smoothstep(0.15, 0.0, hit);
	col = mix(col, CREAM, fill(sd_star(p - vec2(fx, 0.62), 0.07 + 0.08 * flash, 8.0, 3.0), aa) * flash);
	return col;
}

// Plasma globe: a glass ball on the right with lightning tendrils reaching
// from its core to the glass, flickering.
vec3 plasma_globe(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = mix(color_c * 0.25, color_c * 0.5, uv.y);
	vec2 c = vec2(fx, 0.45);
	vec2 q = p - c;
	float r = length(q);
	float R = 0.36;
	float inside = fill(r - R, aa);
	col = mix(col, color_c * 0.15, inside);
	float glow = 0.0;
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float a = fi * 1.047 + sin(t * 0.7 + fi * 3.1) * 0.6;
		float bend = sin(r * 18.0 - t * 5.0 + fi * 2.0) * 0.04 * r / R;
		vec2 dir = vec2(cos(a), sin(a));
		float across = abs(dot(q, vec2(-dir.y, dir.x)) + bend);
		float along = dot(q, dir);
		float flick = 0.7 + 0.3 * sin(t * 31.0 + fi * 7.0);
		glow = max(glow, smoothstep(0.016, 0.0, across) * step(0.0, along) * step(along, R) * flick);
		col += color_a * exp(-length(q - dir * R) * 30.0) * flick * 0.6 * inside;
	}
	col = mix(col, mix(color_a, CREAM, 0.5), glow * inside);
	col += color_a * glow * 0.4 * inside;
	col = mix(col, CREAM, fill(r - 0.05, aa));
	col += color_a * exp(-r * 9.0) * 0.6;
	col = mix(col, CREAM, fill(abs(r - R) - 0.006, aa) * 0.5);
	col = mix(col, CREAM, fill(length(q - vec2(-0.15, -0.18)) - 0.04, aa) * 0.4);
	vec2 bq = p - vec2(fx, 0.88);
	col = mix(col, color_b, fill(sd_round_box(bq, vec2(0.22, 0.09), 0.04), aa));
	col = mix(col, color_b * 0.6, fill(sd_box(bq - vec2(0.0, -0.06), vec2(0.18, 0.012)), aa));
	return col;
}

// Lantern festival: paper lanterns rising slowly into a night sky, glowing
// warm, swaying as they go.
vec3 lantern_festival(vec2 uv, vec2 p, float t, float ar, float fx, float aa) {
	vec3 col = night_sky(uv, p, t, color_c * 0.4, mix(color_c, color_a * 0.4, 0.4));
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		float sc = 1.0 - fk * 0.28;
		vec2 g = p / sc * 3.0 + vec2(fk * 1.7, 0.0);
		g.y += t * (0.12 + fk * 0.04) / sc;
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		f.x += sin(t * 0.8 + id.y + hash(id) * 6.0) * 0.08;
		float on = step(0.35, hash(id + fk * 5.0));
		float body = sd_round_box(f * vec2(1.0, 0.85), vec2(0.13, 0.17), 0.09);
		vec3 warm = mix(color_a, color_b, hash(id + 2.0));
		col += warm * exp(-max(body, 0.0) * 18.0) * 0.25 * on * sc;
		col = mix(col, mix(warm, CREAM, 0.35 * (1.0 - abs(f.x) * 5.0)), fill(body * sc / 3.0, aa) * on);
		col = mix(col, warm * 0.5, fill(sd_box(f - vec2(0.0, 0.16), vec2(0.07, 0.02)) * sc / 3.0, aa) * on);
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
	if (style == 0) { col = big_top(uv, p, t, ar, fx, aa); }
	else if (style == 1) { col = firefly_field(uv, p, t, ar, fx, aa); }
	else if (style == 2) { col = soda_fizz(uv, p, t, ar, fx, aa); }
	else if (style == 3) { col = card_shark(uv, p, t, ar, fx, aa); }
	else if (style == 4) { col = carousel(uv, p, t, ar, fx, aa); }
	else if (style == 5) { col = bumper_cars(uv, p, t, ar, fx, aa); }
	else if (style == 6) { col = plasma_globe(uv, p, t, ar, fx, aa); }
	else { col = lantern_festival(uv, p, t, ar, fx, aa); }
	// Rounded corners.
	vec2 half_size = rect_size * 0.5;
	vec2 q = abs(uv * rect_size - half_size) - (half_size - vec2(radius));
	float sd = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	COLOR = vec4(col, clamp(0.5 - sd, 0.0, 1.0));
}
