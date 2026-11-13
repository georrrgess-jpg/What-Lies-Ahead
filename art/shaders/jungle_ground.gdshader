shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Jungle floor: world-projected grass, blended to trail dirt by vertex colour
// R (painted by the level generator along the paths) and darkened by G
// (damp shade at the foot of walls and around the lagoon).
uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float grass_scale = 0.25;
uniform float dirt_scale = 0.3;

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
	vec3 grass = texture(grass_texture, p * grass_scale).rgb;
	// Large tone variation so the lawn never reads as a repeat.
	float big = noise(p * 0.07) * 0.6 + noise(p * 0.19) * 0.4;
	grass *= mix(vec3(0.66, 0.8, 0.66), vec3(1.0, 0.98, 0.78), big);
	vec3 dirt = texture(dirt_texture, p * dirt_scale).rgb;
	float edge = noise(p * 1.7) * 0.35;
	float k = smoothstep(0.35, 0.65, COLOR.r + edge - 0.17);
	vec3 col = mix(grass, dirt, k);
	col *= 1.0 - COLOR.g * 0.4;
	ALBEDO = col;
	ROUGHNESS = 0.92;
}
