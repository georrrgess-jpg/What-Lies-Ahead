shader_type sky;

// Ashfall City dusk: an ember-orange horizon under a bruised violet zenith,
// the low sun's glow through the smoke, the red underglow of the city's fires
// all round the horizon, banks of drifting smoke lit from below, and a few
// stars where the smoke breaks. No textures.
uniform vec3 zenith_color : source_color = vec3(0.1, 0.07, 0.16);
uniform vec3 mid_color : source_color = vec3(0.38, 0.14, 0.2);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.46, 0.2);
uniform vec3 sun_color : source_color = vec3(1.0, 0.72, 0.36);
uniform vec3 fire_color : source_color = vec3(1.0, 0.3, 0.1);
uniform vec3 smoke_dark : source_color = vec3(0.13, 0.08, 0.1);
uniform vec3 smoke_lit : source_color = vec3(0.95, 0.42, 0.22);
uniform vec3 below_color : source_color = vec3(0.12, 0.07, 0.07);
uniform vec3 sun_direction = vec3(0.75, 0.16, 0.62);

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
	for (int i = 0; i < 4; i++) {
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
	float sun_dot = max(dot(d, sd), 0.0);
	vec2 flat_dir = normalize(d.xz + vec2(0.0001));
	float sun_side = pow(max(dot(flat_dir, normalize(sd.xz)), 0.0), 2.0);
	// Base gradient: ember horizon, rose band, violet-black zenith.
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.2, el));
	col = mix(col, zenith_color, smoothstep(0.16, 0.7, el));
	// The fires' glow all round the horizon, pulsing slowly from place to place.
	float ang = atan(d.z, d.x);
	float flicker = 0.75 + 0.25 * sin(ang * 5.0 + TIME * 0.4) * sin(ang * 3.0 - TIME * 0.23);
	col += fire_color * (1.0 - smoothstep(0.0, 0.12, el)) * 0.45 * flicker;
	// The sun behind the smoke: a soft disc and a wide glow.
	col += sun_color * (pow(sun_dot, 600.0) * 1.6 + pow(sun_dot, 24.0) * 0.45 + sun_side * (1.0 - smoothstep(0.0, 0.35, el)) * 0.35);
	// Smoke banks on a dome, drifting, lit from below by the fires and the sun.
	vec2 uv = d.xz / max(el + 0.2, 0.05);
	float c = fbm(uv * vec2(0.8, 1.6) + vec2(TIME * 0.008, TIME * 0.003));
	float band = smoothstep(0.42, 0.7, c) * smoothstep(-0.02, 0.06, el) * (1.0 - smoothstep(0.4, 0.75, el));
	float lit = clamp(sun_side * 0.8 + (1.0 - smoothstep(0.0, 0.25, el)) * 0.5, 0.0, 1.0);
	vec3 smoke = mix(smoke_dark, smoke_lit, lit * smoothstep(0.45, 0.85, c));
	col = mix(col, smoke, band * 0.8);
	// Stars, high up where the smoke breaks.
	vec2 sp = floor(d.xz / max(el, 0.2) * 200.0);
	float star = step(0.998, hash(sp)) * smoothstep(0.45, 0.8, el) * (1.0 - band);
	col += vec3(1.0, 0.9, 0.85) * star * (0.5 + 0.5 * sin(TIME * 2.0 + hash(sp) * 40.0));
	// Below the horizon: the haze over the city.
	col = mix(col, below_color, smoothstep(0.0, -0.1, el));
	COLOR = col;
}
