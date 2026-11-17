shader_type spatial;
// Weapon finish "Hot Rod": deep candy paint full of metal flake under a clear
// coat, with classic hot-rod flames licking back along the weapon. The tongues
// flicker in length, ripple in the wind and roll from white-hot yellow at the
// root through orange to red tips, outlined by a pale-blue pinstripe; a heat
// shimmer runs back through them. Trim is candy-apple red flake.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.18, 0.03, 0.22);
uniform vec3 trim_color : source_color = vec3(0.62, 0.04, 0.08);
uniform bool is_trim = false;
uniform vec3 pinstripe : source_color = vec3(0.45, 0.85, 1.0);
// One set of flames repeats this often along the barrel, and up the sides.
uniform float flame_period = 0.46;
uniform float flame_height = 0.16;

varying vec3 lp;
varying vec3 ln;

// Signed size of the flames at (x from the root, back along the weapon; y up
// from the flame's centre line): positive inside.
float flames(float x, float y, float t) {
	// The fireball at the root.
	float d = 0.05 * (1.0 - smoothstep(0.0, 0.09, x)) - abs(y);
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float h = fh21(vec2(fi, 3.7));
		float len = 0.15 + 0.13 * h + 0.018 * sin(t * (3.0 + h * 2.0) + fi * 2.0);
		float k = clamp(x / len, 0.0, 1.0);
		float centre = (fi - 2.0) * 0.018 * (1.0 + k * 0.8)
			+ sin(x * 14.0 - t * 4.5 + fi * 1.3) * 0.012 * k
			+ (h - 0.5) * 0.03 * k * k;
		float half_w = 0.02 * pow(1.0 - k, 0.7) * smoothstep(0.0, 0.03, x) + 0.008 * (1.0 - smoothstep(0.0, 0.06, x));
		d = max(d, half_w - abs(y - centre));
	}
	return d * step(-0.005, x);
}

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	if (is_trim) {
		vec3 g = lp * 320.0;
		vec3 fh = fh33(floor(g));
		float flake = smoothstep(0.35, 0.1, length(fract(g) - 0.5)) * pow(0.5 + 0.5 * sin(fh.x * 40.0 + dot(VIEW, fh - 0.5) * 14.0), 8.0);
		ALBEDO = trim_color * (0.75 + 0.5 * fres);
		METALLIC = 0.35;
		ROUGHNESS = 0.12;
		SPECULAR = 0.8;
		EMISSION = fstudio(r, vec3(1.0)) * (0.03 + fres * 0.45) + trim_color * 0.15 + vec3(1.0, 0.7, 0.6) * flake * 0.5;
		PRINT_LAYER
	} else {
		vec2 uv = fplane(lp, ln);
		float t = TIME;
		// Flames run from the muzzle end (-Z) back, a set every flame_period.
		float x = mod(uv.x + 0.04, flame_period);
		float band = floor(uv.y / flame_height);
		float y = uv.y - (band + 0.5) * flame_height;
		x = mod(x + fh21(vec2(band, 1.0)) * 0.12, flame_period);
		float d = flames(x, y, t);
		float aa = fwidth(d) + 1e-5;
		float fire = smoothstep(-aa, aa, d - 0.0012);
		float stripe = smoothstep(-aa, aa, d + 0.0012) - fire;
		// Root to tip: white-hot, yellow, orange, red.
		float k = clamp(x / 0.26, 0.0, 1.0);
		vec3 heat = mix(vec3(1.0, 0.95, 0.6), vec3(1.0, 0.78, 0.12), smoothstep(0.0, 0.3, k));
		heat = mix(heat, vec3(1.0, 0.38, 0.05), smoothstep(0.3, 0.65, k));
		heat = mix(heat, vec3(0.88, 0.08, 0.1), smoothstep(0.65, 1.0, k));
		// Inner glow lines follow the tongue shapes, and a shimmer runs back.
		float inner = smoothstep(0.004, 0.0, abs(d - 0.004)) * 0.25;
		float shimmer = 0.5 + 0.5 * sin(x * 50.0 - t * 9.0 + y * 30.0);
		heat = mix(heat, vec3(1.0, 0.95, 0.7), inner);
		// Candy paint with metal flake that winks as the weapon turns.
		vec3 g = lp * 320.0;
		vec3 fh = fh33(floor(g));
		float flake = smoothstep(0.35, 0.1, length(fract(g) - 0.5)) * pow(0.5 + 0.5 * sin(fh.x * 40.0 + dot(VIEW, fh - 0.5) * 14.0), 8.0);
		vec3 paint = shell_color * (0.75 + 0.5 * fres) + vec3(1.0, 0.6, 0.9) * flake * 0.35;
		vec3 col = mix(paint, heat, fire);
		col = mix(col, pinstripe, stripe);
		ALBEDO = col;
		METALLIC = (1.0 - fire) * 0.35;
		ROUGHNESS = 0.12;
		SPECULAR = 0.8;
		// Clear coat over everything.
		EMISSION = fstudio(r, vec3(1.0)) * (0.03 + fres * 0.45) + heat * fire * (0.35 + shimmer * 0.25)
			+ pinstripe * stripe * 0.6 + vec3(1.0, 0.7, 0.95) * flake * 0.5 * (1.0 - fire);
		PRINT_LAYER
	}
}
