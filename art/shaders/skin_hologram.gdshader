shader_type spatial;
render_mode cull_disabled;
// Hologram body (GL1TCH operator, Holo gloves). Glowing tint with a bright
// rim, scan bands that cut through the surface as they roll upward, flicker,
// and slices that jump sideways for a frame. Opaque with cut-outs, so it
// sorts correctly on a skinned character.
uniform vec3 shell_color : source_color = vec3(0.21, 0.94, 1.0);
uniform vec3 trim_color : source_color = vec3(1.0, 0.25, 0.65);
uniform bool is_trim = false;
uniform float band_density = 26.0;
uniform float glitch = 1.0;

varying vec3 wp;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	float frame = floor(TIME * 9.0);
	float slice = floor(VERTEX.y * 14.0);
	float r = hash21(vec2(slice, frame));
	if (r > 0.94) {
		VERTEX.x += (hash21(vec2(frame, slice)) - 0.5) * 0.08 * glitch;
	}
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 tint = is_trim ? trim_color : shell_color;
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float band = fract(wp.y * band_density - TIME * 1.5);
	if (band < 0.16 && fres < 0.6) {
		discard;
	}
	float scan = 0.7 + 0.3 * sin(wp.y * 260.0 - TIME * 18.0);
	float flicker = 0.9 + 0.1 * sin(TIME * 53.0) * sin(TIME * 17.0);
	ALBEDO = tint * 0.25;
	ROUGHNESS = 0.3;
	EMISSION = tint * (0.55 + fres * 2.2) * scan * flicker + vec3(1.0) * smoothstep(0.16, 0.2, band) * smoothstep(0.26, 0.2, band) * 0.6;
}
