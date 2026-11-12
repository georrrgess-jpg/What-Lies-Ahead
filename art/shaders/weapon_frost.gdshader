shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// Ice overlay drawn on top of a chilled or frozen zombie (material_overlay).
// `amount` 0-1: a light frosty rim while chilled, a solid icy glaze when frozen.
// Facets come from a world-space cell pattern so the ice looks crystalline.
uniform float amount : hint_range(0.0, 1.0) = 0.5;
uniform vec3 ice_color : source_color = vec3(0.62, 0.9, 1.0);
uniform vec3 rim_color : source_color = vec3(0.95, 1.0, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.2);
	vec3 cell = floor(world_pos * 9.0);
	float facet = hash3(cell);
	float sparkle = step(0.93, hash3(cell + floor(TIME * 3.0)));
	float frozen = smoothstep(0.85, 1.0, amount);
	vec3 col = mix(ice_color, rim_color, fres * 0.8 + facet * 0.25);
	col += rim_color * sparkle * 0.8 * amount;
	ALBEDO = col;
	ALPHA = clamp(amount * (0.18 + fres * 0.75) + frozen * (0.38 + facet * 0.16), 0.0, 0.92);
}
