shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// A pool of coloured light on the ground or a wall (Ashfall City): under a
// neon sign, a lamp, a burning wreck. A flat card with a soft radial falloff,
// broken up by noise so it reads as light on wet, uneven ground; fires make
// it waver. Every pool shares the material; the instance colour is COLOR
// (MultiMesh custom colour) or `pool_color`.
uniform vec3 pool_color : source_color = vec3(1.0, 0.5, 0.2);
uniform float strength = 0.6;
// 0 = steady (neon, lamps), 1 = wavers like fire.
uniform float flicker = 0.0;
uniform bool use_instance_color = false;

varying vec4 tint;

void vertex() {
	tint = use_instance_color ? COLOR : vec4(pool_color, 1.0);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec3 wp = NODE_POSITION_WORLD;
	float seed = fract(sin(dot(wp.xz, vec2(12.9898, 78.233))) * 43758.5453) * 40.0;
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float fall = pow(clamp(1.0 - r, 0.0, 1.0), 2.2);
	float grain = 0.75 + 0.25 * noise(UV * 9.0 + seed);
	float t = TIME * 7.0 + seed;
	float waver = 1.0 + flicker * (sin(t) * 0.12 + sin(t * 2.3 + 1.7) * 0.08 + sin(t * 0.7) * 0.1);
	ALBEDO = tint.rgb * fall * grain * strength * waver * tint.a;
}
