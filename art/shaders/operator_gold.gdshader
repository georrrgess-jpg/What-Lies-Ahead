shader_type spatial;
// The Arcade Champion's suit (scripts/cosmetics/operators.gd): polished gold
// with a warm studio gradient that does not need an environment to reflect,
// a sheen that sweeps across now and then, and small twinkling glints.
uniform vec3 shell_color : source_color = vec3(1.0, 0.76, 0.24);
uniform float sweep_speed = 0.3;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float up = NORMAL.y * 0.5 + 0.5;
	// Fake reflection: bright sky above, deep amber below, a hot band near the top.
	vec3 deep = shell_color * vec3(0.55, 0.36, 0.2);
	vec3 bright = mix(shell_color, vec3(1.0, 0.97, 0.82), 0.55);
	vec3 gold = mix(deep, shell_color, smoothstep(0.1, 0.55, up));
	gold = mix(gold, bright, smoothstep(0.62, 0.95, up) * 0.85);
	gold += vec3(1.0, 0.9, 0.6) * pow(1.0 - facing, 3.0) * 0.35;
	float sweep = smoothstep(0.05, 0.0, abs(fract(dot(lp, vec3(0.5, 0.9, 0.3)) * 0.6 - TIME * sweep_speed) - 0.5) - 0.46);
	vec3 cell = floor(lp * 70.0);
	float h = hash31(cell);
	vec3 f = fract(lp * 70.0) - 0.5;
	float star = smoothstep(0.42, 0.0, length(f)) * step(0.93, h) * pow(0.5 + 0.5 * sin(TIME * 3.0 + h * 60.0), 8.0);
	ALBEDO = gold * mix(0.6, 1.0, COLOR.r);
	METALLIC = 0.35;
	ROUGHNESS = 0.26;
	EMISSION = gold * (0.22 + sweep * 0.55) * mix(0.5, 1.0, COLOR.r) + vec3(1.0, 0.96, 0.8) * star * 3.0;
}
