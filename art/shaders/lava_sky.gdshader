shader_type sky;

// Volcano Isle dusk: a magenta-to-violet sky, the afterglow of a sun just set
// in the west-south-west, the volcano's red glow on the clouds in the north,
// drifting cloud bands lit from below and the first stars. No textures.
uniform vec3 zenith_color : source_color = vec3(0.11, 0.07, 0.24);
uniform vec3 mid_color : source_color = vec3(0.42, 0.14, 0.42);
uniform vec3 horizon_color : source_color = vec3(0.95, 0.36, 0.42);
uniform vec3 glow_color : source_color = vec3(1.0, 0.62, 0.3);
uniform vec3 fire_color : source_color = vec3(1.0, 0.28, 0.12);
uniform vec3 cloud_dark : source_color = vec3(0.2, 0.09, 0.22);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.48, 0.42);
uniform vec3 below_color : source_color = vec3(0.1, 0.06, 0.16);
uniform vec3 sun_direction = vec3(-0.86, 0.05, 0.5);     // toward the afterglow
uniform vec3 fire_direction = vec3(0.0, 0.25, -1.0);     // toward the volcano
uniform float eruption = 0.0;                            // 0..1, the eruption twist

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
	vec2 flat_dir = normalize(d.xz + vec2(0.0001));
	float sun = pow(max(dot(flat_dir, normalize(sun_direction.xz)), 0.0), 3.0);
	float fire = pow(max(dot(flat_dir, normalize(fire_direction.xz)), 0.0), 4.0);
	// Base gradient: horizon band warm, rising through magenta to violet.
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.22, el));
	col = mix(col, zenith_color, smoothstep(0.18, 0.75, el));
	// Afterglow of the sun and the volcano's red glow near the horizon.
	col += glow_color * sun * (1.0 - smoothstep(0.0, 0.32, el)) * 0.85;
	col += fire_color * fire * (1.0 - smoothstep(0.0, 0.5, el)) * (0.35 + 0.65 * eruption);
	// Cloud bands, projected on a dome, drifting slowly.
	vec2 uv = d.xz / max(el + 0.18, 0.05);
	float c = fbm(uv * vec2(0.7, 2.2) + vec2(TIME * 0.006, 0.0));
	float band = smoothstep(0.48, 0.72, c) * smoothstep(0.01, 0.08, el) * (1.0 - smoothstep(0.35, 0.6, el));
	float lit = clamp(sun * 0.9 + fire * (0.6 + eruption) + 0.15, 0.0, 1.0);
	vec3 cloud = mix(cloud_dark, cloud_lit, lit * smoothstep(0.5, 0.8, c));
	col = mix(col, cloud, band * 0.85);
	// Stars, only high up and away from the glow.
	vec2 sp = floor(d.xz / max(el, 0.2) * 220.0);
	float star = step(0.9975, hash(sp)) * smoothstep(0.35, 0.7, el) * (0.6 + 0.4 * sin(TIME * 2.0 + hash(sp) * 40.0));
	col += vec3(1.0, 0.92, 0.95) * star * 0.9;
	// Below the horizon: the dark sea haze.
	col = mix(col, below_color, smoothstep(0.0, -0.08, el));
	COLOR = col;
}
