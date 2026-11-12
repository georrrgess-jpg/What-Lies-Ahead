shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
// Clear tinted glass for helmets, visors and snow globes: nearly transparent
// face-on, bright and coloured at grazing angles, with a soft highlight.
uniform vec3 shell_color : source_color = vec3(0.75, 0.94, 1.0);
uniform float opacity = 0.12;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	ALBEDO = mix(shell_color * 0.6, vec3(1.0), fres * 0.4);
	ALPHA = clamp(opacity + fres * 0.7, 0.0, 0.9);
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 1.0;
	EMISSION = shell_color * fres * 0.25;
}
