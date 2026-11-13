shader_type spatial;
// Weapon finish "Marquee Lights": glossy red lacquer studded with carnival
// bulbs in gold sockets. The bulbs chase in threes along the weapon, and every
// few seconds the whole board flashes. Trim is gold leaf with red sockets.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.62, 0.04, 0.09);
uniform vec3 trim_color : source_color = vec3(1.0, 0.74, 0.25);
uniform bool is_trim = false;
uniform vec3 bulb_color : source_color = vec3(1.0, 0.86, 0.5);
uniform float spacing = 0.034;
uniform float chase_rate = 7.0;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	vec2 uv = fplane(lp, ln) / spacing;
	// Rows of bulbs, every other row offset by half a bulb.
	float row = floor(uv.y);
	uv.x += mod(row, 2.0) * 0.5;
	vec2 id = vec2(floor(uv.x), row);
	vec2 f = fract(uv) - 0.5;
	float d = length(f);
	float step3 = floor(TIME * chase_rate);
	float lit = step(mod(id.x + row - step3, 3.0), 0.5);
	// Every ~6 s: the whole board blinks twice.
	float flash = fract(TIME / 6.0);
	float all_on = step(flash, 0.12) * step(0.5, fract(flash * 16.0));
	lit = max(lit, all_on);
	float bulb = smoothstep(0.3, 0.26, d);
	float socket = smoothstep(0.38, 0.34, d) - bulb;
	float core = smoothstep(0.2, 0.0, d);
	float halo = exp(-d * d * 9.0) * lit * 0.35;
	vec3 glass = mix(bulb_color * 0.25, bulb_color, lit);
	vec3 bulbs = bulb * (lit * bulb_color * (1.6 + core * 2.0) + bulb_color * 0.08) + bulb_color * halo * (1.0 - bulb);
	if (is_trim) {
		// Gold leaf with red sockets, an engraved line between the bulbs.
		float line = smoothstep(0.44, 0.48, abs(fract(uv.y) - 0.5));
		float metal = (1.0 - bulb - socket) * (1.0 - line * 0.4);
		ALBEDO = mix(mix(trim_color * 0.85, shell_color, socket), glass, bulb);
		METALLIC = metal * 0.6;
		ROUGHNESS = mix(0.3, 0.22, metal);
		EMISSION = bulbs + fstudio(r, trim_color) * (0.45 + 0.3 * fres) * metal;
	} else {
		// Red lacquer with gold sockets.
		vec3 paint = shell_color * (0.85 + 0.15 * fres);
		ALBEDO = mix(mix(paint, trim_color, socket), glass, bulb);
		METALLIC = socket * 0.6;
		ROUGHNESS = mix(0.18, 0.3, socket);
		EMISSION = bulbs + fstudio(r, trim_color) * socket * 0.4
			+ vec3(1.0, 0.85, 0.85) * pow(fres, 4.0) * 0.15 * (1.0 - bulb);
	}
}
