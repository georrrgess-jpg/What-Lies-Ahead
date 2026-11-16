// Moving patterns of the energy-cell cosmetics (params.fx), shared by the
// pattern pass drawn over a weapon's cell (cell_fx.gdshader) and the Locker
// icon (cell_icon.gdshader), so both show the same animation.
//
//   p     position on the cell; the shorter side spans 0-1, y up
//   span  the cell's extent in the same units (x across, y up)
//   t     time in seconds
//   a, b  the item's colours: a = the cell's own glow, b = the pattern's
// Returns the pattern's colour and coverage (alpha) to lay over the glow.
//
// Patterns (WeaponCosmetics.CELL_FX): 1 bubbles, 2 lava, 3 stripes,
// 4 rainbow, 5 siren, 6 scan, 7 sparkle, 8 caustics, 9 slosh, 10 warp,
// 11 plasma, 12 snow, 13 chase, 14 pixels, 15 arcs, 16 curtains,
// 17 arcade, 18 kintsugi, 19 koi.

float cfx_hash(vec2 q) {
	return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 cfx_hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

// Soft edge of a shape whose signed distance is d (in cell units).
float cfx_fill(float d, float soft) {
	return clamp(0.5 - d / soft, 0.0, 1.0);
}

// Rings rising through a grid of cells; `rise` > 0 goes up, < 0 falls.
vec4 cfx_rising(vec2 p, float t, float rise, float cell, vec3 col, bool ring) {
	vec2 q = vec2(p.x, p.y - t * rise) / cell;
	vec2 id = floor(q);
	float r = cfx_hash(id);
	if (r < 0.35) {
		return vec4(0.0);
	}
	vec2 centre = vec2(0.25 + 0.5 * cfx_hash(id + 3.1), 0.5) + vec2(sin(t * 2.0 + r * 6.3) * 0.12, 0.0);
	float rad = 0.16 + 0.16 * cfx_hash(id + 7.7);
	float d = length(q - id - centre) - rad;
	float k = ring ? cfx_fill(abs(d) - 0.06, 0.08) + cfx_fill(length(q - id - centre + rad * 0.35) - rad * 0.25, 0.08) : cfx_fill(d, 0.1);
	return vec4(col, clamp(k, 0.0, 1.0) * 0.95);
}

// How far the glow under a pattern is dimmed so light marks on it stand out
// (bubbles, glints, snow, streaks, arcs, ripples, a scanning band, bulbs).
float cell_fx_dim(int fx) {
	if (fx == 17 || fx == 18) {
		return 0.85;
	}
	return (fx == 1 || fx == 6 || fx == 7 || fx == 8 || fx == 10 || fx == 12 || fx == 13 || fx == 15) ? 0.55 : 0.0;
}

// Arcade: a pixel chomper eats its way along a row of pellets, a ghost on
// its tail; the pellets come back once both have passed.
vec4 cfx_arcade(float along, float across, float len, float wide, float t) {
	float px = wide / 7.0;
	float gx = floor(along / px);
	float gy = floor(across / px) - 3.0;
	float run = len / px + 16.0;
	float head = mod(t * 9.0, run) - 4.0;
	float ghost = head - 7.0;
	float dx = gx - head;
	// The chomper: a pixel disc with a mouth that opens and shuts.
	float open = step(0.5, fract(t * 6.0));
	bool chomp = dx * dx + gy * gy <= 7.0 && !(open > 0.5 && dx > 0.0 && abs(gy) <= dx);
	// The ghost: a dome and a wavy skirt, with two eyes.
	float gdx = gx - ghost;
	bool body = abs(gdx) <= 2.0 && gy <= 2.0 && gy >= -2.0 && !(gy == 2.0 && abs(gdx) == 2.0)
		&& !(gy == -2.0 && mod(gdx + floor(t * 6.0), 2.0) < 1.0);
	bool eye = gy == 1.0 && (gdx == -1.0 || gdx == 1.0);
	bool pellet = gy == 0.0 && mod(gx, 2.0) < 1.0 && (gx > head + 2.0 || gx < ghost - 3.0);
	vec2 f = fract(vec2(along, across) / px) - 0.5;
	float sq = cfx_fill(max(abs(f.x), abs(f.y)) - 0.42, 0.08);
	if (chomp) {
		return vec4(vec3(1.0, 0.92, 0.15), sq);
	} else if (eye) {
		return vec4(vec3(1.0), sq);
	} else if (body) {
		return vec4(vec3(0.3, 0.95, 1.0), sq);
	} else if (pellet) {
		return vec4(vec3(1.0, 0.85, 0.75), cfx_fill(max(abs(f.x), abs(f.y)) - 0.22, 0.08));
	}
	return vec4(0.0);
}

// Kintsugi: dark glaze cracked by gold seams, molten light running through them.
vec4 cfx_kintsugi(vec2 p, float t, vec3 b) {
	vec2 q = p * 3.2 + vec2(sin(p.y * 9.0), cos(p.x * 8.0)) * 0.06;
	vec2 i = floor(q);
	vec2 f = fract(q);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(cfx_hash(i + g), cfx_hash(i + g + 7.3));
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = cfx_hash(i + g + 2.1);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float edge = sqrt(d2) - sqrt(d1);
	float seam = cfx_fill(edge - 0.07, 0.05);
	float molten = pow(max(sin(p.y * 5.0 + p.x * 2.0 - t * 2.4 + id * 6.283), 0.0), 8.0);
	vec3 gold = mix(b, vec3(1.0, 0.95, 0.75), molten);
	vec3 glaze = vec3(0.04, 0.06, 0.16) + vec3(0.05, 0.08, 0.2) * cfx_hash(i + 4.0);
	return vec4(mix(glaze, gold, seam), 0.9 + seam * 0.1);
}

// Koi: two koi circling each other round the middle of the cell, ripples
// spreading behind them.
vec4 cfx_koi(vec2 p, vec2 span, float t, vec3 b) {
	vec2 c = span * 0.5;
	float rad = min(span.x, span.y) * 0.3;
	vec4 o = vec4(0.0);
	for (int i = 0; i < 2; i++) {
		float a = t * 1.1 + float(i) * 3.14159;
		vec2 at = c + vec2(cos(a), sin(a)) * rad;
		vec2 fwd = vec2(-sin(a), cos(a));
		vec2 d = p - at;
		vec2 l = vec2(dot(d, fwd), dot(d, vec2(-fwd.y, fwd.x)));
		l.y -= sin(l.x * 9.0 + t * 8.0) * 0.04 * step(l.x, 0.0);
		float body = cfx_fill(length(l / vec2(0.3, 0.1)) - 1.0, 0.25);
		float tail = cfx_fill(abs(l.y) - (-0.28 - l.x) * 0.7, 0.03) * step(-0.46, l.x) * step(l.x, -0.26);
		vec3 col = i == 0 ? mix(vec3(1.0, 0.97, 0.92), vec3(1.0, 0.38, 0.08), step(0.0, l.x) * step(abs(l.y), 0.07)) : vec3(1.0, 0.62, 0.12);
		float k = max(body, tail * 0.8);
		o = mix(o, vec4(col, 1.0), k);
	}
	float ring = cfx_fill(abs(length(p - c) - fract(t * 0.4) * rad * 2.2) - 0.015, 0.03) * (1.0 - fract(t * 0.4));
	vec3 water = mix(b * 0.35, b * 0.8, 0.5 + 0.5 * sin(p.x * 7.0 + p.y * 5.0 + t));
	vec3 rgb = mix(water + vec3(0.6, 0.9, 1.0) * ring * 0.5, o.rgb, o.a);
	return vec4(rgb, 0.85 + o.a * 0.15);
}

vec4 cell_fx(int fx, vec2 p, vec2 span, float t, vec3 a, vec3 b) {
	bool tall = span.y > span.x;
	float along = tall ? p.y : p.x;
	float across = tall ? p.x : p.y;
	float len = tall ? span.y : span.x;
	if (fx == 1) {
		return cfx_rising(p, t, 0.55, 0.42, b, true);
	} else if (fx == 2) {
		// Lava lamp: soft blobs drifting up and down, merging.
		float f = 0.0;
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			vec2 c = vec2(span.x * (0.2 + 0.6 * fract(fi * 0.37 + 0.1)) + sin(t * 0.7 + fi * 2.1) * 0.12,
					span.y * (0.5 + 0.5 * sin(t * (0.35 + fi * 0.07) + fi * 1.7)));
			f += 0.045 / max(dot(p - c, p - c), 1e-4);
		}
		float blob = smoothstep(0.85, 1.15, f);
		return vec4(mix(b, vec3(1.0, 0.95, 0.8), smoothstep(1.6, 3.5, f) * 0.5), blob * 0.95);
	} else if (fx == 3) {
		float s = fract((along + across * 0.8) * 2.2 - t * 1.1);
		return vec4(b, cfx_fill(abs(s - 0.5) - 0.24, 0.05) * 0.95);
	} else if (fx == 4) {
		vec3 c = cfx_hue(fract(along * 0.9 / max(len, 1.0) * 2.0 - t * 0.45));
		return vec4(mix(c, vec3(1.0), 0.15), 0.9);
	} else if (fx == 5) {
		// Light bar: the two halves swap colours, with a double flash each beat.
		bool first = along < len * 0.5;
		float beat = fract(t * 1.6);
		bool swap = beat < 0.5;
		vec3 c = (first != swap) ? a : b;
		float flash = step(0.25, fract(beat * 4.0)) * 0.6 + 0.4;
		return vec4(c * flash, 0.92);
	} else if (fx == 6) {
		float c = (0.5 + 0.5 * sin(t * 2.4)) * len;
		float d = along - c;
		float band = exp(-d * d / 0.05);
		return vec4(mix(b, vec3(1.0), band * 0.5), clamp(band * 1.2, 0.0, 0.95) + 0.25);
	} else if (fx == 7) {
		vec2 cell = vec2(0.5);
		vec2 id = floor(p / cell);
		vec2 q = p / cell - id - 0.5;
		float life = fract(t * 0.8 + cfx_hash(id) * 7.0);
		float k = sin(life * 3.14159) * step(0.45, cfx_hash(id + 1.3));
		q += (vec2(cfx_hash(id + 2.0), cfx_hash(id + 5.0)) - 0.5) * 0.4;
		float star = max(cfx_fill(abs(q.x) * 8.0 + abs(q.y) * 1.2 - 0.45 * k, 0.15),
				cfx_fill(abs(q.y) * 8.0 + abs(q.x) * 1.2 - 0.45 * k, 0.15));
		return vec4(mix(b, vec3(1.0), 0.4), star * k);
	} else if (fx == 8) {
		vec2 q = p * 3.0;
		float w = 0.0;
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			q += vec2(sin(q.y * 1.3 + t * (0.9 + fi * 0.3)), cos(q.x * 1.1 - t * (0.8 + fi * 0.2))) * 0.45;
			w += abs(sin(q.x + q.y));
		}
		float web = smoothstep(0.55, 0.05, w / 3.0);
		return vec4(mix(b, vec3(1.0), web * 0.4), web * 0.9);
	} else if (fx == 9) {
		// Liquid sloshing in a half-full cell: dark glass above the surface.
		float level = span.y * 0.55 + sin(along * 4.0 - t * 2.6) * 0.12 * sin(t * 0.9) + sin(along * 7.0 + t * 3.7) * 0.04;
		float d = p.y - level;
		float surface = cfx_fill(abs(d) - 0.04, 0.05);
		vec4 bub = cfx_rising(p, t, 0.4, 0.35, mix(b, vec3(1.0), 0.5), false) * step(d, -0.08);
		vec4 o = d > 0.0 ? vec4(a * 0.12, 0.88) : vec4(b, 0.55);
		o = mix(o, vec4(bub.rgb, 1.0), bub.a * 0.8);
		return mix(o, vec4(mix(b, vec3(1.0), 0.6), 1.0), surface);
	} else if (fx == 10) {
		float row = floor(across / 0.18);
		float speed = 1.5 + 2.5 * cfx_hash(vec2(row, 1.0));
		float x = fract(along / max(len, 1.0) * 0.8 - t * speed * 0.4 + cfx_hash(vec2(row, 4.0)));
		float streak = smoothstep(0.0, 0.25, x) * step(x, 0.3) * step(0.4, cfx_hash(vec2(row, 9.0)));
		float lane = cfx_fill(abs(fract(across / 0.18) - 0.5) - 0.12, 0.12);
		return vec4(mix(b, vec3(1.0), 0.6), clamp(streak * lane * 1.5, 0.0, 1.0));
	} else if (fx == 11) {
		float v = sin(p.x * 5.0 + t * 2.3) + sin(p.y * 6.0 - t * 3.1) + sin((p.x + p.y) * 4.0 + t * 1.7)
				+ sin(length(p - span * 0.5) * 8.0 - t * 4.0);
		v = 0.5 + v * 0.125;
		return vec4(mix(b, vec3(1.0), smoothstep(0.55, 0.9, v)), smoothstep(0.3, 0.75, v) * 0.85);
	} else if (fx == 12) {
		vec2 q = p + vec2(sin(t * 0.8 + p.y * 3.0) * 0.05, 0.0);
		return cfx_rising(q, t, -0.35, 0.3, vec3(1.0), false) * vec4(1.0, 1.0, 1.0, 0.9);
	} else if (fx == 13) {
		// Marquee: bulbs in a row, every third lit, chasing along.
		float spacing = 0.42;
		float k = floor(along / spacing);
		float d = length(vec2(along - (k + 0.5) * spacing, across - (tall ? span.x : span.y) * 0.5));
		float lit = step(mod(k - floor(t * 7.0), 3.0), 0.5);
		float bulb = cfx_fill(d - 0.15, 0.06);
		return vec4(mix(a * 0.25, mix(b, vec3(1.0), 0.35), lit), bulb * 0.95);
	} else if (fx == 14) {
		vec2 id = floor(p / 0.25);
		float r = cfx_hash(id + floor(t * 5.0) * 0.731);
		float on = step(0.55, r);
		float edge = max(abs(fract(p.x / 0.25) - 0.5), abs(fract(p.y / 0.25) - 0.5));
		vec3 c = r > 0.82 ? vec3(1.0) : b;
		return vec4(c, on * cfx_fill(edge - 0.4, 0.04) * 0.95);
	} else if (fx == 15) {
		float glow = 0.0;
		for (int i = 0; i < 2; i++) {
			float fi = float(i);
			float tick = floor(t * 14.0 + fi * 3.0);
			float x = along * 6.0;
			float n = mix(cfx_hash(vec2(floor(x), tick + fi)), cfx_hash(vec2(floor(x) + 1.0, tick + fi)), fract(x));
			float y = (tall ? span.x : span.y) * (0.25 + 0.5 * n);
			float on = step(0.3, cfx_hash(vec2(tick, fi + 11.0)));
			glow = max(glow, cfx_fill(abs(across - y) - 0.025, 0.05) * on);
		}
		return vec4(mix(b, vec3(1.0), glow * 0.6), glow);
	} else if (fx == 16) {
		float wave = sin(along * 5.0 + sin(t * 0.7 + along * 2.0) * 2.0 + t * 0.9);
		float curtain = smoothstep(0.2, 1.0, wave) * (0.6 + 0.4 * sin(across * 9.0 + t * 2.0));
		return vec4(mix(b, vec3(1.0), curtain * 0.3), curtain * 0.85);
	} else if (fx == 17) {
		return cfx_arcade(along, across, len, tall ? span.x : span.y, t);
	} else if (fx == 18) {
		return cfx_kintsugi(p, t, b);
	} else if (fx == 19) {
		return cfx_koi(p, span, t, b);
	}
	return vec4(0.0);
}

// The pattern over a glow of colour `a`, dimmed where the pattern is clear.
vec4 cell_fx_over(int fx, vec2 p, vec2 span, float t, vec3 a, vec3 b) {
	vec4 o = cell_fx(fx, p, span, t, a, b);
	float dim = cell_fx_dim(fx);
	vec3 rgb = mix(a * 0.3, o.rgb, clamp(o.a, 0.0, 1.0));
	return vec4(rgb, max(clamp(o.a, 0.0, 1.0), dim));
}
