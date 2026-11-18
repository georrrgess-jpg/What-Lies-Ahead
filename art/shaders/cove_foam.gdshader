shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// Foam where the sea laps the quay walls, the jetty piles and the hulls: a
// soft white band (UV.y 0 at the wall, 1 out in the water) broken into
// drifting clumps that swell and fade with the waves. UV.x runs along the
// shore in metres.
uniform vec3 color : source_color = vec3(0.95, 1.0, 0.98);
uniform float strength = 0.55;

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
	float t = TIME;
	float lap = 0.5 + 0.5 * sin(t * 1.3 + UV.x * 0.35);
	float reach = 0.45 + 0.4 * lap;
	float band = 1.0 - smoothstep(reach * 0.4, reach, UV.y);
	float clumps = noise(vec2(UV.x * 1.6 - t * 0.25, UV.y * 3.0 + t * 0.4)) * 0.6 + noise(vec2(UV.x * 4.0 + t * 0.3, UV.y * 6.0)) * 0.4;
	float a = band * smoothstep(0.35, 0.75, clumps + (1.0 - UV.y) * 0.35) * strength;
	ALBEDO = color * a;
}
