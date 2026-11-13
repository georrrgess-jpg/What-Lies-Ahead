shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// The volcano's plume on a tall card (UV.y = 1 at the crater): billowing puffs
// rise, widen and drift, dark violet above, lit ember-orange from below.
uniform vec3 smoke_color : source_color = vec3(0.2, 0.12, 0.24);
uniform vec3 under_color : source_color = vec3(1.0, 0.38, 0.14);
uniform vec3 rim_color : source_color = vec3(0.85, 0.4, 0.55);
uniform float opacity = 0.9;
uniform float speed = 0.05;
uniform float seed = 0.0;
uniform float under_glow = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += noise(p) * a;
		p = p * 2.07 + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float h = 1.0 - UV.y;
	float t = TIME * speed + seed;
	float lean = h * h * 0.18;
	float x = (UV.x - 0.5 - lean) / mix(0.12, 0.5, pow(h, 0.7));
	float n = fbm(vec2(x * 1.4 + seed, h * 3.0 - t * 3.0));
	float body = 1.0 - smoothstep(0.55, 1.05, abs(x) + (n - 0.5) * 0.9);
	body *= smoothstep(0.0, 0.05, h) * (1.0 - smoothstep(0.75, 1.0, h + (n - 0.5) * 0.3));
	float puff = smoothstep(0.25, 0.75, n);
	vec3 col = mix(smoke_color, rim_color, smoothstep(0.55, 0.85, n) * 0.35);
	col = mix(col, under_color, (1.0 - smoothstep(0.0, 0.35, h)) * under_glow * (0.6 + 0.4 * puff));
	ALBEDO = col;
	ALPHA = clamp(body * mix(0.55, 1.0, puff) * opacity, 0.0, 1.0);
}
