shader_type spatial;
// Series 2 Epic "Heartbeat": the weapon is a bedside monitor of black glass
// with a faint grid, and rows of EKG traces in shell_color green, color_b
// cyan and color_c pink are drawn by a bright sweep that runs along it, the
// line fading behind. A kill races the heart: the traces spike taller and
// flash red (color_d). The trim is grey monitor plastic with a scan line.
#include "res://art/shaders/finish_common.gdshaderinc"
#include "res://art/shaders/finish_s2.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.25, 1.0, 0.45);
uniform vec3 trim_color : source_color = vec3(0.16, 0.18, 0.2);
uniform bool is_trim = false;
uniform vec3 color_b : source_color = vec3(0.25, 0.85, 1.0);
uniform vec3 color_c : source_color = vec3(1.0, 0.35, 0.65);
uniform vec3 color_d : source_color = vec3(1.0, 0.12, 0.15);

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

// One beat (x 0-1): P wave, the QRS spike, T wave.
float ekg(float x) {
	float y = 0.12 * exp(-pow((x - 0.18) / 0.03, 2.0));
	y -= 0.14 * exp(-pow((x - 0.3) / 0.008, 2.0));
	y += exp(-pow((x - 0.325) / 0.011, 2.0));
	y -= 0.28 * exp(-pow((x - 0.35) / 0.01, 2.0));
	y += 0.24 * exp(-pow((x - 0.56) / 0.045, 2.0));
	return y;
}

void fragment() {
	float t = s2_time(TIME, 1.15);
	vec2 uv = fplane(lp, ln);
	float row_h = 0.04;
	float row = floor(uv.y / row_h);
	float ly = (fract(uv.y / row_h) - 0.42) * row_h;
	float beat = 0.13;
	float x = uv.x / beat + fh21(vec2(row, 2.0)) * 3.0;
	float amp = 0.022 * (1.0 + pulse * 0.6);
	float y = amp * ekg(fract(x));
	float e = 0.004;
	float slope = (ekg(fract(x) + e) - ekg(fract(x) - e)) / (2.0 * e) * amp / beat;
	float d = abs(ly - y) / sqrt(1.0 + slope * slope);
	float aa = fwidth(uv.y) * 1.2;
	float line = 1.0 - smoothstep(0.0012, 0.0012 + aa, d);
	float glow = exp(-d * d / 0.00002);
	// The sweep runs along the weapon; the trace fades behind it.
	float rate = 0.32 * (1.0 + pulse * 1.5);
	float sweep = fract(t * rate + fh21(vec2(row, 5.0)));
	float span = 0.9;
	float pos = fract((uv.x + 0.5) / span);
	float behind = fract(sweep - pos);
	float trail = exp(-behind * 3.2) * step(0.03, behind) + smoothstep(0.03, 0.0, behind) * 1.6;
	trail = mix(1.0, 0.3 + trail, motion);
	float k = mod(row, 3.0);
	vec3 ink = k < 0.5 ? shell_color : (k < 1.5 ? color_b : color_c);
	ink = mix(ink, color_d, pulse);
	float grid = max(s2_lines(uv.x / 0.01, 0.04), s2_lines(uv.y / 0.01, 0.04)) * 0.5
		+ max(s2_lines(uv.x / 0.05, 0.012), s2_lines(uv.y / 0.05, 0.012));
	vec3 glass = vec3(0.012, 0.035, 0.025) + shell_color * grid * 0.12;
	vec3 r = reflect(-VIEW, NORMAL);
	ALBEDO = mix(glass, ink * 0.3, line);
	METALLIC = 0.0;
	ROUGHNESS = 0.06;
	EMISSION = ink * (line * 2.4 + glow * 0.5) * trail + glass * 0.5 + s2_coat(NORMAL, VIEW, 0.9);
	if (is_trim) {
		// The trim wears the same scene a shade deeper, with a metal sheen.
		ALBEDO *= 0.8;
		EMISSION = EMISSION * 0.85 + fstudio(reflect(-VIEW, NORMAL), trim_color) * 0.12;
		METALLIC = max(METALLIC, 0.35);
	}
	PRINT_LAYER
}
