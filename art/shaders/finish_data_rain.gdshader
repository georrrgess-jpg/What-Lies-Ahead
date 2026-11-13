shader_type spatial;
// Weapon finish "Data Rain": columns of blocky glyphs rain down black glass.
// Each column falls at its own speed with a white-hot head and a fading
// trail; glyphs flicker as they change. The trim rains dimmer.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.01, 0.03, 0.03);
uniform vec3 trim_color : source_color = vec3(0.04, 0.06, 0.07);
uniform bool is_trim = false;
uniform vec3 rain_color : source_color = vec3(0.2, 1.0, 0.55);
uniform float glyph = 0.022;
uniform float speed = 0.6;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	vec2 uv = fplane(lp, ln) / vec2(glyph, glyph * 1.4);
	vec2 cell = floor(uv);
	float col_seed = fh21(vec2(cell.x, 7.0));
	// Distance behind this column's falling head, in glyph rows (0 = head).
	float fall = TIME * speed * (6.0 + col_seed * 10.0) + col_seed * 50.0;
	float behind = mod(cell.y + fall, 18.0 + floor(col_seed * 10.0));
	float trail = (1.0 - behind / 13.0) * step(behind, 13.0);
	float head = step(behind, 1.0);
	// Glyph: a 3x4 bit pattern that changes now and then.
	vec2 sub = fract(uv) * vec2(4.0, 5.0);
	vec2 bit_id = floor(sub);
	float inside = step(0.5, bit_id.x) * step(bit_id.x, 2.5) * step(0.5, bit_id.y) * step(bit_id.y, 3.5);
	float change = floor(TIME * (2.0 + col_seed * 3.0) + fh21(cell) * 9.0);
	float bit = step(0.45, fh21(bit_id + cell * 3.1 + change * 0.71)) * inside;
	float pix = bit * smoothstep(0.5, 0.35, max(abs(fract(sub.x) - 0.5), abs(fract(sub.y) - 0.5)));
	float energy = pix * max(max(trail, head), 0.12);
	vec3 col = mix(rain_color, vec3(0.85, 1.0, 0.9), head);
	// Trim: the same rain, dimmer, over its own glass.
	vec3 base = is_trim ? trim_color : shell_color;
	float k = is_trim ? 0.6 : 1.0;
	ALBEDO = mix(base, col * 0.3, energy);
	METALLIC = 0.2;
	ROUGHNESS = 0.1;
	EMISSION = (col * energy * 2.2 + rain_color * pix * 0.06) * k + fstudio(r, vec3(0.25)) * 0.12 * (1.0 + fres);
}
