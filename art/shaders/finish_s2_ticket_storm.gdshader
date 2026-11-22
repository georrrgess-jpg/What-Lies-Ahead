shader_type spatial;
// Series 2 Epic "Ticket Storm": a midnight-blue sky full of prize tickets
// that tumble down the weapon in two layers (small far ones slower, big near
// ones faster), each spinning as it falls, with perforated stubs and a star.
// Ticket inks: color_b, color_c, color_d, trim_color. A kill sends a gust.
#include "res://art/shaders/finish_common.gdshaderinc"
#include "res://art/shaders/finish_s2.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.05, 0.06, 0.2);
uniform vec3 trim_color : source_color = vec3(1.0, 0.76, 0.28);
uniform bool is_trim = false;
uniform vec3 color_b : source_color = vec3(1.0, 0.28, 0.35);
uniform vec3 color_c : source_color = vec3(1.0, 0.85, 0.3);
uniform vec3 color_d : source_color = vec3(0.4, 0.85, 1.0);

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

// One layer of tickets: rgb colour, a = coverage.
vec4 tickets(vec2 uv, float cell, float speed, float t, float layer) {
	vec2 q = uv / cell;
	float colx = floor(q.x);
	float h0 = fh21(vec2(colx, layer));
	q.y += t * speed * (0.7 + 0.6 * h0) + h0 * 5.0;
	q.x += sin(q.y * 0.9 + h0 * 6.0) * 0.12;
	vec2 id = floor(q);
	vec3 h = fh33(vec3(id, layer));
	if (h.x > 0.62) {
		return vec4(0.0);
	}
	vec2 f = fract(q) - 0.5 - (h.yz - 0.5) * 0.25;
	float spin = h.y * 6.28 + t * (h.z - 0.5) * 3.0;
	f = s2_rot(spin) * f;
	float tilt = 0.55 + 0.45 * abs(cos(t * (0.8 + h.x) + h.z * 6.0));
	f.y /= tilt;
	vec2 size = vec2(0.36, 0.17);
	vec2 a = abs(f) - size;
	float body = 1.0 - smoothstep(-0.01, 0.01, max(a.x, a.y));
	float notch = smoothstep(0.045, 0.06, length(vec2(abs(f.x) - size.x, f.y)));
	float perf = step(0.5, fract(f.y * 30.0)) * s2_band(f.x - 0.2, 0.012);
	float border = s2_band(max(abs(f.x) / size.x, abs(f.y) / size.y) - 0.8, 0.04);
	float star = 1.0 - smoothstep(0.05, 0.065, length(f + vec2(0.08, 0.0)) * (0.8 + 0.4 * cos(atan(f.y, f.x + 0.08) * 5.0)));
	float k = fh21(id + 3.0);
	vec3 ink = k < 0.25 ? color_b : (k < 0.5 ? color_c : (k < 0.75 ? color_d : trim_color));
	vec3 col = mix(ink, vec3(1.0, 0.96, 0.88), max(border, star) * 0.85);
	col = mix(col, ink * 0.4, perf);
	col *= 0.75 + 0.25 * tilt;
	return vec4(col, body * notch);
}

void fragment() {
	float t = s2_time(TIME, 6.0) + pulse * pulse * 1.2;
	vec2 uv = fplane(lp, ln);
	vec3 sky = shell_color * (0.7 + 0.5 * ffbm2(uv * 8.0 + vec2(0.0, t * 0.05)));
	float twinkle = step(0.992, fh21(floor(uv * 600.0))) * (0.5 + 0.5 * sin(t * 3.0 + fh21(floor(uv * 600.0) + 1.0) * 30.0));
	vec3 col = sky + vec3(twinkle) * 0.6;
	vec4 far = tickets(uv, 0.028, 1.2, t, 1.0);
	col = mix(col, far.rgb * 0.55 + sky * 0.3, far.a);
	vec4 near = tickets(uv, 0.05, 1.6, t, 2.0);
	col = mix(col, near.rgb, near.a);
	ALBEDO = col;
	METALLIC = 0.0;
	ROUGHNESS = mix(0.18, 0.45, near.a);
	EMISSION = near.rgb * near.a * 0.22 + far.rgb * far.a * 0.08 + vec3(twinkle) * 0.9 + s2_coat(NORMAL, VIEW, 0.6);
	if (is_trim) {
		// The trim wears the same scene a shade deeper, with a metal sheen.
		ALBEDO *= 0.8;
		EMISSION = EMISSION * 0.85 + fstudio(reflect(-VIEW, NORMAL), trim_color) * 0.12;
		METALLIC = max(METALLIC, 0.35);
	}
	PRINT_LAYER
}
