shader_type spatial;
// Update 24 finishes (the "gear" set), picked by `pattern`. Colours:
// shell_color (ground), color_b, color_c, color_d; the trim wears the same
// material on trim_color. Patterns 0-4 are animated: with params.pulse the
// FinishPulse node holds them still under "Reduce motion" (`motion` 0) and a
// kill with the weapon flares them (`pulse` 1 easing to 0).
//   0 fizzy soda       shell soda, color_b deep soda, color_c bubbles, color_d foam
//   1 firefly meadow   shell dusk, color_b grass, color_c firefly glow, color_d moon haze
//   2 plasma globe     shell glass dark, color_b tendril, color_c core, color_d brass base ring
//   3 hypno spin       shell ring one, color_b ring two, color_c centre glow
//   4 cotton candy     shell pink floss, color_b blue floss, color_c sugar sparkle
//   5 prize plush      shell fur, color_b fur shade and trim label, color_c stitches
//   6 card shark       shell felt, color_b card white, color_c red suit, color_d black suit
//   7 bumper car       shell candy paint, color_b deep paint, color_c bumper stripe, color_d flake
//   8 popcorn stripe   shell red, color_b cream stripe, color_c butter kernels
//   9 shooting gallery shell wood, color_b dark grain, color_c brass, color_d target red
//  10 carnival glass   shell marigold base, color_b iridescent sheen, color_c pressed rib
//  11 strongman        shell leopard ground, color_b spot rim, color_c spot centre
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.55, 0.32, 0.15);
uniform vec3 trim_color : source_color = vec3(0.3, 0.17, 0.08);
uniform bool is_trim = false;
uniform int pattern = 0;
uniform vec3 color_b : source_color = vec3(0.3, 0.16, 0.07);
uniform vec3 color_c : source_color = vec3(0.9, 0.7, 0.3);
uniform vec3 color_d : source_color = vec3(0.8, 0.8, 0.8);
uniform float scale = 1.0;
// FinishPulse: 0 holds the animation still ("Reduce motion"), and a kill sets
// `pulse` to 1 and eases it back to 0.
uniform float motion = 1.0;
uniform float pulse = 0.0;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

float g_fill(float d, float soft) {
	return smoothstep(soft, -soft, d);
}

vec2 g_rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// Signed distance to a heart about 1 unit tall, its tip at the origin.
float g_heart(vec2 p) {
	p.x = abs(p.x);
	if (p.y + p.x > 1.0) {
		return length(p - vec2(0.25, 0.75)) - 0.35355;
	}
	vec2 a = p - vec2(0.0, 1.0);
	vec2 b = p - 0.5 * max(p.x + p.y, 0.0);
	return sqrt(min(dot(a, a), dot(b, b))) * sign(p.x - p.y);
}

// The four card suits, each about 1 unit across round the origin (y up).
float g_suit(vec2 p, int suit) {
	if (suit == 0) {
		return g_heart(vec2(p.x, p.y + 0.5) * 1.1) / 1.1;
	} else if (suit == 1) {
		return abs(p.x) * 0.9 + abs(p.y) * 0.62 - 0.42;
	} else if (suit == 2) {
		float d = g_heart(vec2(p.x, -p.y + 0.45) * 1.1) / 1.1;
		float stem = max(abs(p.x) - 0.06 - (-0.1 - p.y) * 0.3, max(p.y + 0.5, -p.y - 0.1));
		return min(d, stem);
	}
	float d = length(p - vec2(0.0, 0.2)) - 0.22;
	d = min(d, length(p - vec2(-0.22, -0.12)) - 0.22);
	d = min(d, length(p - vec2(0.22, -0.12)) - 0.22);
	float stem = max(abs(p.x) - 0.05 - (-0.1 - p.y) * 0.35, max(p.y + 0.5, -p.y - 0.1));
	return min(d, stem);
}

// Voronoi on a jittered grid: x nearest distance, y second, zw nearest id.
vec4 g_voro(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 9.0;
	float d2 = 9.0;
	vec2 best = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 c = o + fh22(i + o) * 0.8 + 0.1;
			float d = length(c - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				best = i + o;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec4(d1, d2, best);
}

// --- animated ----------------------------------------------------------------

// Fizzy soda: a deep-to-bright soda gradient, bubbles streaming up the sides
// (each column its own speed and wobble), a foam head on the top faces.
vec3 soda(vec3 ground, vec3 p, vec3 n, float t, inout float h, inout float rough, inout float metal, inout vec3 emit) {
	float up = clamp(n.y, 0.0, 1.0);
	vec2 q = vec2(p.z + p.x * 0.7, p.y) * 34.0;
	vec3 col = mix(color_b, ground, smoothstep(-0.12, 0.1, p.y));
	col = mix(col, ground * 1.25, 0.35 * (0.5 + 0.5 * sin(p.z * 14.0 + t * 0.6)));
	float b = 0.0;
	float rim = 0.0;
	for (int k = 0; k < 2; k++) {
		float fk = float(k);
		vec2 g = q * (1.0 + fk * 0.65) + vec2(fk * 3.7, 0.0);
		float col_id = floor(g.x);
		float speed = 1.4 + fh21(vec2(col_id, fk)) * 1.6 + pulse * 3.0;
		g.y -= t * speed * 2.2;
		vec2 cell = vec2(col_id, floor(g.y));
		vec2 f = fract(g) - 0.5;
		f.x += sin(g.y * 2.4 + col_id) * 0.14;
		float r = 0.12 + fh21(cell + 4.1) * 0.16;
		float on = step(0.45 - pulse * 0.3, fh21(cell + 9.3));
		float d = length(f) - r;
		b = max(b, g_fill(d, 0.05) * on);
		rim = max(rim, g_fill(abs(d) - 0.03, 0.04) * on);
	}
	col = mix(col, color_c * 0.7, b * 0.35);
	col = mix(col, mix(color_c, vec3(1.0), 0.4), rim * 0.8);
	vec2 spec = fract(q * 1.0) - vec2(0.62, 0.62);
	col += vec3(1.0) * b * g_fill(length(spec) - 0.05, 0.04) * 0.5;
	float foam = smoothstep(0.55, 0.85, up + fnoise2(p.xz * 60.0 + t * 0.3) * 0.25);
	float froth = fnoise2(p.xz * 140.0 - t * 0.5);
	col = mix(col, color_d * (0.85 + froth * 0.2), foam);
	h = foam * froth + b * 0.4;
	rough = mix(0.08, 0.6, foam);
	emit = col * (0.12 + pulse * 0.4) * (1.0 - foam) + color_c * rim * 0.15;
	return col;
}

// Firefly meadow: dusk sky over grass blades swaying along the lower sides,
// fireflies drifting and blinking with soft halos.
vec3 fireflies(vec3 ground, vec3 p, vec3 n, float t, inout float h, inout float rough, inout float metal, inout vec3 emit) {
	vec2 uv = fplane(p, n);
	vec3 col = mix(ground, color_d, smoothstep(0.02, 0.12, uv.y) * 0.45);
	float blade = 0.0;
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		float x = uv.x * (70.0 + fk * 30.0) + fk * 2.3;
		float id = floor(x);
		float sway = sin(t * 1.3 + id * 0.7) * 0.25;
		float top = -0.02 + fh21(vec2(id, fk)) * 0.05 + fk * 0.012;
		float lean = (uv.y + 0.08) * sway * 30.0;
		float w = 0.32 * clamp((top - uv.y) * 40.0, 0.0, 1.0);
		blade = max(blade, step(abs(fract(x + lean) - 0.5), w) * step(uv.y, top));
	}
	col = mix(col, color_b * (0.55 + 0.45 * smoothstep(-0.1, 0.03, uv.y)), blade);
	float glow = 0.0;
	float core = 0.0;
	vec2 g = uv * 22.0;
	for (int k = 0; k < 2; k++) {
		vec2 gg = g + vec2(float(k) * 5.3, float(k) * 2.1);
		vec2 id = floor(gg);
		vec2 f = fract(gg);
		vec2 c = vec2(0.5) + 0.32 * vec2(sin(t * 0.7 + fh21(id) * 6.28), cos(t * 0.9 + fh21(id + 2.0) * 6.28));
		float blink = smoothstep(0.55, 1.0, sin(t * (1.2 + fh21(id + 5.0)) + fh21(id + 8.0) * 6.28));
		blink = max(blink, pulse);
		float on = step(0.42, fh21(id + 3.0));
		float d = length(f - c);
		core = max(core, g_fill(d - 0.06, 0.03) * blink * on);
		glow = max(glow, exp(-d * 9.0) * blink * on);
	}
	col = mix(col, color_c, glow * 0.55);
	col = mix(col, mix(color_c, vec3(1.0), 0.6), core);
	h = blade * 0.5;
	rough = 0.6;
	emit = color_c * (glow * 0.9 + core * 2.0) + color_d * 0.04;
	return col;
}

// Plasma globe: dark glass with electric tendrils wandering from the core
// outwards, branching and flickering; the trim is the brass base.
vec3 plasma(vec3 ground, vec3 p, vec3 n, vec3 r, float t, inout float h, inout float rough, inout float metal, inout vec3 emit) {
	if (is_trim) {
		vec2 uv = fplane(p, n);
		float ring = 0.5 + 0.5 * sin(uv.x * 160.0);
		vec3 brass = color_d * (0.7 + 0.3 * ring);
		h = ring * 0.4;
		rough = 0.25;
		metal = 0.9;
		emit = color_b * 0.05;
		return mix(brass, fstudio(r, color_d), 0.5);
	}
	vec3 q = p * 9.0;
	float lines = 0.0;
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		float w = fnoise3(q * 1.3 + vec3(0.0, 0.0, t * 0.8 + fk * 7.0)) * 2.0 - 1.0;
		float a = atan(q.y + w * 0.6, q.x + 0.001) * 3.0 + fnoise3(q * 0.8 + fk * 4.0 + t * 0.4) * 6.0 + fk * 2.1;
		float arc = abs(sin(a + q.z * 1.6 + t * (0.6 + fk * 0.3)));
		float flick = 0.75 + 0.25 * sin(t * 37.0 + fk * 11.0);
		lines = max(lines, smoothstep(0.08, 0.0, arc) * flick);
	}
	float spark = smoothstep(0.93, 1.0, fnoise3(q * 3.0 + t * 2.0));
	vec3 col = ground + fstudio(r, ground) * 0.12;
	col = mix(col, color_b, lines * 0.85);
	col += color_c * spark * 0.8;
	h = lines * 0.2;
	rough = 0.06;
	metal = 0.1;
	emit = color_b * lines * (1.6 + pulse * 2.0) + color_c * (spark * 1.4 + pulse * 0.4);
	return col;
}

// Hypno spin: op-art concentric rings round centres along the barrel, turning
// in alternate directions, a glowing eye at each centre.
vec3 hypno(vec3 ground, vec3 p, vec3 n, float t, inout float h, inout float rough, inout float metal, inout vec3 emit) {
	vec2 uv = fplane(p, n) * 12.0;
	vec2 id = vec2(floor(uv.x / 1.6 + 0.5), 0.0);
	vec2 c = vec2(id.x * 1.6, 0.0);
	vec2 q = uv - c;
	float dir = mod(id.x, 2.0) < 0.5 ? 1.0 : -1.0;
	float rr = length(q);
	float a = atan(q.y, q.x);
	float spiral = fract(rr * 2.2 - a / 6.28318 * 2.0 * dir + t * 0.7 * dir);
	float band = smoothstep(0.45, 0.5, spiral) * smoothstep(1.0, 0.95, spiral);
	vec3 col = mix(ground, color_b, band);
	float eye = g_fill(rr - 0.16 - pulse * 0.1, 0.03);
	col = mix(col, color_c, eye);
	h = band * 0.2;
	rough = 0.3;
	emit = color_c * (eye * 1.6 + pulse * 0.25) + col * 0.05;
	return col;
}

// Cotton candy: pastel floss in two colours folding through each other and
// drifting slowly, with sparkles of sugar.
vec3 cotton(vec3 ground, vec3 p, vec3 n, float t, inout float h, inout float rough, inout float metal, inout vec3 emit) {
	vec3 q = p * 11.0;
	vec3 warp = vec3(ffbm3(q + vec3(0.0, 0.0, t * 0.15)), ffbm3(q + vec3(5.2, 1.3, -t * 0.12)), 0.0);
	float floss = ffbm3(q * 1.4 + warp * 2.2 + vec3(t * 0.08, 0.0, 0.0));
	float mixk = smoothstep(0.38, 0.62, floss);
	vec3 col = mix(ground, color_b, mixk);
	float fibre = fnoise3(q * 9.0 + warp * 4.0);
	col = mix(col, vec3(1.0), smoothstep(0.7, 0.95, fibre) * 0.3);
	vec3 cell = floor(p * 240.0);
	float sparkle = step(0.985, fh31(cell)) * (0.5 + 0.5 * sin(t * 6.0 + fh31(cell + 3.0) * 30.0));
	col = mix(col, color_c, sparkle);
	h = floss + fibre * 0.3;
	rough = 0.75;
	emit = color_c * (sparkle * 0.9 + pulse * 0.2) + col * 0.04;
	return col;
}

// --- static ------------------------------------------------------------------

// Prize plush: the fuzzy fur of a claw-machine plushie, panels joined by
// seams with running stitches, a satin label on the trim.
vec3 plush(vec3 ground, vec2 uv, inout float h, inout float rough, inout float metal, inout vec3 emit) {
	float fur = fnoise2(uv * 900.0) * 0.6 + fnoise2(uv * 2400.0) * 0.4;
	float clump = fnoise2(uv * 120.0);
	vec3 col = ground * (0.8 + 0.25 * fur + 0.1 * clump);
	col = mix(col, color_b, smoothstep(0.55, 0.8, fnoise2(uv * 18.0)) * 0.35);
	float seam_x = abs(fract(uv.x * 6.0 + fnoise2(uv * 9.0) * 0.08) - 0.5);
	float seam = smoothstep(0.03, 0.0, seam_x - 0.47);
	float stitch = step(0.5, fract(uv.y * 80.0)) * smoothstep(0.012, 0.0, abs(seam_x - 0.455));
	col = mix(col, ground * 0.45, seam);
	col = mix(col, color_c, stitch);
	if (is_trim) {
		float rib = 0.5 + 0.5 * sin(uv.y * 600.0);
		col = mix(color_b, color_b * 1.2, rib * 0.3);
		col = mix(col, color_c, step(0.5, fract(uv.x * 30.0)) * step(abs(fract(uv.y * 8.0) - 0.5), 0.05));
		rough = 0.35;
		h = rib * 0.3;
		return col;
	}
	h = fur * 0.6 - seam * 0.5;
	rough = 0.95;
	return col;
}

// Card shark: green baize scattered with tumbling playing cards, each showing
// a suit in red or black, with a thin gold edge.
vec3 cards(vec3 ground, vec2 uv, inout float h, inout float rough, inout float metal, inout vec3 emit) {
	float baize = fnoise2(uv * 700.0);
	vec3 col = ground * (0.9 + 0.1 * baize);
	vec2 g = uv * 14.0;
	for (int k = 0; k < 2; k++) {
		vec2 gg = g + vec2(float(k) * 0.5, float(k) * 0.37);
		vec2 id = floor(gg);
		if (fh21(id + float(k) * 7.0) < 0.38) {
			continue;
		}
		vec2 f = fract(gg) - 0.5;
		f = g_rot(f, (fh21(id + 2.0) - 0.5) * 1.6);
		vec2 dd = abs(f) - vec2(0.2, 0.28);
		float card = length(max(dd + 0.05, 0.0)) + min(max(dd.x, dd.y), 0.0) - 0.05;
		float inside = g_fill(card, 0.012);
		float edge = g_fill(abs(card + 0.02) - 0.006, 0.006);
		int suit = int(floor(fh21(id + 5.0) * 4.0));
		float sd = g_suit(f / 0.2, suit) * 0.2;
		float mark = g_fill(sd, 0.01);
		vec3 ink = (suit == 0 || suit == 1) ? color_c : color_d;
		vec3 c = mix(color_b, ink, mark);
		c = mix(c, color_c * 0.8 + vec3(0.2, 0.15, 0.0), edge * 0.6);
		col = mix(col * (1.0 - g_fill(card - 0.03, 0.04) * 0.35), c, inside);
		h = max(h, inside * 0.5 + mark * 0.2);
	}
	rough = 0.65;
	return col;
}

// Bumper car: deep candy paint full of metal flake that glints as the weapon
// turns, a chunky black rubber bumper on the trim with yellow hazard chevrons.
vec3 bumper(vec3 ground, vec2 uv, vec3 p, vec3 n, vec3 view, vec3 r, inout float h, inout float rough, inout float metal, inout vec3 emit) {
	if (is_trim) {
		float chev = step(0.5, fract(uv.x * 22.0 + abs(fract(uv.y * 10.0) - 0.5)));
		float band = step(abs(fract(uv.y * 5.0) - 0.5), 0.12);
		vec3 rubber = vec3(0.06, 0.055, 0.07) * (0.8 + 0.4 * fnoise2(uv * 700.0));
		h = band;
		rough = mix(0.85, 0.45, band);
		return mix(rubber, mix(color_c, vec3(0.06), chev), band);
	}
	vec3 cell = floor(p * 900.0);
	vec3 fn = normalize(fh33(cell) * 2.0 - 1.0 + n * 1.6);
	float glint = pow(max(dot(reflect(-view, fn), vec3(0.0, 0.0, 1.0)), 0.0), 24.0) * step(0.4, fh31(cell + 2.0));
	vec3 col = mix(ground, color_b, 0.5 + 0.5 * dot(n, view));
	col += fstudio(r, ground) * 0.35;
	col += mix(color_d, vec3(1.0), 0.5) * glint * 0.9;
	h = 0.0;
	rough = 0.12;
	metal = 0.35;
	emit = color_d * glint * 0.25;
	return col;
}

// Popcorn stripe: the red-and-cream stripes of a popcorn box, buttery kernels
// spilling over the trim.
vec3 popcorn(vec3 ground, vec2 uv, inout float h, inout float rough, inout float metal, inout vec3 emit) {
	float s = fract(uv.x * 14.0);
	float stripe = smoothstep(0.47, 0.5, s) * smoothstep(1.0, 0.97, s);
	vec3 col = mix(ground, color_b, stripe);
	float card = fnoise2(uv * 500.0);
	col *= 0.93 + 0.07 * card;
	if (is_trim) {
		vec4 v = g_voro(uv * 55.0);
		float puff = smoothstep(0.55, 0.15, v.x);
		float hull = fh21(v.zw);
		col = mix(color_b * 0.9, mix(color_b, color_c, hull * 0.7), puff);
		col *= 0.75 + 0.25 * puff;
		h = puff;
		rough = 0.55;
		return col;
	}
	h = card * 0.2;
	rough = 0.5;
	return col;
}

// Shooting gallery: varnished wood with grain, brass rivets in rows and
// little bullseye targets stencilled along the sides.
vec3 gallery(vec3 ground, vec2 uv, vec3 r, inout float h, inout float rough, inout float metal, inout vec3 emit) {
	float grain = fnoise2(vec2(uv.x * 30.0, uv.y * 400.0) + fnoise2(uv * 40.0) * 3.0);
	float rings = 0.5 + 0.5 * sin(grain * 18.0);
	vec3 col = mix(ground, color_b, rings * 0.55);
	float plank = smoothstep(0.012, 0.0, abs(fract(uv.y * 16.0) - 0.5) - 0.48);
	col = mix(col, color_b * 0.5, plank);
	vec2 rv = vec2(fract(uv.x * 30.0) - 0.5, fract(uv.y * 16.0 + 0.5) - 0.5);
	float rivet = g_fill(length(rv * vec2(1.0, 1.9)) - 0.12, 0.03);
	vec3 brass = mix(color_c, fstudio(r, color_c), 0.55);
	col = mix(col, brass, rivet);
	vec2 tg = uv * vec2(7.0, 7.0);
	vec2 tid = floor(tg);
	vec2 tf = fract(tg) - 0.5;
	float on = step(0.6, fh21(tid + 0.7)) * (is_trim ? 0.0 : 1.0);
	float tr = length(tf);
	float target = g_fill(tr - 0.28, 0.01) * on;
	float band = step(0.5, fract(tr * 10.0));
	col = mix(col, mix(vec3(0.96, 0.93, 0.85), color_d, band), target);
	col = mix(col, color_d, g_fill(tr - 0.05, 0.01) * on);
	h = rings * 0.3 + rivet + target * 0.3;
	metal = rivet * 0.9;
	rough = mix(mix(0.35, 0.5, rings), 0.25, rivet);
	return col;
}

// Carnival glass: pressed marigold glass with a petrol-rainbow sheen that
// shifts as the weapon turns, ribbed and dimpled.
vec3 carnival(vec3 ground, vec2 uv, vec3 n, vec3 view, vec3 r, inout float h, inout float rough, inout float metal, inout vec3 emit) {
	float rib = 0.5 + 0.5 * cos(uv.x * 140.0);
	vec2 dg = fract(uv * vec2(40.0, 40.0)) - 0.5;
	float dimple = smoothstep(0.36, 0.0, length(dg));
	float pressed = is_trim ? dimple : rib;
	float facing = dot(n, view);
	vec3 sheen = fhue(facing * 1.4 + pressed * 0.25 + uv.x * 3.0);
	sheen = mix(sheen, color_b, 0.35);
	vec3 col = mix(ground, ground * 0.6, pressed * 0.4);
	col = mix(col, sheen, 0.45 * (1.0 - facing * 0.5));
	col = mix(col, color_c, smoothstep(0.85, 1.0, pressed) * 0.3);
	col += fstudio(r, ground) * 0.25;
	h = pressed;
	rough = 0.08;
	metal = 0.45;
	emit = sheen * 0.04;
	return col;
}

// Strongman: a bold leopard print, spots with dark rims and warm centres.
vec3 leopard(vec3 ground, vec2 uv, inout float h, inout float rough, inout float metal, inout vec3 emit) {
	vec4 v = g_voro(uv * 34.0 + vec2(fnoise2(uv * 60.0) * 0.4));
	float wob = fnoise2(uv * 200.0) * 0.08;
	float spot = smoothstep(0.34 + wob, 0.3 + wob, v.x);
	float rim = spot * smoothstep(0.12, 0.2, v.x);
	float open = step(0.5, fh21(v.zw));
	vec3 col = mix(ground, color_c, spot * (1.0 - open * 0.3));
	col = mix(col, color_b, rim);
	float fur = fnoise2(uv * vec2(900.0, 300.0));
	col *= 0.9 + 0.1 * fur;
	h = fur * 0.4 + spot * 0.1;
	rough = 0.8;
	return col;
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	vec2 uv = fplane(lp, ln) * scale;
	vec3 ground = is_trim ? trim_color : shell_color;
	float t = TIME * motion;
	float h = 0.0;
	float rough = 0.5;
	float metal = 0.0;
	vec3 emit = vec3(0.0);
	vec3 col;
	if (pattern == 0) {
		col = soda(ground, lp * scale, ln, t, h, rough, metal, emit);
	} else if (pattern == 1) {
		col = fireflies(ground, lp * scale, ln, t, h, rough, metal, emit);
	} else if (pattern == 2) {
		col = plasma(ground, lp * scale, ln, r, t, h, rough, metal, emit);
	} else if (pattern == 3) {
		col = hypno(ground, lp * scale, ln, t, h, rough, metal, emit);
	} else if (pattern == 4) {
		col = cotton(ground, lp * scale, ln, t, h, rough, metal, emit);
	} else if (pattern == 5) {
		col = plush(ground, uv, h, rough, metal, emit);
	} else if (pattern == 6) {
		col = cards(ground, uv, h, rough, metal, emit);
	} else if (pattern == 7) {
		col = bumper(ground, uv, lp, NORMAL, VIEW, r, h, rough, metal, emit);
	} else if (pattern == 8) {
		col = popcorn(ground, uv, h, rough, metal, emit);
	} else if (pattern == 9) {
		col = gallery(ground, uv, r, h, rough, metal, emit);
	} else if (pattern == 10) {
		col = carnival(ground, uv, NORMAL, VIEW, r, h, rough, metal, emit);
	} else {
		col = leopard(ground, uv, h, rough, metal, emit);
	}
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = rough;
	NORMAL = fbump(VERTEX, NORMAL, h, 0.004);
	EMISSION = emit + vec3(1.0) * pow(fres, 4.0) * 0.06 * (1.0 - rough);
	PRINT_LAYER
}
