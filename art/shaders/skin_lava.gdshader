shader_type spatial;
// Weapon finish "Lava Flow": a cracked dark crust with molten rivers glowing
// between the plates; the magma creeps along and pulses.
uniform vec3 shell_color : source_color = vec3(0.12, 0.07, 0.07);
uniform vec3 trim_color : source_color = vec3(0.2, 0.1, 0.08);
uniform bool is_trim = false;
uniform vec3 glow_color : source_color = vec3(1.0, 0.32, 0.05);
uniform vec3 hot_color : source_color = vec3(1.0, 0.85, 0.3);
uniform float scale = 26.0;
uniform float flow = 0.5;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

// Distance to the nearest and second-nearest cell centre.
vec2 voronoi(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = hash33(i + g);
				float d = length(g + o - f);
				if (d < d1) {
					d2 = d1;
					d1 = d;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec2(d1, d2);
}

void fragment() {
	vec3 p = lp * scale;
	vec2 v = voronoi(p);
	float edge = v.y - v.x;
	float crack = smoothstep(is_trim ? 0.08 : 0.16, 0.0, edge);
	float wave = 0.5 + 0.5 * sin(dot(lp, vec3(18.0, 30.0, 55.0)) - TIME * 2.4 * flow);
	float pulse = 0.75 + 0.25 * sin(TIME * 1.7 + v.x * 6.0);
	vec3 magma = mix(glow_color, hot_color, wave * crack);
	vec3 base = is_trim ? trim_color : shell_color;
	// Plates darken towards their centres, glow faintly at their rims.
	ALBEDO = mix(base * (0.8 + 0.4 * v.x), magma, crack * 0.85);
	ROUGHNESS = mix(0.85, 0.35, crack);
	METALLIC = 0.1;
	EMISSION = magma * crack * (1.6 + wave) * pulse + glow_color * smoothstep(0.35, 0.0, edge) * 0.25;
}
