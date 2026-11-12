shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Holographic advert / projection: additive, edges glow brighter than the
// core (fresnel), scanlines climb upward, the whole image flickers now and
// then and a slow colour drift sweeps across it.
uniform vec3 color_a : source_color = vec3(0.25, 0.95, 1.0);
uniform vec3 color_b : source_color = vec3(1.0, 0.3, 0.85);
uniform float intensity = 1.0;
uniform float line_density = 9.0;
uniform float line_speed = 1.2;
uniform float core = 0.25;
uniform float drift = 0.15;

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.6);
	float lines = 0.55 + 0.45 * smoothstep(0.3, 0.7, fract(obj_pos.y * line_density - TIME * line_speed));
	float flicker = 0.9 + 0.1 * sin(TIME * 41.0) * sin(TIME * 13.0);
	flicker *= 1.0 - 0.6 * step(0.985, fract(sin(floor(TIME * 9.0) * 12.9898) * 43758.5453));
	float mixer = 0.5 + 0.5 * sin(obj_pos.y * 0.7 + obj_pos.x * 0.4 + TIME * drift * 6.2831);
	vec3 col = mix(color_a, color_b, mixer);
	ALBEDO = col * (core + fres * 1.3) * lines * flicker * intensity;
}
