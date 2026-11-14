// Shared helpers for the finish_*.gdshader weapon finishes
// (contract: scripts/player/weapon_cosmetics.gd). Every finish samples the
// mesh's own space (lp = VERTEX, ln = NORMAL in vertex()), so the pattern
// sticks to the weapon in first person, the Locker and thumbnails alike.
// Weapon models run along local Z (muzzle at -Z), are 0.4-1.0 long and
// 0.1-0.27 wide.

float fh21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float fh31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

vec2 fh22(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

vec3 fh33(vec3 p) {
	return fract(sin(vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)))) * 43758.5453);
}

float fnoise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(fh21(i), fh21(i + vec2(1.0, 0.0)), u.x), mix(fh21(i + vec2(0.0, 1.0)), fh21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(fh31(i), fh31(i + vec3(1.0, 0.0, 0.0)), u.x), mix(fh31(i + vec3(0.0, 1.0, 0.0)), fh31(i + vec3(1.0, 1.0, 0.0)), u.x), u.y),
		mix(mix(fh31(i + vec3(0.0, 0.0, 1.0)), fh31(i + vec3(1.0, 0.0, 1.0)), u.x), mix(fh31(i + vec3(0.0, 1.0, 1.0)), fh31(i + vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
}

float ffbm2(vec2 p) {
	return fnoise2(p) * 0.55 + fnoise2(p * 2.07 + 3.1) * 0.3 + fnoise2(p * 4.13 + 7.7) * 0.15;
}

float ffbm3(vec3 p) {
	return fnoise3(p) * 0.55 + fnoise3(p * 2.07 + 3.1) * 0.3 + fnoise3(p * 4.13 + 7.7) * 0.15;
}

// 2D coordinates on the face's dominant plane. u always runs along the barrel
// (local Z) except on the muzzle and butt faces; v runs up on the sides.
vec2 fplane(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.x >= a.y && a.x >= a.z) {
		return vec2(p.z, p.y);
	}
	if (a.y >= a.z) {
		return vec2(p.z, p.x);
	}
	return vec2(p.x, p.y);
}

// 1 on the side faces (the ones the player sees most), 0 elsewhere.
float fside(vec3 n) {
	vec3 a = abs(n);
	return step(a.y, a.x) * step(a.z, a.x);
}

float ffres(vec3 normal, vec3 view, float power) {
	return pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), power);
}

// A studio reflection for metals: bright soft-box horizon over a darker floor,
// so polished metal reads as metal even with no reflections around (Locker,
// thumbnails). `r` is the view-space reflection vector.
vec3 fstudio(vec3 r, vec3 tint) {
	float sky = smoothstep(-0.15, 0.15, r.y) * 0.6 + smoothstep(0.25, 0.9, r.y) * 0.4;
	float horizon = exp(-pow((r.y - 0.06) * 8.0, 2.0));
	float box = smoothstep(0.5, 0.8, r.x) * smoothstep(-0.1, 0.3, r.y) * 0.5;
	vec3 deep = tint * 0.35;
	vec3 bright = mix(tint, vec3(1.0), 0.5);
	return mix(deep, bright, sky) + vec3(1.0) * (horizon * 0.45 + box);
}

// A height field turned into a bumped normal (screen-space derivatives; cheap
// and renderer-agnostic). `pos` is VERTEX, `n` is NORMAL (both view space).
vec3 fbump(vec3 pos, vec3 n, float h, float strength) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	float dhdx = dFdx(h) * strength;
	float dhdy = dFdy(h) * strength;
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	return normalize(abs(det) * n - grad);
}

// Hue palette: t in 0..1 around the colour wheel.
vec3 fhue(float t) {
	return clamp(abs(fract(t + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

// --- Prize Prints ------------------------------------------------------------
// A print is one rolled copy of a finish (scripts/economy/prints/). Every
// finish_* shader runs `lp = print_xform(VERTEX);` in vertex() and ends its
// fragment() with PRINT_LAYER. With print_on false (a plain finish) both cost
// one uniform branch; a print stays a single pass.
//   print_offset / print_angle / print_scale  where the pattern falls (the pattern seed)
//   print_seed                  0-1, for designs anchored to the model
//   print_shine                 0-1 shine roll: Factory wear < 0.6, Polished, Mint >= 0.9
//   print_variant               0 standard, 1 glitter, 2 holo, 3 gold-ink misprint
uniform bool print_on = false;
uniform vec3 print_offset = vec3(0.0);
uniform float print_angle = 0.0;
uniform float print_scale = 1.0;
uniform float print_seed = 0.0;
uniform float print_shine = 0.75;
uniform int print_variant = 0;

// The pattern-space position of a model-space point: turned in the side plane,
// scaled a little (so regular grids land differently too), shifted, and
// flipped upside down on a misprint.
vec3 print_xform(vec3 p) {
	if (!print_on) {
		return p;
	}
	float c = cos(print_angle);
	float s = sin(print_angle);
	vec3 q = vec3(p.x, c * p.y - s * p.z, s * p.y + c * p.z) * print_scale;
	if (print_variant == 3) {
		q.y = -q.y;
		q.x = -q.x;
	}
	return q + print_offset;
}

// Shine grade: wear and dust below Polished, gloss and a clear coat above.
void print_grade(inout vec3 albedo, inout float rough, inout float metal, inout vec3 emission, vec3 n, vec3 view, vec3 p) {
	float wear = smoothstep(0.62, 0.0, print_shine);
	if (wear > 0.0) {
		vec3 q = p + print_offset * 3.1;
		// Faded, chalky paint.
		float grey = dot(albedo, vec3(0.3, 0.55, 0.15));
		albedo = mix(albedo, vec3(grey), wear * 0.18) * (1.0 - wear * 0.12);
		// Worn patches: the paint is rubbed through to a grey primer.
		float patch = smoothstep(0.6 - wear * 0.06, 0.66 - wear * 0.06, ffbm3(q * 18.0)) * smoothstep(0.0, 0.4, wear);
		vec3 primer = vec3(0.22, 0.21, 0.24) + vec3(grey) * 0.1;
		albedo = mix(albedo, primer, patch * (0.6 + 0.3 * wear));
		// Fine scratches along the barrel catch the light as bare metal.
		float lines = fnoise2(vec2(q.z * 7.0 + q.x * 3.0, q.y * 180.0 + q.x * 120.0));
		float scratch = smoothstep(0.82, 0.92, lines) * smoothstep(0.3, 0.55, fnoise2(q.zy * 11.0)) * wear;
		albedo = mix(albedo, vec3(0.8, 0.78, 0.76), scratch * 0.85);
		metal = mix(metal, 0.9, scratch);
		rough = mix(rough, 0.85, max(patch, wear * 0.6));
		emission *= 1.0 - wear * 0.6;
		emission += vec3(0.8) * scratch * 0.08;
	}
	float gloss = smoothstep(0.55, 1.0, print_shine);
	float mint = smoothstep(0.88, 0.97, print_shine);
	rough = mix(rough, 0.06, gloss * 0.75);
	// Clear coat: a sharp studio reflection over the paint, strongest at Mint.
	vec3 r = reflect(-view, n);
	float fres = ffres(n, view, 3.0);
	emission += fstudio(r, vec3(1.0)) * (0.04 + fres * 0.6) * (gloss * 0.25 + mint * 0.35);
	albedo = mix(albedo, min(albedo * 1.15, vec3(1.0)), mint);
}

// Glitter: metallic flecks that wink as the weapon turns.
void print_glitter(inout vec3 albedo, inout float rough, inout float metal, inout vec3 emission, vec3 n, vec3 view, vec3 p, float time) {
	vec3 g = p * 150.0;
	vec3 cell = floor(g);
	vec3 h = fh33(cell + print_seed * 31.0);
	vec3 f = fract(g) - (h * 0.5 + 0.25);
	float fleck = smoothstep(0.3, 0.1, length(f)) * step(0.15, h.x);
	vec3 dir = normalize(h - 0.5);
	float tw = pow(0.5 + 0.5 * sin(h.y * 40.0 + dot(view, dir) * 14.0 + dot(n, dir) * 8.0 + time * (0.8 + h.z * 1.5)), 10.0);
	vec3 tint = mix(vec3(1.0), fhue(h.z + h.y * 0.3), 0.6);
	albedo = mix(albedo, tint * 0.9, fleck * 0.85);
	metal = mix(metal, 1.0, fleck);
	rough = mix(rough, 0.12, fleck);
	emission += tint * fleck * (0.6 + tw * 3.5);
	// A pearly sheen over the whole coat.
	emission += fhue(dot(n, view) * 0.8 + p.z * 2.0) * ffres(n, view, 2.5) * 0.12;
}

// Holo: an animated rainbow foil, view dependent, with a diffraction grating
// and a light bar sweeping along the weapon.
void print_holo(inout vec3 albedo, inout float rough, inout float metal, inout vec3 emission, vec3 n, vec3 view, vec3 p, float time) {
	float fres = ffres(n, view, 2.0);
	float grating = 0.5 + 0.5 * sin((p.z + p.y * 0.6) * 520.0 + n.x * 6.0);
	float t = dot(n, view) * 1.4 + p.z * 3.5 + p.y * 2.0 + n.y * 0.6 - time * 0.12 + print_seed;
	vec3 foil = fhue(t + grating * 0.08);
	float sweep = exp(-pow(fract(p.z * 0.7 - time * 0.22 + print_seed) * 3.0 - 1.5, 2.0) * 9.0);
	// Diamond-cut facets of the foil sheet.
	vec2 d = fract(vec2(p.z + p.y, p.z - p.y) * 34.0) - 0.5;
	float facet = smoothstep(0.42, 0.5, max(abs(d.x), abs(d.y)));
	albedo = mix(albedo, albedo * 0.55 + foil * 0.45, 0.5);
	metal = mix(metal, 0.75, 0.7);
	rough = mix(rough, 0.18, 0.7);
	emission += foil * (0.1 + fres * 0.4 + sweep * 0.5) * (0.85 + 0.15 * grating) + vec3(facet * 0.06);
}

// Gold-ink misprint: misregistered bands of inverted ink edged in gold leaf,
// gold ink outlines where the pattern changes inside them, and gold splatter.
// `p` is the misprinted pattern space; the bands repeat so one always crosses.
void print_misprint(inout vec3 albedo, inout float rough, inout float metal, inout vec3 emission, vec3 n, vec3 view, vec3 p) {
	vec2 dir = normalize(vec2(0.6 + print_seed * 0.5, 1.0));
	float period = 0.32 + print_seed * 0.1;
	float d = (fract(dot(vec2(p.z, p.y), dir) / period + print_seed) - 0.5) * period;
	float w = 0.045 + print_seed * 0.02;
	float band = smoothstep(w + 0.002, w - 0.002, abs(d));
	float leaf = smoothstep(0.011, 0.006, abs(abs(d) - w));
	float lum = dot(albedo, vec3(0.3, 0.55, 0.15));
	float ink_edge = smoothstep(0.03, 0.1, fwidth(lum)) * band;
	vec3 inverted = vec3(1.0) - albedo;
	inverted = mix(inverted, inverted.gbr, 0.5);
	float splat = smoothstep(0.74, 0.8, fnoise3(p * 60.0 + print_seed * 13.0)) * smoothstep(0.4, 0.55, fnoise3(p * 8.0 + 4.0));
	float gold = max(max(leaf, ink_edge * 0.8), splat);
	albedo = mix(albedo, inverted, band * 0.9);
	vec3 gold_col = vec3(1.0, 0.74, 0.28);
	albedo = mix(albedo, gold_col, gold);
	metal = mix(metal, 1.0, gold);
	rough = mix(rough, 0.2, gold);
	vec3 r = reflect(-view, n);
	emission += fstudio(r, gold_col) * gold * 0.5 + gold_col * gold * 0.18;
}

void print_layer(inout vec3 albedo, inout float rough, inout float metal, inout vec3 emission, vec3 n, vec3 view, vec3 p, float time) {
	if (print_variant == 1) {
		print_glitter(albedo, rough, metal, emission, n, view, p, time);
	} else if (print_variant == 2) {
		print_holo(albedo, rough, metal, emission, n, view, p, time);
	} else if (print_variant == 3) {
		print_misprint(albedo, rough, metal, emission, n, view, p);
	}
	print_grade(albedo, rough, metal, emission, n, view, p);
}

// The last line of every finish fragment(): applies the print, if any.
#define PRINT_LAYER if (print_on) { vec3 _pa = ALBEDO; float _pr = ROUGHNESS; float _pm = METALLIC; vec3 _pe = EMISSION; print_layer(_pa, _pr, _pm, _pe, NORMAL, VIEW, lp, TIME); ALBEDO = _pa; ROUGHNESS = _pr; METALLIC = _pm; EMISSION = _pe; }
