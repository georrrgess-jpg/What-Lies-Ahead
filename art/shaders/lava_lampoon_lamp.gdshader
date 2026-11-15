shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

// The Lava Lampoon's lamp glass (art/blender/build_weapons_lava_lampoon.py,
// node LampGlass; origin at the bottom of the glass, +Y up the lamp). The wax
// is drawn inside it: every pixel marches its view ray through the glass and
// meets a field of metaballs, so blobs merge and split like real wax.
//   count   wax blobs in the lamp (the magazine / 3; a fractional blob shrinks)
//   heat    0-1 warm-up groove: blobs climb faster and the lamp glows brighter
//   gather  0 blobs drift freely, 1 all pooled in one lump where gravity points
//   down    gravity in the glass's own space (the lamp flips in the reload)
//   ripple  height (0-1, base to cap) of the glow ripple; below 0 none
//   flare   a shot's pulse (fades in the view script)
//   swirl   0-1 the liquid churns (the reload's flip)
uniform float count = 10.0;
uniform float heat = 0.0;
uniform float gather = 0.0;
uniform vec3 down = vec3(0.0, -1.0, 0.0);
uniform float ripple = -1.0;
uniform float flare = 0.0;
uniform float swirl = 0.0;

const int BLOBS = 10;
const int STEPS = 18;
// Glass height and radius profile (LAMP_PROFILE of the build script).
const float H = 0.088;
const vec3 WAX = vec3(1.0, 0.84, 0.26);
const vec3 WAX_RIM = vec3(1.0, 0.45, 0.1);
const vec3 LOW = vec3(1.0, 0.36, 0.08);
const vec3 HIGH = vec3(0.95, 0.12, 0.5);

varying vec3 lp;
varying vec3 cam;

float glass_r(float y) {
	float h = clamp(y, 0.0, H);
	if (h < 0.012) return mix(0.024, 0.03, h / 0.012);
	if (h < 0.03) return mix(0.03, 0.032, (h - 0.012) / 0.018);
	if (h < 0.05) return mix(0.032, 0.028, (h - 0.03) / 0.02);
	if (h < 0.07) return mix(0.028, 0.021, (h - 0.05) / 0.02);
	return mix(0.021, 0.0155, (h - 0.07) / 0.018);
}

// Each blob's field reaches REACH2 times its radius squared and falls off
// smoothly to nothing there (Wyvill), so far blobs never add up; a lone blob's
// surface (THRESHOLD) is at its radius, and close blobs merge.
const float REACH2 = 3.02;
const float THRESHOLD = 0.3;

float field(vec3 p, vec4 b[BLOBS + 1]) {
	float f = 0.0;
	for (int i = 0; i <= BLOBS; i++) {
		vec3 d = p - b[i].xyz;
		float q = clamp(1.0 - dot(d, d) / max(1e-6, b[i].w * b[i].w * REACH2), 0.0, 1.0);
		f += q * q * q;
	}
	return f;
}

float hash(float n) {
	return fract(sin(n * 91.345) * 47453.5453);
}

void vertex() {
	lp = VERTEX;
	cam = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[3].xyz, 1.0)).xyz;
}

void fragment() {
	// Where every blob is this frame (xyz) and its radius (w).
	vec4 b[BLOBS + 1];
	vec3 g = normalize(down);
	vec3 pool = vec3(0.0, H * 0.5, 0.0) + g * H * 0.34;
	float t = TIME * (1.0 + heat * 1.6);
	for (int i = 0; i < BLOBS; i++) {
		float fi = float(i);
		float h = 0.5 + 0.36 * sin(t * (0.32 + 0.22 * hash(fi + 1.0)) + 6.283 * hash(fi + 7.0)) + heat * 0.1;
		float y = clamp(h, 0.1, 0.9) * H;
		float br = mix(0.0068, 0.0098, hash(fi + 13.0)) * clamp(count - fi, 0.0, 1.0);
		float a = t * (0.25 + 0.3 * hash(fi + 3.0)) + 6.283 * hash(fi + 5.0) + swirl * 4.0 * TIME;
		float rad = max(0.0, glass_r(y) - br - 0.004) * 0.7;
		vec3 free_pos = vec3(cos(a) * rad, y, sin(a) * rad);
		vec3 lump = pool + (vec3(hash(fi + 21.0), hash(fi + 23.0), hash(fi + 29.0)) - 0.5) * 0.012 * (0.6 + 0.4 * sin(TIME * 3.0 + fi));
		b[i] = vec4(mix(free_pos, lump, gather), br * mix(1.0, 1.5, gather));
	}
	// The wax pool at the bottom of the lamp (where gravity points).
	b[BLOBS] = vec4(pool + vec3(0.0, 0.003 * sin(TIME * 1.7), 0.0), 0.0105 + 0.002 * sin(TIME * 1.3));

	vec3 dir = normalize(lp - cam);
	float span = glass_r(lp.y) * 2.2;
	float step_len = span / float(STEPS);
	vec3 p = lp;
	float peak = 0.0;
	bool hit = false;
	vec3 hp = p;
	// No `break` once the wax is found: the Compatibility renderer on some
	// drivers (Mesa) leaves stray black pixels after a broken-out loop.
	for (int s = 0; s < STEPS; s++) {
		p += dir * step_len;
		float f = hit ? 0.0 : field(p, b);
		peak = max(peak, f);
		if (!hit && f > THRESHOLD) {
			hit = true;
			hp = p;
		}
	}
	// Halve the last step a few times so the wax's edge is smooth.
	vec3 lo = hp - dir * step_len;
	for (int r = 0; r < 3; r++) {
		vec3 mid = (lo + hp) * 0.5;
		bool inside = field(mid, b) > THRESHOLD;
		hp = inside ? mid : hp;
		lo = inside ? lo : mid;
	}
	p = hp;
	float k = lp.y / H;
	vec3 liquid = mix(LOW, HIGH, smoothstep(0.05, 0.95, k));
	// Light through the liquid from the hot base.
	liquid *= 0.62 + 0.38 * (1.0 - k) + heat * 0.25;
	vec3 col = liquid;
	// Soft glow of the wax through the liquid.
	col += WAX * smoothstep(0.02, THRESHOLD, peak) * 0.3;
	if (hit) {
		// Outward normal: the field falls off away from the wax.
		vec2 e = vec2(0.0006, 0.0);
		vec3 n = vec3(field(p - e.xyy, b) - field(p + e.xyy, b), field(p - e.yxy, b) - field(p + e.yxy, b),
			field(p - e.yyx, b) - field(p + e.yyx, b)) + vec3(0.0, 1e-6, 0.0);
		n *= inversesqrt(max(dot(n, n), 1e-20));
		float lit = 0.55 + 0.45 * clamp(dot(n, vec3(0.3, 0.8, 0.5)), 0.0, 1.0);
		float rim = 1.0 - clamp(dot(n, -dir), 0.0, 1.0);
		rim *= rim;
		col = mix(WAX * lit, WAX_RIM, rim * 0.7) * (1.0 + heat * 0.25);
	}
	// Glass: a bright rim and a vertical highlight streak.
	float fres = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	fres *= fres * fres;
	float streak = smoothstep(0.55, 0.9, NORMAL.x * 0.7 + NORMAL.y * 0.6);
	col += vec3(1.0, 0.9, 0.95) * (fres * 0.5 + streak * 0.35);
	// The glow ripple running up from the base, and the shot's pulse.
	if (ripple >= 0.0) {
		float x = (k - ripple) * 9.0;
		float band = exp(-x * x);
		col += vec3(1.0, 0.95, 0.7) * band * 0.9;
	}
	col *= 1.0 + flare * 0.35 + heat * 0.15;
	ALBEDO = col;
}
