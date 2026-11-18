shader_type spatial;
// Weapon finish "Jackpot": a one-armed bandit wrapped round the weapon. Reels
// of cherries, lemons, bells, bars and sevens spin down the side, stop one
// after another with a little bounce, and every third pull lines up triple
// sevens: the reels flash gold and the chrome trim's marquee bulbs chase.
// The trim is gold chrome with the bulbs.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.97, 0.94, 0.86);
uniform vec3 trim_color : source_color = vec3(0.95, 0.72, 0.22);
uniform bool is_trim = false;
uniform float reel_w = 0.04;
uniform float cycle = 6.0;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

float box_sd(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float fillv(float d, float soft) {
	return smoothstep(soft, -soft, d);
}

// The five symbols: colour and coverage for symbol `k` at cell coordinate f
// (-0.5..0.5). Returns rgb in .xyz and coverage in .w.
vec4 symbol(int k, vec2 f) {
	if (k == 0) {
		// Cherries: two red balls on crossing stems with a leaf.
		float balls = min(length(f - vec2(-0.17, -0.16)), length(f - vec2(0.17, -0.2))) - 0.16;
		float stems = min(seg_dist(f, vec2(-0.17, -0.1), vec2(0.04, 0.3)), seg_dist(f, vec2(0.17, -0.14), vec2(0.04, 0.3))) - 0.022;
		float leaf = length((f - vec2(0.15, 0.3)) * vec2(1.0, 2.2)) - 0.12;
		vec3 c = vec3(0.86, 0.06, 0.12) * (0.75 + 0.45 * smoothstep(0.1, -0.15, f.y + f.x * 0.4));
		float hi = fillv(length(f - vec2(-0.22, -0.1)) - 0.035, 0.015);
		c = mix(c, vec3(1.0, 0.8, 0.8), hi * 0.8);
		float cov = fillv(balls, 0.02);
		vec3 col = mix(vec3(0.18, 0.45, 0.12), c, cov);
		return vec4(col, max(cov, max(fillv(stems, 0.015), fillv(leaf, 0.02))));
	} else if (k == 1) {
		// Lemon: a plump ellipse with two pointed ends.
		float body = length(f * vec2(0.8, 1.35)) - 0.33;
		float tips = max(abs(f.x) - 0.42, length(vec2(f.x * 0.6, f.y * 2.4)) - 0.2);
		float d = min(body, tips);
		vec3 c = mix(vec3(1.0, 0.88, 0.15), vec3(0.95, 0.65, 0.05), smoothstep(-0.2, 0.3, f.y + f.x * 0.3));
		c = mix(c, vec3(1.0, 1.0, 0.7), fillv(length(f - vec2(-0.1, 0.1)) - 0.05, 0.03) * 0.7);
		return vec4(c, fillv(d, 0.02));
	} else if (k == 2) {
		// Bell: a golden dome, flared lip and clapper.
		float dome = length((f - vec2(0.0, 0.05)) * vec2(1.0, 1.0)) - 0.27;
		dome = max(dome, -f.y + 0.02 - 0.2 * 0.0);
		float skirt = box_sd(f - vec2(0.0, -0.1), vec2(0.34 - abs(f.y + 0.1) * 0.0, 0.11));
		skirt = max(skirt, abs(f.x) - (0.26 + (0.1 - f.y) * 0.45));
		float clap = length(f - vec2(0.0, -0.3)) - 0.08;
		float d = min(min(dome, skirt), clap);
		vec3 c = mix(vec3(1.0, 0.82, 0.2), vec3(0.8, 0.5, 0.05), smoothstep(-0.2, 0.3, -f.y - f.x * 0.5));
		c = mix(c, vec3(1.0, 0.97, 0.75), fillv(length(f - vec2(-0.1, 0.12)) - 0.05, 0.03) * 0.8);
		return vec4(c, fillv(d, 0.02));
	} else if (k == 3) {
		// BAR: a dark slab with gold edges and three white bars.
		float slab = box_sd(f, vec2(0.38, 0.19));
		vec3 c = vec3(0.1, 0.1, 0.16);
		float edge = fillv(abs(slab + 0.025) - 0.014, 0.008);
		float stripes = step(0.5, fract(f.y * 4.2 + 0.5)) * step(abs(f.x), 0.28) * step(abs(f.y), 0.14);
		c = mix(c, vec3(0.97, 0.97, 0.95), stripes * 0.9);
		c = mix(c, vec3(1.0, 0.8, 0.25), edge);
		return vec4(c, fillv(slab, 0.02));
	}
	// Seven: a fat red 7 with a white outline.
	float top = box_sd(f - vec2(0.0, 0.26), vec2(0.28, 0.06));
	float diag = seg_dist(f, vec2(0.24, 0.22), vec2(-0.1, -0.32)) - 0.065;
	float d = min(top, diag);
	vec3 c = mix(vec3(0.95, 0.1, 0.12), vec3(1.0, 0.45, 0.2), smoothstep(-0.3, 0.3, f.y));
	float outline = fillv(abs(d) - 0.022, 0.01);
	c = mix(c, vec3(1.0), outline * 0.0);
	float cov = fillv(d - 0.0, 0.012);
	float rim = fillv(d - 0.035, 0.015);
	return vec4(mix(vec3(1.0, 0.95, 0.9), c, cov), rim);
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	vec2 uv = fplane(lp, ln);
	float t = mod(TIME, cycle);
	float pull = floor(TIME / cycle);
	// Every third pull is a jackpot.
	float jackpot = step(1.5, mod(pull, 3.0));
	vec3 col;
	vec3 emit;
	float metal = 0.0;
	float rough = 0.3;
	if (is_trim) {
		// Gold chrome with marquee bulbs chasing along it.
		float grain = fnoise3(lp * 200.0);
		col = trim_color * (0.85 + 0.2 * grain);
		vec2 bc = vec2(fract(lp.z / 0.03) - 0.5, (fract((lp.y + lp.x) / 0.024)) - 0.5);
		float idx = floor(lp.z / 0.03);
		float bulb = fillv(length(bc * vec2(0.03, 0.024)) - 0.0052, 0.002);
		float chase = mix(step(0.5, fract(idx * 0.5 - TIME * 3.0)), step(0.5, fract(TIME * 6.0)), jackpot * step(4.4, t));
		float lit = bulb * (0.3 + 0.7 * chase);
		col = mix(col, vec3(1.0, 0.95, 0.7), lit);
		metal = 0.85;
		rough = 0.22;
		emit = fstudio(r, trim_color) * 0.7 + vec3(1.0, 0.85, 0.4) * lit * 1.7;
	} else {
		// Reels run along the weapon: the column is the reel, rows are symbols.
		float reel = floor(uv.x / reel_w);
		vec2 f = vec2(fract(uv.x / reel_w) - 0.5, 0.0);
		float cell_h = reel_w;
		// A reel stops at 2.4 s + 0.55 s per reel (cycled so it is staggered
		// along the weapon), easing out with a small overshoot.
		float stop_at = 1.8 + 0.5 * mod(reel, 4.0);
		float k = clamp((t - 0.2 * mod(reel, 4.0)) / stop_at, 0.0, 1.0);
		float c1 = 1.70158;
		float c3 = c1 + 1.0;
		float e = k >= 1.0 ? 1.0 : 1.0 + c3 * pow(k - 1.0, 3.0) + c1 * pow(k - 1.0, 2.0);
		float travel = (14.0 + mod(reel, 3.0) * 4.0) * (1.0 - e);
		float spinning = smoothstep(1.0, 0.6, k);
		float rowpos = uv.y / cell_h + 0.5 + travel * 1.0;
		float row = floor(rowpos);
		f.y = fract(rowpos) - 0.5;
		// Which symbol lands on row 0: sevens on a jackpot, otherwise mixed.
		float landed = mix(floor(fh21(vec2(reel, pull)) * 4.0), 4.0, jackpot);
		float id = row == 0.0 ? landed : floor(fh21(vec2(row + reel * 7.0, reel)) * 5.0);
		// Blur while spinning fast: smear the symbol vertically.
		vec2 sf = vec2(f.x, f.y * (1.0 + spinning * 0.5));
		vec4 sym = symbol(int(id), sf * 1.15);
		vec3 paper = shell_color * (0.92 + 0.08 * fh21(vec2(reel, 2.0)));
		// Reel shading: a rounded drum, dark top and bottom of each window.
		float drum = 0.55 + 0.45 * cos(clamp(f.x * 2.0, -1.0, 1.0) * 1.2);
		col = mix(paper, sym.rgb, sym.w * (1.0 - spinning * 0.4));
		col *= drum;
		float divider = smoothstep(0.43, 0.49, abs(f.x));
		col = mix(col, vec3(0.12, 0.1, 0.14), divider);
		// Win flash: a gold sweep over the reels once they have all landed.
		float won = jackpot * smoothstep(4.0, 4.3, t) * (0.6 + 0.4 * sin(TIME * 18.0));
		vec3 gold = vec3(1.0, 0.8, 0.25);
		col = mix(col, col * 0.5 + gold * 0.6, won * 0.6);
		emit = col * 0.28 + gold * won * 0.9 * sym.w + fstudio(r, vec3(1.0)) * 0.1 * (1.0 - divider);
		rough = 0.2;
	}
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = emit + vec3(1.0) * pow(fres, 4.0) * 0.08;
	PRINT_LAYER
}
