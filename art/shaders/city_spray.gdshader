shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// A burst hydrant's jet (tools/city/city_life.gd builds the arc as crossed
// ribbons: UV.x across a ribbon, UV.y from the nozzle 0 to where it lands 1).
// Streaks of water race along it and break up toward the end.
uniform vec3 water : source_color = vec3(0.78, 0.86, 0.95);
uniform float speed = 3.2;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

void vertex() {
	// The jet wavers as the pressure surges.
	float s = UV.y;
	VERTEX.x += sin(TIME * 7.0 + s * 5.0) * 0.06 * s;
	VERTEX.y += sin(TIME * 3.1) * 0.08 * s * s;
}

void fragment() {
	float s = UV.y;
	float lane = floor(UV.x * 7.0);
	float streak = fract(s * 5.0 - TIME * speed + hash(vec2(lane, 1.0)));
	float body = smoothstep(0.0, 0.35, streak) * smoothstep(1.0, 0.6, streak);
	float edge = 1.0 - abs(UV.x * 2.0 - 1.0);
	// Solid near the nozzle, ragged spray further out.
	float spray = mix(1.0, step(0.45, hash(floor(UV * vec2(24.0, 30.0)) + floor(TIME * 20.0))), smoothstep(0.3, 1.0, s));
	ALPHA = clamp((0.35 + 0.65 * body) * edge * spray * (1.0 - s * 0.55), 0.0, 1.0) * 0.8;
	ALBEDO = water * (0.85 + 0.3 * body);
}
