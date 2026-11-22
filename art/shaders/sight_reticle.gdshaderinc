// Reticle patterns of the weapon sights, shared by the lens (sight_lens.gdshader)
// and the menu preview (sight_preview.gdshader).
//
//   p   position relative to the point of aim, in reticle units, y up
//       (1.0 = the pattern's nominal radius)
//   aa  x: size of one screen pixel in the same units (anti-aliasing; lines
//       never get thinner than about a pixel, so a reticle stays readable when
//       small); y: how far the shape is grown outwards (outline, glow)
//
// Patterns (WeaponSights.PATTERNS): 0 dot, 1 ring, 2 chevron, 3 circle dot,
// 4 star, 5 heart, 6 pixel, 7 horseshoe, 8 scope cross, 9 periscope,
// 10 diamond, 11 marquee, 12 slit, 13 hex, 14 post, 15 burst, 16 ranger,
// 17 snowflake, 18 quarters, 19 invader, 20 sun, 21 flame, 22 strike,
// 23 radar (its sweep turns with TIME), 24 hazard; update 24: 25 clover,
// 26 crown, 27 spiral (turns), 28 sonar (a ping spreads), 29 orbit (two
// moons circle), 30 brackets (breathe in and out), 31 ticket, 32 skull,
// 33 tactical, 34 bolt.

float sr_fill(float d, vec2 aa) {
	return clamp(0.5 - (d - aa.y) / aa.x, 0.0, 1.0);
}

float sr_width(float w, vec2 aa) {
	return max(w, aa.x * 1.5);
}

float sr_disc(vec2 p, float r, vec2 aa) {
	return sr_fill(length(p) - max(r, aa.x * 1.2), aa);
}

float sr_ring(vec2 p, float r, float w, vec2 aa) {
	return sr_fill(abs(length(p) - r) - sr_width(w, aa) * 0.5, aa);
}

float sr_seg(vec2 p, vec2 a, vec2 b, float w, vec2 aa) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return sr_fill(length(pa - ba * h) - sr_width(w, aa) * 0.5, aa);
}

float sr_box(vec2 p, vec2 centre, vec2 half_size, vec2 aa) {
	vec2 d = abs(p - centre) - half_size;
	return sr_fill(max(d.x, d.y), aa);
}

// Signed distance to a heart with its tip at the origin, about 1 unit tall.
float sr_heart(vec2 p) {
	p.x = abs(p.x);
	if (p.y + p.x > 1.0) {
		return length(p - vec2(0.25, 0.75)) - 0.35355;
	}
	vec2 a = p - vec2(0.0, 1.0);
	vec2 b = p - 0.5 * max(p.x + p.y, 0.0);
	return sqrt(min(dot(a, a), dot(b, b))) * sign(p.x - p.y);
}

float sr_star(vec2 p, float w, vec2 aa) {
	float cover = 0.0;
	vec2 prev = vec2(0.0, 1.0);
	for (int i = 1; i <= 10; i++) {
		float a = float(i) * 0.6283185;
		float r = (i % 2 == 0) ? 1.0 : 0.45;
		vec2 next = vec2(sin(a), cos(a)) * r;
		cover = max(cover, sr_seg(p, prev, next, w, aa));
		prev = next;
	}
	return cover;
}

float sr_pixel(vec2 p, vec2 aa) {
	float cell = 0.26;
	vec2 id = floor(p / cell + 0.5);
	vec2 local = p - id * cell;
	vec2 a = abs(id);
	bool arm = (a.y < 0.5 && a.x > 1.5 && a.x < 4.5) || (a.x < 0.5 && a.y > 1.5 && a.y < 4.5);
	bool corner = a.x > 2.5 && a.x < 3.5 && a.y > 2.5 && a.y < 3.5;
	if (!(arm || corner || (a.x < 0.5 && a.y < 0.5))) {
		return 0.0;
	}
	return sr_box(local, vec2(0.0), vec2(cell * 0.43), aa);
}

// Rotates p by angle a (radians).
vec2 sr_rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// p folded into one of `n` equal slices round the origin, the slice centred on +y.
vec2 sr_fold(vec2 p, float n) {
	float slice = 6.2831853 / n;
	float a = atan(p.x, p.y);
	a = mod(a + slice * 0.5, slice) - slice * 0.5;
	return vec2(sin(a), cos(a)) * length(p);
}

float sr_periscope(vec2 p, vec2 aa) {
	vec2 q = vec2(abs(p.x), p.y);
	float c = sr_seg(q, vec2(0.28, 0.0), vec2(3.2, 0.0), 0.04, aa);
	c = max(c, sr_seg(p, vec2(0.0, -0.28), vec2(0.0, -3.0), 0.04, aa));
	c = max(c, sr_seg(p, vec2(0.0, 0.28), vec2(0.0, 1.1), 0.04, aa));
	for (int i = 1; i <= 5; i++) {
		float x = float(i) * 0.5;
		float h = (i % 2 == 0) ? 0.2 : 0.11;
		c = max(c, sr_seg(q, vec2(x, -h), vec2(x, h), 0.035, aa));
	}
	return max(c, sr_disc(p, 0.06, aa));
}

float sr_diamond(vec2 p, vec2 aa) {
	vec2 q = abs(p);
	float c = sr_seg(q, vec2(0.95, 0.0), vec2(0.0, 0.95), 0.09, aa);
	c = max(c, sr_seg(q, vec2(1.1, 0.0), vec2(1.45, 0.0), 0.06, aa));
	return max(c, sr_disc(p, 0.12, aa));
}

float sr_marquee(vec2 p, vec2 aa) {
	vec2 q = sr_fold(p, 10.0);
	float c = sr_disc(q - vec2(0.0, 1.0), 0.12, aa);
	c = max(c, sr_ring(p, 1.0, 0.025, aa) * 0.6);
	return max(c, sr_disc(p, 0.14, aa));
}

float sr_slit(vec2 p, vec2 aa) {
	// An almond (two arcs meeting at the corners) round a slit pupil.
	float r = 1.3;
	float off = 0.85;
	float almond = max(length(p - vec2(0.0, -off)) - r, length(p - vec2(0.0, off)) - r);
	float c = sr_fill(abs(almond) - sr_width(0.08, aa) * 0.5, aa);
	vec2 e = p / vec2(0.1, 0.36);
	float pupil = (length(e) - 1.0) * 0.1;
	return max(c, sr_fill(pupil, aa));
}

float sr_hex(vec2 p, vec2 aa) {
	vec2 q = sr_fold(p, 6.0);
	// One side of the hexagon (apothem 0.85), cut short of the corners.
	float c = sr_seg(q, vec2(-0.3, 0.85), vec2(0.3, 0.85), 0.09, aa);
	return max(c, sr_disc(p, 0.12, aa));
}

float sr_post(vec2 p, vec2 aa) {
	vec2 q = vec2(abs(p.x), p.y);
	float c = sr_seg(q, vec2(0.45, 0.0), vec2(6.0, 0.0), 0.24, aa);
	c = max(c, sr_seg(p, vec2(0.0, -0.32), vec2(0.0, -6.0), 0.24, aa));
	c = max(c, sr_seg(p, vec2(0.0, 0.45), vec2(0.0, 6.0), 0.04, aa));
	return c;
}

float sr_burst(vec2 p, vec2 aa) {
	vec2 q = sr_fold(p, 8.0);
	float long_ray = sr_seg(q, vec2(0.0, 0.42), vec2(0.0, 1.0), 0.09, aa);
	vec2 r = sr_fold(sr_rot(p, 0.3927), 8.0);
	float short_ray = sr_seg(r, vec2(0.0, 0.5), vec2(0.0, 0.78), 0.06, aa);
	return max(max(long_ray, short_ray), sr_disc(p, 0.12, aa));
}

float sr_ranger(vec2 p, vec2 aa) {
	vec2 q = vec2(abs(p.x), p.y);
	float c = sr_seg(q, vec2(0.22, 0.0), vec2(3.0, 0.0), 0.045, aa);
	c = max(c, sr_seg(p, vec2(0.0, 0.22), vec2(0.0, 1.4), 0.045, aa));
	c = max(c, sr_seg(p, vec2(0.0, -0.22), vec2(0.0, -2.6), 0.045, aa));
	for (int i = 1; i <= 4; i++) {
		float y = -0.5 * float(i);
		float w = 0.42 - 0.07 * float(i);
		c = max(c, sr_seg(q, vec2(0.0, y), vec2(w, y), 0.04, aa));
	}
	// Corner brackets.
	vec2 b = abs(p);
	c = max(c, sr_seg(b, vec2(0.62, 0.9), vec2(0.9, 0.9), 0.05, aa));
	c = max(c, sr_seg(b, vec2(0.9, 0.62), vec2(0.9, 0.9), 0.05, aa));
	return max(c, sr_disc(p, 0.07, aa));
}

float sr_snowflake(vec2 p, vec2 aa) {
	vec2 q = sr_fold(p, 6.0);
	q.x = abs(q.x);
	float c = sr_seg(q, vec2(0.0, 0.26), vec2(0.0, 1.05), 0.06, aa);
	c = max(c, sr_seg(q, vec2(0.0, 0.62), vec2(0.2, 0.82), 0.05, aa));
	c = max(c, sr_seg(q, vec2(0.0, 0.38), vec2(0.13, 0.51), 0.045, aa));
	return max(c, sr_disc(p, 0.1, aa));
}

float sr_quarters(vec2 p, vec2 aa) {
	vec2 q = sr_fold(p, 4.0);
	float gap = smoothstep(0.18, 0.24, abs(atan(q.x, q.y)));
	float c = sr_ring(p, 0.92, 0.08, aa) * gap;
	c = max(c, sr_seg(q, vec2(0.0, 0.5), vec2(0.0, 1.3), 0.06, aa));
	return max(c, sr_disc(p, 0.1, aa));
}

// A pixel space invader round the point of aim, with a hole and a dot at its heart.
float sr_invader(vec2 p, vec2 aa) {
	const int rows[8] = int[](260, 136, 508, 886, 2047, 1533, 1285, 216);
	float cell = 0.2;
	vec2 g = p / cell + vec2(5.5, 4.0);
	int col = int(floor(g.x));
	int row = 7 - int(floor(g.y));
	float c = sr_disc(p, 0.1, aa);
	if (col < 0 || col > 10 || row < 0 || row > 7 || (abs(col - 5) <= 1 && (row == 3 || row == 4))) {
		return c;
	}
	if (((rows[row] >> (10 - col)) & 1) == 0) {
		return c;
	}
	vec2 centre = (vec2(float(col), float(7 - row)) + 0.5 - vec2(5.5, 4.0)) * cell;
	return max(c, sr_box(p, centre, vec2(cell * 0.44), aa));
}

// A sun: a ring with eight tapered rays and a dot.
float sr_sun(vec2 p, vec2 aa) {
	float c = sr_ring(p, 0.5, 0.07, aa);
	vec2 q = sr_fold(p, 8.0);
	q.x = abs(q.x);
	c = max(c, sr_seg(q, vec2(0.0, 0.7), vec2(0.0, 1.05), 0.08, aa));
	c = max(c, sr_seg(q, vec2(0.06, 0.7), vec2(0.0, 1.05), 0.04, aa));
	return max(c, sr_disc(p, 0.1, aa));
}

// A flame outline round a dot.
float sr_flame(vec2 p, vec2 aa) {
	vec2 q = vec2(abs(p.x), p.y);
	float c = sr_seg(q, vec2(0.0, 1.2), vec2(0.24, 0.78), 0.07, aa);
	c = max(c, sr_seg(q, vec2(0.24, 0.78), vec2(0.5, 0.32), 0.07, aa));
	c = max(c, sr_seg(q, vec2(0.5, 0.32), vec2(0.56, -0.1), 0.07, aa));
	c = max(c, sr_seg(q, vec2(0.56, -0.1), vec2(0.4, -0.46), 0.07, aa));
	c = max(c, sr_seg(q, vec2(0.4, -0.46), vec2(0.0, -0.64), 0.07, aa));
	return max(c, sr_disc(p, 0.11, aa));
}

// A bowling scoresheet box with a strike's X (open at the middle) and a dot.
float sr_strike(vec2 p, vec2 aa) {
	vec2 q = abs(p);
	float c = sr_seg(q, vec2(0.0, 0.95), vec2(0.95, 0.95), 0.06, aa);
	c = max(c, sr_seg(q, vec2(0.95, 0.0), vec2(0.95, 0.95), 0.06, aa));
	c = max(c, sr_seg(q, vec2(0.3, 0.3), vec2(0.75, 0.75), 0.08, aa));
	return max(c, sr_disc(p, 0.1, aa));
}

// A radar scope: rings, ticks, a sweep that turns with a fading wake, a blip.
float sr_radar(vec2 p, vec2 aa) {
	float r = length(p);
	float c = sr_ring(p, 1.0, 0.05, aa);
	c = max(c, sr_ring(p, 0.5, 0.03, aa) * 0.6);
	vec2 q = sr_fold(p, 12.0);
	c = max(c, sr_seg(q, vec2(0.0, 0.86), vec2(0.0, 1.0), 0.04, aa));
	float sweep = TIME * 2.4;
	vec2 dir = vec2(sin(sweep), cos(sweep));
	c = max(c, sr_seg(p, dir * 0.16, dir * 0.98, 0.04, aa));
	// The wake is only part of the mark itself (aa.y = 0), not of its outline or halo.
	float behind = mod(sweep - atan(p.x, p.y), 6.2831853);
	c = max(c, (1.0 - smoothstep(0.0, 1.1, behind)) * 0.3 * step(0.16, r) * step(r, 0.98) * step(aa.y, 0.0));
	float blip = 1.0 - smoothstep(0.0, 2.5, mod(sweep - atan(0.55, 0.42), 6.2831853));
	c = max(c, sr_disc(p - vec2(0.55, 0.42), 0.07, aa) * blip);
	return max(c, sr_disc(p, 0.09, aa));
}

// A hazard triangle (point up) round a dot.
float sr_hazard(vec2 p, vec2 aa) {
	vec2 a = vec2(0.0, 1.0);
	vec2 b = vec2(0.866, -0.5);
	vec2 d = vec2(-0.866, -0.5);
	float c = max(sr_seg(p, a, b, 0.08, aa), max(sr_seg(p, b, d, 0.08, aa), sr_seg(p, d, a, 0.08, aa)));
	c = max(c, sr_seg(p, vec2(0.0, 0.2), vec2(0.0, 0.55), 0.06, aa));
	return max(c, sr_disc(p, 0.09, aa));
}

// --- update 24 ---------------------------------------------------------------

// A four-leaf clover: four heart-shaped leaves round a dot, a little stem.
float sr_clover(vec2 p, vec2 aa) {
	vec2 q = sr_fold(sr_rot(p, 0.785398), 4.0);
	float d = sr_heart((q - vec2(0.0, 0.08)) * 1.45) / 1.45;
	float c = sr_fill(abs(d) - sr_width(0.07, aa) * 0.5, aa);
	c = max(c, sr_seg(p, vec2(0.08, -0.12), vec2(0.42, -0.98), 0.07, aa));
	return max(c, sr_disc(p, 0.1, aa));
}

// A crown over the point of aim: a band and three points tipped with beads.
float sr_crown(vec2 p, vec2 aa) {
	vec2 q = vec2(abs(p.x), p.y);
	float c = sr_seg(q, vec2(0.0, 0.42), vec2(0.62, 0.42), 0.07, aa);
	c = max(c, sr_seg(q, vec2(0.62, 0.42), vec2(0.78, 1.05), 0.07, aa));
	c = max(c, sr_seg(q, vec2(0.78, 1.05), vec2(0.36, 0.72), 0.07, aa));
	c = max(c, sr_seg(q, vec2(0.36, 0.72), vec2(0.0, 1.2), 0.07, aa));
	c = max(c, sr_disc(q - vec2(0.78, 1.17), 0.08, aa));
	c = max(c, sr_disc(p - vec2(0.0, 1.32), 0.08, aa));
	c = max(c, sr_seg(q, vec2(0.0, -0.4), vec2(0.0, -1.0), 0.06, aa));
	return max(c, sr_disc(p, 0.11, aa));
}

// Three spiral arms turning slowly round a dot (TIME).
float sr_spiral(vec2 p, vec2 aa) {
	float r = length(p);
	float a = atan(p.y, p.x) + TIME * 1.3;
	float k = r * 4.0 - a * 3.0 / 6.2831853;
	float arm = abs(fract(k) - 0.5) / 4.0 * max(r, 0.2);
	float c = sr_fill(arm - sr_width(0.05, aa) * 0.5, aa) * step(0.28, r) * smoothstep(1.15, 0.95, r);
	c = max(c, sr_ring(p, 1.12, 0.05, aa));
	return max(c, sr_disc(p, 0.11, aa));
}

// Sonar: a fixed ring and dot, and a ping that spreads out and fades (TIME).
float sr_sonar(vec2 p, vec2 aa) {
	float k = fract(TIME * 0.8);
	float c = sr_ring(p, 0.55, 0.07, aa);
	c = max(c, sr_ring(p, 0.55 + k * 0.75, 0.06, aa) * (1.0 - k));
	vec2 q = abs(p);
	q = q.x > q.y ? q : q.yx;
	c = max(c, sr_seg(q, vec2(1.0, 0.0), vec2(1.4, 0.0), 0.07, aa));
	return max(c, sr_disc(p, 0.11, aa));
}

// Orbit: a planet dot in a ring, two moons going round it (TIME).
float sr_orbit(vec2 p, vec2 aa) {
	float c = sr_ring(p, 0.8, 0.04, aa) * 0.8;
	float a = TIME * 1.6;
	c = max(c, sr_disc(p - vec2(cos(a), sin(a)) * 0.8, 0.11, aa));
	c = max(c, sr_disc(p + vec2(cos(a), sin(a)) * 0.8, 0.08, aa));
	c = max(c, sr_ring(p, 0.3, 0.06, aa));
	return max(c, sr_disc(p, 0.1, aa));
}

// Four corner brackets that breathe in and out round a dot (TIME).
float sr_brackets(vec2 p, vec2 aa) {
	float s = 0.85 + 0.12 * sin(TIME * 3.0);
	vec2 q = abs(p);
	float c = sr_seg(q, vec2(s, s), vec2(s - 0.42, s), 0.08, aa);
	c = max(c, sr_seg(q, vec2(s, s), vec2(s, s - 0.42), 0.08, aa));
	return max(c, sr_disc(p, 0.12, aa));
}

// A prize ticket with notched ends round the point of aim, a dot on it.
float sr_ticket(vec2 p, vec2 aa) {
	vec2 q = abs(p);
	vec2 d = q - vec2(1.1, 0.62);
	float box = max(d.x, d.y);
	float notch = 0.26 - length(q - vec2(1.1, 0.0));
	float sd = max(box, notch);
	float c = sr_fill(abs(sd) - sr_width(0.06, aa) * 0.5, aa);
	c = max(c, sr_seg(p, vec2(0.62, -0.42), vec2(0.62, 0.42), 0.035, aa) * 0.7);
	return max(c, sr_disc(p, 0.12, aa));
}

// A little skull: the dome, two eye sockets either side of the point of aim,
// the jaw and teeth below.
float sr_skull(vec2 p, vec2 aa) {
	float dome = length(p - vec2(0.0, 0.18)) - 0.9;
	float jaw = max(abs(p.x) - 0.48, abs(p.y + 0.78) - 0.2);
	float sd = min(dome, jaw);
	sd = max(sd, -(p.y + 1.0));
	float c = sr_fill(abs(sd) - sr_width(0.06, aa) * 0.5, aa);
	vec2 q = vec2(abs(p.x), p.y);
	c = max(c, sr_ring(q - vec2(0.42, 0.12), 0.2, 0.06, aa));
	c = max(c, sr_seg(q, vec2(0.16, -0.58), vec2(0.16, -0.96), 0.04, aa));
	return max(c, sr_disc(p, 0.1, aa));
}

// A tactical cross: four bars with a gap, a T at the end of the lower bar.
float sr_tactical(vec2 p, vec2 aa) {
	vec2 q = abs(p);
	float c = sr_seg(q, vec2(0.32, 0.0), vec2(1.15, 0.0), 0.07, aa);
	c = max(c, sr_seg(p, vec2(0.0, 0.32), vec2(0.0, 1.15), 0.07, aa));
	c = max(c, sr_seg(p, vec2(0.0, -0.32), vec2(0.0, -1.3), 0.07, aa));
	c = max(c, sr_seg(q, vec2(0.0, -1.3), vec2(0.22, -1.3), 0.07, aa) * step(p.y, 0.0));
	return max(c, sr_disc(p, 0.08, aa));
}

// A lightning bolt either side of the point of aim, a dot between.
float sr_bolt(vec2 p, vec2 aa) {
	vec2 q = vec2(abs(p.x), p.y * sign(p.x + 1e-5));
	float c = sr_seg(q, vec2(0.35, 0.55), vec2(0.65, 0.05), 0.08, aa);
	c = max(c, sr_seg(q, vec2(0.65, 0.05), vec2(0.5, 0.05), 0.08, aa));
	c = max(c, sr_seg(q, vec2(0.5, 0.05), vec2(0.82, -0.55), 0.08, aa));
	c = max(c, sr_ring(p, 1.05, 0.04, aa) * 0.7);
	return max(c, sr_disc(p, 0.11, aa));
}

float sight_reticle(vec2 p, int pattern, vec2 aa) {
	float c = 0.0;
	if (pattern == 1) {
		c = max(sr_ring(p, 1.0, 0.09, aa), sr_disc(p, 0.12, aa));
		vec2 q = abs(p);
		q = q.x > q.y ? q : q.yx;
		c = max(c, sr_seg(q, vec2(1.0, 0.0), vec2(1.3, 0.0), 0.09, aa));
	} else if (pattern == 2) {
		vec2 q = vec2(abs(p.x), p.y);
		c = sr_seg(q, vec2(0.0, 0.0), vec2(0.5, -0.72), 0.14, aa);
		c = max(c, sr_seg(p, vec2(0.0, -1.05), vec2(0.0, -1.9), 0.06, aa));
		c = max(c, sr_seg(q, vec2(0.0, -1.35), vec2(0.2, -1.35), 0.06, aa));
		c = max(c, sr_seg(q, vec2(0.0, -1.9), vec2(0.13, -1.9), 0.06, aa));
	} else if (pattern == 3) {
		c = max(sr_ring(p, 0.62, 0.11, aa), sr_disc(p, 0.15, aa));
	} else if (pattern == 4) {
		c = max(sr_star(p, 0.09, aa), sr_disc(p, 0.12, aa));
	} else if (pattern == 5) {
		float d = sr_heart(p * 0.56 + vec2(0.0, 0.56)) / 0.56;
		c = max(sr_fill(abs(d) - sr_width(0.1, aa) * 0.5, aa), sr_disc(p, 0.12, aa));
	} else if (pattern == 6) {
		c = sr_pixel(p, aa);
	} else if (pattern == 7) {
		float open = smoothstep(0.55, 0.62, dot(normalize(p + vec2(0.0, 1e-5)), vec2(0.0, -1.0)));
		c = sr_ring(p, 1.0, 0.1, aa) * (1.0 - open);
		c = max(c, sr_disc(p, 0.11, aa));
		c = max(c, sr_seg(p, vec2(0.0, -0.4), vec2(0.0, -1.7), 0.06, aa));
		vec2 q = vec2(abs(p.x), p.y);
		c = max(c, sr_seg(q, vec2(0.0, -0.8), vec2(0.2, -0.8), 0.06, aa));
		c = max(c, sr_seg(q, vec2(0.0, -1.25), vec2(0.13, -1.25), 0.06, aa));
	} else if (pattern == 8) {
		vec2 q = abs(p);
		vec2 along = q.x > q.y ? q : q.yx;
		c = sr_seg(along, vec2(0.3, 0.0), vec2(60.0, 0.0), 0.035, aa);
		if (p.y < abs(p.x)) {
			c = max(c, sr_seg(along, vec2(2.6, 0.0), vec2(60.0, 0.0), 0.22, aa));
		}
		c = max(c, sr_disc(p, 0.06, aa));
		float tick = abs(fract(q.x / 0.65 + 0.5) - 0.5) * 0.65;
		if (q.x > 0.4 && q.x < 2.4) {
			c = max(c, sr_fill(max(tick - sr_width(0.035, aa) * 0.5, q.y - 0.1), aa));
		}
	} else if (pattern == 9) {
		c = sr_periscope(p, aa);
	} else if (pattern == 10) {
		c = sr_diamond(p, aa);
	} else if (pattern == 11) {
		c = sr_marquee(p, aa);
	} else if (pattern == 12) {
		c = sr_slit(p, aa);
	} else if (pattern == 13) {
		c = sr_hex(p, aa);
	} else if (pattern == 14) {
		c = sr_post(p, aa);
	} else if (pattern == 15) {
		c = sr_burst(p, aa);
	} else if (pattern == 16) {
		c = sr_ranger(p, aa);
	} else if (pattern == 17) {
		c = sr_snowflake(p, aa);
	} else if (pattern == 18) {
		c = sr_quarters(p, aa);
	} else if (pattern == 19) {
		c = sr_invader(p, aa);
	} else if (pattern == 20) {
		c = sr_sun(p, aa);
	} else if (pattern == 21) {
		c = sr_flame(p, aa);
	} else if (pattern == 22) {
		c = sr_strike(p, aa);
	} else if (pattern == 23) {
		c = sr_radar(p, aa);
	} else if (pattern == 24) {
		c = sr_hazard(p, aa);
	} else if (pattern == 25) {
		c = sr_clover(p, aa);
	} else if (pattern == 26) {
		c = sr_crown(p, aa);
	} else if (pattern == 27) {
		c = sr_spiral(p, aa);
	} else if (pattern == 28) {
		c = sr_sonar(p, aa);
	} else if (pattern == 29) {
		c = sr_orbit(p, aa);
	} else if (pattern == 30) {
		c = sr_brackets(p, aa);
	} else if (pattern == 31) {
		c = sr_ticket(p, aa);
	} else if (pattern == 32) {
		c = sr_skull(p, aa);
	} else if (pattern == 33) {
		c = sr_tactical(p, aa);
	} else if (pattern == 34) {
		c = sr_bolt(p, aa);
	} else {
		c = sr_disc(p, 0.2, aa);
	}
	return c;
}
