shader_type canvas_item;
// Animated player-card banners (scripts/cosmetics/banner_view.gd). One shader,
// many looks picked by `style`; colours come from the banner item.
//   0 pier sunset   1 neon grid   2 high tide    3 deep space  4 aurora
//   5 confetti      6 checker     7 circuit      8 bubbles     9 golden rays
//   10 glitch       11 snowfall   12 lava lamp   13 marquee bulbs
uniform int style = 0;
uniform vec3 color_a : source_color = vec3(1.0, 0.48, 0.35);
uniform vec3 color_b : source_color = vec3(1.0, 0.25, 0.62);
uniform vec3 color_c : source_color = vec3(0.24, 0.12, 0.45);
uniform vec2 rect_size = vec2(600.0, 160.0);
uniform float radius = 18.0;
uniform float speed = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1) * 0.3 + noise(p * 4.3) * 0.15;
}

// Uniform-ish dot field: returns brightness of round dots of radius r in cells.
float dots(vec2 p, float r, float density, float seed) {
	vec2 id = floor(p);
	vec2 f = fract(p);
	float h = hash(id + seed);
	vec2 c = vec2(hash(id + seed + 3.1), hash(id + seed + 7.7)) * 0.6 + 0.2;
	return step(1.0 - density, h) * smoothstep(r, r * 0.4, length(f - c));
}

vec3 sunset(vec2 uv, vec2 p, float t) {
	vec3 sky = mix(color_b, color_c, pow(1.0 - uv.y, 1.4));
	sky = mix(sky, color_a, smoothstep(0.35, 0.75, uv.y) * 0.6);
	vec2 sun_c = vec2(p.x * 0.0 + rect_size.x / rect_size.y * 0.72, 0.62);
	float d = length(p - sun_c);
	float sun = smoothstep(0.31, 0.29, d);
	float cut = step(0.5, fract((p.y - t * 0.05) * 16.0)) * step(0.62, p.y);
	vec3 col = mix(sky, mix(vec3(1.0, 0.9, 0.45), color_a, uv.y * 1.2 - 0.2), sun * (1.0 - cut));
	col += color_a * smoothstep(0.7, 0.0, d) * 0.25;
	if (uv.y > 0.72) {
		float shimmer = step(0.6, noise(vec2(p.x * 9.0 - t * 0.5, uv.y * 50.0)));
		col = mix(color_c * 0.8, color_b * 0.6, (uv.y - 0.72) * 2.0) + shimmer * color_a * 0.4 * smoothstep(0.6, 0.0, abs(p.x - sun_c.x));
	}
	return col;
}

vec3 neon_grid(vec2 uv, float t) {
	float horizon = 0.45;
	vec3 col = mix(color_a * 1.6, color_a, abs(uv.y - horizon) * 2.0);
	col += color_b * smoothstep(0.2, 0.0, abs(uv.y - horizon)) * 0.6;
	if (uv.y > horizon) {
		float depth = 1.0 / (uv.y - horizon + 0.02);
		float gx = abs(fract((uv.x - 0.5) * depth * 1.4) - 0.5);
		float gz = abs(fract(depth * 0.6 + t * 0.6) - 0.5);
		float line = smoothstep(0.05, 0.0, gx / depth * 20.0) + smoothstep(0.06, 0.0, gz);
		col += color_c * clamp(line, 0.0, 1.0) * smoothstep(horizon, horizon + 0.25, uv.y);
	} else {
		col += vec3(dots(uv * vec2(40.0, 14.0), 0.12, 0.25, 1.0)) * 0.6;
	}
	return col;
}

vec3 tide(vec2 uv, vec2 p, float t) {
	vec3 col = mix(color_b, color_a, uv.y);
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float wave = 0.35 + fi * 0.2 + sin(p.x * (5.0 - fi) + t * (1.2 + fi * 0.4) + fi) * 0.05;
		float band = smoothstep(wave, wave + 0.02, uv.y);
		col = mix(col, mix(color_b, color_a, 0.3 + fi * 0.3), band * 0.6);
		col += color_c * smoothstep(0.012, 0.0, abs(uv.y - wave)) * 0.8;
	}
	col += color_c * dots(vec2(p.x * 7.0, p.y * 7.0 + t * 0.8), 0.25, 0.25, 4.0) * 0.6;
	return col;
}

vec3 deep_space(vec2 uv, vec2 p, float t) {
	vec3 col = color_a;
	float n = fbm(p * 2.5 + vec2(t * 0.05, 0.0));
	col += color_b * smoothstep(0.45, 0.85, n) * 0.9;
	col += color_b * 0.3 * smoothstep(0.6, 0.0, uv.y);
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 q = p * (14.0 + fi * 10.0) + vec2(t * (0.4 + fi * 0.6), fi * 7.0);
		col += color_c * dots(q, 0.14, 0.3, fi) * (0.6 + 0.4 * sin(t * 3.0 + hash(floor(q)) * 30.0));
	}
	return col;
}

vec3 aurora(vec2 uv, vec2 p, float t) {
	vec3 col = mix(color_a * 1.5, color_a * 0.6, uv.y);
	col += vec3(dots(p * 30.0, 0.1, 0.2, 2.0)) * 0.7 * (1.0 - uv.y);
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float x = p.x * (1.4 + fi * 0.5) + t * 0.15 * (1.0 + fi * 0.3);
		float curtain = 0.32 + fi * 0.12 + (fbm(vec2(x, fi * 3.0)) - 0.5) * 0.4;
		float glow = smoothstep(0.18, 0.0, abs(uv.y - curtain)) * (0.5 + 0.5 * fbm(vec2(x * 6.0, t * 0.3)));
		col += mix(color_b, color_c, fi / 2.0) * glow * 0.75;
	}
	float ridge = 0.78 + (noise(vec2(p.x * 3.0, 0.0)) - 0.5) * 0.2 + abs(fract(p.x * 1.3) - 0.5) * 0.15;
	col = mix(col, color_a * 0.35, smoothstep(ridge, ridge + 0.01, uv.y));
	return col;
}

vec3 confetti(vec2 uv, vec2 p, float t) {
	vec3 col = mix(color_a, color_a * 0.85 + color_b * 0.1, uv.y);
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		vec2 q = p * (8.0 + fi * 5.0) + vec2(sin(t + fi) * 0.4, -t * (1.2 + fi * 0.5));
		vec2 id = floor(q);
		vec2 f = fract(q) - 0.5;
		float h = hash(id + fi * 11.0);
		float a = t * (2.0 + h * 3.0) + h * 6.28;
		vec2 r = vec2(cos(a) * f.x - sin(a) * f.y, sin(a) * f.x + cos(a) * f.y);
		float piece = step(abs(r.x), 0.18) * step(abs(r.y), 0.08 + 0.06 * abs(sin(a))) * step(0.45, h);
		vec3 pc = h > 0.8 ? color_b : (h > 0.62 ? color_c : vec3(1.0, 0.85, 0.3));
		col = mix(col, pc, piece);
	}
	return col;
}

vec3 checker(vec2 uv, vec2 p, float t) {
	vec2 q = vec2(p.x + p.y * 0.5 - t * 0.25, p.y) * 7.0;
	float c = mod(floor(q.x) + floor(q.y), 2.0);
	vec3 col = mix(color_a, color_b, c);
	float band = smoothstep(0.03, 0.0, abs(uv.y - 0.5) - 0.12);
	return mix(col, color_c, band * 0.85);
}

vec3 circuit(vec2 uv, vec2 p, float t) {
	vec3 col = color_a;
	vec2 g = p * 10.0;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h1 = hash(id);
	float h2 = hash(id + 5.0);
	float tr = step(0.5, h1) * smoothstep(0.07, 0.04, abs(f.y)) + step(0.6, h2) * smoothstep(0.07, 0.04, abs(f.x));
	float pad = step(0.85, hash(id + 9.0)) * smoothstep(0.2, 0.15, length(f));
	col = mix(col, color_b, clamp(tr + pad, 0.0, 1.0));
	float pulse = pow(0.5 + 0.5 * sin((h1 > 0.5 ? g.x : g.y) * 1.3 - t * 4.0 + h1 * 6.0), 10.0);
	col += color_c * pulse * clamp(tr, 0.0, 1.0) * 1.4;
	return col;
}

vec3 bubbles(vec2 uv, vec2 p, float t) {
	vec3 col = mix(color_b, color_a, uv.y);
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 q = p * (5.0 + fi * 3.0) + vec2(sin(t * 0.7 + fi * 2.0 + p.y * 3.0) * 0.15, t * (0.6 + fi * 0.3));
		vec2 id = floor(q);
		vec2 f = fract(q) - 0.5;
		float h = hash(id + fi * 13.0);
		float r = 0.12 + h * 0.18;
		float ring = smoothstep(0.04, 0.0, abs(length(f) - r)) * step(0.4, h);
		float shine = smoothstep(0.06, 0.0, length(f + vec2(r * 0.4, r * 0.4))) * step(0.4, h);
		col += color_c * (ring * 0.7 + shine * 0.8);
	}
	return col;
}

vec3 rays(vec2 uv, vec2 p, float t) {
	vec2 c = vec2(rect_size.x / rect_size.y * 0.5, 0.5);
	vec2 d = p - c;
	float a = atan(d.y, d.x) + t * 0.25;
	float ray = step(0.0, sin(a * 12.0));
	vec3 col = mix(color_a, color_b, ray);
	col = mix(col, vec3(1.0, 0.97, 0.85), smoothstep(0.5, 0.0, length(d)) * 0.7);
	col = mix(col, color_c, smoothstep(0.6, 1.4, length(d)) * 0.6);
	float sparkle = dots(p * 18.0 + vec2(0.0, t * 0.2), 0.12, 0.15, 5.0) * (0.5 + 0.5 * sin(t * 5.0 + p.x * 20.0));
	return col + vec3(sparkle);
}

vec3 glitch(vec2 uv, vec2 p, float t) {
	float frame = floor(t * 8.0);
	float row = floor(uv.y * 18.0);
	float shift = step(0.75, hash(vec2(row, frame))) * (hash(vec2(frame, row)) - 0.5) * 0.3;
	vec2 q = vec2(p.x + shift, uv.y);
	vec3 col = color_a;
	float block = hash(floor(q * vec2(9.0, 18.0)) + frame);
	if (block > 0.86) {
		col = color_b;
	} else if (block > 0.76) {
		col = color_c;
	}
	col.r += step(0.5, fract((q.x + 0.01) * 30.0)) * 0.05;
	col *= 0.8 + 0.2 * sin(uv.y * rect_size.y * 1.5);
	col += mix(color_b, color_c, 0.5) * smoothstep(0.02, 0.0, abs(fract(uv.y - t * 0.3) - 0.5) - 0.46) * 0.5;
	return col;
}

vec3 snowfall(vec2 uv, vec2 p, float t) {
	vec3 col = mix(color_b, color_a, uv.y);
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 q = p * (6.0 + fi * 5.0) + vec2(sin(t * 0.5 + fi * 1.7 + p.y * 2.0) * 0.3, -t * (0.5 + fi * 0.35));
		col = mix(col, color_c, dots(q, 0.22 - fi * 0.04, 0.4, fi * 3.0) * (0.9 - fi * 0.2));
	}
	return col;
}

vec3 lava_lamp(vec2 uv, vec2 p, float t) {
	vec3 col = mix(color_a * 1.4, color_a, uv.y);
	float field = 0.0;
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		vec2 c = vec2(0.3 + fi * 0.55 + sin(t * 0.3 + fi) * 0.15, 0.5 + sin(t * (0.35 + fi * 0.07) + fi * 2.0) * 0.45);
		field += 0.018 / dot(p - c, p - c);
	}
	float blob = smoothstep(0.9, 1.0, field);
	col = mix(col, mix(color_b, color_c, uv.y + sin(t * 0.4) * 0.3), blob);
	col += color_b * smoothstep(0.5, 0.9, field) * 0.25 * (1.0 - blob);
	return col;
}

vec3 marquee(vec2 uv, vec2 p, float t) {
	vec3 col = color_a * (0.85 + 0.15 * step(0.5, fract(p.x * 4.0)));
	vec2 px = uv * rect_size;
	vec2 lo = vec2(13.0);
	vec2 hi = rect_size - lo;
	// Nearest point on the inset outline, then its distance round the perimeter.
	vec2 c = clamp(px, lo, hi);
	float dl = c.x - lo.x;
	float dr = hi.x - c.x;
	float dt = c.y - lo.y;
	float db = hi.y - c.y;
	float m = min(min(dl, dr), min(dt, db));
	float w = hi.x - lo.x;
	float h = hi.y - lo.y;
	float s;
	if (m == dt) { s = c.x - lo.x; }
	else if (m == dr) { s = w + (c.y - lo.y); }
	else if (m == db) { s = w + h + (hi.x - c.x); }
	else { s = 2.0 * w + h + (hi.y - c.y); }
	// Snap to bulbs and find the bulb centre.
	float spacing = 24.0;
	float k = floor(s / spacing + 0.5);
	float sb = k * spacing;
	vec2 bulb;
	if (sb < w) { bulb = vec2(lo.x + sb, lo.y); }
	else if (sb < w + h) { bulb = vec2(hi.x, lo.y + sb - w); }
	else if (sb < 2.0 * w + h) { bulb = vec2(hi.x - (sb - w - h), hi.y); }
	else { bulb = vec2(lo.x, hi.y - (sb - 2.0 * w - h)); }
	float d = length(px - bulb);
	float lit = step(0.5, fract(k / 3.0 - t * 1.6));
	col = mix(col, mix(color_b * 0.45, color_b * 1.3, lit), smoothstep(6.0, 4.5, d));
	col += color_c * smoothstep(14.0, 3.0, d) * lit * 0.5;
	return col;
}

void fragment() {
	float t = TIME * speed;
	vec2 uv = UV;
	float aspect = rect_size.x / max(rect_size.y, 1.0);
	vec2 p = vec2(uv.x * aspect, uv.y);
	vec3 col;
	if (style == 1) { col = neon_grid(uv, t); }
	else if (style == 2) { col = tide(uv, p, t); }
	else if (style == 3) { col = deep_space(uv, p, t); }
	else if (style == 4) { col = aurora(uv, p, t); }
	else if (style == 5) { col = confetti(uv, p, t); }
	else if (style == 6) { col = checker(uv, p, t); }
	else if (style == 7) { col = circuit(uv, p, t); }
	else if (style == 8) { col = bubbles(uv, p, t); }
	else if (style == 9) { col = rays(uv, p, t); }
	else if (style == 10) { col = glitch(uv, p, t); }
	else if (style == 11) { col = snowfall(uv, p, t); }
	else if (style == 12) { col = lava_lamp(uv, p, t); }
	else if (style == 13) { col = marquee(uv, p, t); }
	else { col = sunset(uv, p, t); }
	// Rounded corners.
	vec2 half_size = rect_size * 0.5;
	vec2 q = abs(uv * rect_size - half_size) - (half_size - vec2(radius));
	float sd = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	COLOR = vec4(col, clamp(0.5 - sd, 0.0, 1.0));
}
