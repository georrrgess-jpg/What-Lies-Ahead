shader_type sky;

// Lost Temple golden-hour sky: apricot horizon haze grading to a soft teal
// zenith, a big warm sun with a glow, and sunlit cumulus banks (procedural,
// static so the radiance never re-renders). `storm` (0..1, driven by
// JungleWeather during the monsoon) rolls in a low grey-green overcast.
uniform vec3 zenith_color : source_color = vec3(0.24, 0.52, 0.62);
uniform vec3 mid_color : source_color = vec3(0.62, 0.74, 0.72);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.74, 0.46);
uniform vec3 ground_color : source_color = vec3(0.36, 0.42, 0.3);
uniform vec3 sun_color : source_color = vec3(1.0, 0.82, 0.52);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.86, 0.66);
uniform vec3 cloud_shade : source_color = vec3(0.56, 0.52, 0.58);
uniform vec3 storm_color : source_color = vec3(0.3, 0.36, 0.36);
uniform float storm : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.42;

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
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += noise(p) * a;
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 sun_dir = LIGHT0_DIRECTION;
	float sun_dot = max(dot(d, sun_dir), 0.0);
	// The horizon band warms toward the sun.
	vec2 flat_d = normalize(d.xz + vec2(1e-4));
	vec2 flat_s = normalize(sun_dir.xz + vec2(1e-4));
	float toward_sun = pow(max(dot(flat_d, flat_s), 0.0), 2.0);
	vec3 horizon = mix(horizon_color * vec3(0.86, 0.84, 0.92), horizon_color, toward_sun);
	vec3 col = mix(horizon, mid_color, smoothstep(0.0, 0.22, h));
	col = mix(col, zenith_color, smoothstep(0.18, 0.75, h));
	col = mix(col, ground_color, smoothstep(0.0, -0.12, h));
	// Sun glow and disc.
	col += sun_color * (pow(sun_dot, 9.0) * 0.55 + pow(sun_dot, 60.0) * 0.8) * (1.0 - storm);
	col = mix(col, vec3(1.0, 0.95, 0.82) * 3.0, smoothstep(0.9993, 0.9996, sun_dot) * (1.0 - storm));
	// Cumulus projected onto a flat layer overhead.
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 1.6;
		float n = fbm(uv * 0.9 + vec2(3.0, 1.0));
		float cover = mix(cloud_cover, 0.95, storm);
		float c = smoothstep(1.0 - cover, 1.0 - cover + 0.22, n) * smoothstep(0.0, 0.12, h);
		float lit = clamp(fbm(uv * 0.9 + vec2(3.0, 1.0) + sun_dir.xz * 0.25) - n + 0.55, 0.0, 1.0);
		vec3 cloud = mix(cloud_shade, cloud_lit, lit) + sun_color * pow(sun_dot, 6.0) * 0.5;
		cloud = mix(cloud, storm_color * 0.85, storm);
		col = mix(col, cloud, c * 0.92);
	}
	col = mix(col, storm_color * mix(1.05, 0.7, smoothstep(0.0, 0.5, h)), storm * 0.85);
	COLOR = col;
}
