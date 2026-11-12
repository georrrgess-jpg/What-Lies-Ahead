shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Hologram used while a fresh energy cell "prints" into a weapon during a
// reload: scanlines sweep upward, edges glow, and `materialize` (0-1) builds
// the cell from the bottom with a flickering dissolve edge.
uniform vec3 holo_color : source_color = vec3(0.35, 0.95, 1.0);
uniform float materialize : hint_range(0.0, 1.0) = 1.0;
uniform float intensity = 1.2;
// Half-height of the part (local units); set by the game from the mesh bounds.
uniform float span = 0.12;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float lines = 0.55 + 0.45 * sin(local_pos.y * 900.0 - TIME * 30.0);
	float flicker = 0.85 + 0.15 * sin(TIME * 67.0) * sin(TIME * 23.0);
	// Build-up: bottom first, with a noisy bright edge.
	float h = clamp((local_pos.y + span) / (2.0 * span), 0.0, 1.0);
	float edge = materialize * 1.15 - h + (hash(floor(local_pos.xy * 400.0) + floor(TIME * 24.0)) - 0.5) * 0.08;
	if (edge < 0.0) {
		discard;
	}
	float rim = smoothstep(0.08, 0.0, edge) * 2.5;
	ALBEDO = holo_color * (0.35 + fres * 1.4 + rim) * lines * flicker * intensity;
}
