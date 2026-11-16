shader_type spatial;
// Madame Fortuna's cape (scripts/cosmetics/operators.gd): a night sky in the
// cloth. A slow nebula of violet and teal drifts across deep midnight, stars
// twinkle in three sizes, and now and then a shooting star crosses it. The
// sky is laid out in model space, so it moves with the cape.
uniform vec3 shell_color : source_color = vec3(0.11, 0.09, 0.31);
uniform vec3 nebula_a : source_color = vec3(0.62, 0.18, 0.86);
uniform vec3 nebula_b : source_color = vec3(0.12, 0.78, 0.86);
uniform float star_scale = 26.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float stars(vec2 p, float scale, float density, float seed) {
	vec2 cell = floor(p * scale);
	vec2 f = fract(p * scale) - 0.5;
	float h = hash21(cell + seed);
	vec2 off = vec2(hash21(cell + seed + 7.1), hash21(cell + seed + 3.3)) - 0.5;
	float d = length(f - off * 0.5);
	float twinkle = 0.45 + 0.55 * pow(0.5 + 0.5 * sin(TIME * (1.5 + h * 3.0) + h * 40.0), 4.0);
	return smoothstep(0.16, 0.0, d) * step(1.0 - density, h) * twinkle;
}

void fragment() {
	vec2 p = vec2(lp.x, lp.y) + vec2(0.0, lp.z * 0.4);
	vec2 drift = vec2(TIME * 0.02, -TIME * 0.013);
	float n = noise(p * 3.0 + drift) * 0.6 + noise(p * 6.5 - drift * 1.7) * 0.4;
	vec3 sky = shell_color;
	sky = mix(sky, nebula_a * 0.55, smoothstep(0.5, 0.85, n) * 0.8);
	sky = mix(sky, nebula_b * 0.45, smoothstep(0.62, 0.95, noise(p * 4.0 - drift + 9.0)) * 0.6);
	float s = stars(p, star_scale, 0.22, 0.0) + stars(p, star_scale * 0.45, 0.12, 5.0) * 1.6;
	vec3 star_col = mix(vec3(1.0, 0.95, 0.8), vec3(1.0, 0.78, 0.34), step(0.5, hash21(floor(p * star_scale))));
	// A shooting star every few seconds, along a fixed diagonal.
	float cycle = fract(TIME * 0.18);
	vec2 dir = normalize(vec2(-1.0, -0.55));
	vec2 head = vec2(0.35, 1.45) + dir * (cycle * 2.4);
	vec2 rel = p - head;
	float along = dot(rel, -dir);
	float across = abs(dot(rel, vec2(-dir.y, dir.x)));
	float streak = smoothstep(0.012, 0.0, across) * smoothstep(0.35, 0.0, along) * step(0.0, along) * step(cycle, 0.45);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float ao = mix(0.55, 1.0, COLOR.r);
	ALBEDO = sky * ao;
	ROUGHNESS = 0.55;
	EMISSION = (sky * 0.5 + star_col * s * 2.4 + vec3(1.0, 0.92, 0.75) * streak * 3.0) * ao + nebula_a * pow(1.0 - facing, 3.0) * 0.25;
}
