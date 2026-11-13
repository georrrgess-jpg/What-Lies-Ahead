shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Waterfall curtain: streaks scrolling down (UV.y grows downward), whiter at
// the foot, soft at the sides. `rate` speeds it up during the monsoon.
uniform vec3 water : source_color = vec3(0.62, 0.9, 0.88);
uniform vec3 foam : source_color = vec3(0.96, 1.0, 0.98);
uniform float rate = 1.2;
uniform float columns = 14.0;
uniform float opacity = 0.9;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float t = TIME * rate;
	vec2 uv = UV;
	float s1 = noise(vec2(uv.x * columns, uv.y * 3.0 - t * 2.2));
	float s2 = noise(vec2(uv.x * columns * 2.3 + 4.0, uv.y * 6.0 - t * 3.1));
	float streak = s1 * 0.6 + s2 * 0.4;
	vec3 col = mix(water, foam, clamp(smoothstep(0.45, 0.85, streak) * 0.85 + smoothstep(0.75, 1.0, uv.y) * 0.6, 0.0, 1.0));
	float side = smoothstep(0.0, 0.08, uv.x) * smoothstep(0.0, 0.08, 1.0 - uv.x);
	float a = opacity * side * (0.55 + 0.45 * streak) * smoothstep(0.0, 0.04, uv.y);
	ALBEDO = col * 1.05;
	ALPHA = clamp(a, 0.0, 1.0);
}
