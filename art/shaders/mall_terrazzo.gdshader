shader_type spatial;
// Midnight Mall floors: polished terrazzo in world space. Cream-and-pink chips,
// a large tile grid with brass divider strips, and a soft gloss that picks up
// the shop lights. No textures: everything is procedural.

uniform vec3 base_color : source_color = vec3(0.86, 0.8, 0.78);
uniform vec3 chip_a : source_color = vec3(0.95, 0.55, 0.68);
uniform vec3 chip_b : source_color = vec3(0.35, 0.78, 0.8);
uniform vec3 chip_c : source_color = vec3(0.22, 0.2, 0.32);
uniform vec3 strip_color : source_color = vec3(0.82, 0.64, 0.32);
uniform float tile_size = 3.0;
uniform float chip_scale = 9.0;
uniform float roughness_value = 0.22;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Cellular chips: distance to the nearest random point, and that point's id.
vec2 chips(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float best = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 17.3));
			float d = length(g + o - f);
			if (d < best) {
				best = d;
				id = hash(i + g + 5.1);
			}
		}
	}
	return vec2(best, id);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 col = base_color;
	vec2 c = chips(p * chip_scale);
	float chip = (1.0 - smoothstep(0.16, 0.2, c.x)) * 0.8;
	vec3 chip_col = c.y < 0.45 ? chip_a : (c.y < 0.75 ? chip_b : chip_c);
	col = mix(col, chip_col, chip * step(0.35, fract(c.y * 7.0)));
	// Faint large-scale cloudiness so big floors do not look flat.
	col *= 0.94 + 0.06 * hash(floor(p * 0.5));
	vec2 t = abs(fract(p / tile_size + 0.5) - 0.5) * tile_size;
	float strip = 1.0 - smoothstep(0.025, 0.04, min(t.x, t.y));
	col = mix(col, strip_color, strip);
	ALBEDO = col;
	ROUGHNESS = mix(roughness_value, 0.3, strip);
	METALLIC = strip * 0.7;
	SPECULAR = 0.7;
}
