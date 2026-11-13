shader_type spatial;
render_mode cull_back;

// Hot-spring water: milky teal, brighter toward the shallow rim, slow rings
// spreading from the spring vent and soft caustic light. `centre` and
// `radius` (world XZ) describe the pool's disc.
uniform vec3 deep_color : source_color = vec3(0.02, 0.42, 0.48);
uniform vec3 shallow_color : source_color = vec3(0.22, 0.86, 0.74);
uniform vec3 glint_color : source_color = vec3(0.75, 1.0, 0.92);
uniform vec2 centre = vec2(0.0, 0.0);
uniform float radius = 3.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 d = world_pos.xz - centre;
	float r = clamp(length(d) / radius, 0.0, 1.0);
	float ring = sin(length(d) * 5.0 - TIME * 1.6) * 0.5 + 0.5;
	float caustic = smoothstep(0.55, 1.0, sin(world_pos.x * 2.1 + TIME * 0.9) * sin(world_pos.z * 2.4 - TIME * 0.7));
	vec3 col = mix(deep_color, shallow_color, smoothstep(0.35, 1.0, r));
	col += glint_color * (ring * 0.08 * (1.0 - r) + caustic * 0.12);
	ALBEDO = col;
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
	EMISSION = col * 0.35;
	vec3 bump = vec3(d.x, 0.0, d.y) / (length(d) + 0.001) * (ring * 2.0 - 1.0) * 0.08;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(bump, 0.0)).xyz);
}
