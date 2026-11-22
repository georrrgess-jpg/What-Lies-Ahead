shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

// Starlot Studios' painted flats (tools/build_endless_studio.gd), one pass,
// no textures. `scene` picks the painting:
//  0  the Western street's desert sunset: banded sky, a low sun, two rows of
//     mesas and the brush strokes of a scenic painter;
//  1  Soundstage 7's viewscreen: stars streaking out of a blue nebula
//     (the ship at warp), with scanlines;
//  2  the Monster Lot's moonlit hills: a cold sky, a hunched ridge with a
//     ruined tower on it and a band of painted mist.
// UV (0,0) is the top left of the flat (a QuadMesh's front face).
uniform int scene = 0;
uniform float strength = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// A ridge line: height (0 bottom .. 1 top) along x.
float ridge(float x, float seed, float base, float amp, float flat_tops) {
	float n = noise(vec2(x * 3.0 + seed, seed)) * 0.6 + noise(vec2(x * 9.0 - seed, seed * 2.0)) * 0.25;
	// Mesas: the ridge's tops cut flat.
	n = mix(n, floor(n * 3.0 + 0.5) / 3.0, flat_tops);
	return base + amp * n;
}

vec3 desert(vec2 uv) {
	float h = 1.0 - uv.y;
	vec3 sky = mix(vec3(0.98, 0.55, 0.22), vec3(0.42, 0.16, 0.38), smoothstep(0.25, 0.95, h));
	sky = mix(sky, vec3(1.0, 0.8, 0.42), smoothstep(0.35, 0.0, abs(h - 0.32)) * 0.5);
	// Brush strokes across the sky.
	sky *= 0.92 + 0.08 * noise(vec2(uv.x * 4.0, uv.y * 60.0));
	float sun = smoothstep(0.105, 0.095, length((uv - vec2(0.62, 0.62)) * vec2(2.4, 1.0)));
	sky = mix(sky, vec3(1.0, 0.9, 0.55), sun);
	vec3 col = sky;
	float far_ridge = ridge(uv.x, 3.0, 0.2, 0.32, 0.8);
	col = mix(col, vec3(0.62, 0.27, 0.28), step(h, far_ridge));
	float near_ridge = ridge(uv.x + 0.3, 11.0, 0.06, 0.26, 0.9);
	col = mix(col, vec3(0.42, 0.16, 0.14), step(h, near_ridge));
	col = mix(col, vec3(0.78, 0.45, 0.25), step(h, 0.07));
	return col;
}

vec3 warp(vec2 uv) {
	vec2 p = (uv - 0.5) * vec2(2.2, 1.0);
	float r = length(p);
	float a = atan(p.y, p.x);
	vec3 col = mix(vec3(0.02, 0.03, 0.1), vec3(0.1, 0.2, 0.55), smoothstep(0.9, 0.0, r) * (0.5 + 0.5 * noise(p * 3.0 + TIME * 0.05)));
	col += vec3(0.5, 0.2, 0.7) * smoothstep(0.6, 0.0, length(p - vec2(0.4, -0.15))) * 0.35;
	float lanes = 90.0;
	float lane = floor(a / TAU * lanes);
	float seed = hash(vec2(lane, 3.0));
	float t = fract(TIME * (0.25 + seed * 0.5) + seed);
	float head = t * 1.4;
	float streak = smoothstep(0.02, 0.0, abs(fract(a / TAU * lanes) - 0.5) - 0.12) * smoothstep(head - 0.25, head, r) * step(r, head);
	col += vec3(0.75, 0.88, 1.0) * streak * (0.4 + seed);
	col *= 0.9 + 0.1 * sin(uv.y * 400.0);
	return col;
}

vec3 moonlit(vec2 uv) {
	float h = 1.0 - uv.y;
	vec3 col = mix(vec3(0.16, 0.24, 0.36), vec3(0.03, 0.05, 0.12), smoothstep(0.2, 1.0, h));
	float moon_glow = smoothstep(0.5, 0.0, length((uv - vec2(0.3, 0.3)) * vec2(2.0, 1.0)));
	col += vec3(0.35, 0.5, 0.55) * moon_glow * 0.5;
	float far_ridge = ridge(uv.x, 5.0, 0.18, 0.28, 0.0);
	col = mix(col, vec3(0.06, 0.1, 0.14), step(h, far_ridge));
	// A ruined tower on the far ridge.
	float tower = step(abs(uv.x - 0.7), 0.018) * step(h, far_ridge + 0.22) + step(abs(uv.x - 0.73), 0.012) * step(h, far_ridge + 0.14);
	col = mix(col, vec3(0.05, 0.08, 0.11), clamp(tower, 0.0, 1.0));
	float near_ridge = ridge(uv.x + 0.5, 13.0, 0.04, 0.16, 0.0);
	col = mix(col, vec3(0.02, 0.04, 0.05), step(h, near_ridge));
	float mist = smoothstep(0.16, 0.0, abs(h - 0.12)) * (0.6 + 0.4 * noise(vec2(uv.x * 6.0 + TIME * 0.03, 1.0)));
	col = mix(col, vec3(0.45, 0.6, 0.6), mist * 0.45);
	return col;
}

void fragment() {
	vec3 col = scene == 1 ? warp(UV) : (scene == 2 ? moonlit(UV) : desert(UV));
	ALBEDO = col * strength;
}
