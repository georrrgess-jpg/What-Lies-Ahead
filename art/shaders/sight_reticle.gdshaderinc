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
// 4 star, 5 heart, 6 pixel, 7 horseshoe, 8 scope cross.

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
	} else {
		c = sr_disc(p, 0.2, aa);
	}
	return c;
}
