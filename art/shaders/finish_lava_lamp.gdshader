shader_type spatial;
// Weapon finish "Groovy Lamp": glowing wax blobs rise, stretch, split and
// merge through violet liquid, brighter at their rims. On the trim they glow
// through smoked chrome glass.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.22, 0.04, 0.3);
uniform vec3 trim_color : source_color = vec3(0.75, 0.72, 0.8);
uniform bool is_trim = false;
uniform vec3 wax_color : source_color = vec3(1.0, 0.36, 0.2);
uniform vec3 wax_hot : source_color = vec3(1.0, 0.82, 0.3);
uniform float rise = 0.06;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 2.0);
	// Blobs: a slow 3D noise field squashed sideways and rising; the
	// threshold gives round, merging shapes.
	vec3 q = vec3(lp.x * 16.0, (lp.y - TIME * rise) * 11.0, lp.z * 16.0);
	float f = fnoise3(q) * 0.7 + fnoise3(q * 2.1 + vec3(0.0, TIME * 0.2, 0.0)) * 0.3;
	float blob = smoothstep(0.56, 0.6, f);
	float rim = smoothstep(0.56, 0.6, f) - smoothstep(0.6, 0.7, f);
	float glow_core = smoothstep(0.6, 0.8, f);
	vec3 wax = mix(wax_color, wax_hot, glow_core);
	vec3 liquid = shell_color * (0.7 + 0.5 * fnoise3(lp * 4.0 + TIME * 0.05));
	vec3 lit = wax * blob * (0.9 + rim * 0.8) + wax_color * (1.0 - blob) * smoothstep(0.4, 0.56, f) * 0.35;
	if (is_trim) {
		// Smoked chrome glass: darker liquid, the wax glowing through.
		ALBEDO = mix(liquid * 0.4, wax * 0.5, blob);
		METALLIC = 0.6;
		ROUGHNESS = 0.1;
		EMISSION = lit * 0.6 + fstudio(r, trim_color) * 0.4 + wax_color * fres * 0.2;
	} else {
		ALBEDO = mix(liquid, wax, blob);
		METALLIC = 0.0;
		ROUGHNESS = 0.12;
		EMISSION = lit + liquid * 0.35 + vec3(1.0, 0.8, 1.0) * pow(fres, 4.0) * 0.25;
	}
}
