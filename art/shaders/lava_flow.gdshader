shader_type spatial;
render_mode cull_back;

// Molten lava: dark crust plates drifting on a glowing gold-to-orange flow,
// with hot cracks pulsing between them. World-space, so the river, a stream
// on a slope and the crater pool all share it. `flow` sets the drift (world
// XZ); `fall` adds a downhill drift for streams on slopes.
uniform vec3 hot_color : source_color = vec3(1.0, 0.86, 0.42);
uniform vec3 warm_color : source_color = vec3(1.0, 0.36, 0.08);
uniform vec3 crust_color : source_color = vec3(0.12, 0.05, 0.06);
uniform vec2 flow = vec2(-0.35, 0.0);
uniform float fall = 0.0;
uniform float scale = 0.45;
uniform float glow = 3.2;
uniform float crust_amount = 0.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// F2 - F1 of a cellular pattern: 0 on the cracks.
float cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash2(i + g);
			o = 0.5 + 0.4 * sin(TIME * 0.3 + 6.2831 * o);
			float d = length(g + o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return f2 - f1;
}

void fragment() {
	vec2 p = world_pos.xz * scale - flow * TIME + vec2(0.0, world_pos.y * fall * scale + TIME * fall * 0.4);
	float c = cells(p);
	float c2 = cells(p * 2.3 + 7.1);
	float crust = smoothstep(0.08, 0.32, c) * smoothstep(0.02, 0.2, c2) * crust_amount * 2.0;
	crust = clamp(crust, 0.0, 1.0);
	float pulse = 0.85 + 0.15 * sin(TIME * 1.7 + world_pos.x * 0.3 + world_pos.z * 0.2);
	vec3 molten = mix(warm_color, hot_color, smoothstep(0.12, 0.0, c) * pulse);
	ALBEDO = mix(molten, crust_color, crust) * 0.25;
	ROUGHNESS = 0.6;
	EMISSION = molten * (1.0 - min(crust, 0.92)) * glow * pulse;
}
