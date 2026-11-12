shader_type spatial;
// Weapon finish "Galaxy": deep space with drifting nebula clouds and
// twinkling stars, sampled in the model's own space so it wraps every part.
uniform vec3 shell_color : source_color = vec3(0.04, 0.03, 0.12);
uniform vec3 trim_color : source_color = vec3(0.12, 0.08, 0.3);
uniform bool is_trim = false;
uniform vec3 nebula_a : source_color = vec3(1.0, 0.25, 0.7);
uniform vec3 nebula_b : source_color = vec3(0.2, 0.8, 1.0);
uniform float scale = 7.0;
uniform float star_density = 110.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x), mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x), mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.03) * 0.3 + vnoise(p * 4.1) * 0.15;
}

void fragment() {
	vec3 drift = vec3(0.0, 0.0, TIME * 0.04);
	float n1 = fbm(lp * scale + drift);
	float n2 = fbm(lp * scale * 1.7 - drift * 1.3 + 4.0);
	vec3 neb = nebula_a * smoothstep(0.45, 0.85, n1) + nebula_b * smoothstep(0.5, 0.9, n2) * 0.8;
	vec3 base = is_trim ? trim_color : shell_color;
	// Stars: one candidate per cell, a soft dot around a random point.
	vec3 c = lp * star_density;
	vec3 cell = floor(c);
	float h = hash31(cell);
	vec3 centre = vec3(hash31(cell + 11.0), hash31(cell + 23.0), hash31(cell + 37.0)) * 0.6 + 0.2;
	float d = length(fract(c) - centre);
	float star = step(0.82, h) * smoothstep(0.32, 0.0, d) * (0.55 + 0.45 * sin(TIME * (2.0 + h * 5.0) + h * 30.0));
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = base + neb * (is_trim ? 0.15 : 0.35);
	METALLIC = 0.35;
	ROUGHNESS = 0.3;
	EMISSION = neb * (is_trim ? 0.25 : 0.6) + vec3(star) * 2.4 + nebula_b * pow(fres, 3.0) * 0.25;
}
