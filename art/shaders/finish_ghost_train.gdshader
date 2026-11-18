shader_type spatial;
// Weapon finish "Ghost Train": the midnight express that never stops. Rows of
// lit carriage windows rush along the weapon with pale passengers (and a few
// grinning ghosts) at them, flickering as the old wiring fails; speed streaks
// strobe past between the rows and cold steam drifts over the iron. The trim
// is rusted iron with ghost-green lamps that pulse.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.07, 0.09, 0.17);
uniform vec3 trim_color : source_color = vec3(0.27, 0.15, 0.1);
uniform bool is_trim = false;
uniform vec3 glow_color : source_color = vec3(0.45, 1.0, 0.78);
uniform vec3 lamp_color : source_color = vec3(1.0, 0.82, 0.5);
uniform float row_h = 0.032;
uniform float speed = 0.1;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

float box_sd(vec2 p, vec2 b, float rad) {
	vec2 d = abs(p) - b + rad;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - rad;
}

float fillv(float d, float soft) {
	return smoothstep(soft, -soft, d);
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	vec2 uv = fplane(lp, ln);
	float pulse = 0.5 + 0.5 * sin(TIME * 2.4);
	vec3 col;
	vec3 emit;
	float metal = 0.6;
	float rough = 0.4;
	if (is_trim) {
		float rust = ffbm3(lp * 40.0);
		col = mix(trim_color, trim_color * vec3(1.3, 0.8, 0.5), rust);
		col *= 0.75 + 0.4 * fnoise3(lp * 300.0);
		vec2 dc = vec2(fract(lp.z / 0.04) - 0.5, fract((lp.y + lp.x) / 0.03) - 0.5);
		float lamp = fillv(length(dc * vec2(0.04, 0.03)) - 0.0045, 0.002) * step(0.55, fh21(floor(vec2(lp.z / 0.04, (lp.y + lp.x) / 0.03))));
		col = mix(col, glow_color * 0.8, lamp);
		emit = glow_color * lamp * (0.6 + 0.9 * pulse) + fstudio(r, trim_color * 2.0) * 0.1;
		metal = 0.45;
		rough = 0.5;
	} else {
		// Rows of carriage windows, alternate rows rushing opposite ways.
		float row = floor(uv.y / row_h);
		float dir = mod(row, 2.0) < 0.5 ? 1.0 : -1.0;
		float u = uv.x + TIME * speed * dir * (1.0 + 0.3 * fh21(vec2(row, 1.0)));
		float sc = row_h / 0.05;
		float period = 0.075 * sc;
		float wid = floor(u / period + row * 0.37);
		vec2 f = vec2(fract(u / period + row * 0.37) - 0.5, fract(uv.y / row_h) - 0.5) * vec2(0.075, 0.05);
		float h = fh21(vec2(wid, row));
		// Flicker: each window's bulb fails now and then, the whole car browns out sometimes.
		float tick = floor(TIME * 9.0);
		float fail = step(0.9, fh21(vec2(wid + tick * 0.13, row + 5.0)));
		float brown = smoothstep(0.82, 0.95, sin(TIME * 0.9 + row * 2.0) * sin(TIME * 2.3 + wid * 0.1));
		float lit = (1.0 - fail) * (1.0 - brown * 0.7) * step(0.12, h);

		float win = fillv(box_sd(f, vec2(0.026, 0.017), 0.007), 0.0012);
		float frame = fillv(box_sd(f, vec2(0.031, 0.021), 0.009), 0.0014) - win;
		vec3 base = shell_color * (0.8 + 0.5 * fnoise2(uv * 300.0));
		// Iron plating: seams between the rows and rivets along them.
		float seam = smoothstep(0.001, 0.0004, fract(uv.y / row_h) * row_h) + smoothstep(0.001, 0.0004, (1.0 - fract(uv.y / row_h)) * row_h);
		vec2 rv = vec2(fract(uv.x / 0.008) - 0.5, (fract(uv.y / row_h) - 0.5) * row_h / 0.008);
		float rivet = fillv(length(vec2(rv.x, abs(rv.y) - 1.8)) * 0.008 - 0.0011, 0.0005);
		base = mix(base, shell_color * 2.2, max(seam, rivet) * 0.7);
		// What the window shows: bare light, a passenger, or a ghost.
		vec3 room = mix(glow_color, lamp_color, step(0.5, fract(h * 7.0))) * (0.55 + 0.45 * (0.5 - f.y / 0.034));
		float person = 0.0;
		float ghost = 0.0;
		vec2 hp = f - vec2((fract(h * 13.0) - 0.5) * 0.02, -0.004);
		float head = fillv(length(hp * vec2(1.0, 1.15)) - 0.0075, 0.001);
		float shoulders = fillv(length((hp - vec2(0.0, -0.016)) * vec2(0.7, 1.4)) - 0.014, 0.001);
		if (h > 0.3 && h < 0.7) {
			person = max(head, shoulders);
		} else if (h >= 0.7 && h < 0.86) {
			// A ghost: a bright sheet with a hollow gaze, tail trailing, drifting side to side.
			vec2 gp = hp - vec2(sin(TIME * 1.7 + h * 30.0) * 0.004, 0.0);
			float sheet = fillv(length(gp * vec2(0.95, 0.6) - vec2(0.0, 0.0)) - 0.016, 0.0012);
			float tail = fillv(box_sd(gp - vec2(0.0, -0.012), vec2(0.011 + 0.003 * sin(gp.y * 300.0 + TIME * 6.0), 0.011), 0.003), 0.001);
			ghost = max(sheet, tail);
		}
		float eyes = fillv(length(vec2(abs(hp.x) - 0.0045, hp.y - 0.003)) - 0.0019, 0.0007) * step(0.7, h) * step(h, 0.86);
		float mouth = fillv(length((hp - vec2(0.0, -0.004)) * vec2(1.0, 1.7)) - 0.0035, 0.0007) * step(0.7, h) * step(h, 0.86);
		vec3 view_in = room;
		view_in = mix(view_in, vec3(0.04, 0.05, 0.09), person * 0.92);
		view_in = mix(view_in, glow_color * 1.4 + vec3(0.25), ghost * (1.0 - max(eyes, mouth)));
		view_in = mix(shell_color * 1.5, view_in, lit);
		col = mix(base, vec3(0.03, 0.035, 0.06), frame);
		col = mix(col, view_in * 0.5, win);
		emit = view_in * win * (1.15 + 0.45 * fres);
		// Speed streaks in the bands between windows, and lamplit window sills.
		float band = (1.0 - win) * smoothstep(0.014, 0.022, abs(f.y));
		float streak = smoothstep(0.82, 0.95, fnoise2(vec2(uv.x * 55.0 + TIME * 9.0 * dir, uv.y * 700.0))) * band;
		emit += glow_color * streak * 0.5 * (0.5 + 0.5 * sin(TIME * 20.0 + wid));
		// Steam drifting up over everything.
		float steam = smoothstep(0.58, 0.82, ffbm2(vec2(uv.x * 11.0 - TIME * 0.5, uv.y * 11.0 - TIME * 0.6) + 5.0)) * (0.5 + 0.5 * sin(TIME * 0.8 + uv.x * 9.0));
		col = mix(col, vec3(0.7, 0.85, 0.9), steam * 0.3);
		emit += glow_color * steam * 0.16;
		emit += glow_color * fres * 0.55 * (0.7 + 0.3 * pulse) + fstudio(r, vec3(0.5)) * 0.06 * (1.0 - win);
	}
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = emit;
	PRINT_LAYER
}
