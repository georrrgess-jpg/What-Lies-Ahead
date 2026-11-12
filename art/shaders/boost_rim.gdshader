// Hot rim glow drawn over the viewmodel while the station's damage boost is
// loaded or running (material_overlay; see scripts/ui/boost_glow.gd).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.34, 0.06, 1.0);
uniform float strength = 1.0;
uniform float rim_power = 3.5;
uniform float time_scroll = 0.0;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	// A faint band sweeping along the weapon so the glow reads as live energy.
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float band = smoothstep(0.6, 1.0, sin(world.x * 14.0 + world.y * 7.0 - time_scroll * 6.0));
	ALBEDO = glow_color.rgb * (rim * 2.2 + band * 0.4 * (0.12 + rim)) * strength;
}
