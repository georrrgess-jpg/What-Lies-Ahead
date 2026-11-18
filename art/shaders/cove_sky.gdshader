shader_type sky;

// Pirate Cove sunset: a violet zenith over coral and gold, the big sun sitting
// low over the cove mouth (south-west) with a glowing halo and long rays,
// streaky clouds lit gold on their undersides and plum in shade, and a few
// first stars high up opposite the sun. Below the horizon it fades to the
// sea haze. `barrage` (0..1, the Broadside twist) adds drifting gun smoke and
// reddens the light. No textures.
uniform vec3 zenith_color : source_color = vec3(0.2, 0.24, 0.5);
uniform vec3 mid_color : source_color = vec3(0.96, 0.56, 0.5);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.7, 0.44);
uniform vec3 sun_horizon : source_color = vec3(1.0, 0.78, 0.36);
uniform vec3 far_horizon : source_color = vec3(0.86, 0.56, 0.6);
uniform vec3 sun_color : source_color = vec3(1.0, 0.82, 0.5);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.72, 0.48);
uniform vec3 cloud_shade : source_color = vec3(0.62, 0.38, 0.48);
uniform vec3 below_color : source_color = vec3(0.86, 0.55, 0.52);
uniform vec3 sun_direction = vec3(-0.6, 0.2, 0.77);
uniform float barrage = 0.0;

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
	float el = d.y;
	vec3 sd = normalize(sun_direction);
	float cos_sun = dot(d, sd);
	vec2 flat_dir = normalize(d.xz + vec2(0.0001));
	float facing = dot(flat_dir, normalize(sd.xz));
	float sun_side = pow(max(facing, 0.0), 2.0);
	// Gradient: gold toward the sun, plum opposite, coral above, violet overhead.
	vec3 hz = mix(far_horizon, horizon_color, smoothstep(-0.7, 0.5, facing));
	hz = mix(hz, sun_horizon, sun_side * 0.85);
	vec3 col = mix(hz, mix(mid_color, horizon_color, sun_side * 0.4), smoothstep(0.0, 0.22, el));
	col = mix(col, zenith_color, smoothstep(0.2, 0.9, el));
	// Stars opposite the sun, high up.
	vec2 sp = d.xz / max(el, 0.05) * 60.0;
	float star = step(0.995, hash(floor(sp))) * smoothstep(0.35, 0.7, el) * smoothstep(0.2, -0.4, facing);
	col += vec3(1.0, 0.95, 0.85) * star * 0.8;
	// The sun: a big soft disc, halo and rays.
	float disc = smoothstep(0.9985, 0.9991, cos_sun);
	float glow = pow(max(cos_sun, 0.0), 28.0) * 0.7 + pow(max(cos_sun, 0.0), 5.0) * 0.3;
	vec3 side = normalize(cross(sd, vec3(0.0, 1.0, 0.0)));
	vec3 upv = cross(side, sd);
	float ang = atan(dot(d, upv), dot(d, side));
	float rays = smoothstep(0.55, 0.95, noise(vec2(ang * 8.0, TIME * 0.04))) * pow(max(cos_sun, 0.0), 7.0);
	col += sun_color * (glow + rays * 0.3);
	col = mix(col, vec3(1.0, 0.93, 0.7), disc);
	// Clouds: long streaks low over the sea, lit gold from below near the sun.
	float drift = TIME * 0.003;
	vec2 uv = d.xz / max(el + 0.1, 0.04);
	float streaks = fbm(uv * vec2(0.35, 1.9) + vec2(drift * 2.0, 0.0));
	float band = smoothstep(0.5, 0.72, streaks) * smoothstep(0.0, 0.06, el) * (1.0 - smoothstep(0.3, 0.6, el));
	float puffs = fbm(uv * 1.1 + vec2(drift * 3.0, drift));
	float bank = smoothstep(0.56, 0.72, puffs) * smoothstep(0.02, 0.08, el) * (1.0 - smoothstep(0.15, 0.35, el));
	float lit = clamp(0.25 + sun_side * 0.75 + (puffs - 0.5) * 0.8, 0.0, 1.0);
	vec3 cloud = mix(cloud_shade, cloud_lit, lit);
	cloud += sun_color * pow(max(cos_sun, 0.0), 10.0) * 0.6;
	col = mix(col, cloud, band * 0.7);
	col = mix(col, cloud, bank * 0.8);
	// Gun smoke in the Broadside twist.
	float smoke = smoothstep(0.45, 0.75, fbm(uv * 0.8 + vec2(TIME * 0.02, 0.0))) * smoothstep(-0.02, 0.1, el) * (1.0 - smoothstep(0.25, 0.5, el));
	col = mix(col, vec3(0.55, 0.45, 0.5), smoke * barrage * 0.6);
	col = mix(col, col * vec3(1.08, 0.86, 0.8), barrage * 0.4);
	// Below the horizon: the bright haze over the sea.
	col = mix(col, mix(below_color, sun_horizon, sun_side * 0.4), smoothstep(0.0, -0.05, el));
	COLOR = col;
}
