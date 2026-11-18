shader_type spatial;
render_mode cull_disabled, shadows_disabled;

// The castle moat: clear teal water with lazy ripples, sun sparkle and a
// pale fringe where it meets the stone (world-space, so tiles never show).
uniform vec3 deep_color : source_color = vec3(0.13, 0.42, 0.55);
uniform vec3 shallow_color : source_color = vec3(0.32, 0.7, 0.78);
uniform vec3 sparkle_color : source_color = vec3(1.0, 0.98, 0.9);
uniform float scale = 0.35;

float wave(vec2 p, float t) {
	return sin(p.x * 1.7 + t * 1.1) * 0.5 + sin(p.y * 2.3 - t * 0.9 + p.x * 0.6) * 0.35 + sin((p.x + p.y) * 3.1 + t * 1.7) * 0.15;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = wp.xz * scale;
	float t = TIME;
	float h = wave(p, t);
	float hx = wave(p + vec2(0.05, 0.0), t) - h;
	float hz = wave(p + vec2(0.0, 0.05), t) - h;
	vec3 n = normalize(vec3(-hx * 3.0, 1.0, -hz * 3.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float band = smoothstep(0.2, 0.9, h * 0.5 + 0.5);
	ALBEDO = mix(deep_color, shallow_color, band * 0.6);
	float glint = smoothstep(0.82, 0.98, sin(p.x * 9.0 + t * 2.0) * sin(p.y * 7.0 - t * 1.6));
	EMISSION = sparkle_color * glint * 0.35;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.7;
}
