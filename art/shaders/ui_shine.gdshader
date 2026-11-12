shader_type canvas_item;
// Text shine for the menu logo: a bright diagonal band sweeps across the
// glyphs every few seconds, plus a soft vertical gradient (white top, warm
// bottom). `span` is the label's width in pixels.
uniform float span = 900.0;
uniform float period = 4.5;
uniform vec4 top_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 bottom_color : source_color = vec4(1.0, 0.86, 0.72, 1.0);
uniform float height = 160.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec4 tex = COLOR;
	float g = clamp(local.y / height, 0.0, 1.0);
	vec3 grad = mix(top_color.rgb, bottom_color.rgb, g);
	float phase = mod(TIME, period) / period;
	float sweep = (local.x + local.y * 0.6) / span - (phase * 2.4 - 0.7);
	float shine = smoothstep(0.08, 0.0, abs(sweep)) * 0.85;
	// Only tint the white fill, not the dark outline.
	float fill = smoothstep(0.55, 0.8, max(tex.r, max(tex.g, tex.b)));
	COLOR.rgb = mix(tex.rgb, tex.rgb * grad + vec3(shine), fill);
}
