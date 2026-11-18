shader_type spatial;
// Weapon finish "Multiball": a pinball playfield wrapped round the weapon.
// Round pop bumpers (rings of red, yellow and white) flash and swell when a
// ball strikes them; two chrome balls roll and ricochet across the table
// leaving comet trails, and star inserts twinkle on a deep violet board. The trim is chrome rail with rollover lights.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.14, 0.05, 0.4);
uniform vec3 trim_color : source_color = vec3(0.8, 0.82, 0.9);
uniform bool is_trim = false;
uniform vec3 hot_color : source_color = vec3(1.0, 0.18, 0.5);
uniform vec3 cool_color : source_color = vec3(0.2, 0.9, 1.0);
uniform vec3 gold_color : source_color = vec3(1.0, 0.8, 0.2);
uniform float cell = 0.045;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

float fillv(float d, float soft) {
	return smoothstep(soft, -soft, d);
}

// A ball's position on the table: bounces along the barrel (a triangle wave in
// u) while drifting across in v, each ball with its own speed.
vec2 ball_pos(float t, float k) {
	float u = abs(fract(t * (0.11 + 0.04 * k) + k * 0.37) * 2.0 - 1.0) * 0.8 - 0.4;
	float v = (abs(fract(t * (0.23 + 0.07 * k) + k * 0.61) * 2.0 - 1.0) * 2.0 - 1.0) * 0.05;
	return vec2(u, v);
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	vec2 uv = fplane(lp, ln);
	vec3 col;
	vec3 emit;
	float metal = 0.0;
	float rough = 0.3;
	if (is_trim) {
		// Chrome rail with a row of rollover lights.
		float grain = fnoise3(lp * 250.0);
		col = trim_color * (0.8 + 0.2 * grain);
		vec2 bc = vec2(fract(lp.z / 0.035) - 0.5, fract((lp.y + lp.x) / 0.028) - 0.5);
		float idx = floor(lp.z / 0.035);
		float bulb = fillv(length(bc * vec2(0.035, 0.028)) - 0.0048, 0.002);
		float on = step(0.5, fract(idx / 3.0 - TIME * 1.6));
		vec3 bc_col = mod(idx, 2.0) < 0.5 ? hot_color : cool_color;
		col = mix(col, bc_col, bulb);
		metal = 0.9;
		rough = 0.2;
		emit = fstudio(r, vec3(0.9)) * 0.75 + bc_col * bulb * (0.25 + on * 1.6);
	} else {
		// The playfield: deep violet with a faint star-field.
		float stars = step(0.985, fh21(floor(uv / 0.006))) * (0.4 + 0.6 * sin(TIME * 4.0 + fh21(floor(uv / 0.006) + 3.0) * 40.0));
		col = shell_color * (0.8 + 0.4 * fnoise2(uv * 150.0));
		emit = shell_color * 0.4 + cool_color * stars * 0.9;
		// Balls: two, each with a fading comet trail.
		vec2 b0 = ball_pos(TIME, 0.0);
		vec2 b1 = ball_pos(TIME, 1.0);
		float trail = 0.0;
		float ball = 0.0;
		for (int i = 0; i < 2; i++) {
			float k = float(i);
			vec2 b = i == 0 ? b0 : b1;
			float d = length(uv - b);
			ball = max(ball, fillv(d - 0.0085, 0.002));
			for (int s = 1; s < 6; s++) {
				vec2 bt = ball_pos(TIME - float(s) * 0.07, k);
				trail = max(trail, fillv(length(uv - bt) - 0.0075 * (1.0 - float(s) * 0.14), 0.0015) * (1.0 - float(s) * 0.17));
			}
		}
		// Bumpers on a staggered lattice, each a set of rings that swells when a ball is near.
		vec2 q = uv / cell;
		q.x += mod(floor(q.y), 2.0) * 0.5;
		vec2 c = floor(q);
		vec2 f = fract(q) - 0.5;
		float h = fh21(c + 7.0);
		float is_b = step(0.34, h);
		vec2 centre = (c + 0.5 - vec2(mod(floor(q.y), 2.0) * 0.5, 0.0)) * cell;
		float near = max(smoothstep(0.05, 0.01, length(centre - b0)), smoothstep(0.05, 0.01, length(centre - b1)));
		float pop = clamp(near + step(0.92, fract(TIME * 0.31 + h * 9.0)) * 0.6, 0.0, 1.0);
		float rr = length(f) * (1.0 - 0.18 * pop);
		float skirt = fillv(rr - 0.44, 0.03);
		float body = fillv(rr - 0.34, 0.03);
		float cap = fillv(rr - 0.2, 0.03);
		float ringw = fillv(abs(rr - 0.38) - 0.025, 0.02);
		vec3 bcol = mod(c.x + c.y, 2.0) < 0.5 ? hot_color : gold_color;
		vec3 b_col = col;
		b_col = mix(b_col, vec3(0.06, 0.03, 0.15), skirt * is_b);
		b_col = mix(b_col, bcol * (0.8 + 0.6 * pop), body * is_b);
		b_col = mix(b_col, vec3(1.0, 0.97, 0.9), cap * is_b * (0.6 + 0.4 * pop));
		b_col = mix(b_col, vec3(1.0), ringw * is_b * pop);
		col = b_col;
		emit += (bcol * body + vec3(1.0) * cap * 0.8) * is_b * (0.45 + 1.3 * pop) + vec3(1.0) * ringw * is_b * pop;
		// Where there is no bumper, a star insert twinkles in the lattice cell.
		float ins = (1.0 - is_b) * step(0.5, h);
		float a = atan(f.y, f.x);
		float star = fillv(length(f) - (0.07 + 0.1 * pow(0.5 + 0.5 * cos(a * 4.0), 3.0)), 0.025) * ins;
		float tw = 0.4 + 0.6 * step(0.5, fract(TIME * 1.1 + h * 5.0));
		col = mix(col, cool_color, star * 0.8);
		emit += cool_color * star * tw * 1.1;
		// The balls on top, chrome with a hot highlight.
		col = mix(col, vec3(0.8, 0.85, 0.95), max(ball, trail * 0.5));
		emit += vec3(1.0) * ball * 1.1 + cool_color * trail * 0.9;
		metal = ball * 0.8;
		rough = mix(0.28, 0.1, ball);
	}
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = emit + fstudio(r, vec3(1.0)) * 0.05 + vec3(1.0) * pow(fres, 4.0) * 0.1;
	PRINT_LAYER
}
