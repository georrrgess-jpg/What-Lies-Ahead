shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Madame Fortuna's Mythic aura (scripts/cosmetics/operator_aura.gd), the
// additive quads: mode 0 is the sigil on the floor (two rings of runes turning
// opposite ways round a hexagram), mode 1 the halo of turning rays behind the
// head on the player card. Colour flows from the Mythic red to gold. Alpha
// blended rather than additive, so it shows on a transparent menu viewport.
uniform int mode = 0;
uniform float strength = 1.0;
uniform vec3 red : source_color = vec3(1.0, 0.23, 0.36);
uniform vec3 gold : source_color = vec3(1.0, 0.78, 0.3);

float band(float x, float a, float b, float soft) {
	return smoothstep(a - soft, a, x) * (1.0 - smoothstep(b, b + soft, x));
}

// Distance to the line through a and b (for the hexagram's sides).
float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float triangle_lines(vec2 p, float r, float turn) {
	float d = 1.0;
	for (int i = 0; i < 3; i++) {
		float a0 = turn + 6.2832 * float(i) / 3.0;
		float a1 = turn + 6.2832 * float(i + 1) / 3.0;
		d = min(d, seg(p, vec2(cos(a0), sin(a0)) * r, vec2(cos(a1), sin(a1)) * r));
	}
	return d;
}

vec3 flow(float a) {
	return mix(red, gold, 0.5 + 0.5 * sin(a * 2.0 - TIME * 1.4));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float glow = 0.0;
	if (mode == 0) {
		glow += band(r, 0.9, 0.93, 0.02) + band(r, 0.6, 0.62, 0.02) * 0.9;
		float runes = band(r, 0.68, 0.84, 0.015) * step(0.55, fract((a + TIME * 0.25) * 24.0 / 6.2832)) * step(0.3, sin((a + TIME * 0.25) * 72.0) + 0.6);
		glow += runes * 0.7;
		float ticks = band(r, 0.94, 0.99, 0.01) * step(0.8, fract((a - TIME * 0.12) * 48.0 / 6.2832));
		glow += ticks;
		float hex = min(triangle_lines(p, 0.58, -TIME * 0.18 + 1.5708), triangle_lines(p, 0.58, -TIME * 0.18 - 1.5708));
		glow += smoothstep(0.018, 0.0, hex) * 0.9;
		glow += exp(-r * r * 9.0) * 0.35;
		glow *= 1.0 - smoothstep(0.97, 1.0, r);
	} else {
		float rays = pow(0.5 + 0.5 * sin(a * 10.0 + TIME * 0.6), 6.0) + pow(0.5 + 0.5 * sin(a * 7.0 - TIME * 0.45), 8.0) * 0.6;
		glow = rays * smoothstep(1.0, 0.35, r) * smoothstep(0.12, 0.45, r) * 0.55;
		glow += band(r, 0.52, 0.56, 0.05) * 0.8 + exp(-r * r * 4.0) * 0.4;
		glow *= 1.0 - smoothstep(0.85, 1.0, r);
	}
	float pulse = 0.85 + 0.15 * sin(TIME * 2.2);
	float g = glow * strength * pulse;
	ALBEDO = flow(a) + vec3(1.0, 0.95, 0.85) * clamp(g - 0.8, 0.0, 1.0) * 0.6;
	ALPHA = clamp(g, 0.0, 1.0);
}
