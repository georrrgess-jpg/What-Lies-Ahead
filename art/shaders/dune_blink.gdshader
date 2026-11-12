shader_type spatial;
render_mode cull_back;

// Landing and perimeter lights. Each light's lens blinks on its own phase, so a
// row of them chases toward the pad. MultiMesh: INSTANCE_CUSTOM.r = phase (0-1);
// a single mesh can set `phase` instead.
uniform vec3 light_color : source_color = vec3(1.0, 0.62, 0.18);
uniform vec3 housing_color : source_color = vec3(0.22, 0.2, 0.24);
uniform float speed = 0.8;
uniform float duty = 0.22;
uniform float glow = 4.0;
uniform float idle = 0.25;
uniform float phase = 0.0;

varying float pulse;

void vertex() {
	float ph = fract(TIME * speed - INSTANCE_CUSTOM.r - phase);
	pulse = smoothstep(duty, 0.0, ph) + smoothstep(0.96, 1.0, ph);
}

void fragment() {
	// The upward-facing lens glows; the sides read as a dark housing.
	vec3 n_world = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float lens = smoothstep(0.6, 0.95, n_world.y);
	float k = idle + pulse * (1.0 - idle);
	ALBEDO = mix(housing_color, light_color * (0.4 + 0.6 * k), lens);
	EMISSION = light_color * lens * k * glow;
	ROUGHNESS = 0.4;
}
