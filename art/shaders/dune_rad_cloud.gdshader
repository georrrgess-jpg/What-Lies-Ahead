shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front, shadows_disabled, fog_disabled;

// The hazmat zombie's radioactive cloud: a churning green-yellow dome, drawn
// from the inside faces so it still reads while the player stands in it.
// `strength` is driven by script (swell in, fade out).
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 core_color : source_color = vec3(0.75, 1.0, 0.25);
uniform vec3 edge_color : source_color = vec3(0.2, 0.9, 0.35);
uniform float strength = 1.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
	float wob = sin(TIME * 3.0 + VERTEX.y * 4.0 + VERTEX.x * 3.0) * 0.04;
	VERTEX *= 1.0 + wob;
}

void fragment() {
	vec2 uv = vec2(atan(local_pos.z, local_pos.x) / 6.2831, local_pos.y * 0.5);
	float n = texture(noise_tex, uv * vec2(2.0, 1.0) + vec2(TIME * 0.05, -TIME * 0.18)).r;
	float m = texture(noise_tex, uv * vec2(4.0, 2.0) + vec2(-TIME * 0.09, -TIME * 0.3)).g;
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
	float churn = smoothstep(0.35, 0.85, n * 0.7 + m * 0.5);
	vec3 col = mix(edge_color, core_color, churn);
	ALBEDO = col * (0.12 + churn * 0.35 + fres * 0.5) * strength;
}
