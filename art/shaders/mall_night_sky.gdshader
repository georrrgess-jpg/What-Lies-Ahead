shader_type sky;
// Midnight over the Moonbeam Galleria's dome: a deep blue gradient, three
// layers of twinkling stars, a violet haze near the horizon and a big cream
// moon with a halo. Procedural (no texture).

uniform vec3 zenith : source_color = vec3(0.02, 0.03, 0.11);
uniform vec3 horizon : source_color = vec3(0.13, 0.11, 0.32);
uniform vec3 haze : source_color = vec3(0.42, 0.22, 0.52);
uniform vec3 moon_color : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3 moon_dir = vec3(0.35, 0.78, -0.52);
uniform float moon_size = 0.06;
uniform float star_strength = 1.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float stars(vec3 dir, float scale, float threshold) {
	vec3 p = dir * scale;
	vec3 i = floor(p);
	vec3 f = fract(p) - 0.5;
	float h = hash(i);
	if (h < threshold) {
		return 0.0;
	}
	float d = length(f - (vec3(hash(i + 3.1), hash(i + 7.7), hash(i + 1.3)) - 0.5) * 0.6);
	float tw = 0.6 + 0.4 * sin(TIME * (1.0 + h * 3.0) + h * 40.0);
	return smoothstep(0.14, 0.0, d) * tw * (0.4 + 0.6 * (h - threshold) / (1.0 - threshold));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(horizon, zenith, pow(up, 0.55));
	col += haze * pow(1.0 - up, 6.0) * 0.6;
	float s = stars(d, 160.0, 0.9) + stars(d, 320.0, 0.93) * 0.7 + stars(d, 80.0, 0.965) * 1.6;
	col += vec3(0.9, 0.92, 1.0) * s * star_strength * smoothstep(-0.05, 0.25, d.y);
	vec3 md = normalize(moon_dir);
	float cosang = dot(d, md);
	float ang = acos(clamp(cosang, -1.0, 1.0));
	float disc = smoothstep(moon_size, moon_size * 0.92, ang);
	// Craters: darker blotches across the disc.
	vec3 local = d - md * cosang;
	float crater = smoothstep(0.55, 0.8, sin(local.x * 160.0 + 2.0) * sin(local.z * 130.0 + 1.0) * 0.5 + 0.5);
	col = mix(col, moon_color * (1.0 - 0.2 * crater), disc);
	col += moon_color * (0.35 * exp(-ang * 9.0) + 0.1 * exp(-ang * 2.5));
	COLOR = col;
}
