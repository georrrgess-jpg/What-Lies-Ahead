shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
// Madame Fortuna's crystal ball (scripts/cosmetics/operator_aura.gd): a clear
// rim, a swirl of violet and teal mist turning inside, a core that breathes
// and a white highlight, so it reads as a glowing crystal ball without a
// reflection probe.
uniform float strength = 1.0;
uniform vec3 mist_a : source_color = vec3(0.62, 0.25, 1.0);
uniform vec3 mist_b : source_color = vec3(0.2, 0.95, 1.0);
uniform vec3 rim : source_color = vec3(0.85, 0.95, 1.0);

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 d = normalize(lp);
	float a = atan(d.z, d.x);
	float swirl = 0.5 + 0.5 * sin(a * 3.0 + d.y * 6.0 - TIME * 1.6 + sin(TIME * 0.7 + d.y * 4.0) * 1.5);
	float swirl2 = 0.5 + 0.5 * sin(a * 2.0 - d.y * 5.0 + TIME * 1.1);
	vec3 mist = mix(mist_a, mist_b, swirl) * (0.45 + 0.55 * swirl2);
	float core = pow(facing, 3.0) * (0.75 + 0.25 * sin(TIME * 2.4));
	vec3 col = mist * (0.35 + 0.9 * facing) + vec3(1.0, 0.95, 1.0) * core * 0.6;
	col += rim * pow(1.0 - facing, 2.5) * 1.2;
	vec3 hl = normalize(vec3(-0.4, 0.6, 0.7));
	col += vec3(1.0) * smoothstep(0.93, 0.97, dot(NORMAL, hl));
	ALBEDO = col * strength;
}
