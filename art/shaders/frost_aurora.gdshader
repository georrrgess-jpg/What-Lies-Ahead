shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Aurora curtain: a tall ribbon (UV.x along the ribbon, UV.y bottom -> top)
// with drifting vertical rays, a bright green lower hem fading into violet
// and a slow billow of the whole sheet.
uniform vec3 hem_color : source_color = vec3(0.32, 1.0, 0.62);
uniform vec3 top_color : source_color = vec3(0.66, 0.34, 1.0);
uniform float strength = 0.9;
uniform float speed = 1.0;
uniform float billow = 9.0;
uniform float seed = 0.0;

void vertex() {
	float t = TIME * 0.12 * speed + seed;
	VERTEX += NORMAL * sin(UV.x * 9.0 + t * 2.0) * billow * (0.4 + UV.y);
	VERTEX.y += sin(UV.x * 5.0 - t * 1.3) * billow * 0.5;
}

void fragment() {
	float t = TIME * speed + seed * 13.0;
	float x = UV.x;
	float y = UV.y;
	// Vertical rays that slide along the curtain.
	float rays = 0.5 + 0.5 * sin(x * 140.0 + sin(x * 17.0 + t * 0.35) * 4.0 + t * 0.6);
	rays = pow(rays, 2.5) * 0.65 + 0.35 * (0.5 + 0.5 * sin(x * 53.0 - t * 0.45));
	// Bright pulses travelling along the hem.
	float pulse = 0.6 + 0.4 * sin(x * 11.0 - t * 0.9) * sin(x * 4.0 + t * 0.3);
	float hem = smoothstep(0.0, 0.07, y) * (1.0 - smoothstep(0.08, 0.5, y) * 0.55);
	float fade_top = 1.0 - smoothstep(0.35, 1.0, y);
	float ends = smoothstep(0.0, 0.12, x) * (1.0 - smoothstep(0.88, 1.0, x));
	vec3 col = mix(hem_color, top_color, smoothstep(0.18, 0.75, y));
	ALBEDO = col * rays * pulse * hem * fade_top * ends * strength;
}
