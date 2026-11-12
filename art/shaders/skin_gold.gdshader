shader_type spatial;
// "Prize Gold": polished gold with engraved swirls, twinkling glints and a
// shine that sweeps across every few seconds. Used by gold weapon finishes,
// gold gloves and the Arcade Champion operator (scripts/cosmetics/operators.gd).
uniform vec3 shell_color : source_color = vec3(1.0, 0.76, 0.24);
uniform vec3 trim_color : source_color = vec3(0.85, 0.5, 0.12);
uniform bool is_trim = false;
uniform float engrave = 1.0;
uniform float sweep_speed = 0.35;

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
	vec3 base = is_trim ? trim_color : shell_color;
	// Engraved scrollwork: thin grooves along warped bands.
	float warp = vnoise(lp * 14.0) * 5.0;
	float groove = smoothstep(0.88, 0.97, sin(dot(lp, vec3(40.0, 60.0, 25.0)) + warp)) * engrave;
	// A diagonal sheen that sweeps across now and then.
	float sweep = smoothstep(0.06, 0.0, abs(fract(dot(lp, vec3(0.8, 1.6, 0.6)) * 0.9 - TIME * sweep_speed) - 0.5) - 0.44);
	float h = hash31(floor(lp * 130.0));
	float glint = step(0.955, h) * pow(0.5 + 0.5 * sin(TIME * 4.0 + h * 50.0), 6.0);
	ALBEDO = base * (1.0 - groove * 0.45);
	METALLIC = 1.0;
	ROUGHNESS = 0.18 + groove * 0.3;
	EMISSION = base * (0.08 + sweep * 0.9) + vec3(1.0, 0.95, 0.8) * glint * 2.5;
}
