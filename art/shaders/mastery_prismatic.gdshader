shader_type spatial;
// Prismatic mastery camo (rank 10). A rainbow that flows along the weapon,
// swirled by noise, with an iridescent sheen at grazing angles and star
// sparkles. The trim stays dark and glows with the same colours, like neon.
// hue_offset / hue_range narrow the palette (e.g. a pink-to-orange sunset).
// Contract: weapon_cosmetics.gd.
uniform vec3 shell_color : source_color = vec3(1.0);
uniform vec3 trim_color : source_color = vec3(0.1, 0.06, 0.21);
uniform bool is_trim = false;
uniform float flow_speed = 0.22;
uniform float hue_offset = 0.0;
uniform float hue_range = 1.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), u.x);
	float b = mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), u.x);
	float c = mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), u.x);
	float e = mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), u.x);
	return mix(mix(a, b, u.y), mix(c, e, u.y), u.z);
}

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

// Full rainbow wraps seamlessly; a narrower palette sweeps back and forth.
float palette_hue(float t) {
	float wave = hue_range >= 0.999 ? fract(t) : abs(fract(t * 0.5) * 2.0 - 1.0);
	return hue_offset + wave * hue_range;
}

void fragment() {
	float swirl = vnoise3(lp * 6.0 + vec3(0.0, TIME * 0.25, 0.0)) * 0.35
		+ vnoise3(lp * 17.0 - vec3(TIME * 0.15)) * 0.12;
	float t = lp.z * 4.2 + lp.y * 2.4 + lp.x * 1.2 + swirl - TIME * flow_speed;
	// Fine diagonal holo lines give the pearlescent, printed-foil look.
	float lines = 0.95 + 0.05 * sin((lp.z + lp.y) * 420.0);
	vec3 col = mix(hue(palette_hue(t)), vec3(1.0), 0.16) * shell_color * lines;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 sheen = mix(hue(palette_hue(t + 0.35 + fres * 0.6)), vec3(1.0), 0.3);

	vec3 cell = floor(lp * 80.0);
	float seed = hash3(cell);
	float star = 1.0 - smoothstep(0.08, 0.3, length(fract(lp * 80.0) - 0.5));
	float twinkle = step(0.97, seed) * star * pow(0.5 + 0.5 * sin(TIME * 3.5 + seed * 50.0), 8.0);

	if (is_trim) {
		ALBEDO = trim_color;
		EMISSION = col * 0.85 + sheen * fres * 0.8;
		ROUGHNESS = 0.35;
	} else {
		ALBEDO = col * 0.8;
		EMISSION = col * 0.32 + sheen * fres * 0.7 + vec3(1.0) * twinkle * 2.0;
		ROUGHNESS = 0.2;
	}
	METALLIC = 0.4;
	SPECULAR = 0.7;
}
