shader_type spatial;
// Weapon finish "Bass Drop": rows of LED equalizer bars along the weapon's
// sides pump to a beat, centred on the body line; green at rest, yellow and
// pink at the peaks. Top and bottom faces carry a beat-flashing strip. The
// trim pumps too, a little dimmer.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.05, 0.04, 0.08);
uniform vec3 trim_color : source_color = vec3(0.1, 0.09, 0.14);
uniform bool is_trim = false;
uniform vec3 low_color : source_color = vec3(0.2, 1.0, 0.45);
uniform vec3 mid_color : source_color = vec3(1.0, 0.85, 0.15);
uniform vec3 high_color : source_color = vec3(1.0, 0.15, 0.55);
uniform float bpm = 118.0;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float beat_t = TIME * bpm / 60.0;
	float kick = exp(-fract(beat_t) * 5.0);
	// Columns along the barrel, LED rows up and down from the body line.
	float col_w = 0.022;
	float row_h = 0.012;
	float col = floor(lp.z / col_w);
	float off = abs(lp.y + 0.02) / row_h;
	float row = floor(off);
	vec2 cell = vec2(fract(lp.z / col_w), fract(off));
	float led = step(0.12, cell.x) * step(cell.x, 0.88) * step(0.15, cell.y) * step(cell.y, 0.85);
	// Bar height: a few beat-locked sines per column, kicked on the beat.
	float h = 0.25 + 0.35 * abs(sin(beat_t * 0.5 * 3.14159 + col * 0.9))
		+ 0.25 * abs(sin(TIME * 2.3 + col * 2.7)) + kick * (0.6 + 0.4 * fh21(vec2(col, floor(beat_t))));
	h *= 9.0;
	float lit = step(row, h) * led;
	float level = clamp(row / 9.0, 0.0, 1.0);
	vec3 hue = level < 0.5 ? mix(low_color, mid_color, level * 2.0) : mix(mid_color, high_color, level * 2.0 - 1.0);
	float peak = step(abs(row - floor(h)), 0.5) * led;
	float side = fside(ln);
	vec2 uv = fplane(lp, ln);
	float strip = (1.0 - side) * step(abs(uv.y), 0.012) * (0.25 + kick);
	vec3 base = is_trim ? trim_color : shell_color;
	float k = is_trim ? 0.7 : 1.0;
	ALBEDO = mix(base, hue * 0.4, lit * side) + vec3(0.03) * led * side;
	METALLIC = 0.3;
	ROUGHNESS = 0.25;
	EMISSION = (hue * side * (lit * 1.7 + peak * 1.2 + led * 0.04) + low_color * strip) * k
		+ fstudio(r, base * 2.0 + 0.1) * 0.12;
}
