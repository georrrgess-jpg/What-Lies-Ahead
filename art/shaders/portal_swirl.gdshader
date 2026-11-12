shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// Swirling portal surface, masked to an arched doorway.
uniform vec3 color_core : source_color = vec3(0.85, 1.0, 1.0);
uniform vec3 color_a : source_color = vec3(0.1, 0.85, 1.0);
uniform vec3 color_b : source_color = vec3(0.45, 0.2, 0.95);
uniform float speed = 1.4;
uniform float brightness = 1.6;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;          // -1..1, y down
	p.y = -p.y;
	// Arch mask: straight sides below, half-circle on top.
	float arch = p.y > 0.2 ? length(vec2(p.x, (p.y - 0.2) * 1.25)) : abs(p.x);
	if (arch > 1.0 || p.y < -1.0) {
		discard;
	}
	vec2 c = vec2(p.x, p.y * 0.8 + 0.1);
	float r = length(c);
	float a = atan(c.y, c.x);
	float spiral = sin(a * 3.0 + r * 9.0 - TIME * speed * 3.0);
	float rings = sin(r * 16.0 - TIME * speed * 4.0);
	float mixv = 0.5 + 0.5 * spiral * 0.75 + rings * 0.12;
	vec3 col = mix(color_b, color_a, clamp(mixv, 0.0, 1.0));
	col = mix(color_core, col, smoothstep(0.0, 0.35, r));
	col *= brightness * (1.0 - 0.35 * smoothstep(0.6, 1.0, arch));
	ALBEDO = col;
}
