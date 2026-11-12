shader_type spatial;
// Weapon finish "Frostbite": faceted ice crystals with frosted white edges,
// glinting sparkles that move with the view and a faint cold glow in the seams.
uniform vec3 shell_color : source_color = vec3(0.72, 0.9, 1.0);
uniform vec3 trim_color : source_color = vec3(0.24, 0.5, 0.95);
uniform bool is_trim = false;
uniform vec3 glow_color : source_color = vec3(0.45, 0.9, 1.0);
uniform float scale = 34.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

// x: distance to nearest centre, y: second nearest, z: id of nearest.
vec3 voronoi(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = hash33(i + g);
				float d = length(g + o - f);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					id = o.x;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec3(d1, d2, id);
}

void fragment() {
	vec3 v = voronoi(lp * scale);
	float seam = smoothstep(0.1, 0.0, v.y - v.x);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 base = is_trim ? trim_color : shell_color;
	// Each crystal facet catches the light a little differently.
	vec3 facet = base * (0.82 + 0.3 * v.z);
	vec3 col = mix(facet, vec3(0.97, 0.99, 1.0), clamp(seam * 0.7 + fres * 0.65, 0.0, 1.0));
	vec3 g = hash33(floor(lp * 150.0));
	float glint = step(0.965, g.x) * pow(max(0.0, sin(dot(VIEW, g * 2.0 - 1.0) * 20.0 + TIME * 1.5)), 8.0);
	ALBEDO = col;
	ROUGHNESS = mix(0.12, 0.4, seam);
	METALLIC = 0.15;
	SPECULAR = 0.9;
	EMISSION = glow_color * seam * 0.45 + vec3(glint) * 2.0 + glow_color * fres * 0.15;
}
