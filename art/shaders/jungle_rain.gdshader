shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Monsoon rain drawn as one MultiMesh of thin streaks (scripts/props/jungle_rain.gd).
// Each instance origin is a random seed in the volume; the drop falls fast,
// slants with the wind and wraps around a box that follows the camera.
// `amount` (0..1) is the share of drops drawn (the downpour fades in and out).
uniform vec3 box_size = vec3(36.0, 20.0, 36.0);
uniform float fall_speed = 16.0;
uniform vec2 wind = vec2(1.5, 0.6);
uniform float amount = 0.0;
uniform vec4 drop_color : source_color = vec4(0.78, 0.86, 0.9, 0.42);
// Roofed volumes (world-space boxes) no drop is drawn in.
uniform vec3 shelter_min[8];
uniform vec3 shelter_max[8];
uniform int shelter_count = 0;

varying float fade;

void vertex() {
	vec3 seed = MODEL_MATRIX[3].xyz;
	float r = fract(sin(dot(seed, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	vec3 vel = vec3(wind.x, -fall_speed * (0.85 + 0.3 * r), wind.y);
	vec3 p = seed + vel * TIME;
	vec3 base = CAMERA_POSITION_WORLD - box_size * 0.5;
	vec3 world = base + mod(p - base, box_size);
	float keep = step(r, amount);
	for (int i = 0; i < 8; i++) {
		if (i < shelter_count && all(greaterThan(world, shelter_min[i])) && all(lessThan(world, shelter_max[i]))) {
			keep = 0.0;
		}
	}
	// A thin streak along the fall direction, turned to face the camera.
	vec3 along = normalize(vel);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world);
	vec3 side = normalize(cross(along, to_cam));
	vec3 v = world + (side * VERTEX.x * 0.018 + along * VERTEX.y * 0.42) * keep;
	vec4 view_pos = VIEW_MATRIX * vec4(v, 1.0);
	float depth = -view_pos.z;
	fade = smoothstep(0.6, 2.5, depth) * (1.0 - smoothstep(box_size.x * 0.3, box_size.x * 0.5, depth));
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	float a = (1.0 - abs(UV.x * 2.0 - 1.0)) * smoothstep(0.0, 0.4, UV.y) * smoothstep(0.0, 0.3, 1.0 - UV.y);
	ALBEDO = drop_color.rgb;
	ALPHA = a * fade * drop_color.a;
}
