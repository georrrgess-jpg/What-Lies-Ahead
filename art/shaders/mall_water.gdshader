shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
// Fountain water: moving ripples on the pools and streaks running down the
// falling sheets, tinted by the fountain's light colour (the level cycles
// `tint`). Works without UVs: pools use world XZ, sheets the world height.

uniform vec3 tint : source_color = vec3(0.4, 0.85, 1.0);
uniform float alpha_value = 0.72;
uniform float flow = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

float wave(vec2 p, float t) {
	return sin(p.x * 3.1 + t * 1.7) * 0.5 + sin(p.y * 2.7 - t * 1.3) * 0.5 + sin((p.x + p.y) * 5.3 + t * 2.9) * 0.25;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float t = TIME * flow;
	float up = abs(world_normal.y);
	float w = wave(world_pos.xz * 1.4, t);
	float falling = sin(world_pos.y * 9.0 + t * 9.0 + atan(world_pos.x, world_pos.z) * 12.0) * 0.5 + 0.5;
	float pattern = mix(falling, w * 0.5 + 0.5, up);
	ALBEDO = mix(tint * 0.55, mix(tint, vec3(1.0), 0.55), pattern);
	EMISSION = tint * (0.35 + 0.5 * pattern);
	ROUGHNESS = 0.05;
	SPECULAR = 0.9;
	ALPHA = mix(alpha_value * 0.75, alpha_value, pattern);
}
