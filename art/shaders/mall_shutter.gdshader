shader_type spatial;
// Roll-down security shutter: ribbed steel slats (horizontal, 0.12 m pitch in
// world height) with a faint grime gradient toward the floor.

uniform vec3 slat_color : source_color = vec3(0.62, 0.64, 0.72);
uniform vec3 groove_color : source_color = vec3(0.28, 0.29, 0.36);
uniform float pitch = 0.12;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float s = fract(world_pos.y / pitch);
	float groove = smoothstep(0.0, 0.12, s) * (1.0 - smoothstep(0.82, 1.0, s));
	vec3 col = mix(groove_color, slat_color, groove);
	col *= 0.8 + 0.2 * smoothstep(0.0, 1.2, fract(world_pos.y / 5.0) * 5.0);
	ALBEDO = col;
	METALLIC = 0.55;
	ROUGHNESS = 0.42;
	// Fake the slat profile in the normal so lights roll over the ribs.
	NORMAL = normalize(NORMAL + VIEW_MATRIX[1].xyz * (s - 0.5) * 0.35 * groove);
}
