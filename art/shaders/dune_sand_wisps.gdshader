shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Blowing sand: streaky noise scrolling along the wind over a quad. Lay quads
// flat just above the ground for snaking drifts, or stand them up along walls
// for sand spilling over the top. Edges fade so the quad never shows.
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 sand_color : source_color = vec3(0.95, 0.78, 0.55);
uniform vec2 wind = vec2(1.0, 0.0);      // in UV space
uniform float speed = 0.35;
uniform float density = 0.55;
uniform float opacity = 0.35;
uniform vec2 stretch = vec2(1.0, 4.0);
uniform float edge = 0.18;

void fragment() {
	vec2 uv = UV * stretch;
	vec2 flow = normalize(wind) * TIME * speed;
	float a = texture(noise_tex, uv * vec2(0.6, 0.35) - flow).r;
	float b = texture(noise_tex, uv * vec2(1.3, 0.7) - flow * 1.7 + 0.5).g;
	float streak = smoothstep(density, density + 0.25, a * 0.65 + b * 0.5);
	vec2 e = smoothstep(vec2(0.0), vec2(edge), UV) * smoothstep(vec2(0.0), vec2(edge), 1.0 - UV);
	ALBEDO = sand_color;
	ALPHA = streak * e.x * e.y * opacity;
}
