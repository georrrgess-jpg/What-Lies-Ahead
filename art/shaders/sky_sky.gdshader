shader_type sky;

// Sky Carnival sunrise: a clear blue zenith over a peach-and-gold horizon, the
// low sun in the east with soft rays, cirrus streaks and puffy cloud banks lit
// warm on the sun side and lilac in shade. Below the horizon it fades to the
// cloud sea's haze. `gale` (0..1, the Gale twist) speeds the clouds and greys
// the light a little. No textures.
uniform vec3 zenith_color : source_color = vec3(0.3, 0.6, 0.93);
uniform vec3 mid_color : source_color = vec3(0.6, 0.82, 1.0);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.84, 0.74);
uniform vec3 sun_horizon : source_color = vec3(1.0, 0.7, 0.45);
uniform vec3 far_horizon : source_color = vec3(0.86, 0.78, 0.95);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.7);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.93, 0.86);
uniform vec3 cloud_shade : source_color = vec3(0.72, 0.68, 0.86);
uniform vec3 below_color : source_color = vec3(0.98, 0.9, 0.88);
uniform vec3 sun_direction = vec3(0.92, 0.3, 0.25);
uniform float gale = 0.0;

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
	float toward = max(dot(flat_dir, normalize(sd.xz)), 0.0);
	float sun_side = pow(toward, 2.0);
	// Gradient: a warm horizon (gold toward the sun, lilac opposite), blue above.
	vec3 hz = mix(far_horizon, horizon_color, smoothstep(-0.6, 0.4, dot(flat_dir, normalize(sd.xz))));
	hz = mix(hz, sun_horizon, sun_side * 0.8);
	vec3 col = mix(hz, mid_color, smoothstep(0.0, 0.3, el));
	col = mix(col, zenith_color, smoothstep(0.25, 0.85, el));
	// The sun: disc, glow, and rays fanning from it.
	float disc = smoothstep(0.9993, 0.9997, cos_sun);
	float glow = pow(max(cos_sun, 0.0), 24.0) * 0.55 + pow(max(cos_sun, 0.0), 4.0) * 0.25;
	vec3 side = normalize(cross(sd, vec3(0.0, 1.0, 0.0)));
	vec3 upv = cross(side, sd);
	float ang = atan(dot(d, upv), dot(d, side));
	float rays = smoothstep(0.55, 0.95, noise(vec2(ang * 9.0, TIME * 0.05))) * pow(max(cos_sun, 0.0), 6.0);
	col += sun_color * (glow + rays * 0.35) * (1.0 - gale * 0.4);
	col = mix(col, vec3(1.0, 0.98, 0.9), disc);
	// Clouds on a dome: high cirrus streaks and lower puffy banks, drifting.
	float drift = TIME * (0.004 + gale * 0.03);
	vec2 uv = d.xz / max(el + 0.12, 0.04);
	float cirrus = fbm(uv * vec2(0.5, 2.6) + vec2(drift * 2.0, 0.0));
	float streak = smoothstep(0.55, 0.8, cirrus) * smoothstep(0.12, 0.35, el) * (1.0 - smoothstep(0.6, 0.95, el));
	float puffs = fbm(uv * 1.3 + vec2(drift * 3.0, drift));
	float bank = smoothstep(0.5, 0.68, puffs) * smoothstep(-0.02, 0.05, el) * (1.0 - smoothstep(0.18, 0.4, el));
	float lit = clamp(0.35 + sun_side * 0.65 + (puffs - 0.5), 0.0, 1.0);
	vec3 cloud = mix(cloud_shade, cloud_lit, lit);
	cloud += sun_color * pow(max(cos_sun, 0.0), 8.0) * 0.4;
	col = mix(col, cloud, streak * 0.55);
	col = mix(col, cloud, bank * 0.85);
	col = mix(col, col * vec3(0.86, 0.88, 0.95), gale * 0.35);
	// Below the horizon: the bright haze over the cloud sea.
	col = mix(col, mix(below_color, sun_horizon, sun_side * 0.35), smoothstep(0.0, -0.06, el));
	COLOR = col;
}
