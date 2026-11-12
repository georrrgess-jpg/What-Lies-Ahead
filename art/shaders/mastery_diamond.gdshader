shader_type spatial;
// Diamond mastery camo (rank 9). Faceted crystal: the surface is split into
// Voronoi facets, each tilted its own way, so highlights jump from facet to
// facet as the weapon moves. Rainbow "fire" along the facet edges, a cold
// inner glow at grazing angles and twinkling sparkles. Contract: weapon_cosmetics.gd.
uniform vec3 shell_color : source_color = vec3(0.75, 0.96, 1.0);
uniform vec3 trim_color : source_color = vec3(0.18, 0.44, 0.6);
uniform bool is_trim = false;
uniform float facet_scale = 34.0;
uniform float sparkle = 1.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

// Nearest and second-nearest feature distances, plus the nearest cell id.
vec2 voronoi(vec3 p, out vec3 id) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec2 d = vec2(8.0);
	id = i;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 r = g + hash33(i + g) - f;
				float dd = dot(r, r);
				if (dd < d.x) {
					d.y = d.x;
					d.x = dd;
					id = i + g;
				} else if (dd < d.y) {
					d.y = dd;
				}
			}
		}
	}
	return sqrt(d);
}

void fragment() {
	vec3 id;
	vec2 d = voronoi(lp * facet_scale, id);
	vec3 rnd = hash33(id) * 2.0 - 1.0;
	float edge = 1.0 - smoothstep(0.0, 0.07, d.y - d.x);

	// Each facet tilts the normal its own way.
	vec3 n = normalize(NORMAL + rnd * 0.5);
	NORMAL = n;
	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 2.5);
	vec3 r = reflect(-VIEW, n);
	// Two slowly orbiting "studio lights" make facets flash even at rest.
	vec3 l1 = normalize(vec3(sin(TIME * 0.7), 0.7, cos(TIME * 0.55)));
	vec3 l2 = normalize(vec3(-cos(TIME * 0.45), 0.3, sin(TIME * 0.8)));
	float flash = pow(max(dot(r, l1), 0.0), 28.0) + 0.6 * pow(max(dot(r, l2), 0.0), 40.0);
	vec3 fire = 0.5 + 0.5 * cos(6.2831 * (rnd.x * 0.5 + rnd.z * 0.3 + TIME * 0.08 + vec3(0.0, 0.33, 0.67)));

	vec3 base = is_trim ? trim_color : shell_color;
	vec3 ice = base * (0.72 + 0.28 * rnd.y);
	float seed = hash33(id + 17.0).x;
	float twinkle = step(0.9, seed) * pow(0.5 + 0.5 * sin(TIME * 5.0 + seed * 80.0), 14.0);
	float strength = is_trim ? 0.45 : 1.0;

	ALBEDO = ice * 0.8;
	METALLIC = 0.35;
	ROUGHNESS = 0.06;
	SPECULAR = 0.9;
	EMISSION = ice * (0.12 + 0.45 * fres)
		+ (vec3(1.0) * flash + fire * edge * 0.45) * strength
		+ vec3(1.0) * twinkle * sparkle * 2.2 * strength;
}
