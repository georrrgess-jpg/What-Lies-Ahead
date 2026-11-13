shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;
// Helmet glass for operators (scripts/cosmetics/operators.gd): clear face-on so
// the face behind it reads, tinted and bright toward the rim, with two soft
// window highlights.
uniform vec3 shell_color : source_color = vec3(0.75, 0.94, 1.0);
uniform float opacity = 0.06;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.6);
	vec2 n = NORMAL.xy;
	float glint = smoothstep(0.14, 0.0, length(n - vec2(-0.38, 0.5))) * 0.55 + smoothstep(0.07, 0.0, length(n - vec2(-0.2, 0.3))) * 0.4;
	ALBEDO = mix(shell_color * 0.7, vec3(1.0), rim * 0.4);
	ALPHA = clamp(opacity + rim * 0.75 + glint, 0.0, 0.92);
	ROUGHNESS = 0.05;
	SPECULAR = 0.8;
	EMISSION = shell_color * rim * 0.3 + vec3(1.0) * glint;
}
