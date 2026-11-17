shader_type spatial;
// Weapon finish "Holo Tiger": tiger stripes printed in holographic foil on
// black velvet. The stripes taper, fork and wrap round the weapon; their foil
// shifts through the rainbow with the viewing angle over a fine diffraction
// grating, hologram scanlines crawl up them and a glint prowls along the
// weapon. The stripes themselves creep slowly, like a big cat breathing.
// Trim is rainbow-tinted chrome.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.04, 0.03, 0.06);
uniform vec3 trim_color : source_color = vec3(0.8, 0.82, 0.9);
uniform bool is_trim = false;
uniform float stripe_scale = 1.0;

varying vec3 lp;

void vertex() {
	lp = print_xform(VERTEX);
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 2.0);
	float t = TIME;
	vec3 p = lp * stripe_scale;
	// Foil colour: angle, position and a slow drift pick the hue.
	float grating = 0.5 + 0.5 * sin((p.z * 0.8 + p.y) * 900.0);
	vec3 foil = fhue(dot(NORMAL, VIEW) * 1.6 + p.z * 2.5 + p.y * 3.0 - t * 0.08 + grating * 0.05);
	foil = mix(foil, vec3(1.0), 0.12);
	float glint = exp(-pow(fract(p.z * 0.9 - t * 0.18) * 3.0 - 1.5, 2.0) * 10.0);
	if (is_trim) {
		ALBEDO = trim_color * 0.45;
		METALLIC = 1.0;
		ROUGHNESS = 0.1;
		EMISSION = fstudio(r, mix(trim_color, foil, 0.4)) * 0.65 + foil * (fres * 0.25 + glint * 0.2);
		PRINT_LAYER
	} else {
		// Stripes cross the barrel: a wavy phase along Z, bent by noise, with
		// widths that swell and taper so the bands end in points and forks.
		float breathe = sin(t * 0.6) * 0.15 + t * 0.04;
		float phase = p.z * 165.0 + (fnoise3(vec3(p.x * 14.0, p.y * 14.0, p.z * 9.0)) - 0.5) * 9.0
			+ sin(p.y * 45.0 + p.x * 30.0) * 1.1 + breathe;
		float tri = abs(fract(phase / 6.2832) - 0.5) * 2.0;
		float width = 0.12 + 0.38 * fnoise3(vec3(p.x * 30.0, p.y * 30.0, p.z * 30.0) + 4.0);
		float fork = smoothstep(0.62, 0.7, fnoise3(p * vec3(30.0, 30.0, 14.0) + 9.0)) * smoothstep(0.1, 0.02, tri);
		float aa = fwidth(tri) + 1e-4;
		float stripe = smoothstep(width + aa, width - aa, tri) * (1.0 - fork);
		// Hologram scanlines crawling up the foil.
		float scan = 0.82 + 0.18 * step(0.5, fract(p.y * 260.0 - t * 1.5));
		vec3 velvet = shell_color * (0.8 + 0.4 * fres) + vec3(0.1, 0.05, 0.15) * pow(fres, 3.0);
		ALBEDO = mix(velvet, foil * 0.55, stripe);
		METALLIC = stripe * 0.8;
		ROUGHNESS = mix(0.75, 0.15, stripe);
		EMISSION = stripe * foil * (0.55 + fres * 0.5 + glint * 0.9) * scan * (0.9 + 0.1 * grating)
			+ fstudio(r, foil) * stripe * 0.25;
		PRINT_LAYER
	}
}
