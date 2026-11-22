shader_type spatial;
// Series 2 Epic "Overclock": a circuit board in shell_color green-black with
// gold traces, solder pads and black chips. Packets of light race along the
// traces (color_b cyan, some color_c magenta), and the chips' status lights
// blink. A kill overclocks it: every trace lights at once. Trim: gold.
#include "res://art/shaders/finish_common.gdshaderinc"
#include "res://art/shaders/finish_s2.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.02, 0.12, 0.08);
uniform vec3 trim_color : source_color = vec3(1.0, 0.75, 0.3);
uniform bool is_trim = false;
uniform vec3 color_b : source_color = vec3(0.2, 0.95, 1.0);
uniform vec3 color_c : source_color = vec3(1.0, 0.3, 0.9);

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

void fragment() {
	float t = s2_time(TIME, 1.7);
	vec2 uv = fplane(lp, ln);
	// Traces run along the weapon in lanes; each lane is broken into runs
	// that jog to the lane above at their ends.
	float lane_h = 0.009;
	float lane = floor(uv.y / lane_h);
	float ly = fract(uv.y / lane_h) - 0.5;
	float seg_len = 0.045 + fh21(vec2(lane, 1.0)) * 0.05;
	float sx = uv.x / seg_len + fh21(vec2(lane, 2.0)) * 7.0;
	float seg = floor(sx);
	float sf = fract(sx);
	vec3 h = fh33(vec3(lane, seg, 3.0));
	float live = step(0.3, h.x);
	float run = live * s2_band(ly, 0.14) * step(0.06, sf) * step(sf, 0.94);
	float jog = live * step(0.55, h.y) * s2_band((sf - 0.94) * seg_len / lane_h, 0.14) * step(0.0, ly);
	float pad = live * (1.0 - smoothstep(0.2, 0.26, length(vec2((sf - 0.06) * seg_len / lane_h, ly))));
	float trace = max(max(run, jog), pad);
	// Chips: black blocks with pins along their long sides.
	vec2 cq = uv / vec2(0.07, 0.045);
	vec2 cid = floor(cq);
	vec2 cf = fract(cq) - 0.5;
	vec3 ch = fh33(vec3(cid, 9.0));
	float chip = step(0.62, ch.x) * step(abs(cf.x), 0.3) * step(abs(cf.y), 0.22);
	float pins = step(0.62, ch.x) * step(abs(cf.x), 0.28) * step(0.22, abs(cf.y)) * step(abs(cf.y), 0.3) * step(0.5, fract(cf.x * 18.0));
	float led = step(0.62, ch.x) * (1.0 - smoothstep(0.02, 0.04, length(cf - vec2(0.22, 0.12))));
	float blink = step(0.5, fract(t * (0.6 + ch.y * 1.5) + ch.z));
	// Packets: a short bright dash running along each live lane.
	float speed = 0.25 + h.z * 0.35;
	float pk = fract(uv.x / 0.22 * (0.8 + h.y * 0.4) - t * speed * 4.0 + h.x * 3.0);
	float packet = smoothstep(0.86, 0.97, pk) * (1.0 - smoothstep(0.97, 1.0, pk)) * run;
	vec3 hot = h.y > 0.8 ? color_c : color_b;
	float all_lit = pulse;
	vec3 board = shell_color * (0.85 + 0.15 * fnoise2(uv * 400.0));
	vec3 r = reflect(-VIEW, NORMAL);
	vec3 col = mix(board, trim_color * 0.85, trace * (1.0 - chip));
	col = mix(col, vec3(0.02), chip);
	col = mix(col, vec3(0.75), pins);
	ALBEDO = col;
	METALLIC = trace * 0.9 * (1.0 - chip) + pins * 0.8;
	ROUGHNESS = mix(0.45, 0.25, trace);
	EMISSION = hot * (packet * 3.0 + trace * all_lit * 1.6) * (1.0 - chip)
		+ fstudio(r, trim_color) * trace * 0.25 * (1.0 - chip)
		+ mix(color_c, color_b, ch.y) * led * blink * 2.0 + s2_coat(NORMAL, VIEW, 0.3);
	if (is_trim) {
		// The trim wears the same scene a shade deeper, with a metal sheen.
		ALBEDO *= 0.8;
		EMISSION = EMISSION * 0.85 + fstudio(reflect(-VIEW, NORMAL), trim_color) * 0.12;
		METALLIC = max(METALLIC, 0.35);
	}
	PRINT_LAYER
}
