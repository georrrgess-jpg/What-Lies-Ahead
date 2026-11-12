shader_type spatial;
// Weapon finish "Marble": polished stone with flowing veins in a second and
// third colour (bubblegum, mint or classic white marble), drifting slowly.
uniform vec3 shell_color : source_color = vec3(0.98, 0.94, 0.96);
uniform vec3 trim_color : source_color = vec3(1.0, 0.45, 0.72);
uniform bool is_trim = false;
uniform vec3 vein_color : source_color = vec3(0.3, 0.85, 0.85);
uniform float scale = 9.0;
uniform float drift = 0.02;

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
	return vnoise(p) * 0.5 + vnoise(p * 2.1) * 0.3 + vnoise(p * 4.3) * 0.2;
}

void fragment() {
	vec3 p = lp * scale + vec3(TIME * drift, 0.0, 0.0);
	float t = fbm(p) * 7.0;
	float v1 = 1.0 - abs(sin(p.x * 1.5 + p.y + t));
	float v2 = 1.0 - abs(sin(p.z * 1.2 - p.y * 0.8 + t * 1.3 + 2.0));
	float swirl = smoothstep(0.55, 0.95, v1);
	float vein = smoothstep(0.93, 0.99, v2);
	vec3 base = is_trim ? mix(trim_color, shell_color, 0.2) : shell_color;
	vec3 col = mix(base, trim_color, swirl * (is_trim ? 0.3 : 0.75));
	col = mix(col, vein_color, vein);
	ALBEDO = col;
	ROUGHNESS = 0.12;
	METALLIC = 0.05;
	SPECULAR = 0.8;
}
