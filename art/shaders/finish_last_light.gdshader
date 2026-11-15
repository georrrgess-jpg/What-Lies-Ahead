shader_type spatial;
// Mythic weapon finish "Last Light" (Endless: reach wave 30). A black-chrome
// shell with the burning skyline of Ashfall City drawn on it in molten
// light: two rows of towers drift past at different speeds (the far row
// dimmer), their windows flickering, under a sky that glows from ember red
// to gold. Molten rivulets run along the weapon, embers rise off it, the
// whole picture wavers in a heat shimmer, and every few seconds a gold glint
// sweeps the length of the weapon. Trim is molten gold with a red-hot ripple.
// Seen small (thumbnails, the Arsenal stand, the Locker) the fine detail
// fades by screen size into a bold version: one row of big towers in black
// against a glowing ember sky, so the finish reads as a skyline, not specks.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.04, 0.035, 0.05);
uniform vec3 trim_color : source_color = vec3(1.0, 0.68, 0.22);
uniform bool is_trim = false;
uniform vec3 molten : source_color = vec3(1.0, 0.32, 0.06);
uniform vec3 hot : source_color = vec3(1.0, 0.86, 0.5);
// Height of one skyline band (m) and how fast the city drifts past (m/s).
uniform float band = 0.065;
uniform float drift = 0.012;
// Screen footprint (m per pixel) over which the fine city gives way to the
// bold one: first person is about 0.0006, the Arsenal stand 0.003.
uniform vec2 detail_fade = vec2(0.0012, 0.0028);

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

// Tower height (0-1 of the band) at `u` along the weapon, for a row of
// towers `w` wide; `seed` picks the row. Returns height, and the window grid
// of that tower in `win` (lit 0/1 per window, flickering).
float skyline(float u, float w, float seed, float v, float t, out float win) {
	float id = floor(u / w);
	vec2 h = fh22(vec2(id, seed));
	float height = 0.25 + 0.6 * h.x * h.x + 0.15 * step(0.8, h.y);
	// Stepped tops and antennas on some towers.
	float fu = fract(u / w);
	height -= 0.12 * step(0.5, h.y) * step(abs(fu - 0.5), 0.5) * step(0.3, abs(fu - 0.5));
	float mast = step(0.86, h.y) * step(abs(fu - 0.5), 0.04) * 0.25;
	vec2 cell = vec2(floor(fu * 3.0), floor(v / 0.009));
	float lit = step(0.45, fh21(cell + id * 7.3 + seed));
	float flick = step(0.08, fract(sin(floor(t * 3.0 + fh21(cell + id) * 40.0) * 78.233) * 43758.5453));
	vec2 wf = fract(vec2(fu * 3.0, v / 0.009));
	win = lit * flick * step(0.25, wf.x) * step(wf.x, 0.75) * step(0.3, wf.y) * step(wf.y, 0.7);
	return height + mast;
}

// The burning city up close (emission only): the sky, two rows of towers
// with their windows, and rising embers. `px` is the screen footprint (m per
// pixel): edges stay at least a pixel wide.
vec3 city(vec2 uv, float t, float px) {
	float row = floor(uv.y / band);
	float v = fract(uv.y / band);
	float u = uv.x + row * 0.37;
	// Far row (slow, dim) and near row (faster, bright).
	float win_far;
	float win_near;
	float far_h = skyline(u + t * drift * 0.5, 0.011, row + 11.0, v * band, t, win_far) * 0.85;
	float near_h = skyline(u + t * drift, 0.017, row, v * band, t, win_near) * 0.6;
	float aa = max(0.01, px / band);
	float in_far = 1.0 - smoothstep(far_h - aa, far_h + aa, v);
	float in_near = 1.0 - smoothstep(near_h - aa, near_h + aa, v);
	float edge_near = smoothstep(max(0.045, aa * 1.5), 0.0, abs(v - near_h)) * (1.0 - in_near * 0.6);
	float edge_far = smoothstep(max(0.035, aa * 1.5), 0.0, abs(v - far_h)) * (1.0 - in_far * 0.6) * (1.0 - in_near);
	// An ember haze just above the rooftops; the sky above stays dark.
	float haze = exp(-max(v - far_h, 0.0) * 9.0) * (1.0 - in_far) * (1.0 - in_near);
	vec3 glow = molten * haze * 0.35;
	glow += molten * edge_far * 0.7 + mix(molten, hot, 0.55) * edge_near * 2.0;
	glow += hot * win_far * in_far * (1.0 - in_near) * 0.5 + hot * win_near * in_near * 1.4;
	// Embers rising off the shell.
	vec2 eg = vec2(uv.x * 55.0, uv.y * 55.0 - t * 1.6);
	vec2 eh = fh22(floor(eg));
	vec2 ef = fract(eg) - 0.5 - (eh - 0.5) * 0.6;
	float ember = smoothstep(0.16, 0.0, length(ef)) * step(0.82, eh.x) * (0.5 + 0.5 * sin(t * 6.0 + eh.y * 30.0));
	return glow + mix(hot, molten, eh.y) * ember * 2.0;
}


// The burning city seen small: one row of big towers, twice the band high,
// black against an ember sky that glows hottest at the rooftops, with
// molten rims and a few steady lit windows while they are still big enough.
vec3 city_bold(vec2 uv, float t, float px) {
	float bb = band * 2.0;
	float row = floor(uv.y / bb);
	float v = fract(uv.y / bb);
	float u = uv.x + row * 0.53 + t * drift;
	float w = 0.034;
	float id = floor(u / w);
	float fu = fract(u / w);
	vec2 h = fh22(vec2(id, row + 31.0));
	float height = 0.3 + 0.38 * h.x + 0.12 * step(0.75, h.y) - 0.1 * step(0.55, h.y) * step(0.3, abs(fu - 0.5));
	float aa = max(0.006, px / bb);
	float inside = 1.0 - smoothstep(height - aa, height + aa, v);
	// The sky is one smooth gradient behind every tower (hot low, ember red
	// high), so the towers read as cut-outs against it.
	vec3 sky = mix(mix(hot, molten, 0.4), molten * 0.8, smoothstep(0.15, 0.95, v)) * mix(0.75, 0.2, v);
	float rim = smoothstep(aa * 2.0, 0.0, abs(v - height)) * (1.0 - inside);
	vec3 glow = sky * (1.0 - inside) + hot * rim * 0.5;
	vec2 cell = vec2(floor(fu * 2.0), floor(v / 0.16));
	vec2 wf = fract(vec2(fu * 2.0, v / 0.16));
	float win = step(0.7, fh21(cell + id * 3.1 + row)) * step(0.3, wf.x) * step(wf.x, 0.7) * step(0.35, wf.y) * step(wf.y, 0.65);
	win *= inside * step(v, height - 0.08) * (1.0 - smoothstep(0.003, 0.006, px));
	return glow + hot * win * 0.7;
}


// The city at this screen footprint: fine up close, bold when small.
vec3 skyline_glow(vec2 uv, float t, float px) {
	float k = smoothstep(detail_fade.x, detail_fade.y, px);
	vec3 near = k < 1.0 ? city(uv, t, px) : vec3(0.0);
	vec3 far = k > 0.0 ? city_bold(uv, t, px) : vec3(0.0);
	return mix(near, far, k);
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	float t = TIME;
	vec2 uv = fplane(lp, ln);
	// Footprint along the less squeezed screen axis: a face seen edge-on
	// keeps its detail; only a weapon that is small on screen goes bold.
	float px = min(length(dFdx(uv)), length(dFdy(uv)));
	float fine = 1.0 - smoothstep(detail_fade.x, detail_fade.y, px);
	// Heat shimmer: the picture wavers.
	uv += vec2(sin(uv.y * 90.0 + t * 3.1), sin(uv.x * 70.0 - t * 2.3)) * 0.0012;
	float glint = exp(-pow(fract(lp.z * 0.6 - t * 0.16) * 5.0 - 2.5, 2.0) * 4.0);
	// Molten rivulets flowing along the weapon.
	float flow = ffbm3(lp * vec3(9.0, 16.0, 5.0) + vec3(0.0, 0.0, t * 0.25));
	float rivulet = smoothstep(0.012, 0.0, abs(flow - 0.52));
	vec3 lava = mix(molten, hot, 0.35 + 0.35 * sin(t * 2.0 + lp.z * 20.0)) * rivulet * 1.3 * fine;
	vec3 rim = mix(molten, hot, 0.6) * pow(fres, 2.5) * 0.45;
	if (is_trim) {
		// Blackened gold: the city glows through it dimmer, gold veins ripple
		// red-hot and its edges catch the light like polished gold.
		float ripple = 0.5 + 0.5 * sin(lp.z * 60.0 + ffbm3(lp * 14.0 + vec3(0.0, 0.0, -t * 0.3)) * 8.0 - t * 2.5);
		// Seen small the veins widen and dim, so they stay strokes, not specks.
		float vein = smoothstep(mix(0.09, 0.03, fine), 0.0, abs(ffbm3(lp * 18.0) - 0.5)) * mix(0.55, 1.0, fine);
		vec3 bronze = trim_color * 0.12;
		ALBEDO = mix(bronze, trim_color, vein);
		METALLIC = 1.0;
		ROUGHNESS = mix(0.24, 0.12, vein);
		EMISSION = fstudio(r, trim_color) * 0.12 + skyline_glow(uv + 0.05, t, px) * 0.7 + lava
			+ mix(molten, hot, ripple) * vein * (0.3 + ripple * 0.8) + trim_color * pow(fres, 2.5) * 0.35 + hot * glint * 0.5;
	} else {
		// Black chrome.
		ALBEDO = shell_color;
		METALLIC = 0.9;
		ROUGHNESS = 0.2;
		EMISSION = fstudio(r, vec3(0.3, 0.26, 0.36)) * 0.18 + skyline_glow(uv, t, px) + lava + rim + hot * glint * 0.35;
	}
	PRINT_LAYER
}
