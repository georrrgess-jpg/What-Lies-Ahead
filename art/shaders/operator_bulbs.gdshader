shader_type spatial;
// Madame Fortuna's marquee bulbs (scripts/cosmetics/operators.gd): every bulb
// on the coat, the collar and the turban band glows warm, and a chase runs
// round the body and up the coat edges, its colour drifting from gold to the
// Mythic red and back. The phase comes from where a bulb sits on the body
// (angle round the vertical axis and height), so no per-bulb data is needed.
uniform vec3 shell_color : source_color = vec3(1.0, 0.83, 0.42);
uniform vec3 hot_color : source_color = vec3(1.0, 0.23, 0.36);
uniform float chase_speed = 5.0;

varying float phase;

void vertex() {
	phase = atan(VERTEX.x, VERTEX.z) * 1.114 + VERTEX.y * 9.0;
}

void fragment() {
	float wave = 0.5 + 0.5 * sin(phase * 6.2832 - TIME * chase_speed);
	float lit = 0.3 + 0.7 * wave * wave * wave;
	vec3 tint = mix(shell_color, hot_color, 0.5 + 0.5 * sin(TIME * 0.7 + phase * 0.5));
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = tint * 0.4;
	ROUGHNESS = 0.2;
	EMISSION = mix(tint, vec3(1.0, 0.95, 0.82), lit * 0.3 * facing) * (0.45 + 2.1 * lit);
}
