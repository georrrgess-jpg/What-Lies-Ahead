shader_type canvas_item;
// Cinematic transitions over the whole screen (CineOverlay):
//   mode 0  diagonal stripe wipe: neon pink and cyan bands race across and
//           cover the frame at progress 0.5, then clear off the far side
//   mode 1  iris: a dark frame outside a circle of `progress` screen heights,
//           with a glowing ring on its edge
uniform int mode = 0;
uniform float progress = 0.0;
uniform vec2 aspect = vec2(1.777, 1.0);
uniform vec4 color_a : source_color = vec4(1.0, 0.25, 0.64, 1.0);
uniform vec4 color_b : source_color = vec4(0.21, 0.94, 1.0, 1.0);
uniform vec4 ink : source_color = vec4(0.05, 0.03, 0.12, 1.0);

void fragment() {
	vec2 p = UV * aspect;
	if (mode == 0) {
		// Position along the wipe direction (left to right, leaning 30 degrees).
		float x = (p.x + p.y * 0.55) / (aspect.x + 0.55);
		float lead = progress * 2.4 - 0.2;
		float tail = lead - 1.2;
		float inside = step(x, lead) * step(tail, x);
		float bands = fract((p.x + p.y * 0.55) * 3.0);
		vec3 c = mix(ink.rgb, mix(color_a.rgb, color_b.rgb, step(0.5, bands)), smoothstep(0.08, 0.0, min(lead - x, x - tail)));
		COLOR = vec4(c, inside);
	} else {
		float d = length((UV - 0.5) * aspect);
		float outside = smoothstep(progress - 0.004, progress + 0.004, d);
		float ring = smoothstep(0.03, 0.0, abs(d - progress)) * step(0.001, progress);
		COLOR = vec4(mix(ink.rgb, color_b.rgb, ring), max(outside, ring));
	}
}
