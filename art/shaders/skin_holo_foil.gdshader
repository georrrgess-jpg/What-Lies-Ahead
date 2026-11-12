shader_type spatial;
// Weapon finish "Holo Foil": a rainbow sheen that shifts with the viewing angle
// and drifts slowly, with twinkling glitter flakes. Trim keeps more of its own
// colour so the two-tone read survives. Contract: scripts/player/weapon_cosmetics.gd.
uniform vec3 shell_color : source_color = vec3(0.86, 0.88, 1.0);
uniform vec3 trim_color : source_color = vec3(0.45, 0.3, 0.95);
uniform bool is_trim = false;
uniform float flake_density = 240.0;
uniform float speed = 0.22;
uniform float strength = 0.62;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec3 rainbow(float t) {
	return 0.5 + 0.5 * cos(6.28318 * (t + vec3(0.0, 0.33, 0.67)));
}

void fragment() {
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float t = dot(lp, vec3(5.0, 8.0, 3.5)) + fres * 1.4 + dot(NORMAL, vec3(0.3, 0.5, 0.2)) + TIME * speed;
	vec3 foil = rainbow(t);
	vec3 base = is_trim ? trim_color : shell_color;
	float h = hash31(floor(lp * flake_density));
	float twinkle = step(0.93, h) * pow(0.5 + 0.5 * sin(TIME * 3.5 + h * 60.0), 4.0);
	ALBEDO = mix(base, foil, is_trim ? strength * 0.5 : strength);
	METALLIC = 0.7;
	ROUGHNESS = 0.2;
	EMISSION = foil * (0.06 + fres * 0.3) + vec3(twinkle) * 1.2;
}
