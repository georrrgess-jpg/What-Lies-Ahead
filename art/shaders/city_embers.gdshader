shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Rising embers above a fire, one MultiMesh of tiny quads (no particles node):
// every instance origin is a random seed above the fire; the shader lifts it,
// sways it and wraps its life, so nothing runs on the CPU.
uniform float rise = 3.0;
uniform float speed = 0.45;
uniform float size = 0.05;
uniform vec3 hot_color : source_color = vec3(1.0, 0.8, 0.35);
uniform vec3 cool_color : source_color = vec3(1.0, 0.25, 0.05);

varying float life;

void vertex() {
	vec3 seed = MODEL_MATRIX[3].xyz;
	float r = fract(sin(dot(seed, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	life = fract(TIME * speed * (0.7 + 0.6 * r) + r * 7.0);
	vec3 p = seed;
	p.y += life * rise;
	p.x += sin(TIME * (1.3 + r) + r * 6.0) * 0.35 * life;
	p.z += cos(TIME * (1.1 + r) + r * 3.0) * 0.35 * life;
	vec4 view_pos = VIEW_MATRIX * vec4(p, 1.0);
	view_pos.xy += VERTEX.xy * size * (1.0 - life * 0.6);
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float a = (1.0 - smoothstep(0.2, 1.0, d)) * (1.0 - smoothstep(0.6, 1.0, life)) * smoothstep(0.0, 0.08, life);
	ALBEDO = mix(hot_color, cool_color, life) * a * 2.0;
}
