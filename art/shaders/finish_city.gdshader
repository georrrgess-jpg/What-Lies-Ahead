shader_type spatial;
// The Ashfall City camos (Endless rewards, data/cosmetics/finishes/fin_city_*):
// one shader, `pattern` picks the design. Shell and Trim get the same design
// in their own colours (trim darker, or the design's second element).
//   0 Ash Camo       ash and charcoal blotches, embers that breathe
//   1 Rust Belt      flaking teal paint over rust, drip streaks, rivet rows
//   2 Hazard Stripe  scrolling yellow/black stripes, chipped, a beacon sweep
//   3 Neon Graffiti  spray-paint blobs with drips and outlines, flickering neon tube
//   4 Burnt Chrome   heat-tempered chrome (gold to blue), soot and a glowing muzzle
//   5 Blackout Grid  matte black tiles, green emergency strips with a running pulse
//   6 Police Lights  navy gloss, a strobing red/blue light bar, checked trim
//   7 Concrete       aggregate and cracks, form-tie holes bleeding rust, safety paint
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.5);
uniform vec3 trim_color : source_color = vec3(0.2);
uniform bool is_trim = false;
uniform int pattern = 0;
uniform vec3 color_b : source_color = vec3(1.0, 0.45, 0.1);
uniform vec3 color_c : source_color = vec3(1.0);
uniform vec3 color_d : source_color = vec3(0.6, 1.0, 0.2);

const vec3 POLICE_BLUE = vec3(0.15, 0.4, 1.0);

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

// Anti-aliased step of `x` across `edge` (width from screen derivatives).
float aa_step(float edge, float x) {
	float w = max(fwidth(x), 0.0001);
	return smoothstep(edge - w, edge + w, x);
}

// Distance to the nearest line of a 1D grid of `period` (0 on a line).
float grid_dist(float x, float period) {
	return abs(fract(x / period + 0.5) - 0.5) * period;
}

void ash_camo(vec3 base, vec3 p, float t, inout vec3 alb, inout float rough, inout float metal, inout vec3 emi) {
	float n1 = ffbm3(p * 13.0);
	float n2 = ffbm3(p * 21.0 + 5.3);
	alb = base;
	alb = mix(alb, base * 0.42, aa_step(0.52, n1));
	alb = mix(alb, mix(base, color_c, 0.6), aa_step(0.58, n2) * (1.0 - aa_step(0.52, n1)));
	alb *= 0.88 + 0.24 * fnoise3(p * 260.0);
	// Embers: sparse glowing specks, each breathing at its own pace.
	vec3 g = p * 60.0;
	vec3 h = fh33(floor(g));
	float d = length(fract(g) - 0.5 - (h - 0.5) * 0.5);
	float ember = smoothstep(0.22, 0.05, d) * step(0.86, h.x);
	float breathe = 0.5 + 0.5 * sin(t * (1.2 + h.y * 2.4) + h.z * 6.28);
	alb = mix(alb, color_b * 0.6, ember);
	emi += color_b * ember * (0.5 + 2.6 * breathe);
	rough = 0.82;
	metal = 0.0;
}

void rust_belt(vec3 base, vec3 p, inout vec3 alb, inout float rough, inout float metal, inout vec3 emi) {
	float patina = ffbm3(p * 8.0);
	// Rust runs down in streaks under the flaking.
	float streak = fnoise2(vec2((p.z + p.x) * 55.0, p.y * 3.0));
	float rust = patina + streak * 0.3 - 0.15;
	float mask = aa_step(0.5, rust);
	float edge = smoothstep(0.035, 0.0, abs(rust - 0.5));
	vec3 rusty = mix(color_b, color_b * 0.45, ffbm3(p * 40.0));
	alb = mix(base * (0.9 + 0.1 * fnoise3(p * 120.0)), rusty, mask);
	alb = mix(alb, mix(base, vec3(0.9), 0.5), edge * (1.0 - mask) * 0.7);
	rough = mix(0.45, 0.92, mask);
	metal = mix(0.25, 0.05, mask);
	// Rivet rows along the weapon.
	vec2 uv = fplane(p, ln);
	vec2 cell = vec2(grid_dist(uv.x, 0.028), grid_dist(uv.y - 0.012, 0.05));
	float rivet = smoothstep(0.0048, 0.0036, length(cell));
	alb = mix(alb, color_c * 0.8, rivet);
	metal = mix(metal, 0.8, rivet);
	rough = mix(rough, 0.3, rivet);
}

void hazard(vec3 base, vec3 p, float t, inout vec3 alb, inout float rough, inout float metal, inout vec3 emi) {
	vec2 uv = fplane(p, ln);
	float s = fract((uv.x * 0.8 + uv.y) / 0.05 + t * 0.3);
	float black = aa_step(0.5, s) * (1.0 - aa_step(0.98, s));
	float seam = 1.0 - smoothstep(0.0, 0.06, min(abs(s - 0.5), min(s, 1.0 - s)));
	alb = mix(base, color_c, black);
	// Chipped to bare steel along the edges of the paint.
	float chip = aa_step(0.66, ffbm3(p * 34.0));
	alb = mix(alb, vec3(0.62, 0.62, 0.66), chip);
	metal = chip * 0.85;
	rough = mix(0.42, 0.3, chip);
	// A rotating beacon's amber sweep along the weapon, the seams glowing in it.
	float beacon = exp(-pow(fract(p.z * 0.9 - t * 0.45) * 4.0 - 2.0, 2.0) * 5.0);
	emi += color_b * (beacon * (0.25 + seam * 1.6) + seam * 0.25) * (1.0 - chip);
}

void graffiti(vec3 base, vec3 p, float t, inout vec3 alb, inout float rough, inout float metal, inout vec3 emi) {
	alb = base * (0.85 + 0.25 * fnoise3(p * 180.0));
	rough = 0.75;
	metal = 0.0;
	vec3 inks[3] = vec3[3](color_b, color_c, color_d);
	for (int i = 0; i < 3; i++) {
		vec3 q = p * 9.0 + vec3(float(i) * 7.1, float(i) * 3.3, float(i) * 5.7);
		// Drips: the blob's field stretched downwards.
		float blob = ffbm3(q);
		float drip = ffbm3(vec3(q.x, q.y * 0.18 + 0.5, q.z)) * smoothstep(0.62, 0.4, fnoise2(vec2(q.x + q.z, 0.0) * 6.0));
		float field = max(blob, drip - 0.04);
		float paint = aa_step(0.6, field);
		float outline = aa_step(0.57, field) - paint;
		alb = mix(alb, vec3(0.05), outline);
		alb = mix(alb, inks[i], paint);
		rough = mix(rough, 0.45, paint);
	}
	// A neon tube tracing a tag across the weapon, flickering now and then.
	float tag = ffbm3(p * vec3(4.0, 7.0, 4.0) + 11.0);
	float line = smoothstep(0.012, 0.004, abs(tag - 0.55));
	float flick = step(0.12, fract(sin(floor(t * 9.0) * 12.9898) * 43758.5453));
	vec3 tube = mix(color_b, color_c, step(0.0, p.z));
	alb = mix(alb, tube, line);
	emi += tube * (line * (0.6 + 2.4 * flick) + smoothstep(0.05, 0.0, abs(tag - 0.55)) * 0.15 * flick);
}

vec3 temper(float x) {
	vec3 straw = vec3(0.86, 0.74, 0.5);
	vec3 bronze = vec3(0.72, 0.42, 0.18);
	vec3 purple = vec3(0.42, 0.16, 0.52);
	vec3 blue = vec3(0.14, 0.32, 0.82);
	vec3 pale = vec3(0.56, 0.76, 0.95);
	x = fract(x) * 4.0;
	if (x < 1.0) return mix(straw, bronze, x);
	if (x < 2.0) return mix(bronze, purple, x - 1.0);
	if (x < 3.0) return mix(purple, blue, x - 2.0);
	return mix(blue, mix(pale, straw, smoothstep(3.6, 4.0, x)), x - 3.0);
}

void burnt_chrome(vec3 base, vec3 p, float t, vec3 n, vec3 view, inout vec3 alb, inout float rough, inout float metal, inout vec3 emi) {
	float x = p.z * 1.6 + ffbm3(p * 5.0) * 0.7 + dot(n, view) * 0.35 + t * 0.02;
	vec3 tint = temper(x);
	// Soot builds up towards the muzzle (-Z).
	float soot = smoothstep(-0.15, -0.45, p.z) * smoothstep(0.45, 0.75, ffbm3(p * 18.0));
	vec3 r = reflect(-view, n);
	alb = mix(tint, base * 0.25, soot);
	metal = mix(1.0, 0.3, soot);
	rough = mix(0.14, 0.7, soot);
	emi += (fstudio(r, tint) * 0.5 + tint * 0.12) * (1.0 - soot);
	// Heat cracks glowing near the muzzle, breathing.
	float crack = smoothstep(0.02, 0.0, abs(ffbm3(p * 22.0) - 0.5)) * smoothstep(-0.05, -0.4, p.z);
	emi += color_b * crack * (0.8 + 0.6 * sin(t * 2.2 + p.z * 9.0));
}

void blackout(vec3 base, vec3 p, float t, inout vec3 alb, inout float rough, inout float metal, inout vec3 emi) {
	vec2 uv = fplane(p, ln);
	float tile = 0.026;
	vec2 id = floor(uv / tile);
	float gx = grid_dist(uv.x, tile);
	float gy = grid_dist(uv.y, tile);
	float grout = 1.0 - aa_step(0.0012, min(gx, gy));
	float h = fh21(id);
	alb = mix(base * (0.8 + 0.4 * h), base * 0.4, grout);
	rough = mix(0.88, 0.6, grout);
	metal = 0.05;
	// Every fourth line is an emergency strip, a pulse running along it.
	float strip = (1.0 - aa_step(0.0016, grid_dist(uv.y, tile * 4.0)));
	float run = pow(fract(uv.x * 3.0 - t * 0.6 + floor(uv.y / (tile * 4.0)) * 0.37), 6.0);
	alb = mix(alb, color_b * 0.5, strip);
	emi += color_b * strip * (0.5 + 2.4 * run);
	// A few tiles glow like lit exit signs, flickering.
	float lit = step(0.93, h) * (0.6 + 0.4 * step(0.2, fract(sin((floor(t * 7.0) + h * 91.0) * 12.9898) * 43758.5453)));
	emi += color_b * lit * (1.0 - grout) * 0.35;
}

void police(vec3 base, vec3 p, float t, vec3 n, vec3 view, inout vec3 alb, inout float rough, inout float metal, inout vec3 emi) {
	vec2 uv = fplane(p, ln);
	vec3 r = reflect(-view, n);
	if (is_trim) {
		// Black gloss with a checked band, two rows high.
		vec2 c = floor(uv / 0.016);
		float check = mod(c.x + c.y, 2.0) * step(-0.016, uv.y) * step(uv.y, 0.016);
		alb = mix(base, color_c, check);
		rough = 0.25;
		metal = 0.0;
		emi += fstudio(r, vec3(0.3)) * 0.1;
	} else {
		// Navy gloss with a white door panel band.
		float panel = aa_step(-0.01, uv.y) * (1.0 - aa_step(0.03, uv.y));
		alb = mix(base, color_c * 0.92, panel * fside(ln));
		rough = 0.22;
		metal = 0.1;
		emi += fstudio(r, base) * 0.12;
	}
	// The light bar: lens cells along the weapon, red on one side, blue on the other,
	// flashing in doubles (red, red, blue, blue).
	vec2 cell = fract(uv / vec2(0.022, 0.012)) - 0.5;
	float lens = smoothstep(0.42, 0.34, max(abs(cell.x), abs(cell.y)));
	float ph = fract(t * 1.5);
	float red_on = step(ph, 0.07) + step(0.12, ph) * step(ph, 0.19);
	float blue_on = step(0.5, ph) * step(ph, 0.57) + step(0.62, ph) * step(ph, 0.69);
	float side = step(0.0, p.x + p.z * 0.15);
	float bar = 1.0 - aa_step(0.016, abs(uv.y - 0.06));
	vec3 lamp = color_b * red_on * (1.0 - side) + POLICE_BLUE * blue_on * side;
	alb = mix(alb, mix(color_b * 0.3, POLICE_BLUE * 0.4, side), bar * lens);
	emi += lamp * bar * lens * 3.0;
	// The strobe washes over the whole paint job.
	emi += (color_b * red_on + POLICE_BLUE * blue_on) * ffres(n, view, 2.0) * 0.35;
}

void concrete(vec3 base, vec3 p, inout vec3 alb, inout float rough, inout float metal, inout vec3 emi) {
	float agg = fnoise3(p * 140.0);
	float pebble = smoothstep(0.78, 0.82, fnoise3(p * 70.0 + 2.0));
	alb = base * (0.82 + 0.3 * agg);
	alb = mix(alb, base * 0.55, pebble * 0.6);
	alb *= 0.9 + 0.15 * ffbm3(p * 6.0);
	// Hairline cracks.
	float crack = smoothstep(0.006, 0.0, abs(ffbm3(p * 11.0) - 0.5));
	alb = mix(alb, base * 0.3, crack);
	// Form-tie holes on the sides, rust bleeding down from each.
	vec2 uv = fplane(p, ln);
	vec2 cell = vec2(grid_dist(uv.x, 0.07), grid_dist(uv.y, 0.06));
	float hole = smoothstep(0.0055, 0.004, length(cell)) * fside(ln);
	vec2 under = vec2(cell.x, fract(uv.y / 0.06 + 0.5) * 0.06 - 0.03);
	float bleed = smoothstep(0.004, 0.0, abs(under.x)) * smoothstep(0.0, -0.025, under.y) * fside(ln);
	alb = mix(alb, color_b * 0.6, bleed * 0.6);
	alb = mix(alb, vec3(0.06), hole);
	rough = 0.94;
	metal = 0.0;
	if (is_trim) {
		// Worn safety-yellow stripes painted across it.
		float stripe = 1.0 - aa_step(0.25, fract((uv.x + uv.y) / 0.12));
		float paint = stripe * (1.0 - aa_step(0.62, ffbm3(p * 16.0)));
		alb = mix(alb, color_c, paint);
		rough = mix(0.94, 0.6, paint);
	}
}

void fragment() {
	vec3 base = is_trim ? trim_color : shell_color;
	vec3 alb = base;
	float rough = 0.5;
	float metal = 0.0;
	vec3 emi = vec3(0.0);
	if (pattern == 0) {
		ash_camo(base, lp, TIME, alb, rough, metal, emi);
	} else if (pattern == 1) {
		rust_belt(base, lp, alb, rough, metal, emi);
	} else if (pattern == 2) {
		hazard(is_trim ? color_c : shell_color, lp, TIME, alb, rough, metal, emi);
		if (is_trim) {
			alb = mix(trim_color, alb, 0.25);
		}
	} else if (pattern == 3) {
		graffiti(base, lp, TIME, alb, rough, metal, emi);
	} else if (pattern == 4) {
		burnt_chrome(base, lp, TIME, NORMAL, VIEW, alb, rough, metal, emi);
	} else if (pattern == 5) {
		blackout(base, lp, TIME, alb, rough, metal, emi);
	} else if (pattern == 6) {
		police(base, lp, TIME, NORMAL, VIEW, alb, rough, metal, emi);
	} else {
		concrete(base, lp, alb, rough, metal, emi);
	}
	ALBEDO = alb;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emi;
	PRINT_LAYER
}
