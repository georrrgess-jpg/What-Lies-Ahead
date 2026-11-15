shader_type spatial;

// Smouldering embers and fire glow inside the city's wrecks: a slow, uneven
// pulse that drifts across the surface (world-space noise), hotter in spots.
uniform vec3 cool_color : source_color = vec3(0.55, 0.06, 0.02);
uniform vec3 hot_color : source_color = vec3(1.0, 0.55, 0.12);
uniform float strength = 3.0;
uniform float speed = 1.0;

varying vec3 world_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * speed;
	float n = noise(world_pos.xz * 4.0 + vec2(t * 0.7, -t * 0.4)) * 0.6 + noise(world_pos.xy * 7.0 - vec2(t * 1.3, t)) * 0.4;
	float heat = clamp(n * 1.3 - 0.15 + 0.15 * sin(t * 3.0 + world_pos.x * 2.0), 0.0, 1.0);
	vec3 c = mix(cool_color, hot_color, heat);
	ALBEDO = c * 0.2;
	ROUGHNESS = 0.8;
	EMISSION = c * strength * (0.45 + heat * 0.9);
}
