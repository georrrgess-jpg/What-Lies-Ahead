shader_type spatial;
// Mythic weapon finish "Celestial Midway" (50,000 lifetime kills). The shell
// is a pane of deep indigo glass with a midnight sky behind it, layered in
// depth: a violet nebula far back, three star fields at different depths
// (they slide past each other as the weapon turns: view-dependent parallax),
// aurora ribbons in teal and pink, and, nearest the glass, constellations
// that draw themselves in gold into carnival shapes (a Ferris wheel, a
// hot-air balloon, a crown, a rocket, a teacup, a wishing star), hold, and
// fade for the next. An iridescent film plays on the glass edges. The trim
// is polished gold filigree (a vine with curls and beads between gold rules),
// pierced so the night shows through, with a glint travelling along it. A
// kill (`pulse`, driven by FinishPulse) sends a shooting star along the
// weapon and flares the sky. Seen small (thumbnails, the Arsenal stand) the
// fine stars and the lattice give way to a bolder sky and solid gold, so the
// finish still reads: glowing nebula, gold shapes, gold trim.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.03, 0.02, 0.08);
uniform vec3 trim_color : source_color = vec3(1.0, 0.77, 0.36);
uniform bool is_trim = false;
uniform vec3 violet : source_color = vec3(0.42, 0.16, 0.85);
uniform vec3 teal : source_color = vec3(0.12, 0.9, 0.86);
uniform vec3 pink : source_color = vec3(1.0, 0.34, 0.68);
uniform vec3 star_gold : source_color = vec3(1.0, 0.76, 0.38);
// 1 animates, 0 holds a still sky with every constellation drawn
// (Settings "Reduce motion"; FinishPulse sets it).
uniform float motion = 1.0;
// 1 at a kill, easing back to 0 (FinishPulse); the seed varies its path.
uniform float pulse = 0.0;
uniform float pulse_seed = 0.0;
// The shooting star's path in world space (FinishPulse: across the weapon's
// bounds, back to muzzle, following the weapon), and the weapon's side axis.
uniform vec3 pulse_from = vec3(0.0, 0.05, 0.3);
uniform vec3 pulse_to = vec3(0.0, 0.08, -0.5);
uniform vec3 pulse_side = vec3(1.0, 0.0, 0.0);
// Screen footprint (m per pixel) over which the fine sky gives way to the
// bold one: first person is about 0.0006, the Arsenal stand 0.003.
uniform vec2 detail_fade = vec2(0.0014, 0.0034);

varying vec3 lp;
varying vec3 ln;
varying vec3 lv;
varying vec3 wp;

// The six constellations, as segments (a.xy, b.xy) in a -1..1 box, in the
// order they are drawn. SHAPE_START / SHAPE_COUNT index into SEGS.
const vec4 SEGS[47] = {
	// Ferris wheel: legs, rim, spokes.
	vec4(0.0, 0.2, -0.45, -0.9), vec4(0.0, 0.2, 0.45, -0.9),
	vec4(0.0, 0.8, 0.52, 0.5), vec4(0.52, 0.5, 0.52, -0.1), vec4(0.52, -0.1, 0.0, -0.4),
	vec4(0.0, -0.4, -0.52, -0.1), vec4(-0.52, -0.1, -0.52, 0.5), vec4(-0.52, 0.5, 0.0, 0.8),
	vec4(0.0, 0.2, 0.52, 0.5), vec4(0.0, 0.2, 0.0, -0.4), vec4(0.0, 0.2, -0.52, 0.5),
	// Hot-air balloon: envelope, ropes, basket.
	vec4(0.0, 0.95, -0.5, 0.7), vec4(-0.5, 0.7, -0.55, 0.2), vec4(-0.55, 0.2, -0.18, -0.35),
	vec4(0.0, 0.95, 0.5, 0.7), vec4(0.5, 0.7, 0.55, 0.2), vec4(0.55, 0.2, 0.18, -0.35),
	vec4(-0.18, -0.35, -0.15, -0.75), vec4(0.18, -0.35, 0.15, -0.75), vec4(-0.15, -0.75, 0.15, -0.75),
	// Crown.
	vec4(-0.8, -0.55, -0.8, 0.45), vec4(-0.8, 0.45, -0.4, -0.05), vec4(-0.4, -0.05, 0.0, 0.65),
	vec4(0.0, 0.65, 0.4, -0.05), vec4(0.4, -0.05, 0.8, 0.45), vec4(0.8, 0.45, 0.8, -0.55),
	vec4(0.8, -0.55, -0.8, -0.55),
	// Rocket: nose, body, fins.
	vec4(0.0, 0.95, -0.25, 0.45), vec4(0.0, 0.95, 0.25, 0.45), vec4(-0.25, 0.45, 0.25, 0.45),
	vec4(-0.25, 0.45, -0.25, -0.5), vec4(0.25, 0.45, 0.25, -0.5), vec4(-0.25, -0.5, 0.25, -0.5),
	vec4(-0.25, -0.5, -0.55, -0.85), vec4(0.25, -0.5, 0.55, -0.85),
	// Teacup: cup, handle, saucer.
	vec4(-0.6, 0.3, 0.6, 0.3), vec4(0.6, 0.3, 0.4, -0.4), vec4(0.4, -0.4, -0.4, -0.4),
	vec4(-0.4, -0.4, -0.6, 0.3), vec4(0.6, 0.3, 0.9, 0.1), vec4(0.9, 0.1, 0.5, -0.15),
	vec4(-0.8, -0.62, 0.8, -0.62),
	// Wishing star.
	vec4(0.0, 0.8, 0.5, -0.74), vec4(0.5, -0.74, -0.81, 0.21), vec4(-0.81, 0.21, 0.81, 0.21),
	vec4(0.81, 0.21, -0.5, -0.74), vec4(-0.5, -0.74, 0.0, 0.8)
};
const int SHAPE_START[6] = { 0, 11, 20, 27, 35, 42 };
const int SHAPE_COUNT[6] = { 11, 9, 7, 8, 7, 5 };

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lv = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz - VERTEX;
}

// A direction in pattern space (print_xform without the shift and scale).
vec3 print_dir(vec3 d) {
	if (!print_on) {
		return d;
	}
	float c = cos(print_angle);
	float s = sin(print_angle);
	vec3 q = vec3(d.x, c * d.y - s * d.z, s * d.y + c * d.z);
	if (print_variant == 3) {
		q.xy = -q.xy;
	}
	return q;
}

// The point of a layer `depth` (m) behind the glass, seen along the view:
// slid along the face (parallax mapping), so a face keeps its own slice of
// the sky and the deeper layers drift against the nearer ones as it turns.
vec3 behind(vec3 p, vec3 n, vec3 v, float depth) {
	float c = max(dot(v, n), 0.3);
	return p - (v - n * dot(v, n)) * depth / c;
}

// Teal, violet, pink and gold, round and round (the glass film).
vec3 film(float t) {
	float f = fract(t) * 4.0;
	if (f < 1.0) {
		return mix(teal, violet * 1.4, smoothstep(0.0, 1.0, f));
	} else if (f < 2.0) {
		return mix(violet * 1.4, pink, smoothstep(1.0, 2.0, f));
	} else if (f < 3.0) {
		return mix(pink, star_gold, smoothstep(2.0, 3.0, f));
	}
	return mix(star_gold, teal, smoothstep(3.0, 4.0, f));
}

// One star field: a star per `cell` (with chance `density`), drawn by its
// distance across the face, so each is a round point. A star never shrinks
// below a pixel: one that would is dimmed instead, and a field whose cells
// get too small on screen fades into its mean glow (no shimmer). Bright ones
// get a soft halo and, with `rays`, four fine rays.
vec3 stars(vec3 q, vec3 n, float cell, float size, float density, float px, float t, vec3 tint, bool rays) {
	float vis = 1.0 - smoothstep(cell * 0.07, cell * 0.2, px);
	vec3 mean = tint * density * size * size / (cell * cell) * 4.0 * (1.0 - vis);
	vec3 id = floor(q / cell);
	vec3 h = fh33(id);
	if (h.x > density || vis <= 0.0) {
		return mean;
	}
	vec3 j = fh33(id + 17.3);
	vec3 sp = (id + 0.3 + 0.4 * j) * cell;
	vec3 d = q - sp;
	d -= n * dot(d, n);
	float r = size * (0.3 + 0.7 * h.y * h.y * h.y);
	float rad = max(r, px * 0.85);
	float energy = (r * r) / (rad * rad);
	float dist = length(d);
	float core = exp(-dist * dist / (rad * rad) * 1.6);
	float halo = exp(-dist / (rad * 2.5)) * 0.2 * h.y;
	// Kept inside the cell, so no star is ever cut square.
	float inside = 1.0 - smoothstep(cell * 0.14, cell * 0.28, dist);
	float twinkle = 0.6 + 0.4 * sin(t * (1.1 + h.z * 2.4) + h.y * 40.0);
	vec3 col = mix(vec3(0.92, 0.94, 1.0), tint, j.z * 0.8);
	float light = (core * energy * 1.8 + halo * min(energy * 4.0, 1.0)) * twinkle;
	if (rays && h.y > 0.72) {
		// Thin diffraction rays along the face's two axes, never under a pixel.
		vec2 f = abs(fplane(d, n));
		float w = max(r * 0.14, px * 0.6);
		float len = r * 4.0;
		float ray = exp(-f.y * f.y / (w * w)) * exp(-f.x / len) + exp(-f.x * f.x / (w * w)) * exp(-f.y / len);
		light += ray * 0.7 * min(energy * 3.0, 1.0) * twinkle * min(1.0, r * 0.14 / w);
	}
	return col * light * inside * vis + mean;
}

// The deep sky: indigo to violet, with teal and pink clouds and dark dust
// lanes, slowly turning. Returns emission.
vec3 nebula(vec3 q, float t, float bold) {
	vec3 w = q * 6.0 + vec3(0.0, 0.0, t * 0.01);
	vec3 warp = vec3(ffbm3(w + 1.7), ffbm3(w + 8.3), ffbm3(w + 4.1));
	float cloud = ffbm3(q * 8.0 + warp * 1.8 - vec3(0.0, t * 0.008, 0.0));
	float wisps = ffbm3(q * 20.0 + warp * 2.5);
	float dense = smoothstep(0.42, 0.72, cloud) * (0.55 + 0.45 * smoothstep(0.35, 0.7, wisps));
	float dust = smoothstep(0.5, 0.62, ffbm3(q * 14.0 - warp * 1.2 + 5.0));
	vec3 deep = mix(shell_color * 1.5, violet * 0.3, smoothstep(0.3, 0.7, warp.x));
	vec3 tint = mix(teal * 0.9, pink, smoothstep(0.38, 0.62, warp.y));
	vec3 col = deep + mix(violet * 0.7, tint, 0.55 + 0.45 * wisps) * dense * 0.85;
	col *= 1.0 - dust * 0.55;
	return col * mix(1.0, 1.6, bold);
}

// Aurora ribbons: curtains that hang along the weapon, swaying, bright at
// their lower hem (teal) and fading upward into pink, with fine vertical rays.
vec3 aurora(vec3 q, float t, float px) {
	float sway = sin(q.z * 9.0 + t * 0.16) * 0.012 + sin(q.z * 23.0 - t * 0.23 + q.x * 10.0) * 0.005;
	float period = 0.11;
	float y = q.y - sway + q.z * 0.12;
	float lane = floor(y / period);
	float v = y - (lane + 0.5) * period;
	float soft = max(px * 1.5, 0.0015);
	float hem = smoothstep(-soft, soft, v + 0.012);
	float body = hem * exp(-max(v + 0.012, 0.0) / 0.024);
	float rays = 0.55 + 0.45 * fnoise2(vec2(q.z * 140.0 + sin(t * 0.3 + q.z * 6.0) * 2.0, lane * 3.0 + t * 0.05));
	// Rays finer than a pixel average out to their mean.
	rays = mix(rays, 0.78, smoothstep(0.0006, 0.002, px));
	float fade = 0.5 + 0.5 * sin(q.z * 4.0 + lane * 2.1 - t * 0.21);
	vec3 col = mix(teal, pink, smoothstep(0.0, 0.05, v + 0.012));
	return col * body * rays * fade * fade * 0.6;
}

float seg_dist(vec2 p, vec2 a, vec2 b, out float along) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	along = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * along);
}

// The constellations on the side faces (2D coordinates `s`, m). Each tile
// may hold one shape; it draws itself segment by segment with a bright pen,
// holds, and fades back to its guide stars, on its own clock. Lines and
// stars never get thinner than a pixel. Returns emission.
vec3 constellations(vec2 s, float t, float px, float flare) {
	vec2 tile = vec2(0.105, 0.08);
	vec2 cell = floor(s / tile);
	vec2 h = fh22(cell + 3.7);
	if (h.x > 0.62) {
		return vec3(0.0);
	}
	vec2 jit = (fh22(cell + 9.1) - 0.5) * tile * 0.22;
	vec2 c = s - (cell + 0.5) * tile - jit;
	float scale = 0.029;
	vec2 p = c / scale;
	int k = int(floor(fh21(cell + 1.3) * 6.0));
	int start = SHAPE_START[k];
	int count = SHAPE_COUNT[k];
	// The tile's clock: draw (to 0.42), hold (to 0.75), fade (to 1).
	float phase = fract(t / 11.0 + h.y);
	float draw = mix(1.0, smoothstep(0.02, 0.42, phase), motion);
	float lit = mix(1.0, 1.0 - smoothstep(0.75, 0.98, phase), motion);
	float w = max(0.0007, px * 0.7) / scale;
	float aa = max(px, 0.0003) / scale;
	float energy = min(1.0, 0.0007 / max(px * 0.7, 0.0007) + 0.3);
	float star_r = max(0.0021, px * 1.1) / scale;
	float line = 0.0;
	float glow = 0.0;
	float node = 0.0;
	float guide = 0.0;
	float pen = 0.0;
	float fc = float(count);
	for (int i = 0; i < 11; i++) {
		if (i >= count) {
			break;
		}
		vec4 sg = SEGS[start + i];
		float shown = clamp(draw * fc - float(i), 0.0, 1.0);
		float along;
		float d = seg_dist(p, sg.xy, sg.zw, along);
		// Only the drawn part of the segment shows.
		float on = step(along, shown) * step(0.001, shown);
		line = max(line, on * smoothstep(w + aa, w - aa, d));
		glow = max(glow, on * exp(-d * 10.0));
		float da = length(p - sg.xy);
		float db = length(p - sg.zw);
		node = max(node, smoothstep(star_r + aa, star_r - aa, da) * step(0.001, shown));
		node = max(node, smoothstep(star_r + aa, star_r - aa, db) * step(0.999, shown));
		guide = max(guide, smoothstep(star_r * 0.8 + aa, star_r * 0.8 - aa, min(da, db)));
		if (shown > 0.0 && shown < 1.0) {
			vec2 tip = mix(sg.xy, sg.zw, shown) - p;
			pen = max(pen, exp(-dot(tip, tip) * 90.0));
		}
	}
	vec3 col = star_gold * line * lit * energy * 0.95;
	col += mix(star_gold, pink, 0.4) * glow * lit * 0.08;
	col += vec3(1.0, 0.92, 0.75) * max(node * lit, guide * 0.28) * 1.4;
	col += vec3(1.0, 0.96, 0.88) * pen * 2.5;
	return col * (1.0 + flare * 1.5);
}

// A shooting star crossing the weapon after a kill (`k`: 1 at the kill, then
// down to 0): a white-gold head with a tail cooling through pink to violet,
// shedding sparks, along pulse_from -> pulse_to. `p` is the world position;
// the path is measured across the weapon's side (pulse_side left out), so it
// reads as one comet over every face it crosses.
vec3 shooting_star(vec3 p, float k, float px) {
	if (k <= 0.0) {
		return vec3(0.0);
	}
	vec3 dir = normalize(pulse_to - pulse_from);
	vec3 rel = p - mix(pulse_from, pulse_to, 1.0 - k);
	rel -= pulse_side * dot(rel, pulse_side);
	// Distance behind the head (along the way it came) and across the path.
	float dz = -dot(rel, dir);
	float dy = length(rel + dir * dz);
	float w = max(0.0022, px * 1.3);
	float behind_head = step(0.0, dz);
	// Ahead of the head nothing; `along` keeps every exponent finite there.
	float along = max(dz, 0.0);
	float tail = behind_head * exp(-along / 0.16) * exp(-dy * dy / (w * w * (1.0 + along * 60.0)));
	float r2 = dz * dz + dy * dy;
	float head = exp(-r2 / (w * w * 3.0));
	float halo = exp(-sqrt(r2) / 0.012);
	// Sparks shed along the tail, twinkling out.
	float spark_id = floor(along / 0.012);
	vec2 sh = fh22(vec2(spark_id, floor(pulse_seed * 97.0)));
	float spark = behind_head * step(0.55, sh.x) * exp(-pow((along - (spark_id + 0.5) * 0.012) / w, 2.0) - pow((dy - (sh.y - 0.5) * 0.012) / w, 2.0)) * exp(-along / 0.1);
	vec3 white = vec3(1.0, 0.95, 0.85);
	vec3 trail = mix(mix(white, pink, smoothstep(0.0, 0.05, along)), violet * 1.5, smoothstep(0.05, 0.22, along));
	return (trail * tail * 3.0 + white * (head * 5.0 + halo * 0.35) + star_gold * spark * 2.5) * smoothstep(0.0, 0.12, k);
}

// The gold filigree in face coordinates `uv` (m): gold rules between rows of
// a vine with curls hanging off it and beads over its crests. Returns the
// distance to the nearest gold line (m).
float filigree(vec2 uv) {
	float lw = 0.072;
	float rh = 0.05;
	float row = floor(uv.y / rh);
	float u = uv.x + row * lw * 0.5;
	float v = (fract(uv.y / rh) - 0.5) * rh;
	float rule = abs(abs(v) - rh * 0.5);
	float ph = u / lw * 6.2831853;
	float amp = rh * 0.15;
	float slope = amp * 6.2831853 / lw * cos(ph);
	float vine = abs(v - amp * sin(ph)) * inversesqrt(1.0 + slope * slope);
	// One curl per half wave, under a crest and over a trough in turn.
	float k = floor(u / (lw * 0.5));
	float side = 1.0 - 2.0 * mod(k, 2.0);
	vec2 lc = vec2(u - (k + 0.5) * lw * 0.5, v + side * rh * 0.12);
	lc.x *= side;
	float rad = rh * 0.16;
	float rr = length(lc);
	float turn = rad / 1.6;
	float ang = atan(lc.y * side, lc.x) / 6.2831853;
	float arm = abs(fract(ang + rr / turn) - 0.5) * turn;
	float curl = max(arm, rr - rad);
	float bead = abs(length(vec2(lc.x, v - side * rh * 0.33)) - rh * 0.035);
	return min(min(rule, vine), min(curl, bead));
}

void fragment() {
	float t = TIME * motion + 41.0;
	vec3 n = normalize(ln);
	vec3 v = normalize(print_dir(lv));
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	// Footprint (m per pixel) across the face's most squeezed screen axis
	// (for anti-aliasing), and along its least squeezed one: a face seen
	// edge-on keeps its detail; only a weapon small on screen goes bold.
	float fx = length(dFdx(lp));
	float fy = length(dFdy(lp));
	float px = max(fx, fy);
	float bold = smoothstep(detail_fade.x, detail_fade.y, min(fx, fy));
	float side = smoothstep(0.55, 0.85, abs(n.x));
	float flare = pulse * pulse;
	// The night behind the glass, back to front.
	vec3 q_mid = behind(lp, n, v, 0.018);
	vec3 q_near = behind(lp, n, v, 0.007);
	vec3 sky = nebula(behind(lp, n, v, 0.06), t, bold);
	sky += stars(behind(lp, n, v, 0.035), n, 0.006, 0.00045, 0.7, px, t, violet * 1.6, false);
	sky += stars(q_mid, n, 0.012, 0.0008, 0.65, px, t, teal, false);
	sky += aurora(q_mid, t, px) * mix(1.0, 1.3, bold);
	sky += stars(q_near, n, 0.026, 0.0015, 0.55, px, t, pink, true) * (1.4 + flare);
	// Seen small: a few big steady stars keep the sky sparkling.
	sky += stars(lp, n, 0.05, 0.0032, 0.45, px, t, star_gold, false) * bold;
	vec3 shapes = constellations(vec2(q_near.z, q_near.y), t, px, flare) * side;
	vec3 streak = shooting_star(wp, pulse, max(length(dFdx(wp)), length(dFdy(wp))));
	// Dither under the dark gradients so they never band.
	float dither = (fh21(FRAGCOORD.xy + fract(t) * 17.0) - 0.5) / 255.0;
	if (is_trim) {
		// Pierced gold filigree; small and far it closes into solid gold.
		float d = filigree(fplane(lp, ln));
		float fine = 1.0 - smoothstep(0.0012, 0.0026, sqrt(fx * fy));
		float wgold = 0.0011;
		float soft = max(px, 0.0002);
		float gold = mix(1.0, smoothstep(wgold + soft, wgold - soft, d), fine);
		float bevel = smoothstep(wgold, 0.0, d) * fine;
		vec3 nb = normalize(mix(NORMAL, fbump(VERTEX, NORMAL, bevel, 0.0015), gold));
		vec3 rb = reflect(-VIEW, nb);
		float glint = exp(-pow((lp.z * 0.9 - lp.y * 0.5 - fract(t / 7.0) * 3.0 + 1.5) * 7.0, 2.0));
		// The gold is lit mostly by its own studio reflection, so it stays
		// warm gold whatever the level around it reflects.
		ALBEDO = mix(shell_color, trim_color * 0.55, gold);
		METALLIC = mix(0.0, 0.85, gold);
		ROUGHNESS = mix(0.09, 0.22, gold);
		NORMAL = nb;
		vec3 shine = fstudio(rb, trim_color) * trim_color * 0.75 + trim_color * (pow(ffres(nb, VIEW, 2.0), 1.5) * 0.4 + glint * 0.8 + flare * 0.5 + 0.03);
		EMISSION = (sky * 0.85 + shapes * 0.5) * (1.0 - gold) + shine * gold + streak * 0.5 + dither;
	} else {
		// Deep glass: a dark, glossy coat over the sky with an iridescent film
		// at its edges and a soft clear-coat reflection.
		vec3 iri = film(dot(NORMAL, VIEW) * 1.3 + lp.z * 2.2 + lp.y * 1.5 + t * 0.02);
		ALBEDO = shell_color;
		METALLIC = 0.0;
		ROUGHNESS = 0.09;
		SPECULAR = 0.6;
		EMISSION = sky + shapes + streak + iri * pow(fres, 1.6) * 0.5 + fstudio(r, vec3(0.4, 0.36, 0.6)) * (0.02 + fres * 0.12) + dither;
	}
	PRINT_LAYER
}
