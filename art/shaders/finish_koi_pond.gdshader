shader_type spatial;
// Weapon finish "Koi Pond": the weapon is a garden pond seen from above. Koi
// (kohaku, gold and calico) swim along it with a tail beat, casting soft
// shadows on the pond floor through dappled caustics; lily pads with pink
// lotus flowers drift on the surface and raindrop rings spread now and then.
// Trim is black urushi lacquer dusted with gold (maki-e).
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.05, 0.42, 0.45);
uniform vec3 trim_color : source_color = vec3(0.07, 0.06, 0.08);
uniform bool is_trim = false;
// How big the koi are, the lane height and the stretch of barrel one lane
// repeats over (two fish per lane).
uniform float fish_scale = 1.55;
uniform float lane_height = 0.1;
uniform float lane_length = 0.6;

varying vec3 lp;
varying vec3 ln;

// One koi in its own frame (x towards the head, metres). Returns coverage in
// .a and the scale colour in .rgb; `kind` picks the variety.
vec4 koi(vec2 p, float kind, float t, float seed) {
	// The body bends: the tail swings more than the head.
	float bend = sin(p.x * 55.0 + t * 9.0 + seed * 6.0) * 0.006 * smoothstep(0.03, -0.04, p.x);
	p.y -= bend;
	// A tapered body, round at the head.
	float along = clamp((p.x + 0.035) / 0.07, 0.0, 1.0);
	float half_w = 0.012 * sin(pow(along, 0.75) * 3.14159) + 0.0015;
	float body = smoothstep(0.0012, -0.0012, abs(p.y) - half_w) * step(-0.036, p.x) * step(p.x, 0.036);
	// Forked tail and two pectoral fins, a little see-through.
	float tx = -0.036 - p.x;
	float tail = step(0.0, tx) * step(tx, 0.024) * smoothstep(0.0012, -0.0012, abs(p.y) - (0.003 + tx * 0.6)) * step(tx * 0.45, abs(p.y) + 0.004);
	vec2 fp = vec2(p.x - 0.012, abs(p.y) - 0.013);
	fp = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * fp;
	float fin = smoothstep(1.05, 0.95, length(fp / vec2(0.008, 0.004)));
	vec3 white = vec3(0.97, 0.95, 0.92);
	vec3 orange = vec3(1.0, 0.36, 0.06);
	vec3 col;
	float patch = smoothstep(0.48, 0.56, fnoise2(p * 70.0 + seed * 13.0));
	if (kind < 0.4) {
		col = mix(white, orange, patch);
	} else if (kind < 0.7) {
		col = mix(vec3(1.0, 0.68, 0.12), vec3(1.0, 0.85, 0.35), fnoise2(p * 50.0 + seed));
	} else {
		float ink = smoothstep(0.6, 0.66, fnoise2(p * 90.0 + seed * 7.0 + 3.0));
		col = mix(mix(white, orange, patch), vec3(0.05, 0.05, 0.07), ink);
	}
	// Scales: a faint row of arcs, and the eyes.
	float scales = smoothstep(0.35, 0.5, abs(fract(p.x * 260.0 + abs(p.y) * 150.0) - 0.5));
	col *= 0.9 + 0.1 * scales;
	float eye = smoothstep(0.0016, 0.0008, length(vec2(p.x - 0.026, abs(p.y) - 0.006)));
	col = mix(col, vec3(0.02), eye * body);
	float cover = max(body, max(tail * 0.8, fin * 0.6));
	return vec4(mix(col * 0.92, col, body), cover);
}

// The fish of one lane over the point `uv`: colour and coverage.
vec4 lane_fish(vec2 uv, float lane, float t) {
	vec4 best = vec4(0.0);
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		float seed = fh21(vec2(lane, fi));
		float dir = seed < 0.5 ? 1.0 : -1.0;
		float speed = 0.03 + 0.025 * fh21(vec2(lane, fi + 4.0));
		float cu = t * speed * dir + (fi * 0.5 + seed) * lane_length;
		float du = mod(uv.x - cu + lane_length * 0.5, lane_length) - lane_length * 0.5;
		// A lazy S-shaped path up and down the lane.
		float k = 18.0;
		float ph = uv.x * k + seed * 9.0 + t * 0.4;
		float centre = (lane + 0.5) * lane_height + sin(ph) * lane_height * 0.18;
		float slope = cos(ph) * lane_height * 0.18 * k;
		vec2 d = vec2(du, uv.y - centre);
		vec2 fwd = normalize(vec2(dir, slope * dir));
		vec2 p = vec2(dot(d, fwd), dot(d, vec2(-fwd.y, fwd.x)));
		p /= fish_scale;
		if (abs(p.x) < 0.07 && abs(p.y) < 0.03) {
			vec4 f = koi(p, fh21(vec2(lane, fi + 9.0)), t, seed);
			if (f.a > best.a) {
				best = f;
			}
		}
	}
	return best;
}

vec4 fish_at(vec2 uv, float t) {
	float lane = floor(uv.y / lane_height);
	vec4 a = lane_fish(uv, lane, t);
	vec4 b = lane_fish(uv, lane + (fract(uv.y / lane_height) > 0.5 ? 1.0 : -1.0), t);
	return a.a >= b.a ? a : b;
}

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	if (is_trim) {
		// Gold dust settles in drifts over the lacquer.
		vec3 g = lp * 260.0;
		vec3 h = fh33(floor(g));
		float drift = smoothstep(0.35, 0.75, ffbm3(lp * 9.0));
		float fleck = smoothstep(0.32, 0.12, length(fract(g) - 0.5)) * step(1.0 - drift * 0.3, h.x);
		vec3 gold = vec3(1.0, 0.76, 0.33);
		ALBEDO = mix(trim_color, gold, fleck);
		METALLIC = fleck;
		ROUGHNESS = mix(0.12, 0.3, fleck);
		EMISSION = fstudio(r, vec3(0.8, 0.85, 1.0)) * (0.04 + fres * 0.4) * (1.0 - fleck)
			+ gold * fleck * (0.35 + 0.65 * pow(0.5 + 0.5 * sin(h.y * 40.0 + TIME * (1.0 + h.z)), 6.0));
		PRINT_LAYER
	} else {
		vec2 uv = fplane(lp, ln);
		float t = TIME;
		// Pond floor: deep water, dappled caustics drifting over it.
		float depth = ffbm2(uv * 9.0 + vec2(t * 0.02, 0.0));
		vec3 water = mix(shell_color * 0.45, shell_color * 1.15, depth);
		vec2 q = uv * 42.0;
		float w = 0.0;
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			q += vec2(sin(q.y * 1.3 + t * (0.7 + fi * 0.2)), cos(q.x * 1.1 - t * (0.6 + fi * 0.15))) * 0.5;
			w += abs(sin(q.x + q.y));
		}
		float caustic = smoothstep(0.5, 0.05, w / 3.0);
		vec3 col = water + vec3(0.55, 0.95, 0.85) * caustic * 0.16;
		// Fish, with their shadows a little lower on the floor.
		vec4 shadow = fish_at(uv + vec2(-0.004, 0.006), t);
		col *= 1.0 - shadow.a * 0.45;
		vec4 fish = fish_at(uv, t);
		col = mix(col, fish.rgb * (0.85 + caustic * 0.25), fish.a * 0.94);
		float glow = fish.a;
		// Raindrop rings.
		vec2 cell = floor(uv / 0.09);
		vec2 c = (cell + 0.2 + 0.6 * fh22(cell)) * 0.09;
		float life = fract(t * 0.35 + fh21(cell + 4.0));
		float ring = smoothstep(0.0025, 0.0, abs(length(uv - c) - life * 0.04)) * (1.0 - life) * step(0.55, fh21(cell + floor(t * 0.35 + fh21(cell + 4.0))));
		col += vec3(0.75, 0.95, 1.0) * ring * 0.5;
		// Lily pads drifting on top, some with a lotus.
		vec2 pc = floor(uv / 0.11);
		vec2 ph = fh22(pc + 21.0);
		if (ph.x > 0.45) {
			vec2 centre = (pc + 0.25 + 0.5 * ph) * 0.11 + vec2(sin(t * 0.15 + ph.y * 6.0), cos(t * 0.12 + ph.x * 6.0)) * 0.008;
			vec2 d = uv - centre;
			float rad = 0.022 + 0.012 * ph.y;
			float a = atan(d.y, d.x) + t * 0.05 + ph.x * 6.0;
			float notch = step(0.25, abs(mod(a, 6.2832) - 3.1416));
			float pad = smoothstep(0.0012, -0.0012, length(d) - rad) * notch;
			float veins = smoothstep(0.8, 1.0, cos(a * 9.0)) * 0.12;
			vec3 green = mix(vec3(0.12, 0.42, 0.12), vec3(0.32, 0.68, 0.2), smoothstep(rad, rad * 0.3, length(d))) + veins;
			col = mix(col, green, pad);
			glow = max(glow, pad * 0.5);
			if (ph.y > 0.55) {
				float pa = atan(d.y, d.x);
				float petals = rad * (0.32 + 0.14 * abs(cos(pa * 4.0 + 0.4)));
				float flower = smoothstep(0.001, -0.001, length(d) - petals);
				vec3 pink = mix(vec3(1.0, 0.55, 0.75), vec3(1.0, 0.92, 0.95), smoothstep(petals, 0.0, length(d)));
				pink = mix(pink, vec3(1.0, 0.85, 0.3), smoothstep(rad * 0.1, rad * 0.05, length(d)));
				col = mix(col, pink, flower);
				glow = max(glow, flower);
			}
		}
		ALBEDO = col;
		METALLIC = 0.0;
		ROUGHNESS = mix(0.08, 0.4, glow);
		SPECULAR = 0.6;
		// Wet surface: a sky reflection at grazing angles; the colours glow a
		// little so the pond reads in dark levels.
		EMISSION = col * 0.22 + fstudio(r, vec3(0.75, 0.95, 1.0)) * fres * 0.4 * (1.0 - glow * 0.6);
		PRINT_LAYER
	}
}
