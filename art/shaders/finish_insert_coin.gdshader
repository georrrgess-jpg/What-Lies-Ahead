shader_type spatial;
// Weapon finish "Insert Coin": the weapon is an arcade screen. Lanes of 8-bit
// sprites (ghosts, invaders, pixel zombies, chompers, hearts and coins) march
// along the barrel a whole pixel at a time, behind CRT scanlines, an RGB
// phosphor mask and a slow rolling refresh bar, under glossy glass. The mask
// fades out where the pixels get too small to resolve (thumbnails, distance),
// so it never shimmers. Trim is glossy cabinet plastic whose coin-door light
// blinks INSERT COIN.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.03, 0.03, 0.08);
uniform vec3 trim_color : source_color = vec3(0.32, 0.1, 0.62);
uniform bool is_trim = false;
// One screen pixel, in model units.
uniform float pixel = 0.0062;
uniform float march = 7.0;

varying vec3 lp;
varying vec3 ln;

const float LANE = 11.0;
const float SLOT = 12.0;

// Four 8-pixel rows (MSB on the left, top row first) of sprite `s`
// (0 ghost, 1 invader, 2 zombie, 3 heart, 4 coin, 5 chomper): the top half
// (`low` false) or the bottom half, in animation frame `f`.
uint sprite_rows(int s, bool low, int f) {
	if (s == 0) {
		return low ? (f == 0 ? 0xFFFFFFAAu : 0xFFFFFF55u) : 0x3C7EDBDBu;
	} else if (s == 1) {
		return low ? (f == 0 ? 0xFFBDA542u : 0xFFBD2481u) : 0x243C7EDBu;
	} else if (s == 2) {
		return low ? (f == 0 ? 0xFFC35A3Cu : 0xFFC37E3Cu) : 0x3C7EFF99u;
	} else if (s == 3) {
		return low ? 0x7E3C1800u : 0x66FFFFFFu;
	} else if (s == 4) {
		return low ? 0xE7E77E3Cu : 0x3C7EE7E7u;
	}
	if (f == 0) {
		return low ? 0xF0FC7E3Cu : 0x3C7EFCF0u;
	}
	return low ? 0xFFFF7E3Cu : 0x3C7EFFFFu;
}

// Whether pixel (`col`, `row`) of sprite `s` is lit (row 0 at the top).
bool sprite_bit(int s, int row, int col, int f) {
	uint rows = sprite_rows(s, row >= 4, f);
	uint bits = (rows >> uint(24 - 8 * (row % 4))) & 0xFFu;
	return ((bits >> uint(7 - col)) & 1u) == 1u;
}

vec3 sprite_color(int s, float h) {
	if (s == 0) {
		return h < 0.5 ? vec3(0.25, 0.95, 1.0) : vec3(1.0, 0.45, 0.8);
	} else if (s == 1) {
		return vec3(0.95, 0.3, 1.0);
	} else if (s == 2) {
		return vec3(0.45, 1.0, 0.3);
	} else if (s == 3) {
		return vec3(1.0, 0.18, 0.3);
	} else if (s == 4) {
		return vec3(1.0, 0.8, 0.2);
	}
	return vec3(1.0, 0.92, 0.15);
}

// The screen's colour at pixel `id` (whole pixels): a sprite, a pellet or a star.
vec3 screen(vec2 id) {
	float lane = floor(id.y / LANE);
	float row = id.y - lane * LANE;
	float dir = mod(lane, 2.0) < 0.5 ? 1.0 : -1.0;
	float speed = march * (0.75 + 0.5 * fh21(vec2(lane, 3.0)));
	float steps = floor(TIME * speed);
	float x = id.x - dir * steps + floor(fh21(vec2(lane, 9.0)) * 40.0);
	float slot = floor(x / SLOT);
	float h = fh21(vec2(slot, lane));
	int s = int(floor(fh21(vec2(slot, lane + 17.0)) * 6.0));
	int f = int(mod(steps, 2.0));
	// Ghosts and zombies hop a pixel every other step.
	float hop = (s == 0 || s == 2) ? float(f) : 0.0;
	float col = x - slot * SLOT - 2.0;
	float r = 9.0 - row + hop;
	vec3 c = vec3(0.0);
	if (h > 0.18 && col >= 0.0 && col < 8.0 && r >= 0.0 && r < 8.0) {
		// Chompers face the way they go.
		float cx = (s == 5 && dir < 0.0) ? 7.0 - col : col;
		if (sprite_bit(s, int(r), int(cx), f)) {
			c = sprite_color(s, fh21(vec2(slot, lane + 5.0)));
		}
	} else if (h <= 0.18 && abs(row - 5.5) < 0.6 && mod(x, 3.0) < 1.0) {
		// An empty slot holds a row of pellets.
		c = vec3(1.0, 0.85, 0.7) * 0.8;
	}
	// A dim, twinkling starfield behind everything.
	float star = step(0.985, fh21(id + 0.5)) * (0.5 + 0.5 * sin(TIME * 3.0 + fh21(id) * 30.0));
	return max(c, vec3(0.25, 0.35, 0.7) * star * 0.35);
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	vec2 uv = fplane(lp, ln);
	if (is_trim) {
		// Cabinet plastic, a faint pixel dither, and the coin-door light.
		vec2 d = floor(uv / (pixel * 2.0));
		float dither = mod(d.x + d.y, 2.0);
		float blink = step(0.45, fract(TIME * 0.9));
		vec3 coin = vec3(1.0, 0.18, 0.25);
		float stripe = smoothstep(0.003, 0.0015, abs(fract(uv.y / 0.1) - 0.5) * 0.1);
		ALBEDO = trim_color * (0.94 + 0.06 * dither);
		METALLIC = 0.0;
		ROUGHNESS = 0.22;
		EMISSION = fstudio(r, trim_color) * fres * 0.35 + trim_color * 0.12
			+ coin * stripe * (0.4 + blink * 1.8);
		PRINT_LAYER
	} else {
		vec2 p = uv / pixel;
		vec2 id = floor(p);
		vec2 f = fract(p);
		vec3 c = screen(id);
		// CRT: dark scanline gaps between rows, an RGB phosphor triad in each
		// pixel; both fade to their average once a pixel is under ~2 screen pixels.
		float aa = clamp(max(fwidth(p.x), fwidth(p.y)) * 0.6, 0.0, 1.0);
		float scan = mix(smoothstep(0.0, 0.22, f.y) * smoothstep(1.0, 0.78, f.y), 0.72, aa);
		float k = fract(f.x * 3.0);
		int tri = int(floor(f.x * 3.0));
		vec3 triad = vec3(tri == 0 ? 1.0 : 0.35, tri == 1 ? 1.0 : 0.35, tri == 2 ? 1.0 : 0.35);
		triad = mix(triad * (0.7 + 0.3 * smoothstep(0.0, 0.2, k) * smoothstep(1.0, 0.8, k)), vec3(0.6), aa);
		// A slow refresh bar rolling up the screen, and a faint flicker.
		float roll = exp(-pow(fract(uv.y * 4.0 - TIME * 0.35) - 0.5, 2.0) * 50.0);
		float flicker = 0.96 + 0.04 * sin(TIME * 57.0);
		vec3 lit = c * triad * scan * 2.6 * flicker;
		vec3 glass = shell_color + vec3(0.02, 0.05, 0.1) * roll;
		ALBEDO = glass + c * 0.15;
		METALLIC = 0.0;
		ROUGHNESS = 0.08;
		SPECULAR = 0.7;
		EMISSION = lit + vec3(0.1, 0.25, 0.45) * roll * 0.25 + fstudio(r, vec3(0.6, 0.7, 1.0)) * (0.03 + fres * 0.3);
		PRINT_LAYER
	}
}

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}
