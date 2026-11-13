shader_type spatial;
render_mode cull_disabled, shadows_disabled;

// Pennant strings built by the level generator (flag colour in the vertex
// colour, UV.y 0 along the string and 1 at the tip) fluttering in the wind;
// `gust` (1 calm, about 3 in the Gale twist) whips them harder.
uniform float gust = 1.0;
uniform float roughness_value = 0.6;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * (2.6 + gust * 1.8) + wp.x * 0.9 + wp.z * 0.7) * 0.5 + sin(TIME * 5.1 * gust + wp.x * 2.3) * 0.25;
	VERTEX += NORMAL * sway * UV.y * 0.09 * gust;
	VERTEX.y += UV.y * 0.03 * gust * sin(TIME * 3.0 + wp.z);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = roughness_value;
}
