shader_type spatial;
render_mode cull_back;

// Rain-soaked rooftop for Neon Skyline. Cheap fake wetness, no screen reads:
//  - world-space paver texture (albedo + normal), darker and glossier when wet;
//  - puddles from a tiling mask: near-mirror roughness, the night sky sampled
//    along the reflected view ray, and vertical neon streaks for up to eight
//    sign "lights" (the classic wet-street smear), plus rain ripple rings.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D puddle_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D sky_tex : source_color, filter_linear, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float tile_metres = 4.0;
uniform float puddle_metres = 13.0;
// 0 = bone dry, 1 = flooded.
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.5;
uniform float sky_yaw = 0.0;
uniform float sky_reflect = 0.55;
uniform float streak_strength = 1.0;
uniform float ripple_strength = 1.0;
// xyz = world position of a neon light to reflect, w = radius of its glow (metres).
uniform vec4 neon_pos[8];
// rgb = colour, a = intensity (0 disables the slot).
uniform vec4 neon_col[8];

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Expanding rings where raindrops hit standing water.
float ripples(vec2 p, float t) {
	vec2 cell = floor(p / 0.55);
	vec2 local = fract(p / 0.55) - 0.5;
	float h = hash12(cell);
	vec2 centre = vec2(hash12(cell + 7.1), hash12(cell + 3.7)) - 0.5;
	float age = fract(t * 0.9 + h);
	float r = length(local - centre * 0.6);
	float ring = smoothstep(0.035, 0.0, abs(r - age * 0.42)) * (1.0 - age);
	return ring * step(0.35, h);
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 uv = p / tile_metres;
	vec3 base = texture(albedo_tex, uv).rgb * tint;
	vec3 tn = texture(normal_tex, uv).rgb * 2.0 - 1.0;

	// Puddles: soft-edged mask, a little stronger on flat ground.
	float mask = texture(puddle_tex, p / puddle_metres).r;
	float level_ground = smoothstep(0.92, 0.99, world_normal.y);
	float puddle = smoothstep(0.62 - puddle_amount * 0.45, 0.7 - puddle_amount * 0.45, mask) * level_ground;
	float damp = 0.55 + 0.45 * puddle;

	// Wet surfaces darken; standing water hides the texture's bumps.
	vec3 col = base * mix(0.82, 0.38, puddle);
	vec3 n_tan = normalize(mix(vec3(tn.xy * 0.9, 1.0), vec3(0.0, 0.0, 1.0), puddle));

	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	vec3 r = reflect(-view_dir, vec3(0.0, 1.0, 0.0));
	float fres = pow(1.0 - clamp(view_dir.y, 0.0, 1.0), 4.0);

	// Night sky reflected in the water (equirectangular lookup).
	// Same mapping as Godot's panorama sky: the image centre is +Z.
	float az = atan(r.x, r.z) + sky_yaw;
	vec2 sky_uv = vec2(fract(az / 6.2831853 + 0.5), clamp(acos(clamp(r.y, -1.0, 1.0)) / 3.14159265, 0.0, 1.0));
	vec3 sky = texture(sky_tex, sky_uv).rgb;
	vec3 refl = sky * sky_reflect * (0.25 + 0.75 * fres);

	// Neon smears: each light reflects as a streak stretched toward the viewer.
	vec2 cam = CAMERA_POSITION_WORLD.xz;
	float cam_h = max(0.3, CAMERA_POSITION_WORLD.y - world_pos.y);
	for (int i = 0; i < 8; i++) {
		if (neon_col[i].a <= 0.0) {
			continue;
		}
		vec3 lp = neon_pos[i].xyz;
		float light_h = max(0.2, lp.y - world_pos.y);
		vec2 to_light = lp.xz - cam;
		float len_cl = max(0.01, length(to_light));
		vec2 dir = to_light / len_cl;
		// Mirror point on the floor between the camera and the light.
		vec2 mirror = cam + dir * len_cl * (cam_h / (cam_h + light_h));
		vec2 d = p - mirror;
		float along = dot(d, dir);
		float across = d.x * dir.y - d.y * dir.x;
		float w = neon_pos[i].w * (0.35 + 0.012 * len_cl);
		float streak = exp(-pow(across / w, 2.0)) * exp(-pow(along / (w * 5.5 + len_cl * 0.08), 2.0));
		refl += neon_col[i].rgb * neon_col[i].a * streak * streak_strength;
	}

	float wet_refl = mix(0.22, 1.0, puddle);
	float ring = ripples(p, TIME) * puddle * ripple_strength;

	ALBEDO = col;
	NORMAL_MAP = n_tan * 0.5 + 0.5;
	ROUGHNESS = mix(0.62, 0.06, puddle) * (1.0 - 0.25 * damp);
	SPECULAR = mix(0.35, 0.7, puddle);
	METALLIC = 0.0;
	EMISSION = refl * wet_refl + vec3(0.55, 0.75, 1.0) * ring * 0.35;
}
