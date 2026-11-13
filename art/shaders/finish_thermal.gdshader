shader_type spatial;
// Weapon finish "Heat Vision": the weapon seen through a thermal camera.
// A wandering heat field is mapped through a false-colour ramp (black,
// indigo, magenta, orange, yellow, white) with thin isotherm contour lines
// and faint sensor noise. Trim reads cooler.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.02, 0.0, 0.06);
uniform vec3 trim_color : source_color = vec3(0.1, 0.05, 0.4);
uniform bool is_trim = false;
uniform float scale = 6.0;
uniform float drift = 0.12;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

vec3 ironbow(float t) {
	t = clamp(t, 0.0, 1.0);
	vec3 c = mix(shell_color, vec3(0.25, 0.05, 0.6), smoothstep(0.0, 0.25, t));
	c = mix(c, vec3(0.85, 0.1, 0.55), smoothstep(0.2, 0.45, t));
	c = mix(c, vec3(1.0, 0.45, 0.05), smoothstep(0.45, 0.7, t));
	c = mix(c, vec3(1.0, 0.9, 0.2), smoothstep(0.68, 0.88, t));
	return mix(c, vec3(1.0, 1.0, 0.92), smoothstep(0.88, 1.0, t));
}

void fragment() {
	vec3 t3 = vec3(TIME * drift, TIME * drift * 0.6, -TIME * drift * 0.8);
	float heat = ffbm3(lp * scale + t3);
	// Two hot spots that wander along the weapon, like hands and a hot barrel.
	float spot = exp(-pow((lp.z + 0.25 + 0.2 * sin(TIME * 0.4)) * 6.0, 2.0)) * 0.35
		+ exp(-pow((lp.z - 0.05 - 0.15 * sin(TIME * 0.31 + 2.0)) * 7.0, 2.0)) * 0.25;
	float temp = (heat - 0.25) * 1.5 + spot - (is_trim ? 0.3 : 0.0);
	float contour = smoothstep(0.06, 0.0, abs(fract(temp * 8.0) - 0.5) - 0.44);
	float grain = (fh31(floor(lp * 400.0) + floor(TIME * 24.0)) - 0.5) * 0.05;
	vec3 col = ironbow(temp + grain) * (1.0 - contour * 0.25);
	ALBEDO = is_trim ? mix(col * 0.3, trim_color, 0.4) : col * 0.3;
	METALLIC = 0.0;
	ROUGHNESS = 0.6;
	EMISSION = col * (is_trim ? 0.8 : 1.1);
}
