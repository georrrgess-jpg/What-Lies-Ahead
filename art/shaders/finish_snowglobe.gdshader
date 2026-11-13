shader_type spatial;
// Weapon finish "Snow Globe": glossy navy glass with fat six-pointed flakes
// and fine snow drifting down and swaying, two depths of them, a soft glow
// near the bottom like a lit village. On the trim the snow drifts behind
// polished silver.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.04, 0.08, 0.24);
uniform vec3 trim_color : source_color = vec3(0.8, 0.82, 0.88);
uniform bool is_trim = false;
uniform vec3 glow_color : source_color = vec3(1.0, 0.75, 0.45);
uniform float fall = 0.035;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

// Snow in 3D cells of size `s` falling at `spd`: returns coverage.
float snow(float s, float spd, float seed, float star) {
	vec3 p = lp + vec3(sin(TIME * 0.7 + lp.y * 30.0) * 0.004, TIME * spd, 0.0);
	vec3 q = p / s;
	vec3 c = floor(q);
	float h = fh31(c + seed);
	vec3 f = fract(q) - (fh33(c + seed) * 0.5 + 0.25);
	float d = length(f);
	float a = atan(f.y, f.z) + h * 6.0 + TIME * (h - 0.5);
	float arms = mix(1.0, 0.55 + 0.45 * abs(cos(a * 3.0)), star);
	return step(0.35, h) * smoothstep(0.26 * arms, 0.18 * arms, d);
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 2.5);
	float big = snow(0.035, fall, 1.0, 1.0);
	float fine = snow(0.012, fall * 0.6, 9.0, 0.0);
	float flake = max(big, fine * 0.7);
	if (is_trim) {
		// Silver frame: the snow drifts past behind polished silver glass.
		ALBEDO = mix(trim_color * 0.5, vec3(0.9), flake * 0.6);
		METALLIC = 0.8;
		ROUGHNESS = 0.15;
		EMISSION = fstudio(r, trim_color) * 0.45 + vec3(0.9, 0.95, 1.0) * flake * 0.35;
	} else {
		float glow = smoothstep(0.0, -0.2, lp.y) * 0.35;
		vec3 glass = shell_color + glow_color * glow * 0.3;
		ALBEDO = mix(glass, vec3(0.95), flake);
		METALLIC = 0.0;
		ROUGHNESS = 0.06;
		EMISSION = glass * 0.3 + vec3(0.9, 0.95, 1.0) * flake * 0.6 + glow_color * glow * 0.4
			+ fstudio(r, vec3(0.5, 0.6, 0.8)) * (0.1 + 0.5 * pow(fres, 2.0));
	}
}
