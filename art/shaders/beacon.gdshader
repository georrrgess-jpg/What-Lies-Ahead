shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Vertical light column over the loadout station: a hot core inside a soft
// glow, brightest at the base, with bands rising up the column so it reads as
// "active" from anywhere on the map.
uniform vec3 beam_color : source_color = vec3(1.0, 0.72, 0.22);
uniform float strength = 1.6;

void fragment() {
	float x = abs(UV.x * 2.0 - 1.0);
	float glow = pow(1.0 - x, 2.0);
	float core = smoothstep(0.12, 0.0, x);
	float height = 1.0 - UV.y;            // 1 at the bottom of the quad, 0 at the top
	float rise = 0.7 + 0.3 * sin(UV.y * 40.0 + TIME * 5.0);
	vec3 col = beam_color * glow * rise + vec3(1.0, 0.95, 0.8) * core * 0.8;
	ALBEDO = col * pow(height, 1.2) * strength;
}
