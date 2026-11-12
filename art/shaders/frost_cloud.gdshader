shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// Frost cloud left by a shattered Frozen Tourist: a swirling icy dome with a
// bright fresnel edge, so its slowing area reads clearly from any side.
uniform vec3 mist_color : source_color = vec3(0.45, 0.85, 1.0);
uniform vec3 edge_color : source_color = vec3(0.85, 0.97, 1.0);
uniform float strength = 0.55;
// 0..1: fades the cloud in and out (driven by the script).
uniform float life = 1.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
	VERTEX *= 1.0 + 0.04 * sin(TIME * 3.0 + VERTEX.y * 6.0 + atan(VERTEX.x, VERTEX.z) * 3.0);
}

void fragment() {
	float a = atan(local_pos.x, local_pos.z);
	float swirl = 0.5 + 0.5 * sin(a * 5.0 + local_pos.y * 7.0 - TIME * 2.4);
	swirl = swirl * 0.6 + 0.4 * (0.5 + 0.5 * sin(a * 9.0 - local_pos.y * 4.0 + TIME * 1.7));
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	float base = smoothstep(0.0, 0.25, local_pos.y + 0.05);
	vec3 col = mist_color * (0.25 + swirl * 0.5) + edge_color * fresnel * 0.9;
	ALBEDO = col * strength * life * base;
}
