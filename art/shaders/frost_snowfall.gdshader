shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Falling snow drawn as one MultiMesh of tiny quads (see
// scripts/fx/frost_snowfall.gd). Each instance origin is a random seed inside
// the volume; the flake falls, drifts with the wind and wraps around a box
// that follows the camera, so a few thousand flakes cover any view.
uniform vec3 box_size = vec3(40.0, 22.0, 40.0);
uniform float fall_speed = 1.3;
uniform vec2 wind = vec2(0.6, 0.2);
uniform float flake_size = 0.045;
uniform vec4 flake_color : source_color = vec4(0.92, 0.95, 1.0, 0.85);

varying float fade;

void vertex() {
	vec3 seed = MODEL_MATRIX[3].xyz;
	float r = fract(sin(dot(seed, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float t = TIME;
	vec3 p = seed;
	p.y -= t * fall_speed * (0.7 + 0.6 * r);
	p.xz += wind * t * (0.8 + 0.4 * r);
	p.x += sin(t * (0.6 + r) + seed.z) * 0.5;
	p.z += cos(t * (0.5 + r * 0.7) + seed.x) * 0.5;
	vec3 base = CAMERA_POSITION_WORLD - box_size * 0.5;
	vec3 world = base + mod(p - base, box_size);
	vec4 view_pos = VIEW_MATRIX * vec4(world, 1.0);
	float size = flake_size * (0.6 + 0.8 * r);
	view_pos.xy += VERTEX.xy * size;
	float depth = -view_pos.z;
	fade = smoothstep(0.4, 2.0, depth) * (1.0 - smoothstep(box_size.x * 0.32, box_size.x * 0.5, depth));
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float a = (1.0 - smoothstep(0.35, 1.0, d)) * fade * flake_color.a;
	ALBEDO = flake_color.rgb;
	ALPHA = a;
}
