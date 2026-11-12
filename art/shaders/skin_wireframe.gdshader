shader_type spatial;
// Weapon finish "Neon Wireframe": a dark body under a glowing grid, as if the
// weapon were still a blueprint, with a scan pulse sweeping along the barrel.
uniform vec3 shell_color : source_color = vec3(0.03, 0.02, 0.08);
uniform vec3 trim_color : source_color = vec3(0.05, 0.03, 0.12);
uniform bool is_trim = false;
uniform vec3 line_color : source_color = vec3(0.2, 0.95, 1.0);
uniform vec3 pulse_color : source_color = vec3(1.0, 0.3, 0.8);
uniform float cell = 0.03;
uniform float width = 0.06;
uniform float speed = 0.6;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

float grid(vec2 uv) {
	vec2 g = uv / cell;
	vec2 fw = fwidth(g) * 0.75;
	vec2 d = abs(fract(g + 0.5) - 0.5);
	vec2 l = 1.0 - smoothstep(vec2(width) - fw, vec2(width) + fw, d);
	return max(l.x, l.y);
}

void fragment() {
	vec3 a = abs(ln);
	vec2 uv = a.x > a.y && a.x > a.z ? lp.yz : (a.y > a.z ? lp.xz : lp.xy);
	float lines = grid(uv);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	// A bright band travels from the back of the weapon to the muzzle (-Z).
	float scan = smoothstep(0.08, 0.0, abs(fract(-lp.z * 1.4 - TIME * speed) - 0.5) - 0.38);
	vec3 base = is_trim ? trim_color : shell_color;
	vec3 lc = mix(line_color, pulse_color, scan);
	ALBEDO = base + lc * lines * 0.3;
	ROUGHNESS = 0.4;
	METALLIC = 0.2;
	EMISSION = lc * (lines * (is_trim ? 2.4 : 1.8) + fres * 0.35) * (0.8 + 0.6 * scan);
}
