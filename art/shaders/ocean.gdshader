shader_type spatial;
render_mode cull_back;

// Stylised sunset sea: teal water near the pier, warm reflections toward the
// horizon, rolling foam lines and a sun glitter path. Cheap: no textures, no
// screen reads, restrained reflections.
uniform vec3 near_color : source_color = vec3(0.04, 0.4, 0.55);
uniform vec3 deep_color : source_color = vec3(0.06, 0.2, 0.5);
uniform vec3 horizon_color : source_color = vec3(0.86, 0.45, 0.62);
uniform vec3 foam_color : source_color = vec3(1.0, 0.93, 0.9);
uniform vec3 glitter_color : source_color = vec3(1.0, 0.82, 0.55);
uniform vec2 sun_direction = vec2(0.588, -0.809);   // world XZ, toward the sun
uniform float wave_speed = 0.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float waves(vec2 p, float t) {
	float w = sin(p.x * 0.21 + t * 0.9 + sin(p.y * 0.13) * 1.7);
	w += sin(p.y * 0.34 - t * 1.2 + sin(p.x * 0.11 + t * 0.3) * 2.1) * 0.8;
	w += sin((p.x + p.y) * 0.63 + t * 1.6) * 0.35;
	w += sin((p.x - p.y * 1.3) * 1.15 - t * 2.1) * 0.18;
	return w;
}

void fragment() {
	vec2 p = world_pos.xz;
	float t = TIME * wave_speed;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float far = smoothstep(40.0, 420.0, dist);

	// Wave normal from finite differences (fades with distance to avoid shimmer).
	float e = 0.6;
	float h = waves(p, t);
	float hx = waves(p + vec2(e, 0.0), t);
	float hz = waves(p + vec2(0.0, e), t);
	float strength = mix(0.34, 0.05, smoothstep(10.0, 160.0, dist));
	vec3 n = normalize(vec3((h - hx) * strength, 1.0, (h - hz) * strength));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	float fresnel = pow(1.0 - clamp(dot(view_dir, n), 0.0, 1.0), 3.0);

	vec3 col = mix(near_color, deep_color, smoothstep(8.0, 110.0, dist));
	col = mix(col, horizon_color, clamp(fresnel * 0.3 + far * 0.42, 0.0, 1.0));

	// Rolling foam lines, strongest near the pier.
	float crest = smoothstep(0.82, 0.98, sin(p.y * 0.19 + p.x * 0.05 - t * 0.9 + sin(p.x * 0.08) * 1.6) * 0.5 + 0.5 + h * 0.06);
	col = mix(col, foam_color, crest * 0.55 * (1.0 - smoothstep(30.0, 170.0, dist)));

	// Sun glitter path: bright dashes along the direction of the sun.
	vec2 to_frag = normalize(p - CAMERA_POSITION_WORLD.xz);
	float along = clamp(dot(to_frag, normalize(sun_direction)), 0.0, 1.0);
	float path = pow(along, 90.0);
	float sparkle = smoothstep(0.55, 0.95, sin(p.x * 1.7 + t * 3.0) * sin(p.y * 0.9 - t * 2.2) * 0.5 + 0.5 + h * 0.2);
	col += glitter_color * path * (0.35 + sparkle * 0.9) * smoothstep(6.0, 60.0, dist);

	ALBEDO = col * 0.72;
	ROUGHNESS = 0.3;
	SPECULAR = 0.45;
	METALLIC = 0.0;
}
