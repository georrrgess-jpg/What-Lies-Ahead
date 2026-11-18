shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// The lighthouse beam: a soft additive cone, brightest along its axis near
// the lamp, fading toward its wide end and at its silhouette edges.
uniform vec3 color : source_color = vec3(1.0, 0.92, 0.66);
uniform float strength = 0.35;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float along = clamp(abs(local_pos.z) / 34.0, 0.0, 1.0);
	float edge = abs(dot(NORMAL, VIEW));
	float a = strength * (1.0 - along) * (1.0 - along) * smoothstep(0.0, 0.6, edge);
	ALBEDO = color * a;
}
