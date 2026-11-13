shader_type spatial;
render_mode cull_back;
// GL1TCH's projected body (scripts/cosmetics/operators.gd): a dark core with
// a bright edge glow, fine scanlines that drift upward, a slow sweep band, a
// slight flicker and the odd slice that jumps sideways. Opaque, so it sorts
// correctly on a skinned character and on transparent menu viewports.
uniform vec3 shell_color : source_color = vec3(0.21, 0.94, 1.0);
uniform vec3 trim_color : source_color = vec3(1.0, 0.25, 0.65);
uniform bool is_trim = false;
uniform float line_density = 150.0;
uniform float glitch = 1.0;

varying vec3 wp;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	float frame = floor(TIME * 7.0);
	float slice = floor(VERTEX.y * 11.0);
	if (hash21(vec2(slice, frame)) > 0.965) {
		VERTEX.x += (hash21(vec2(frame, slice)) - 0.5) * 0.07 * glitch;
	}
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 tint = is_trim ? trim_color : shell_color;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float edge = pow(1.0 - facing, 2.2);
	float lines = 0.72 + 0.28 * smoothstep(0.35, 0.65, fract(wp.y * line_density * 0.5 - TIME * 0.6));
	float sweep = smoothstep(0.08, 0.0, abs(fract(wp.y * 0.45 - TIME * 0.22) - 0.5));
	float flicker = 0.93 + 0.07 * sin(TIME * 41.0) * sin(TIME * 13.0);
	float ao = COLOR.r;
	ALBEDO = tint * 0.1;
	ROUGHNESS = 0.35;
	EMISSION = (tint * (0.42 + 0.22 * facing + edge * 2.4) * lines + mix(tint, vec3(1.0), 0.6) * (sweep * 0.9 + edge * edge * 0.8)) * flicker * mix(0.55, 1.0, ao);
}
