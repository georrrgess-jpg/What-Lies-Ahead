shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Ashfall City flames on crossed quads (scenes/props/city_fire.tscn): tall
// licking tongues eaten by scrolling noise, white-gold core, orange body, red
// tips that fade to nothing. Each fire is seeded by its world position, so all
// fires share one material and still never move in step.
uniform vec3 core_color : source_color = vec3(1.0, 0.9, 0.55);
uniform vec3 body_color : source_color = vec3(1.0, 0.45, 0.1);
uniform vec3 tip_color : source_color = vec3(0.85, 0.12, 0.05);
uniform float strength = 1.5;
uniform float speed = 1.0;

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec3 wp = NODE_POSITION_WORLD;
	float seed = fract(sin(dot(wp, vec3(12.9898, 78.233, 37.719))) * 43758.5453) * 50.0;
	float t = TIME * speed + seed;
	vec2 uv = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float n = noise2(vec2(uv.x * 3.0 + seed, uv.y * 3.5 - t * 2.4)) * 0.55
			+ noise2(vec2(uv.x * 6.5 - seed, uv.y * 7.0 - t * 3.9)) * 0.3
			+ noise2(vec2(uv.x * 13.0, uv.y * 12.0 - t * 6.0)) * 0.15;
	float sway = (sin(t * 2.1 + uv.y * 3.0) * 0.6 + sin(t * 3.7 + uv.y * 5.0) * 0.4) * 0.1 * uv.y;
	float width = (1.0 - pow(uv.y, 1.5)) * 0.85 + 0.05;
	float d = abs(uv.x - sway) + n * (0.25 + 0.4 * uv.y);
	float shape = 1.0 - smoothstep(width * 0.5, width, d);
	shape *= smoothstep(0.0, 0.05, uv.y) * (1.0 - smoothstep(0.55, 1.0, uv.y + n * 0.35));
	float heat = shape * (1.0 - uv.y * 0.75);
	vec3 col = mix(tip_color, body_color, smoothstep(0.08, 0.4, heat));
	col = mix(col, core_color, smoothstep(0.5, 0.85, heat));
	ALBEDO = col * shape * strength;
}
