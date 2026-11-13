shader_type spatial;
// Weapon finish "Warp Speed": star streaks rush down the barrel towards the
// player in three parallax layers (near ones long, fast and bright), with
// blue-white heads and red-shifted tails over deep space. On the trim they
// streak across dark chrome with a blue rim.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.01, 0.01, 0.05);
uniform vec3 trim_color : source_color = vec3(0.08, 0.09, 0.14);
uniform bool is_trim = false;
uniform vec3 head_color : source_color = vec3(0.6, 0.8, 1.0);
uniform vec3 tail_color : source_color = vec3(1.0, 0.25, 0.4);
uniform float speed = 1.0;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

// One layer of streaks: rows `row_h` apart, streaks `len` long (0-1 of a
// lane), moving at `spd`. Returns (intensity, position along the streak).
vec2 streaks(vec2 uv, float row_h, float lane, float len, float spd, float seed) {
	float row = floor(uv.y / row_h);
	float h = fh21(vec2(row, seed));
	float centre = 0.25 + 0.5 * fh21(vec2(row, seed + 1.0));
	float across = abs(fract(uv.y / row_h) - centre);
	// Moves towards +Z (the player), head first.
	float along = fract(uv.x / lane - TIME * spd * (0.7 + h * 0.6) + h * 9.0);
	float on = step(0.2, h);
	float body = smoothstep(1.0 - len, 1.0, along) * step(along, 0.995);
	float width = mix(0.08, 0.2, body);
	return vec2(on * body * smoothstep(width, 0.0, across), body);
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	vec2 uv = fplane(lp, ln);
	vec2 a = streaks(uv, 0.01, 0.3, 0.35, 0.6 * speed, 1.0);
	vec2 b = streaks(uv, 0.018, 0.45, 0.5, 1.1 * speed, 7.0);
	vec2 c = streaks(uv, 0.03, 0.6, 0.65, 1.9 * speed, 13.0);
	vec3 sa = mix(tail_color, head_color, a.y * a.y) * a.x;
	vec3 sb = mix(tail_color, head_color, b.y * b.y) * b.x * 1.6;
	vec3 sc = mix(tail_color, vec3(1.0), c.y * c.y) * c.x * 2.6;
	vec3 stars = sa + sb + sc;
	if (is_trim) {
		// Dark chrome with the streaks reflected in it.
		ALBEDO = trim_color;
		METALLIC = 0.7;
		ROUGHNESS = 0.18;
		EMISSION = fstudio(r, trim_color * 3.0) * 0.25 + stars * 0.5 + head_color * fres * 0.4;
	} else {
		float neb = ffbm3(lp * 5.0 + vec3(0.0, 0.0, TIME * 0.2 * speed));
		vec3 space = shell_color + vec3(0.16, 0.06, 0.34) * smoothstep(0.4, 0.85, neb);
		ALBEDO = space;
		METALLIC = 0.2;
		ROUGHNESS = 0.2;
		EMISSION = space * 0.6 + stars + head_color * pow(fres, 3.0) * 0.2;
	}
}
