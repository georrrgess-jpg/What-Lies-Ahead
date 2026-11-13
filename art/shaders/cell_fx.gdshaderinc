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
// 11 plasma, 12 snow, 13 chase, 14 pixels, 15 arcs, 16 curtains.

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
	}
	return vec4(0.0);
}
