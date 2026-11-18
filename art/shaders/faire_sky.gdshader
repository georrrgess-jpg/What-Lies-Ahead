shader_type sky;

// Castle Kingdom morning: a clear royal-blue zenith over a pale, sunny horizon,
// the sun up in the east-south-east with a soft glow, and fair-weather cumulus
// drifting low round the horizon, lit cream on top and lilac-grey below. Under
// the horizon it fades to the green haze of the far hills. No textures.
uniform vec3 zenith_color : source_color = vec3(0.24, 0.5, 0.93);
uniform vec3 mid_color : source_color = vec3(0.5, 0.74, 0.98);
uniform vec3 horizon_color : source_color = vec3(0.86, 0.92, 0.98);
uniform vec3 sun_horizon : source_color = vec3(1.0, 0.93, 0.78);
uniform vec3 sun_color : source_color = vec3(1.0, 0.96, 0.86);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.99, 0.96);
uniform vec3 cloud_shade : source_color = vec3(0.74, 0.78, 0.9);
uniform vec3 below_color : source_color = vec3(0.62, 0.78, 0.6);
uniform vec3 sun_direction = vec3(0.6, 0.55, 0.58);

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
	float sun_side = pow(max(dot(flat_dir, normalize(sd.xz)), 0.0), 2.0);
	vec3 hz = mix(horizon_color, sun_horizon, sun_side * 0.6);
	vec3 col = mix(hz, mid_color, smoothstep(0.0, 0.28, el));
	col = mix(col, zenith_color, smoothstep(0.22, 0.85, el));
	// The sun: a bright disc and a wide soft glow.
	float disc = smoothstep(0.9994, 0.9997, cos_sun);
	float glow = pow(max(cos_sun, 0.0), 32.0) * 0.5 + pow(max(cos_sun, 0.0), 5.0) * 0.18;
	col += sun_color * glow;
	col = mix(col, vec3(1.0, 0.99, 0.95), disc);
	// Puffy cumulus in a band above the horizon and a few higher wisps.
	float drift = TIME * 0.006;
	vec2 uv = d.xz / max(el + 0.1, 0.04);
	float puffs = fbm(uv * 1.1 + vec2(drift * 3.0, drift));
	float bank = smoothstep(0.52, 0.66, puffs) * smoothstep(0.0, 0.06, el) * (1.0 - smoothstep(0.22, 0.5, el));
	float wisp = smoothstep(0.6, 0.8, fbm(uv * vec2(0.4, 1.8) + vec2(drift * 2.0, 3.0))) * smoothstep(0.2, 0.4, el) * (1.0 - smoothstep(0.7, 0.95, el));
	float lit = clamp(0.45 + (puffs - 0.55) * 3.0 + sun_side * 0.3, 0.0, 1.0);
	vec3 cloud = mix(cloud_shade, cloud_lit, lit) + sun_color * pow(max(cos_sun, 0.0), 10.0) * 0.3;
	col = mix(col, cloud, bank * 0.92);
	col = mix(col, cloud_lit, wisp * 0.4);
	// Below the horizon: the haze over the far green hills.
	col = mix(col, below_color, smoothstep(0.0, -0.08, el));
	COLOR = col;
}
