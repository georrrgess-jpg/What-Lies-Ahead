shader_type spatial;
// Weapon finish "Sonar Ping": a dark teal plotting screen with a fine grid.
// Pings ring out from points along the weapon; each ring lights up the
// contacts it passes, which then fade like phosphor. The trim is the same
// screen behind a darker bezel.
#include "res://art/shaders/finish_common.gdshaderinc"

uniform vec3 shell_color : source_color = vec3(0.01, 0.07, 0.07);
uniform vec3 trim_color : source_color = vec3(0.03, 0.05, 0.05);
uniform bool is_trim = false;
uniform vec3 ping_color : source_color = vec3(0.25, 1.0, 0.7);
uniform float period = 2.4;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

// One ping series with phase `o`: (ring, contact glow) at this point.
vec2 ping(float o) {
	float t = TIME / period + o;
	float n = floor(t);
	float age = fract(t);
	vec3 origin = (fh33(vec3(n, o * 7.0, 3.0)) - 0.5) * vec3(0.1, 0.2, 0.8);
	float radius = age * 0.55;
	float d = length(lp - origin);
	float ring = exp(-pow((d - radius) * 90.0, 2.0)) * (1.0 - age);
	float wake = smoothstep(radius, radius - 0.15, d) * step(d, radius) * 0.15 * (1.0 - age);
	// Contacts: sparse points that glow once the ring has passed them.
	vec3 q = lp * 22.0;
	vec3 c = floor(q);
	float h = fh31(c + n * 0.37);
	float dc = length(fract(q) - (fh33(c) * 0.6 + 0.2));
	float blip = step(0.93, h) * smoothstep(0.22, 0.05, dc) * step(d, radius) * exp(-(radius - d) * 8.0);
	return vec2(ring + wake, blip);
}

void fragment() {
	vec3 r = reflect(-VIEW, NORMAL);
	vec2 uv = fplane(lp, ln);
	vec2 p = ping(0.0) + ping(0.5);
	vec2 g = abs(fract(uv / 0.025) - 0.5);
	float grid = smoothstep(0.45, 0.5, max(g.x, g.y));
	vec2 g2 = abs(fract(uv / 0.1) - 0.5);
	float major = smoothstep(0.47, 0.5, max(g2.x, g2.y));
	// Trim: the bezel, same screen a little dimmer.
	float k = is_trim ? 0.6 : 1.0;
	ALBEDO = is_trim ? trim_color : shell_color;
	METALLIC = is_trim ? 0.4 : 0.1;
	ROUGHNESS = 0.15;
	EMISSION = ping_color * (grid * 0.08 + major * 0.18 + p.x * 1.8 + p.y * 3.0) * k
		+ fstudio(r, vec3(0.2, 0.35, 0.35)) * 0.12;
}
