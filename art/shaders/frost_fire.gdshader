shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// Stylised campfire flame for crossed quads: a tapering silhouette eaten away
// by scrolling noise, white-gold core, orange body and red tips.
uniform vec3 core_color : source_color = vec3(1.0, 0.92, 0.6);
uniform vec3 body_color : source_color = vec3(1.0, 0.5, 0.12);
uniform vec3 tip_color : source_color = vec3(0.9, 0.16, 0.08);
uniform float strength = 1.4;
uniform float seed = 0.0;

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
	float t = TIME + seed * 7.0;
	vec2 uv = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);      // y: 0 at the base, 1 at the top
	float n = noise2(vec2(uv.x * 3.0, uv.y * 4.0 - t * 2.6)) * 0.6 + noise2(vec2(uv.x * 7.0, uv.y * 8.0 - t * 4.1)) * 0.4;
	float sway = sin(t * 2.3 + uv.y * 3.0) * 0.08 * uv.y;
	float width = (1.0 - uv.y) * 0.85 + 0.05;
	float shape = 1.0 - smoothstep(width * 0.55, width, abs(uv.x - sway) + n * 0.35 * uv.y);
	shape *= smoothstep(0.0, 0.06, uv.y) * (1.0 - smoothstep(0.65, 1.0, uv.y + n * 0.3));
	float heat = shape * (1.0 - uv.y * 0.7);
	vec3 col = mix(tip_color, body_color, smoothstep(0.1, 0.45, heat));
	col = mix(col, core_color, smoothstep(0.55, 0.85, heat));
	ALBEDO = col * shape * strength;
}
