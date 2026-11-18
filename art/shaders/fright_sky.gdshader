shader_type sky;

// Fright Fair midnight: a deep violet zenith over a plum horizon with a faint
// toxic-green glow low down, a huge full moon (soft craters, a wide halo) low
// in the north-west, twinkling stars and thin cloud wisps drifting across the
// moon. `dim` (0..1, the Lights Out twist) darkens the sky and moon a little.
// No textures.
uniform vec3 zenith_color : source_color = vec3(0.07, 0.04, 0.16);
uniform vec3 mid_color : source_color = vec3(0.16, 0.09, 0.3);
uniform vec3 horizon_color : source_color = vec3(0.33, 0.17, 0.42);
uniform vec3 glow_color : source_color = vec3(0.2, 0.55, 0.32);
uniform vec3 moon_color : source_color = vec3(0.98, 0.95, 1.0);
uniform vec3 halo_color : source_color = vec3(0.62, 0.52, 0.95);
uniform vec3 cloud_color : source_color = vec3(0.3, 0.22, 0.46);
uniform vec3 below_color : source_color = vec3(0.08, 0.05, 0.14);
uniform vec3 moon_direction = vec3(-0.45, 0.32, -0.83);
uniform float moon_size = 0.11;
uniform float dim = 0.0;

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
	vec3 md = normalize(moon_direction);
	vec2 flat_dir = normalize(d.xz + vec2(0.0001));
	float toward = max(dot(flat_dir, normalize(md.xz)), 0.0);
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.28, el));
	col = mix(col, zenith_color, smoothstep(0.22, 0.85, el));
	// A low toxic-green glow all round the horizon, stronger away from the moon.
	col += glow_color * exp(-max(el, 0.0) * 18.0) * (0.35 + 0.35 * (1.0 - toward));
	// Stars: a sparse hash grid on a dome, twinkling.
	vec2 suv = d.xz / max(el + 0.25, 0.05) * 90.0;
	vec2 cell = floor(suv);
	float star = step(0.985, hash(cell));
	vec2 off = fract(suv) - 0.5 - (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.6;
	float twinkle = 0.6 + 0.4 * sin(TIME * (1.5 + hash(cell + 1.3) * 3.0) + hash(cell) * 40.0);
	col += vec3(0.85, 0.85, 1.0) * star * smoothstep(0.12, 0.0, length(off)) * twinkle * smoothstep(0.05, 0.3, el) * 1.4;
	// The moon: a wide halo, the disc with soft craters, a crisp limb.
	float cos_m = dot(d, md);
	float ang = acos(clamp(cos_m, -1.0, 1.0));
	col += halo_color * (exp(-ang * 7.0) * 0.55 + exp(-ang * 2.2) * 0.18);
	vec3 side = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
	vec3 upv = cross(side, md);
	vec2 mp = vec2(dot(d, side), dot(d, upv)) / moon_size;
	float disc = smoothstep(1.0, 0.985, length(mp)) * step(0.0, cos_m);
	float craters = fbm(mp * 3.0 + 4.0);
	float maria = smoothstep(0.45, 0.65, fbm(mp * 1.4 + 11.0));
	vec3 moon = moon_color * (0.92 - maria * 0.18 - (craters - 0.5) * 0.12);
	moon *= 0.85 + 0.15 * (1.0 - length(mp) * 0.6);
	col = mix(col, moon * 1.6, disc);
	// Thin cloud wisps drifting across (lit violet near the moon).
	float drift = TIME * 0.006;
	vec2 cuv = d.xz / max(el + 0.15, 0.04);
	float wisps = fbm(cuv * vec2(0.7, 2.2) + vec2(drift * 3.0, drift));
	float band = smoothstep(0.55, 0.78, wisps) * smoothstep(0.02, 0.12, el) * (1.0 - smoothstep(0.5, 0.9, el));
	vec3 cloud = cloud_color + halo_color * exp(-ang * 4.0) * 0.8;
	col = mix(col, cloud, band * 0.75);
	// Below the horizon: dark hills' haze.
	col = mix(col, below_color, smoothstep(0.0, -0.08, el));
	COLOR = col * (1.0 - dim * 0.55);
}
