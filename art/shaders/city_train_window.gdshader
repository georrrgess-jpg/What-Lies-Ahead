shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

// A lit window of the stalled Metro train (one MultiMesh of quads): the warm
// carriage light brightest under the ceiling strip, seat backs and a grab
// pole against it, and in some windows a figure standing still. A few
// windows buzz on a failing tube. Every window is seeded by its position.
uniform vec3 light_color : source_color = vec3(1.0, 0.82, 0.52);
uniform float strength = 1.7;

varying vec3 centre;

void vertex() {
	centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
}

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float h = hash(centre.x * 1.37 + centre.z * 0.11);
	vec3 col = light_color * mix(1.0, 0.5, uv.y);
	col += light_color * smoothstep(0.14, 0.0, uv.y) * 1.2;
	// Seat backs along the bottom.
	float bump = smoothstep(0.3, 0.18, abs(fract(uv.x * 2.0 + h) - 0.5));
	float seat = step(0.7 - bump * 0.12, uv.y);
	col = mix(col, vec3(0.1, 0.06, 0.07), seat * 0.85);
	// A grab pole.
	float pole_x = 0.12 + hash(h * 17.0) * 0.76;
	col = mix(col, vec3(0.55, 0.55, 0.58), smoothstep(0.022, 0.0, abs(uv.x - pole_x)) * 0.8);
	// Someone (something) standing in the carriage.
	if (h > 0.62) {
		float x = uv.x - (0.22 + 0.56 * hash(h * 91.0));
		float body = step(abs(x), 0.085 - (uv.y - 0.3) * 0.03) * step(0.3, uv.y);
		float head = step(length(vec2(x, (uv.y - 0.2) * 1.2)), 0.075);
		col = mix(col, vec3(0.03, 0.02, 0.03), max(body, head));
	}
	// A failing tube in a few windows.
	if (h < 0.12) {
		col *= 0.55 + 0.45 * step(0.3, fract(sin(floor(TIME * 9.0 + h * 50.0)) * 43758.5453));
	}
	ALBEDO = col * strength;
}
