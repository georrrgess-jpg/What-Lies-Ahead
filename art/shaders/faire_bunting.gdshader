shader_type spatial;
render_mode cull_disabled, shadows_disabled;

// Pennant strings built by the Royal Faire generator (flag colour in the
// vertex colour, UV.y 0 along the string and 1 at the tip) fluttering in a
// light morning breeze.
uniform float breeze = 1.0;
uniform float roughness_value = 0.6;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * (2.4 + breeze * 1.6) + wp.x * 0.9 + wp.z * 0.7) * 0.5 + sin(TIME * 4.7 * breeze + wp.x * 2.3) * 0.25;
	VERTEX += NORMAL * sway * UV.y * 0.08 * breeze;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = roughness_value;
}
