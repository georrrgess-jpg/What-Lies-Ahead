shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Additive light shaft for open rooms (from the dome oculus, ceiling slots and
// the tank lights): soft at the edges and ends, with slow bands drifting down
// and a shimmer, so a few crossed quads read as a volumetric beam. UV.y = 0 at
// the top of the quad.
uniform vec3 color : source_color = vec3(0.35, 0.85, 1.0);
uniform float strength = 0.35;
uniform float band_scale = 6.0;

void fragment() {
	float x = abs(UV.x * 2.0 - 1.0);
	float edge = pow(1.0 - x, 1.8);
	float ends = smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.55, UV.y);
	float bands = 0.65 + 0.35 * sin(UV.y * band_scale - TIME * 0.6 + UV.x * 3.0) * sin(UV.x * 9.0 + TIME * 0.3);
	float view = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	ALBEDO = color * edge * ends * bands * strength * (0.4 + 0.6 * view);
}
