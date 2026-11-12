shader_type spatial;

// Abyss Aquarium surfaces (floors, walls, plinths): a world-projected tiling
// texture with animated caustic light rippling across it, as if the room were
// lit through the water of the tanks. Two scrolling copies of one caustic
// texture are combined with min() for the classic sharp network.
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D caustic_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
// Texture tiles per metre (a 4 m texture = 0.25).
uniform float uv_scale = 0.25;
uniform float normal_strength = 0.0;
uniform float roughness = 0.4;
uniform float specular = 0.5;
uniform vec3 caustic_color : source_color = vec3(0.35, 0.85, 1.0);
uniform float caustic_strength = 0.6;
// Caustic cells per metre and drift speed.
uniform float caustic_scale = 0.2;
uniform float caustic_speed = 0.04;
// On vertical faces the caustics fade out above this height (metres).
uniform float wall_fade_height = 5.0;
uniform float wall_fade_base = 0.0;
// Curved walls carry their own UVs in metres (u = along the wall, v = height).
uniform bool use_mesh_uv = false;
// 0 = even caustics everywhere, 1 = drifting bright and dark patches.
uniform float patchiness = 0.65;

varying vec3 wpos;
varying vec3 wnormal;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float caustic(vec2 uv) {
	float t = TIME * caustic_speed;
	float a = texture(caustic_tex, uv * caustic_scale + vec2(t, t * 0.62)).r;
	float b = texture(caustic_tex, uv * caustic_scale * 1.31 + vec2(-t * 0.77, t * 0.41) + vec2(0.37, 0.11)).r;
	float c = pow(min(a, b) * 1.6, 1.35);
	// Slow, large patches: light comes through the water unevenly.
	float patch = 0.5 + 0.5 * sin(uv.x * 0.37 + t * 9.0) * sin(uv.y * 0.29 - t * 7.0 + 1.3);
	return c * mix(1.0, smoothstep(0.15, 0.85, patch) * 1.35, patchiness);
}

void fragment() {
	vec3 n = abs(wnormal);
	vec2 uv;
	float fade = 1.0;
	if (use_mesh_uv) {
		uv = UV;
		fade = 1.0 - smoothstep(wall_fade_base, wall_fade_base + wall_fade_height, wpos.y);
	} else if (n.y > 0.65) {
		uv = wpos.xz;
	} else {
		uv = (n.x > n.z ? wpos.zy : wpos.xy) * vec2(1.0, -1.0);
		fade = 1.0 - smoothstep(wall_fade_base, wall_fade_base + wall_fade_height, wpos.y);
	}
	vec3 alb = texture(albedo_tex, uv * uv_scale).rgb * tint;
	ALBEDO = alb;
	if (normal_strength > 0.0) {
		NORMAL_MAP = texture(normal_tex, uv * uv_scale).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	ROUGHNESS = roughness;
	SPECULAR = specular;
	float c = caustic(uv) * fade;
	EMISSION = caustic_color * c * caustic_strength * (0.3 + alb * 1.4);
}
