shader_type spatial;
// Weapon finish "Tidal": sea-glass colours with rippling caustic light, like
// sunlight dancing on the bottom of a pool.
uniform vec3 shell_color : source_color = vec3(0.05, 0.55, 0.62);
uniform vec3 trim_color : source_color = vec3(0.03, 0.2, 0.42);
uniform bool is_trim = false;
uniform vec3 light_color : source_color = vec3(0.75, 1.0, 0.95);
uniform float scale = 30.0;
uniform float speed = 0.5;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

// Edge distance of a 3D cell pattern whose centres orbit over time.
float ripples(vec3 p, float t) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = hash33(i + g);
				o = 0.5 + 0.4 * sin(t + o * 6.28318);
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
	return d2 - d1;
}

void fragment() {
	float t = TIME * speed;
	float c1 = smoothstep(0.18, 0.0, ripples(lp * scale, t));
	float c2 = smoothstep(0.14, 0.0, ripples(lp * scale * 1.6 + 3.1, -t * 1.3));
	float caustic = clamp(c1 * 0.8 + c2 * 0.6, 0.0, 1.2);
	vec3 base = is_trim ? trim_color : mix(trim_color, shell_color, clamp(lp.y * 3.0 + 0.6, 0.0, 1.0));
	ALBEDO = base + light_color * caustic * 0.25;
	ROUGHNESS = 0.18;
	METALLIC = 0.1;
	SPECULAR = 0.8;
	EMISSION = light_color * caustic * (is_trim ? 0.35 : 0.8);
}
