shader_type spatial;
render_mode cull_back;

// Ashfall City streets and platforms (tools/build_endless_city.gd). Cheap fake
// wetness from the fire hoses and the burst mains, no screen reads:
//  - world-space paving/asphalt texture (albedo + normal) with soot stains
//    and oil patches breaking up the tiling;
//  - puddles from a tiling mask: near-mirror roughness, the ember sky along
//    the reflected view ray, and vertical streaks of up to twelve nearby
//    lights (neon signs, burning wrecks, lamps): the classic wet-street smear;
//  - scorch rings: up to four burnt patches round fires.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D puddle_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float tile_metres = 4.0;
uniform float puddle_metres = 11.0;
// 0 = bone dry, 1 = flooded.
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.35;
uniform float grime = 0.5;
uniform float normal_depth = 0.9;
uniform vec3 sky_low : source_color = vec3(0.95, 0.42, 0.2);
uniform vec3 sky_high : source_color = vec3(0.22, 0.08, 0.26);
uniform float sky_reflect = 0.5;
uniform float streak_strength = 1.0;
// xyz = world position of a light to reflect, w = streak width (metres).
uniform vec4 light_pos[12];
// rgb = colour, a = intensity (0 disables the slot).
uniform vec4 light_col[12];
// xz = centre of a scorched patch, y = radius (0 disables).
uniform vec3 scorch[4];

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
	vec2 p = world_pos.xz;
	vec2 uv = p / tile_metres;
	vec3 base = texture(albedo_tex, uv).rgb * tint;
	vec3 tn = texture(normal_tex, uv).rgb * 2.0 - 1.0;

	// Soot and oil: big soft blotches, a few sharper dark stains.
	float blot = noise(p * 0.13) * 0.6 + noise(p * 0.41 + 7.3) * 0.4;
	float stain = smoothstep(0.62, 0.78, noise(p * 0.7 + 3.1)) * 0.6;
	float dirt = clamp(smoothstep(0.35, 0.85, blot) * 0.55 + stain, 0.0, 1.0) * grime;
	base *= 1.0 - dirt * 0.55;

	// Burnt patches round the fires.
	float burn = 0.0;
	for (int i = 0; i < 4; i++) {
		if (scorch[i].y <= 0.0) {
			continue;
		}
		float r = length(p - scorch[i].xz) / scorch[i].y;
		float ragged = r + (noise(p * 2.3 + float(i) * 5.0) - 0.5) * 0.45;
		burn = max(burn, 1.0 - smoothstep(0.35, 1.0, ragged));
	}
	base = mix(base, base * vec3(0.12, 0.1, 0.1), burn * 0.85);

	// Puddles: soft-edged mask; none on the burnt patches.
	float mask = texture(puddle_tex, p / puddle_metres).r;
	float puddle = smoothstep(0.62 - puddle_amount * 0.45, 0.7 - puddle_amount * 0.45, mask) * (1.0 - burn);
	vec3 col = base * mix(0.92, 0.55, puddle);
	vec3 n_tan = normalize(mix(vec3(tn.xy * normal_depth, 1.0), vec3(0.0, 0.0, 1.0), puddle));

	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	float fres = pow(1.0 - clamp(view_dir.y, 0.0, 1.0), 4.0);
	// The ember sky reflected in the water: glowing low, dark overhead.
	vec3 refl = mix(sky_low, sky_high, clamp(view_dir.y * 1.6, 0.0, 1.0)) * sky_reflect * (0.4 + 0.6 * fres);

	// Light smears: each light reflects as a streak stretched toward the viewer.
	vec2 cam = CAMERA_POSITION_WORLD.xz;
	float cam_h = max(0.3, CAMERA_POSITION_WORLD.y - world_pos.y);
	for (int i = 0; i < 12; i++) {
		if (light_col[i].a <= 0.0) {
			continue;
		}
		vec3 lp = light_pos[i].xyz;
		float light_h = max(0.2, lp.y - world_pos.y);
		vec2 to_light = lp.xz - cam;
		float len_cl = max(0.01, length(to_light));
		vec2 dir = to_light / len_cl;
		vec2 mirror = cam + dir * len_cl * (cam_h / (cam_h + light_h));
		vec2 d = p - mirror;
		float along = dot(d, dir);
		float across = d.x * dir.y - d.y * dir.x;
		float w = light_pos[i].w * (0.35 + 0.012 * len_cl);
		float streak = exp(-pow(across / w, 2.0)) * exp(-pow(along / (w * 5.5 + len_cl * 0.08), 2.0));
		refl += light_col[i].rgb * light_col[i].a * streak * streak_strength;
	}

	float wet = mix(0.12, 1.0, puddle);
	ALBEDO = col;
	NORMAL_MAP = n_tan * 0.5 + 0.5;
	ROUGHNESS = mix(0.78 - dirt * 0.25, 0.12, puddle);
	SPECULAR = mix(0.4, 0.5, puddle);
	EMISSION = refl * wet;
}
