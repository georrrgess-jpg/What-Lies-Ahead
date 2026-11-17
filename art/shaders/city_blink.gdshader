shader_type spatial;
render_mode unshaded, shadows_disabled;

// Ashfall City signal lamps that still run on their own (one MultiMesh of
// small lenses): car hazards and alarms, flashing ambers, a traffic signal
// still cycling, crossing hands. The instance colour is the lamp's colour.
// INSTANCE_CUSTOM: x period (s), y phase (0..1), z on-fraction (blink) or
// slot (cycle: 0 green, 1 amber, 2 red), w mode (0 blink, 1 cycle).
uniform float strength = 3.0;
uniform float dim = 0.07;

varying vec4 cfg;
varying vec3 lamp;

void vertex() {
	cfg = INSTANCE_CUSTOM;
	lamp = COLOR.rgb;
}

void fragment() {
	float t = fract(TIME / max(cfg.x, 0.01) + cfg.y);
	float on;
	if (cfg.w < 0.5) {
		on = step(t, cfg.z);
	} else {
		// Green for 45%, amber 10%, red 45% of the cycle.
		float slot = t < 0.45 ? 0.0 : (t < 0.55 ? 1.0 : 2.0);
		on = 1.0 - step(0.5, abs(slot - cfg.z));
	}
	ALBEDO = lamp * mix(dim, strength, on);
}
