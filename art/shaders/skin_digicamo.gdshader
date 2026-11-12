shader_type spatial;
// Weapon finish "Digital Camo": blocky pixel camouflage in four colours,
// built from 3D pixel cells so it wraps every face without seams.
uniform vec3 shell_color : source_color = vec3(0.36, 0.45, 0.25);
uniform vec3 trim_color : source_color = vec3(0.16, 0.2, 0.12);
uniform bool is_trim = false;
uniform vec3 color_c : source_color = vec3(0.62, 0.58, 0.4);
uniform vec3 color_d : source_color = vec3(0.1, 0.12, 0.08);
uniform float pixel = 0.016;
uniform float roughness = 0.75;
uniform float metallic = 0.0;

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

void fragment() {
	// Quantise the position to pixels, then read smooth noise there: clusters of pixels.
	vec3 q = (floor(lp / pixel) + 0.5) * pixel;
	vec3 q2 = (floor(lp / (pixel * 0.5)) + 0.5) * pixel * 0.5;
	float big = vnoise(q * 9.0);
	float small = vnoise(q2 * 21.0 + 7.0);
	vec3 col = shell_color;
	if (big > 0.62) {
		col = trim_color;
	} else if (big < 0.34) {
		col = color_c;
	}
	if (small > 0.72) {
		col = color_d;
	}
	if (is_trim) {
		col = mix(col, trim_color, 0.55);
	}
	ALBEDO = col;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
