shader_type spatial;
// A Spark: a camera-facing four-point star with a white-hot centre, a gold
// body and a soft cyan halo. Drawn through a MultiMesh (SparkField);
// INSTANCE_CUSTOM = (size in metres, spin in radians, fade 0-1, unused).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.847, 0.29, 1.0);
uniform vec4 glow_color : source_color = vec4(0.22, 0.94, 1.0, 1.0);

varying float v_spin;
varying float v_fade;

void vertex() {
	v_spin = INSTANCE_CUSTOM.y;
	v_fade = INSTANCE_CUSTOM.z;
	vec4 centre = VIEW_MATRIX * (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0));
	centre.xy += VERTEX.xy * INSTANCE_CUSTOM.x;
	POSITION = PROJECTION_MATRIX * centre;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float c = cos(v_spin);
	float s = sin(v_spin);
	p = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	float d = length(p);
	// Four-point star: |x|^k + |y|^k < r with k < 1 pinches the diagonals.
	float star = pow(abs(p.x), 0.55) + pow(abs(p.y), 0.55);
	float body = smoothstep(0.86, 0.74, star);
	float hot = smoothstep(0.5, 0.2, star);
	float halo = smoothstep(1.0, 0.15, d) * 0.55;
	vec3 col = mix(glow_color.rgb, core_color.rgb, body);
	col = mix(col, vec3(1.0, 0.98, 0.9), hot);
	ALBEDO = col;
	ALPHA = clamp(max(body, halo), 0.0, 1.0) * v_fade;
}
