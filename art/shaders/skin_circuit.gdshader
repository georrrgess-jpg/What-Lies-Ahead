shader_type spatial;
// Weapon finish "Circuit Pulse": a circuit board with copper traces, solder
// pads and bright pulses racing along the tracks.
uniform vec3 shell_color : source_color = vec3(0.04, 0.22, 0.14);
uniform vec3 trim_color : source_color = vec3(0.05, 0.08, 0.1);
uniform bool is_trim = false;
uniform vec3 trace_color : source_color = vec3(0.95, 0.72, 0.3);
uniform vec3 pulse_color : source_color = vec3(0.3, 1.0, 0.85);
uniform float cell = 0.022;
uniform float speed = 1.6;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// One projection of the board: returns (trace mask, pad mask, pulse).
vec3 board(vec2 uv) {
	vec2 g = uv / cell;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h1 = hash21(id);
	float h2 = hash21(id + 17.3);
	float h3 = hash21(id + 41.9);
	float w = 0.09;
	float horiz = step(0.45, h1) * smoothstep(w, w * 0.5, abs(f.y));
	float vert = step(0.62, h2) * smoothstep(w, w * 0.5, abs(f.x));
	float pad = step(0.8, h3) * smoothstep(0.24, 0.18, length(f));
	float ring = step(0.8, h3) * smoothstep(0.05, 0.0, abs(length(f) - 0.2));
	float traces = max(max(horiz, vert), ring);
	float along = horiz > vert ? g.x : g.y;
	float pulse = pow(0.5 + 0.5 * sin(along * 0.9 - TIME * speed * 3.0 + h1 * 6.28), 12.0);
	return vec3(traces, pad, pulse * traces);
}

void fragment() {
	vec3 a = abs(ln);
	vec2 uv = a.x > a.y && a.x > a.z ? lp.yz : (a.y > a.z ? lp.xz : lp.xy);
	vec3 b = board(uv);
	vec3 base = is_trim ? trim_color : shell_color;
	vec3 col = mix(base, trace_color, max(b.x, b.y) * (is_trim ? 0.5 : 1.0));
	ALBEDO = col;
	METALLIC = max(b.x, b.y) * 0.7;
	ROUGHNESS = mix(0.55, 0.25, b.x);
	EMISSION = pulse_color * (b.z * 3.0 + b.y * 0.35 * (0.6 + 0.4 * sin(TIME * 3.0)));
}
