shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;

// Rocket vapour and steam vents. Each MultiMesh instance is one puff that is
// born at its instance origin, rises and drifts along `drift`, swells and fades,
// then starts over. INSTANCE_CUSTOM: r = phase (0-1), g = speed scale,
// b = size scale, a = drift scale. The quad is billboarded in the vertex stage.
uniform vec3 drift = vec3(1.2, 0.0, 0.4);
uniform float rise = 3.0;
uniform float life = 3.2;
uniform float size_start = 0.5;
uniform float size_end = 2.2;
uniform float opacity = 0.55;
uniform vec3 lit_color : source_color = vec3(1.0, 0.93, 0.84);
uniform vec3 shadow_color : source_color = vec3(0.62, 0.56, 0.7);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

varying float age;
varying float seed;

void vertex() {
	seed = INSTANCE_CUSTOM.r;
	age = fract(TIME / (life / max(0.2, INSTANCE_CUSTOM.g)) + INSTANCE_CUSTOM.r);
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float ease_up = 1.0 - pow(1.0 - age, 1.6);
	vec3 centre = origin + vec3(0.0, rise * ease_up, 0.0) + drift * INSTANCE_CUSTOM.a * age * age;
	float size = mix(size_start, size_end, sqrt(age)) * INSTANCE_CUSTOM.b;
	float spin = seed * 6.283 + age * 0.8;
	vec2 corner = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * VERTEX.xy;
	VERTEX = (VIEW_MATRIX * vec4(centre, 1.0)).xyz + vec3(corner * size, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float n = texture(noise_tex, UV * 0.6 + vec2(seed * 3.1, age * 0.3)).r;
	float r = length(c) + (n - 0.5) * 0.45;
	float puff = smoothstep(1.0, 0.35, r);
	float fade = smoothstep(0.0, 0.12, age) * (1.0 - smoothstep(0.55, 1.0, age));
	// Lit from above: the top of each puff is warm, the underside cool.
	vec3 col = mix(shadow_color, lit_color, clamp(0.55 - c.y * 0.6 + n * 0.3, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = puff * fade * opacity;
}
