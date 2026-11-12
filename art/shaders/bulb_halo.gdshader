shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Soft additive glow for the crossed halo quads around every bulb.
uniform vec3 glow_color : source_color = vec3(1.0, 0.7, 0.3);
uniform float strength = 0.55;

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float g = pow(clamp(1.0 - r, 0.0, 1.0), 2.2);
	ALBEDO = glow_color * g * strength;
}
