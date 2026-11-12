shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Soft additive light card: sign halos, canyon haze, searchlight beams.
// shape 0 = radial blob, 1 = vertical fade (bright at the bottom, UV.y = 1),
// 2 = beam (bright along the centre line, fading toward the far end).
uniform vec3 glow_color : source_color = vec3(1.0, 0.3, 0.8);
uniform float strength = 0.6;
uniform int shape = 0;
uniform float pulse = 0.0;

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float g;
	if (shape == 0) {
		g = pow(clamp(1.0 - length(c), 0.0, 1.0), 2.0);
	} else if (shape == 1) {
		g = pow(UV.y, 2.2) * (1.0 - pow(abs(c.x), 4.0));
	} else {
		g = pow(clamp(1.0 - abs(c.x), 0.0, 1.0), 2.5) * pow(UV.y, 1.4);
	}
	float p = 1.0 + pulse * sin(TIME * 2.3);
	ALBEDO = glow_color * g * strength * p;
}
