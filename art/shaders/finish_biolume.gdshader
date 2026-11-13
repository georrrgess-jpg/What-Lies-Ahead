shader_type spatial;
// Weapon finish "Bioluminescence": abyss-navy skin with plankton sparks
// drifting through it and soft jelly glows that breathe in and out, over
// faint wavering currents. The trim adds rows of photophores (glowing dots)
// like a lanternfish.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.01, 0.04, 0.1);
uniform vec3 trim_color : source_color = vec3(0.01, 0.02, 0.04);
uniform bool is_trim = false;
uniform vec3 glow_a : source_color = vec3(0.1, 0.95, 1.0);
uniform vec3 glow_b : source_color = vec3(0.75, 0.25, 1.0);

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	// Plankton: a sparse 3D grid of tiny sparks drifting slowly.
	vec3 q = (lp + vec3(0.0, TIME * 0.006, TIME * 0.012)) * 70.0;
	vec3 cell = floor(q);
	float h = fh31(cell);
	vec3 centre = fh33(cell) * 0.6 + 0.2;
	float spark = step(0.78, h) * smoothstep(0.25, 0.0, length(fract(q) - centre))
		* (0.7 + 0.3 * sin(TIME * (1.0 + h * 3.0) + h * 40.0));
	// Jelly glows: larger soft spots that swell and fade.
	vec3 jq = lp * 9.0 + vec3(0.0, TIME * 0.05, 0.0);
	vec3 jc = floor(jq);
	float jh = fh31(jc + 5.0);
	float jd = length(fract(jq) - (fh33(jc) * 0.5 + 0.25));
	float breathe = 0.5 + 0.5 * sin(TIME * 0.9 + jh * 20.0);
	float jelly = step(0.55, jh) * smoothstep(0.35, 0.0, jd) * breathe;
	vec3 jcol = mix(glow_a, glow_b, step(0.8, jh));
	// Currents: thin wavering lines of faint light.
	float cur = fnoise3(lp * vec3(6.0, 14.0, 4.0) + vec3(TIME * 0.1, 0.0, TIME * 0.05));
	float current = smoothstep(0.03, 0.0, abs(cur - 0.5)) * 0.2;
	vec3 life = glow_a * spark * 2.2 + jcol * jelly * 1.3 + glow_a * current * 1.5;
	if (is_trim) {
		// Photophores: glowing dots on a 3 cm grid (about half lit), pulsing in a wave.
		vec2 uv = fplane(lp, ln);
		float s = 0.03;
		vec2 f = vec2(fract(uv.x / s) - 0.5, (uv.y - (floor(uv.y / s) + 0.5) * s) / s);
		float id = floor(uv.x / s);
		float dotm = smoothstep(0.2, 0.1, length(f)) * step(0.55, fh21(floor(uv / s)));
		float pulse = 0.5 + 0.5 * sin(TIME * 2.0 - id * 0.6);
		ALBEDO = trim_color + jcol * jelly * 0.05;
		METALLIC = 0.3;
		ROUGHNESS = 0.2;
		EMISSION = life * 0.5 + glow_a * dotm * (0.4 + 1.6 * pulse) + fstudio(r, vec3(0.15, 0.3, 0.4)) * 0.15;
	} else {
		ALBEDO = shell_color + jcol * jelly * 0.1;
		METALLIC = 0.1;
		ROUGHNESS = 0.2;
		EMISSION = life + shell_color * 0.4 + glow_a * pow(fres, 3.0) * 0.15;
	}
}
