shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

// Fright Fair graveyard mist: a low, drifting sheet of soft violet-green
// haze on a flat plane, faded to nothing at its edges. No textures.
uniform vec3 mist_color : source_color = vec3(0.7, 0.78, 0.9);
uniform float strength = 0.7;
uniform float drift = 0.05;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = v_world.xz * 0.22 + vec2(TIME * drift, TIME * drift * 0.6);
	float n = noise(p) * 0.6 + noise(p * 2.3 - vec2(TIME * drift * 1.7, 0.0)) * 0.4;
	vec2 e = min(UV, 1.0 - UV);
	float edge = smoothstep(0.0, 0.25, min(e.x, e.y));
	ALBEDO = mist_color;
	ALPHA = smoothstep(0.3, 0.8, n) * edge * strength;
}
