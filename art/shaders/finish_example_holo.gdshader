shader_type spatial;
// Example animated weapon finish (see scripts/player/weapon_cosmetics.gd).
// Iridescent bands that drift along the weapon, brighter on the trim.
uniform vec3 shell_color : source_color = vec3(0.9, 0.85, 1.0);
uniform vec3 trim_color : source_color = vec3(0.4, 0.2, 0.8);
uniform bool is_trim = false;
uniform float speed = 0.6;

varying vec3 lp;
void vertex() { lp = VERTEX; }

void fragment() {
	vec3 base = is_trim ? trim_color : shell_color;
	float band = 0.5 + 0.5 * sin(lp.y * 40.0 + lp.x * 25.0 - TIME * speed * 6.0);
	vec3 rainbow = 0.5 + 0.5 * cos(6.2831 * (band + vec3(0.0, 0.33, 0.67)));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = mix(base, rainbow, 0.35 + 0.3 * fres);
	METALLIC = 0.6;
	ROUGHNESS = 0.25;
	EMISSION = rainbow * fres * 0.4;
}
