shader_type sky;

// Gold Rush Gulch, high noon: a deep turquoise zenith over a pale, sun-bleached
// horizon haze, the sun high and white-gold with a hot glow, a few flat-bottomed
// cumulus puffs and a warm dusty band where the sky meets the desert. Below the
// horizon it fades to the sand-coloured haze. `dust` (0..1, the Dust Storm
// twist) turns everything to a rolling ochre haze and hides the sun's disc.
uniform vec3 zenith_color : source_color = vec3(0.13, 0.64, 0.78);
uniform vec3 mid_color : source_color = vec3(0.42, 0.82, 0.86);
uniform vec3 horizon_color : source_color = vec3(0.86, 0.93, 0.88);
uniform vec3 dust_band : source_color = vec3(1.0, 0.84, 0.64);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.78);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.98, 0.94);
uniform vec3 cloud_shade : source_color = vec3(0.7, 0.82, 0.86);
uniform vec3 below_color : source_color = vec3(0.93, 0.78, 0.6);
uniform vec3 storm_color : source_color = vec3(0.86, 0.56, 0.3);
uniform vec3 sun_direction = vec3(0.3, 0.9, 0.3);
uniform float dust = 0.0;

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
	// Gradient: pale haze at the horizon with a warm dust band, turquoise above.
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.02, 0.28, el));
	col = mix(col, zenith_color, smoothstep(0.22, 0.9, el));
	col = mix(col, dust_band, (1.0 - smoothstep(0.0, 0.09, el)) * 0.55);
	// The high sun: disc, a hot glow and a soft halo.
	float disc = smoothstep(0.9990, 0.9995, cos_sun);
	float glow = pow(max(cos_sun, 0.0), 40.0) * 0.6 + pow(max(cos_sun, 0.0), 6.0) * 0.18;
	col += sun_color * glow * (1.0 - dust * 0.7);
	col = mix(col, vec3(1.0, 0.99, 0.93), disc * (1.0 - dust));
	// Fair-weather cumulus: flat-bottomed puffs low in the sky, drifting slowly.
	float drift = TIME * (0.006 + dust * 0.05);
	vec2 uv = d.xz / max(el + 0.18, 0.05);
	float puffs = fbm(uv * 0.9 + vec2(drift * 3.0, drift));
	float base = smoothstep(0.03, 0.08, el) * (1.0 - smoothstep(0.32, 0.55, el));
	float cloud_k = smoothstep(0.56, 0.7, puffs) * base;
	float lit = clamp(0.45 + (puffs - 0.55) * 2.0 + (el - 0.1) * 1.5, 0.0, 1.0);
	vec3 cloud = mix(cloud_shade, cloud_lit, lit);
	col = mix(col, cloud, cloud_k * 0.9);
	// Below the horizon: the desert haze.
	col = mix(col, below_color, smoothstep(0.0, -0.08, el));
	// Dust storm: rolling ochre bands over everything, darker toward the ground.
	float roll = fbm(vec2(atan(d.x, d.z) * 3.0 + TIME * 0.35, el * 6.0 - TIME * 0.12));
	vec3 storm = storm_color * (0.75 + roll * 0.45) * mix(0.82, 1.08, smoothstep(-0.1, 0.6, el));
	col = mix(col, storm, dust * 0.92);
	COLOR = col;
}
