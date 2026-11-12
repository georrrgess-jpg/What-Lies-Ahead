shader_type spatial;
// Gold mastery camo (rank 7). Brushed gold: fine grain running along the
// barrel, a studio-style reflection so it reads as metal under any light, a
// glint that sweeps down the weapon every few seconds, and tiny sparkles.
// Shell = bright gold, trim = antique gold. Contract: weapon_cosmetics.gd.
uniform vec3 shell_color : source_color = vec3(1.0, 0.76, 0.23);
uniform vec3 trim_color : source_color = vec3(0.48, 0.29, 0.06);
uniform bool is_trim = false;
uniform float glint_speed = 0.55;
uniform float brush_scale = 180.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec3 gold = is_trim ? trim_color : shell_color;
	// Brushed grain: streaks stretched along the weapon's long axis (local Z).
	float across = (lp.y + lp.x * 0.7) * brush_scale;
	float grain = vnoise(vec2(lp.z * brush_scale * 0.05, across)) * 0.65
		+ vnoise(vec2(lp.z * brush_scale * 0.015, across * 2.7)) * 0.35;

	// Fake studio reflection: warm bright "ceiling", deep amber "floor".
	vec3 r = reflect(-VIEW, NORMAL);
	float sky = smoothstep(-0.35, 0.75, r.y);
	vec3 deep = gold * vec3(0.42, 0.3, 0.16);
	vec3 bright = mix(gold, vec3(1.0, 0.97, 0.85), 0.5);
	vec3 refl = mix(deep, bright, sky);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);

	// Glint band sweeping along the weapon; idles off-weapon between passes.
	float phase = fract(TIME * glint_speed * 0.3);
	float centre = mix(-0.9, 0.9, phase);
	float band = (lp.z + lp.y * 0.6 - centre) * 10.0;
	float glint = exp(-band * band) * (is_trim ? 0.5 : 1.0);

	// Sparkles: rare round flecks that twinkle.
	vec3 cell = floor(lp * 95.0);
	float seed = hash3(cell);
	float fleck = 1.0 - smoothstep(0.12, 0.32, length(fract(lp * 95.0) - 0.5));
	float twinkle = step(0.975, seed) * fleck * pow(0.5 + 0.5 * sin(TIME * 4.0 + seed * 60.0), 10.0);

	float polish = is_trim ? 0.25 : 1.0;
	ALBEDO = gold * mix(0.62, 1.0, mix(1.0, grain, polish));
	METALLIC = 0.8;
	ROUGHNESS = mix(0.2, 0.42, grain * polish);
	SPECULAR = 0.7;
	EMISSION = refl * (0.22 + 0.25 * fres) + bright * glint * 1.3 + vec3(1.0, 0.95, 0.8) * twinkle * 2.5;
}
