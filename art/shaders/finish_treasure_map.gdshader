shader_type spatial;
// Weapon finish "Treasure Map": a creased parchment chart that draws itself.
// Every map panel along the weapon sketches its coast and sea, then an inked
// dotted route winds across it, head first, and ends on a big red X that
// pulses before the ink dries away and the map starts over. Compass roses
// in the corners; the trim is oiled wood with brass fittings.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.91, 0.82, 0.58);
uniform vec3 trim_color : source_color = vec3(0.3, 0.17, 0.09);
uniform bool is_trim = false;
uniform vec3 ink_color : source_color = vec3(0.25, 0.14, 0.07);
uniform vec3 sea_color : source_color = vec3(0.45, 0.66, 0.62);
uniform vec3 mark_color : source_color = vec3(0.85, 0.12, 0.1);
uniform float panel = 0.1;
uniform float cycle = 11.0;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = print_xform(VERTEX);
	ln = NORMAL;
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// The route across one panel: x runs 0..1 along the weapon, y is height.
float route_y(float x, float seed) {
	return 0.3 * sin(x * 7.0 + seed * 6.0) * (0.35 + 0.45 * x) + 0.06 * sin(x * 17.0 + seed * 3.0);
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	float fres = ffres(NORMAL, VIEW, 3.0);
	vec2 uv = fplane(lp, ln);
	if (is_trim) {
		float grain = fnoise2(vec2(lp.z * 40.0, lp.y * 600.0 + lp.x * 600.0));
		float band = smoothstep(0.012, 0.006, abs(fract(lp.z / 0.16) - 0.5) * 0.16 - 0.03);
		vec3 wood = trim_color * (0.7 + 0.5 * grain);
		vec3 brass = vec3(0.85, 0.62, 0.22);
		ALBEDO = mix(wood, brass, band);
		METALLIC = band * 0.9;
		ROUGHNESS = mix(0.45, 0.28, band);
		EMISSION = fstudio(r, brass) * band * 0.6 + fstudio(r, vec3(0.5)) * 0.08;
		PRINT_LAYER
	} else {
	// Panel coordinates: x along the barrel, y across; each panel has its own seed.
	vec2 pp = vec2(uv.x / panel, uv.y / (panel * 0.62));
	float seed = fh21(floor(pp) + 3.0);
	vec2 q = vec2(fract(pp.x), fract(pp.y) - 0.5);
	float phase = fract(TIME / cycle);
	// Timeline (fractions of the cycle): 0-0.12 coast sketch, 0.12-0.6 the route
	// is drawn, 0.6-0.8 the X pulses, 0.8-1.0 the ink dries away.
	float sketch = smoothstep(0.0, 0.12, phase);
	float route_t = clamp((phase - 0.12) / 0.48, 0.0, 1.0);
	float fade = 1.0 - smoothstep(0.82, 0.98, phase);
	float ink_on = sketch * fade;

	// Parchment: mottled, with stains, folds and burnt-brown edges to each panel.
	float mottle = ffbm2(uv * 22.0 + seed * 9.0);
	float stain = smoothstep(0.55, 0.8, ffbm2(uv * 7.0 + 4.0));
	vec3 paper = shell_color * (0.95 + 0.3 * mottle) * (1.0 - stain * 0.16);
	float fold = smoothstep(0.03, 0.0, abs(q.x - 0.5) * panel) * 0.5;
	paper *= 1.0 - fold * 0.4;
	float edge = smoothstep(0.0, 0.06, min(min(q.x, 1.0 - q.x), 0.5 - abs(q.y)));
	paper = mix(paper * vec3(0.7, 0.5, 0.35), paper, edge);

	// Land: a blobby island per panel, with a sea wash and wave ticks round it.
	vec2 c = vec2(0.5 + (seed - 0.5) * 0.2, 0.0);
	float shape = length((q - c) * vec2(0.9, 1.25)) - 0.27 - (ffbm2(q * 5.0 + seed * 20.0) - 0.5) * 0.45;
	float land = smoothstep(0.02, -0.02, shape);
	float coast = smoothstep(0.022, 0.0, abs(shape)) * ink_on;
	float sea = smoothstep(0.1, -0.06, -shape) * (1.0 - land) * 0.0 + smoothstep(0.4, 0.0, shape) * (1.0 - land);
	// Contour ripples round the coast, as on an old chart.
	float ripple = smoothstep(0.1, 0.0, abs(fract(shape * 11.0) - 0.5) * 2.0 - 0.8) * step(0.03, shape) * step(shape, 0.3) * (1.0 - land);
	vec3 col = mix(paper, mix(paper, sea_color, 0.6), sea * sketch);
	col = mix(col, paper * 1.06, land * sketch * 0.5);
	col = mix(col, ink_color, max(coast * 0.95, ripple * 0.4 * ink_on));
	// Little hatching on the land: a mountain range.
	float hill = smoothstep(0.012, 0.0, abs(fract((q.x + q.y * 0.5) * 22.0) - 0.5) * 0.045 - 0.006) * land * ink_on * 0.2;
	col = mix(col, ink_color, hill);

	// The dotted route, drawn head first along the panel.
	float x = q.x;
	float y = route_y(x, seed);
	float d = abs(q.y - y) * 0.9;
	float along = x * panel;
	vec2 dp = vec2(fract(along / 0.0065) - 0.5, d * panel * 0.62 / 0.0065);
	float dot_v = smoothstep(0.42, 0.32, length(dp)) * step(x, route_t) * step(0.04, x) * step(x, 0.9);
	float head = exp(-pow((x - route_t) * 22.0, 2.0)) * step(0.0001, route_t) * step(route_t, 0.999) * smoothstep(0.0, 0.01, d * -1.0 + 0.03);
	vec3 route_col = mix(mark_color * 0.8, ink_color, 0.2);
	col = mix(col, route_col, dot_v * fade);

	// The X at the end of the route: two inked bars, pulsing once the route lands.
	vec2 xp = q - vec2(0.9, route_y(0.9, seed));
	float arm = min(seg_dist(xp, vec2(-0.075, -0.075), vec2(0.075, 0.075)), seg_dist(xp, vec2(-0.075, 0.075), vec2(0.075, -0.075)));
	float xmark = smoothstep(0.032, 0.02, arm) * smoothstep(0.96, 1.0, route_t) * fade;
	float pulse = 0.5 + 0.5 * sin(TIME * 7.0);
	float xglow = smoothstep(0.1, 0.0, arm) * smoothstep(0.96, 1.0, route_t) * fade;
	col = mix(col, mark_color, xmark);

	// Compass rose in the first quarter of every panel: a four-point star in a ring.
	vec2 cp = q - vec2(0.13, 0.3);
	float ring = smoothstep(0.012, 0.0, abs(length(cp * vec2(1.0, 1.0)) - 0.09));
	float cross_v = min(abs(cp.x), abs(cp.y)) * 6.0 + length(cp) * 1.2;
	float star = smoothstep(0.16, 0.0, cross_v - 0.02) * smoothstep(0.11, 0.09, length(cp));
	col = mix(col, ink_color, max(ring * 0.7, star * 0.8) * ink_on);

	// A wet-ink glint at the drawing head.
	float wet = head * 0.5 * (1.0 - xmark);

	ALBEDO = col;
	METALLIC = 0.0;
	ROUGHNESS = 0.78 - wet * 0.3;
	EMISSION = mark_color * (xglow * (0.2 + 0.55 * pulse) + wet * 0.35) + fstudio(r, vec3(0.9)) * 0.03 + vec3(1.0) * pow(fres, 4.0) * 0.04;
	PRINT_LAYER
	}
}
