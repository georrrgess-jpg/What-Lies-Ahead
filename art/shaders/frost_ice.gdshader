shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

// Frozen pond: deep blue-teal ice with fake depth (cracks and trapped bubbles
// sampled twice with a view-dependent offset), a frosted rim and a cheap
// reflection of the twilight sky and the aurora (reflected view vector into
// an analytic sky, no screen reads, no reflection probes).
uniform sampler2D crack_texture : filter_linear_mipmap, repeat_enable;   // r: cracks, g: frost, b: bubbles
uniform vec3 deep_color : source_color = vec3(0.04, 0.16, 0.32);
uniform vec3 shallow_color : source_color = vec3(0.2, 0.52, 0.72);
uniform vec3 crack_color : source_color = vec3(0.78, 0.94, 1.0);
uniform vec3 frost_color : source_color = vec3(0.86, 0.88, 1.0);
uniform vec3 sky_low : source_color = vec3(0.62, 0.52, 0.86);
uniform vec3 sky_high : source_color = vec3(0.08, 0.1, 0.32);
uniform vec3 aurora_color : source_color = vec3(0.3, 1.0, 0.62);
uniform vec3 warm_color : source_color = vec3(1.0, 0.62, 0.28);
// Ellipse of the pond (world XZ centre and radii) for the frosted rim.
uniform vec2 centre = vec2(0.0);
uniform vec2 radii = vec2(7.0, 5.0);
uniform float uv_scale = 0.12;
uniform float depth = 0.35;
uniform float reflection_strength = 0.85;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 view = normalize(CAMERA_POSITION_WORLD - world_pos);
	vec2 uv = world_pos.xz * uv_scale;
	vec4 surface = texture(crack_texture, uv);
	// Deeper layer: shifted along the view ray, so it slides under the surface.
	vec2 parallax = -view.xz / max(view.y, 0.2) * depth * uv_scale;
	vec4 deep = texture(crack_texture, uv * 0.83 + parallax + vec2(0.31, 0.17));
	vec4 deeper = texture(crack_texture, uv * 0.61 + parallax * 2.2 + vec2(0.71, 0.43));

	float rim = length((world_pos.xz - centre) / radii);
	float frost = smoothstep(0.72, 1.0, rim) + surface.g * 0.35;

	vec3 col = mix(deep_color, shallow_color, smoothstep(0.2, 1.0, rim) * 0.7 + deep.b * 0.2);
	col = mix(col, crack_color * 0.55, deep.r * 0.55 + deeper.r * 0.3);
	col += crack_color * deeper.b * 0.12;
	col = mix(col, crack_color, surface.r * 0.8);
	col = mix(col, frost_color, clamp(frost, 0.0, 1.0) * 0.85);

	// Analytic sky reflection: horizon glow, deep zenith, an aurora band that
	// drifts, and warm light from the lodge side (north, -Z).
	vec3 n = normalize(vec3((surface.r - 0.5) * 0.08, 1.0, (deep.r - 0.5) * 0.08));
	vec3 r = reflect(-view, n);
	float elev = clamp(r.y, 0.0, 1.0);
	vec3 sky = mix(sky_low, sky_high, smoothstep(0.0, 0.55, elev));
	float az = atan(r.x, -r.z);
	float band = smoothstep(0.08, 0.26, elev) * (1.0 - smoothstep(0.3, 0.62, elev));
	band *= 0.55 + 0.45 * sin(az * 3.0 + TIME * 0.25 + sin(az * 7.0 - TIME * 0.4));
	sky += aurora_color * band * 0.9;
	sky += warm_color * pow(max(-r.z, 0.0), 6.0) * (1.0 - smoothstep(0.0, 0.25, elev)) * 0.8;
	float fresnel = pow(1.0 - clamp(view.y, 0.0, 1.0), 4.0) * 0.85 + 0.12;
	float reflect_k = fresnel * reflection_strength * (1.0 - clamp(frost, 0.0, 1.0) * 0.8);

	ALBEDO = col * (1.0 - reflect_k * 0.6);
	EMISSION = sky * reflect_k * 0.75;
	ROUGHNESS = mix(0.06, 0.6, clamp(frost, 0.0, 1.0));
	SPECULAR = 0.7;
}
