shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

// Frostpeak snow: lavender-white world-projected snow with soft drifts, rock
// strata on steep slopes (terrain only) and tiny sparkles that flash as the
// view moves. Cheap: two texture reads, no screen reads.
uniform sampler2D snow_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float uv_scale = 0.16;
uniform float normal_strength = 0.7;
// 0 = flat ground (never rock), 1 = steep faces turn to rock.
uniform float rock_amount = 0.0;
uniform vec3 rock_dark : source_color = vec3(0.16, 0.15, 0.25);
uniform vec3 rock_light : source_color = vec3(0.36, 0.33, 0.48);
uniform float sparkle_strength = 1.4;
uniform vec3 sparkle_color : source_color = vec3(0.8, 0.92, 1.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec2 uv = world_pos.xz * uv_scale;
	vec3 snow = texture(snow_texture, uv).rgb;
	// Broad drifts: a second, much larger read of the same texture.
	float broad = texture(snow_texture, uv * 0.11 + vec2(0.37, 0.71)).g;
	snow *= mix(0.9, 1.06, broad) * tint;

	// Rock on steep faces, broken up by noise so snow patches cling to it.
	vec2 side_uv = vec2(world_pos.x + world_pos.z, world_pos.y * 1.6) * 0.035;
	// The snow texture's green channel spans ~0.78..0.95: stretch it to 0..1.
	float grain = clamp((texture(snow_texture, side_uv).g - 0.78) * 6.0, 0.0, 1.0);
	float patches = clamp((texture(snow_texture, world_pos.xz * 0.013 + vec2(0.5, 0.2)).g - 0.78) * 6.0, 0.0, 1.0);
	float steep = 1.0 - smoothstep(0.42 + patches * 0.25, 0.8, world_normal.y);
	float rock_mask = steep * rock_amount;
	vec3 rock = mix(rock_dark, rock_light, smoothstep(0.2, 0.8, grain));
	rock = mix(rock, snow * 0.9, smoothstep(0.75, 0.95, grain) * 0.7);

	ALBEDO = mix(snow, rock, rock_mask);
	NORMAL_MAP = texture(snow_normal, uv).rgb;
	NORMAL_MAP_DEPTH = normal_strength * (1.0 - rock_mask);
	ROUGHNESS = mix(0.72, 0.92, rock_mask);
	SPECULAR = 0.35;

	// Sparkles: one candidate glint per 12 cm cell; a glint shows when the
	// view direction lines up with its random facet, so they twinkle as you move.
	vec3 cell_pos = world_pos * 8.0;
	vec3 cell = floor(cell_pos);
	float h = hash13(cell);
	vec3 local = fract(cell_pos) - vec3(hash13(cell + 7.1), 0.5, hash13(cell + 3.7));
	float dot_size = 1.0 - smoothstep(0.05, 0.16, length(local.xz));
	vec3 view = normalize(CAMERA_POSITION_WORLD - world_pos);
	vec3 facet = normalize(vec3(hash13(cell + 1.3) - 0.5, 1.2, hash13(cell + 9.2) - 0.5));
	float flash = pow(clamp(dot(reflect(-view, facet), normalize(vec3(0.3, 0.8, -0.5))), 0.0, 1.0), 24.0);
	flash += step(0.993, h) * 0.35;
	float dist = length(CAMERA_POSITION_WORLD - world_pos);
	float near = 1.0 - smoothstep(5.0, 26.0, dist);
	float glint = step(0.93, h) * dot_size * flash * near * (1.0 - rock_mask);
	EMISSION = sparkle_color * glint * sparkle_strength;
}
