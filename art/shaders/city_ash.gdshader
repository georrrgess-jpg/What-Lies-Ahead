shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Drifting ash over Ashfall City, one MultiMesh of tiny quads (see
// scripts/props/city_ashfall.gd). Each instance origin is a random seed in the
// volume; the flake falls slowly, flutters, drifts with the wind and wraps
// around a box that follows the camera. A few flakes are still-glowing embers.
uniform vec3 box_size = vec3(44.0, 24.0, 44.0);
uniform float fall_speed = 0.55;
uniform vec2 wind = vec2(0.8, 0.3);
uniform float flake_size = 0.04;
uniform vec4 ash_color : source_color = vec4(0.44, 0.41, 0.4, 0.7);
uniform vec3 ember_color : source_color = vec3(1.0, 0.45, 0.12);
// Share of flakes that glow.
uniform float ember_share = 0.07;

varying float fade;
varying float ember;

void vertex() {
	vec3 seed = MODEL_MATRIX[3].xyz;
	float r = fract(sin(dot(seed, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float r2 = fract(r * 17.31 + 0.13);
	float t = TIME;
	vec3 p = seed;
	p.y -= t * fall_speed * (0.6 + 0.8 * r);
	p.xz += wind * t * (0.7 + 0.6 * r);
	p.x += sin(t * (0.5 + r) + seed.z) * 0.7;
	p.z += cos(t * (0.4 + r * 0.6) + seed.x) * 0.7;
	vec3 base = CAMERA_POSITION_WORLD - box_size * 0.5;
	vec3 world = base + mod(p - base, box_size);
	vec4 view_pos = VIEW_MATRIX * vec4(world, 1.0);
	ember = step(1.0 - ember_share, r2);
	float flutter = 0.35 + 0.65 * abs(sin(t * (2.0 + r * 3.0) + r * 9.0));
	vec2 corner = VERTEX.xy * flake_size * (0.6 + 0.9 * r) * mix(1.0, 0.7, ember);
	corner.x *= flutter;
	view_pos.xy += corner;
	float depth = -view_pos.z;
	fade = smoothstep(0.4, 2.0, depth) * (1.0 - smoothstep(box_size.x * 0.3, box_size.x * 0.5, depth));
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float a = (1.0 - smoothstep(0.4, 1.0, d)) * fade;
	float pulse = 0.7 + 0.3 * sin(TIME * 6.0 + FRAGCOORD.x * 0.01);
	ALBEDO = mix(ash_color.rgb, ember_color * 2.5 * pulse, ember);
	ALPHA = a * mix(ash_color.a, 1.0, ember);
}
