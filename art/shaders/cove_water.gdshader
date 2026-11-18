shader_type spatial;
render_mode cull_back;

// The cove's sea at sunset: clear turquoise over the shallows by the quay,
// deepening to teal and blue out in the bay, a warm sunset sheen only at
// grazing angles far out, rolling foam lines and a glitter path toward the
// sun. No textures, no screen reads.
uniform vec3 shallow_color : source_color = vec3(0.16, 0.78, 0.72);
uniform vec3 near_color : source_color = vec3(0.07, 0.56, 0.6);
uniform vec3 deep_color : source_color = vec3(0.05, 0.3, 0.48);
uniform vec3 sheen_color : source_color = vec3(1.0, 0.6, 0.45);
uniform vec3 foam_color : source_color = vec3(1.0, 0.97, 0.92);
uniform vec3 glitter_color : source_color = vec3(1.0, 0.78, 0.45);
uniform vec2 sun_direction = vec2(-0.6, 0.77);   // world XZ, toward the sun
// The shallows: a rounded box round the harbour (centre, half size) whose
// edge fades to the bay.
uniform vec2 shallows_centre = vec2(10.0, 0.0);
uniform vec2 shallows_half = vec2(48.0, 34.0);
uniform float wave_speed = 0.5;
uniform float brightness = 0.85;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float waves(vec2 p, float t) {
	float w = sin(p.x * 0.23 + t * 0.9 + sin(p.y * 0.13) * 1.7);
	w += sin(p.y * 0.31 - t * 1.1 + sin(p.x * 0.11 + t * 0.3) * 2.1) * 0.8;
	w += sin((p.x + p.y) * 0.67 + t * 1.6) * 0.35;
	w += sin((p.x - p.y * 1.3) * 1.2 - t * 2.1) * 0.18;
	return w;
}

void fragment() {
	vec2 p = world_pos.xz;
	float t = TIME * wave_speed;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);

	float e = 0.6;
	float h = waves(p, t);
	float hx = waves(p + vec2(e, 0.0), t);
	float hz = waves(p + vec2(0.0, e), t);
	float strength = mix(0.3, 0.04, smoothstep(10.0, 160.0, dist));
	vec3 n = normalize(vec3((h - hx) * strength, 1.0, (h - hz) * strength));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	float fresnel = pow(1.0 - clamp(dot(view_dir, n), 0.0, 1.0), 4.0);

	// Shallows by the harbour, open water beyond.
	vec2 q = abs(p - shallows_centre) - shallows_half;
	float out_d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
	float bay = smoothstep(-6.0, 60.0, out_d);
	vec3 col = mix(shallow_color, near_color, smoothstep(-30.0, -4.0, out_d));
	col = mix(col, deep_color, bay);
	col = mix(col, sheen_color, clamp(fresnel * 0.35 + smoothstep(120.0, 600.0, dist) * 0.45, 0.0, 0.75));

	// Rolling foam lines (near), sparkle.
	float crest = smoothstep(0.84, 0.98, sin(p.y * 0.21 + p.x * 0.06 - t * 0.9 + sin(p.x * 0.08) * 1.6) * 0.5 + 0.5 + h * 0.06);
	col = mix(col, foam_color, crest * 0.4 * (1.0 - smoothstep(25.0, 140.0, dist)));

	vec2 to_frag = normalize(p - CAMERA_POSITION_WORLD.xz);
	float along = clamp(dot(to_frag, normalize(sun_direction)), 0.0, 1.0);
	float path = pow(along, 70.0);
	float sparkle = smoothstep(0.55, 0.95, sin(p.x * 1.7 + t * 3.0) * sin(p.y * 0.9 - t * 2.2) * 0.5 + 0.5 + h * 0.2);
	col += glitter_color * path * (0.35 + sparkle * 0.9) * smoothstep(6.0, 60.0, dist);

	ALBEDO = col * brightness;
	EMISSION = col * 0.18;
	ROUGHNESS = 0.22;
	SPECULAR = 0.3;
	METALLIC = 0.0;
}
