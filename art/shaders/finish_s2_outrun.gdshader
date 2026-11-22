shader_type spatial;
// Series 2 Legendary chase print "Outrun": a synthwave sunset on the side of
// the weapon. Above the horizon a sky from color_b violet to shell_color hot
// pink and color_c orange, a huge sun with slatted bands that scroll down
// through it and a ridge of wireframe mountains; below, a neon grid floor
// (trim_color cyan) racing towards the muzzle in perspective, with a scatter
// of stars overhead. The scene repeats along the weapon. A kill flashes the
// grid and swells the sun. The trim is a shade deeper.
#include "res://art/shaders/finish_common.gdshaderinc"
#include "res://art/shaders/finish_s2.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(1.0, 0.2, 0.6);
uniform vec3 trim_color : source_color = vec3(0.2, 0.95, 1.0);
uniform bool is_trim = false;
uniform vec3 color_b : source_color = vec3(0.2, 0.04, 0.35);
uniform vec3 color_c : source_color = vec3(1.0, 0.65, 0.15);
uniform float horizon = -0.012;
uniform float span = 0.34;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

void fragment() {
	float t = s2_time(TIME, 1.0);
	vec2 uv = fplane(lp, ln);
	float ci = floor(uv.x / span + 0.5);
	float x = uv.x - ci * span;
	float h = uv.y - horizon;
	float swell = 1.0 + pulse * 0.25;
	vec3 col;
	vec3 glow = vec3(0.0);
	if (h > 0.0) {
		float k = clamp(h / 0.09, 0.0, 1.0);
		vec3 sky = mix(color_c, shell_color, smoothstep(0.0, 0.35, k));
		sky = mix(sky, color_b, smoothstep(0.35, 1.0, k));
		// The sun: a disc with slats that scroll down and thicken near the horizon.
		vec2 sp = vec2(x, h - 0.03);
		float sr = 0.045 * swell;
		float disc = 1.0 - smoothstep(sr - 0.001, sr + 0.001, length(sp));
		float slat_y = (h + t * 0.004) / 0.006;
		float gap = smoothstep(0.035, 0.0, h) * 0.55;
		float slat = step(gap, fract(slat_y)) + step(0.03, h);
		vec3 sun = mix(vec3(1.0, 0.92, 0.4), shell_color, smoothstep(sr, -sr, sp.y));
		float sun_on = disc * min(slat, 1.0);
		// Wireframe mountains in front of the sun.
		float ridge = 0.012 + 0.014 * abs(sin(x * 40.0 + ci)) * (0.6 + 0.4 * sin(x * 97.0 + ci * 2.0));
		float mount = step(h, ridge);
		float ridge_line = s2_band(h - ridge, 0.0007) + s2_lines(x / 0.012, 0.03) * mount * 0.5;
		float star = step(0.992, fh21(floor(uv * 520.0))) * smoothstep(0.03, 0.08, h);
		col = mix(sky, sun, sun_on);
		col = mix(col, color_b * 0.35, mount);
		glow = sun * sun_on * 0.95 + sky * 0.45 * (1.0 - mount) + trim_color * ridge_line * mount * 1.2 + vec3(star) + shell_color * exp(-length(sp) * 30.0) * 0.4 * (1.0 - mount);
	} else {
		// The grid floor in perspective, racing towards the muzzle (-Z).
		float depth = 0.012 / max(-h, 0.0008);
		float gz = depth * 2.0 + t * 1.4;
		float gx = x * depth * 60.0;
		float lz = s2_lines(gz, 0.05);
		float lx = s2_lines(gx, 0.05);
		float fade = smoothstep(14.0, 2.0, depth);
		float line = max(lz, lx) * fade;
		col = color_b * 0.25;
		glow = trim_color * line * (1.4 + pulse * 2.0) + shell_color * exp(h * 160.0) * 0.6;
	}
	ALBEDO = col * 0.4;
	METALLIC = 0.0;
	ROUGHNESS = 0.1;
	EMISSION = glow + col * 0.2 + s2_coat(NORMAL, VIEW, 0.4);
	if (is_trim) {
		// The trim wears the same scene a shade deeper, with a metal sheen.
		ALBEDO *= 0.8;
		EMISSION = EMISSION * 0.85 + fstudio(reflect(-VIEW, NORMAL), trim_color) * 0.12;
		METALLIC = max(METALLIC, 0.35);
	}
	PRINT_LAYER
}
