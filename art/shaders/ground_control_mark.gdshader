shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_back, shadows_disabled, fog_disabled;

// Ground Control's radar mark (material_overlay on a marked zombie): a lime
// rim drawn through walls, with a scan line climbing the body like a radar
// echo. `strength` fades it in and out.
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec3 mark_color : source_color = vec3(0.66, 0.9, 0.24);

varying float height;

void vertex() {
	height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.4);
	float scan = smoothstep(0.82, 1.0, fract(height * 1.6 - TIME * 1.4));
	float pulse = 0.8 + 0.2 * sin(TIME * 7.0);
	ALBEDO = mark_color * (rim * 1.6 * pulse + scan * 0.35 + 0.04) * strength;
}
