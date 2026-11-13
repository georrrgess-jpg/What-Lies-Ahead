shader_type spatial;
// Weapon finish "Thunderhead": dark storm clouds roll along the weapon; every
// second or two a forked bolt cracks across and lights the clouds around it.
// On the trim the clouds sit under wet gunmetal that catches the flash.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.1, 0.11, 0.17);
uniform vec3 trim_color : source_color = vec3(0.16, 0.17, 0.22);
uniform bool is_trim = false;
uniform vec3 bolt_color : source_color = vec3(0.7, 0.6, 1.0);
uniform float rate = 0.9;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

// One bolt series with phase offset `o`: returns (core, glow, cloud flash).
vec3 bolt(vec2 uv, float o) {
	float t = TIME * rate + o;
	float strike = floor(t);
	float age = fract(t);
	// Flickers twice in its first tenth of a cycle, then dark.
	float on = step(age, 0.1) * (0.6 + 0.4 * step(0.5, fract(age * 40.0)));
	float seed = fh21(vec2(strike, o * 13.0));
	float y0 = (seed - 0.5) * 0.18;
	float path = y0 + (fnoise2(vec2(uv.x * 14.0, strike * 3.7)) - 0.5) * 0.12
		+ (fnoise2(vec2(uv.x * 60.0, strike * 5.1)) - 0.5) * 0.03;
	float d = abs(uv.y - path);
	// A fork: a second path that splits off part-way.
	float fork_at = (fh21(vec2(strike, 2.0)) - 0.5) * 0.4;
	float fork_path = path + (uv.x - fork_at) * 0.5 * (seed > 0.5 ? 1.0 : -1.0) + (fnoise2(vec2(uv.x * 50.0, strike)) - 0.5) * 0.02;
	float df = abs(uv.y - fork_path) + step(uv.x, fork_at) * 1.0 + max(uv.x - fork_at - 0.12, 0.0) * 4.0;
	// Between strikes the path still smoulders faintly, so the bolt never quite leaves.
	float lvl = max(on, 0.12);
	float core = (smoothstep(0.004, 0.0, d) + smoothstep(0.003, 0.0, df) * 0.8) * lvl;
	float glow = (exp(-d * 60.0) + exp(-df * 80.0) * 0.6) * lvl;
	return vec3(core, glow, on * exp(-abs(uv.y - y0) * 6.0));
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	vec2 uv = fplane(lp, ln);
	vec3 b = bolt(uv, 0.0) + bolt(uv, 0.47);
	float flash = clamp(b.z, 0.0, 1.0);
	vec3 q = lp * 9.0 + vec3(0.0, 0.0, TIME * 0.15);
	float cloud = ffbm3(q + vec3(ffbm3(q * 0.7 - TIME * 0.05)));
	vec3 sky = mix(shell_color * 0.5, shell_color * 2.2 + vec3(0.03, 0.03, 0.05), smoothstep(0.3, 0.75, cloud));
	// Trim: darker clouds on wet gunmetal; the same bolts cross it.
	vec3 base = is_trim ? trim_color * 0.6 + sky * 0.4 : sky;
	ALBEDO = base;
	METALLIC = is_trim ? 0.5 : 0.1;
	ROUGHNESS = is_trim ? 0.3 : 0.55;
	EMISSION = base * 0.25 + bolt_color * cloud * flash * 0.9 + mix(bolt_color, vec3(1.0), 0.7) * b.x * 4.0 + bolt_color * b.y * 1.2
		+ (is_trim ? fstudio(r, trim_color * 2.0) * (0.2 + flash * 0.5) : vec3(0.0));
}
