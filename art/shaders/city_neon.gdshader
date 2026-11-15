shader_type spatial;

// Ashfall City neon tubes: emissive, humming, and every so often a sign
// stutters off and back on. Each object flickers on its own pattern (seeded by
// its world position), so no script runs per frame.
uniform vec3 color : source_color = vec3(1.0, 0.18, 0.68);
uniform float strength = 3.2;
// 0 = steady, 1 = flickers as much as the worst sign on the street.
uniform float flicker = 1.0;

float hash11(float p) {
	return fract(sin(p * 127.1) * 43758.5453);
}

void fragment() {
	vec3 wp = NODE_POSITION_WORLD;
	float seed = hash11(dot(wp, vec3(1.7, 9.2, 3.1)));
	float t = TIME + seed * 40.0;
	// A burst window opens for ~1.5 s every 6-11 s; inside it the tube cuts out in random steps.
	float cycle = 6.0 + seed * 5.0;
	float in_burst = step(cycle - 1.5, mod(t, cycle));
	float step_rand = hash11(floor(t * 14.0) + seed * 91.0);
	float off = in_burst * step(0.45, step_rand) * flicker;
	float hum = 0.94 + 0.06 * sin(t * 47.0);
	float on = (1.0 - off * 0.88) * hum;
	ALBEDO = color * 0.25;
	ROUGHNESS = 0.3;
	EMISSION = color * strength * on;
}
