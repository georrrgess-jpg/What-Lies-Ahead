shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

// Lagoon water: teal shallows to deep green, scrolling ripples for the
// normal, a foam rim near the elliptic shore (`centre`, `radii`) and churned
// white water under the waterfall (`falls`).
uniform vec3 shallow : source_color = vec3(0.24, 0.72, 0.66);
uniform vec3 deep : source_color = vec3(0.07, 0.36, 0.38);
uniform vec2 centre = vec2(0.0);
uniform vec2 radii = vec2(8.0, 6.0);
uniform vec2 falls = vec2(-1000.0);
uniform float falls_radius = 3.0;

varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	float t = TIME;
	float r = length((p - centre) / radii);
	vec2 drift = vec2(t * 0.18, -t * 0.3);
	float n1 = noise(p * 0.9 + vec2(t * 0.25, t * 0.12));
	float n2 = noise(p * 2.3 - drift);
	float h = n1 * 0.6 + n2 * 0.4;
	vec3 col = mix(deep, shallow, smoothstep(0.35, 1.0, r) * 0.8 + h * 0.15);
	float foam = smoothstep(0.86, 0.98, r + (n2 - 0.5) * 0.12);
	float fd = length(p - falls) / falls_radius;
	foam = max(foam, (1.0 - smoothstep(0.3, 1.0, fd + (n1 - 0.5) * 0.5)) * 0.95);
	foam *= smoothstep(0.3, 0.6, n2 + foam * 0.5);
	col = mix(col, vec3(0.92, 0.98, 0.95), clamp(foam, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.08 + foam * 0.6;
	SPECULAR = 0.6;
	float dx = noise(p * 2.3 + vec2(0.05, 0.0) - drift) - n2;
	float dz = noise(p * 2.3 + vec2(0.0, 0.05) - drift) - n2;
	NORMAL = normalize((VIEW_MATRIX * vec4(-dx * 3.0, 1.0, -dz * 3.0, 0.0)).xyz);
}
