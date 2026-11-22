shader_type spatial;
// Series 2 Legendary chase print "Phoenix": the weapon burns without being
// consumed. Tongues of flame lick up its sides and stream back towards the
// player as if it flies, rolling from shell_color crimson through color_b
// orange to color_c gold and a white-hot root, over a charred black coat
// etched with golden feather barbs; embers rise off it. A kill makes the
// fire roar up white-gold. The trim is gold leaf engraved with feathers,
// lit by the flames.
#include "res://art/shaders/finish_common.gdshaderinc"
#include "res://art/shaders/finish_s2.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.85, 0.05, 0.08);
uniform vec3 trim_color : source_color = vec3(1.0, 0.72, 0.28);
uniform bool is_trim = false;
uniform vec3 color_b : source_color = vec3(1.0, 0.42, 0.05);
uniform vec3 color_c : source_color = vec3(1.0, 0.86, 0.35);

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

vec3 fire_ramp(float k) {
	vec3 c = mix(vec3(0.0), shell_color, smoothstep(0.05, 0.3, k));
	c = mix(c, color_b, smoothstep(0.3, 0.55, k));
	c = mix(c, color_c, smoothstep(0.55, 0.8, k));
	return mix(c, vec3(1.0, 0.97, 0.88), smoothstep(0.92, 1.0, k));
}

// Golden feather barbs: chevrons along the weapon with a central quill.
float feathers(vec2 uv) {
	vec2 q = uv / vec2(0.09, 0.04);
	q.x += mod(floor(q.y), 2.0) * 0.5;
	vec2 f = fract(q) - 0.5;
	float quill = s2_band(f.y, 0.03) * step(f.x, 0.35);
	float barb = s2_band(fract((f.x + abs(f.y) * 1.6) * 9.0) - 0.5, 0.12) * step(abs(f.y), 0.42) * step(f.x, 0.4);
	float vane = 1.0 - smoothstep(0.38, 0.45, length(vec2(f.x * 0.75, f.y)));
	return max(quill, barb * vane * 0.55);
}

void fragment() {
	float t = s2_time(TIME, 1.4);
	vec2 uv = fplane(lp, ln);
	float roar = pulse * pulse;
	// Flames: turbulence stretched upright into tongues, rising and
	// streaming back (+Z), warped sideways so they lick and sway.
	vec2 fq = vec2(uv.x * 26.0 + t * 0.8, uv.y * 9.0 - t * 2.4);
	float w = ffbm2(fq * 0.6 + vec2(0.0, -t * 0.5));
	float n = ffbm2(fq + vec2(w * 2.0, 0.0)) * 0.7 + ffbm2(fq * 2.1 + vec2(3.0, -t)) * 0.3;
	float k = clamp((n - 0.38) * 2.4 + roar * 0.4, 0.0, 1.0);
	vec3 fire = fire_ramp(k);
	float lick = smoothstep(0.08, 0.25, k);
	// Embers: sparks drifting up and back, flickering.
	vec2 eq = (uv + vec2(-t * 0.02, -t * 0.035)) * 220.0;
	vec2 eid = floor(eq);
	vec3 eh = fh33(vec3(eid, 5.0));
	float ember = step(0.975, eh.x) * (1.0 - smoothstep(0.08, 0.3, length(fract(eq) - 0.5 - (eh.yz - 0.5) * 0.4))) * (0.5 + 0.5 * sin(t * 9.0 + eh.y * 50.0));
	float fe = feathers(uv);
	vec3 char = vec3(0.03, 0.012, 0.01) * (0.7 + 0.6 * fnoise2(uv * 300.0));
	vec3 r = reflect(-VIEW, NORMAL);
	vec3 base = mix(char, trim_color * 0.6, fe * 0.85);
	ALBEDO = mix(base, fire * 0.4, lick);
	METALLIC = fe * 0.8 * (1.0 - lick);
	ROUGHNESS = mix(0.5, 0.3, fe);
	EMISSION = fire * lick * (1.1 + roar * 1.6) + color_c * ember * 3.0
		+ fstudio(r, trim_color) * fe * 0.3 * (1.0 - lick) + shell_color * 0.04;
	if (is_trim) {
		// The trim wears the same scene a shade deeper, with a metal sheen.
		ALBEDO *= 0.8;
		EMISSION = EMISSION * 0.85 + fstudio(reflect(-VIEW, NORMAL), trim_color) * 0.12;
		METALLIC = max(METALLIC, 0.35);
	}
	PRINT_LAYER
}
