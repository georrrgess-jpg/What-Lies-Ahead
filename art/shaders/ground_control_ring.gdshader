shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Ground Control's ping ring: one quad facing along its flight, drawn as a
// fat glowing annulus at the quad's rim with a white-hot core line, a faint
// sonar fill and echo ripples running outwards inside it. `fade` 0-1 fades
// the whole ring, `thickness` is the band's share of the radius, `crackle`
// (the overcharged feedback blast) breaks the band into flickering arcs.
uniform vec3 ring_color : source_color = vec3(0.66, 0.9, 0.24);
uniform vec3 core_color : source_color = vec3(0.95, 1.0, 0.8);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float thickness : hint_range(0.02, 0.5) = 0.16;
uniform float crackle : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float band = 1.0 - smoothstep(0.0, thickness, abs(r - (1.0 - thickness)));
	float core = 1.0 - smoothstep(0.0, thickness * 0.28, abs(r - (1.0 - thickness)));
	float echo = 0.0;
	for (int i = 0; i < 2; i++) {
		float er = fract(TIME * 1.8 + float(i) * 0.5) * (1.0 - thickness * 2.0);
		echo += (1.0 - smoothstep(0.0, 0.035, abs(r - er))) * er;
	}
	float fill = smoothstep(0.2, 1.0, r) * 0.08;
	float a = atan(p.y, p.x);
	float arcs = mix(1.0, step(0.35, fract(sin(floor(a * 5.0 + TIME * 23.0) * 91.7) * 437.1)), crackle);
	vec3 col = ring_color * (band * 1.25 + echo * 0.35 + fill) * arcs + core_color * core * 0.9 * arcs;
	ALBEDO = col * fade;
}
