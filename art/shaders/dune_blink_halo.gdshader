shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

// Soft camera-facing glow for the blinking lights (dune_blink.gdshader), in
// step with the lens: same `speed`, `duty` and INSTANCE_CUSTOM.r phase.
uniform vec3 light_color : source_color = vec3(1.0, 0.62, 0.18);
uniform float speed = 0.8;
uniform float duty = 0.22;
uniform float size = 0.7;
uniform float strength = 0.9;
uniform float idle = 0.15;
uniform float lift = 0.12;

varying float pulse;

void vertex() {
	float ph = fract(TIME * speed - INSTANCE_CUSTOM.r);
	pulse = smoothstep(duty, 0.0, ph) + smoothstep(0.96, 1.0, ph);
	vec3 origin = (MODEL_MATRIX * vec4(0.0, lift, 0.0, 1.0)).xyz;
	VERTEX = (VIEW_MATRIX * vec4(origin, 1.0)).xyz + vec3(VERTEX.xy * size, 0.0);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float g = pow(clamp(1.0 - r, 0.0, 1.0), 2.4);
	ALBEDO = light_color * g * strength * (idle + pulse * (1.0 - idle));
}
