shader_type spatial;
// Weapon finish "Clockwork": an open watch movement. Rows of polished brass
// gears mesh along the weapon, big and small in turn, and tick round together
// (each tick snaps forward with a little overshoot, the small gears turning
// the other way and faster). Ruby jewels sit in their hubs; behind them is a
// blued plate with perlage (rings of circular graining) and the gears' cast
// shadows. Trim is polished rose gold engraved with guilloche waves.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.95, 0.7, 0.32);
uniform vec3 trim_color : source_color = vec3(0.95, 0.6, 0.42);
uniform bool is_trim = false;
// Pitch radius of the big gear; the small one meshes with it.
uniform float big_r = 0.05;
uniform float ticks_per_second = 2.0;

varying vec3 lp;
varying vec3 ln;

const float BIG_TEETH = 16.0;
const float SMALL_TEETH = 10.0;

// The escapement: the angle advances one tooth per tick, snapping forward
// with a small overshoot that settles.
float tick_angle(float teeth) {
	float t = TIME * ticks_per_second;
	float k = fract(t);
	float settle = 1.0 - exp(-k * 18.0) * cos(k * 30.0);
	return (floor(t) + settle) * 6.2832 / teeth;
}

// One gear about its centre: x = signed distance to its solid (teeth, rim,
// spokes, hub; negative inside), y = 1 on the jewel.
vec2 gear(vec2 p, float radius, float teeth, float angle) {
	float r = length(p);
	float a = atan(p.y, p.x) - angle;
	float tooth = clamp(cos(a * teeth) * 2.2 + 0.4, 0.0, 1.0);
	float h = radius * 0.11;
	float outer = r - (radius - h + 2.0 * h * tooth);
	// Rim, five spokes and the hub; the windows between them are open.
	float rim_in = radius * 0.7;
	float hub = radius * 0.24;
	float seg = 6.2832 / 5.0;
	float sa = mod(a, seg) - seg * 0.5;
	float spoke = r * abs(sin(sa)) - radius * 0.07;
	// Negative inside a window: between hub and rim, away from the spokes.
	float window = max(max(hub - r, r - rim_in), -spoke);
	float jewel = step(r, radius * 0.1);
	return vec2(max(outer, -window), jewel);
}

// The movement at `uv`: x = distance to the nearest gear's solid, y = jewel,
// z = how high the surface is (for the bevel).
vec3 movement(vec2 uv) {
	float small_r = big_r * SMALL_TEETH / BIG_TEETH;
	float pitch = big_r + small_r;
	float period = pitch * 2.0;
	float row_h = big_r * 2.3;
	float row = floor(uv.y / row_h);
	float flip = mod(row, 2.0) < 0.5 ? 1.0 : -1.0;
	float u = uv.x + (flip > 0.0 ? 0.0 : period * 0.5);
	float v = uv.y - (row + 0.5) * row_h;
	float k = floor(u / period);
	float x = u - k * period;
	float big_a = tick_angle(BIG_TEETH) * flip;
	float small_a = -tick_angle(SMALL_TEETH) * flip + 3.1416 / SMALL_TEETH;
	vec2 g0 = gear(vec2(x, v), big_r, BIG_TEETH, big_a);
	vec2 g1 = gear(vec2(x - period, v), big_r, BIG_TEETH, big_a);
	vec2 g2 = gear(vec2(x - pitch, v), small_r, SMALL_TEETH, small_a);
	vec2 best = g0;
	if (g1.x < best.x) {
		best = g1;
	}
	if (g2.x < best.x) {
		best = g2;
	}
	return vec3(best, smoothstep(0.0015, -0.0015, best.x));
}

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

void fragment() {
	vec2 uv = fplane(lp, ln);
	if (is_trim) {
		// Guilloche: two families of fine engraved waves crossing.
		// They fade to a satin sheen where they are too fine to draw.
		float a1 = uv.y * 280.0 + sin(uv.x * 55.0) * 3.0;
		float a2 = uv.y * 280.0 - sin(uv.x * 55.0 + 1.6) * 3.0;
		float fine = clamp(max(fwidth(a1), fwidth(a2)) * 0.45, 0.0, 1.0);
		float lines = mix(smoothstep(0.5, 1.0, max(sin(a1), sin(a2))), 0.25, fine);
		vec3 n = fbump(VERTEX, NORMAL, lines, 0.004);
		NORMAL = n;
		vec3 r = reflect(-VIEW, n);
		float fres = ffres(n, VIEW, 2.5);
		ALBEDO = trim_color * 0.6;
		METALLIC = 1.0;
		ROUGHNESS = 0.22;
		EMISSION = fstudio(r, trim_color) * (0.5 + lines * 0.2) + trim_color * 0.1;
		PRINT_LAYER
	} else {
		vec3 m = movement(uv);
		vec3 shade = movement(uv + vec2(-0.003, 0.004));
		float solid = m.z;
		// The plate: blued steel with perlage, darker in the gears' shadow.
		vec2 pc = uv / 0.012;
		vec2 pid = floor(pc);
		float perlage = 0.5 + 0.5 * sin(length(fract(pc) - 0.5) * 38.0 + fh21(pid) * 6.0);
		perlage = mix(perlage, 0.5, clamp(fwidth(pc.x) * 4.0, 0.0, 1.0));
		vec3 plate = vec3(0.12, 0.2, 0.55) * (0.75 + 0.35 * perlage) * (1.0 - shade.z * 0.55 * (1.0 - solid));
		// Gears: brass with a bevel on every edge and a ruby in the hub.
		float h = smoothstep(0.0, -0.002, m.x);
		vec3 n = fbump(VERTEX, NORMAL, h * solid + solid, 0.0025);
		NORMAL = mix(NORMAL, n, solid);
		vec3 r = reflect(-VIEW, NORMAL);
		float fres = ffres(NORMAL, VIEW, 3.0);
		vec3 brass = shell_color * (0.9 + 0.1 * fnoise2(uv * 400.0));
		vec3 ruby = vec3(0.85, 0.05, 0.2);
		float jewel = m.y * solid;
		ALBEDO = mix(plate, mix(brass, ruby, jewel), solid);
		METALLIC = solid * (1.0 - jewel);
		ROUGHNESS = mix(0.35, 0.18, solid);
		EMISSION = mix(fstudio(r, vec3(0.3, 0.4, 0.9)) * 0.1 * perlage, fstudio(r, shell_color) * 0.6, solid)
			+ ruby * jewel * (0.8 + fres) + plate * 0.15 * (1.0 - solid);
		PRINT_LAYER
	}
}
