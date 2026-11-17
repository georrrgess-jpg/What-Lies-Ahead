shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// The Strike Zone's hologram ball-return rail: an open channel whose UV.x runs
// across it (0 and 1 are the two lip edges) and UV.y along it, from the bottom
// (0) to the chamber (1). A glassy fill, glowing lip edges and floor corners,
// and lane arrows that chase along it toward the chamber (alpha-blended). `materialize` (0-1)
// prints it in from the bottom end with a flickering bright front.
uniform vec3 holo_color : source_color = vec3(0.3, 0.95, 1.0);
uniform float materialize : hint_range(0.0, 1.0) = 1.0;
uniform float intensity = 1.2;
// Arrows per unit of the rail's length (UV.y), and how fast they chase (rails per second).
uniform float arrows = 9.0;
uniform float chase = 1.4;
// Where the floor meets the walls across UV.x (the walls' share of the channel).
uniform float wall = 0.17;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float edge = min(u, 1.0 - u);
	float floor_k = smoothstep(wall * 0.8, wall, edge);
	float lip = smoothstep(0.06, 0.0, edge);
	float corner = smoothstep(0.035, 0.0, abs(edge - wall));
	// Chevrons point toward the chamber: the middle of each leads its wings.
	float phase = fract(v * arrows + abs(u - 0.5) * 1.5 - TIME * chase);
	float arrow = smoothstep(0.0, 0.07, phase) * smoothstep(0.3, 0.2, phase) * floor_k;
	float fill = mix(0.55, 0.42, floor_k) + 0.04 * sin(v * 500.0 - TIME * 24.0);
	float flicker = 0.9 + 0.1 * sin(TIME * 61.0) * sin(TIME * 19.0);
	float front = materialize * 1.12 - v + (hash(floor(vec2(u, v) * 160.0) + floor(TIME * 24.0)) - 0.5) * 0.05;
	if (front < 0.0) {
		discard;
	}
	float rim = smoothstep(0.07, 0.0, front);
	// Blended, not added, so the cyan holds against a bright floor or sky: the
	// edges and arrows go pale cyan-white, the fill stays a see-through cyan.
	float bright = clamp(lip * 0.8 + corner * 0.5 + arrow * 0.9 + rim, 0.0, 1.0);
	ALBEDO = mix(holo_color * vec3(0.55, 0.92, 1.0), vec3(0.85, 1.0, 1.0), bright);
	ALPHA = min((fill + lip * 0.6 + corner * 0.35 + arrow * 0.6 + rim * 0.6) * flicker * intensity * 0.85, 0.97);
}
