// Shared by the Prize Prints Series 2 "Midnight Marquee" finishes
// (art/shaders/finish_s2_*.gdshader, data/cosmetics/finishes/fin_s2_*.tres).
// Include it after finish_common.gdshaderinc. Every Series 2 finish has
// params.pulse, so FinishPulse drives these two uniforms:
//   motion  1 animates; 0 holds a still frame (Settings "Reduce motion")
//   pulse   1 on a kill with the weapon, easing back to 0 over 1.4 s
// The animated finishes read time through s2_time(), which holds the
// finish's chosen still frame `rest` when motion is 0.
uniform float motion = 1.0;
uniform float pulse = 0.0;
uniform float pulse_seed = 0.0;

float s2_time(float t, float rest) {
	return mix(rest, t, motion);
}

mat2 s2_rot(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

// Anti-aliased band: 1 inside |d| < w, softened by the pixel footprint
// (capped, so the jump where a fract() wraps leaves no seam line).
float s2_band(float d, float w) {
	float aa = clamp(fwidth(d), 1e-5, 0.15);
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

// Anti-aliased grid lines: 1 within w (in units of x) of every whole x.
float s2_lines(float x, float w) {
	float d = abs(fract(x + 0.5) - 0.5);
	float aa = clamp(fwidth(x), 1e-5, 0.5);
	return 1.0 - smoothstep(w - aa, w + aa, d);
}

// Nearest and second-nearest feature distances of a jittered grid (Voronoi),
// and the nearest cell's id in .zw.
vec4 s2_voronoi(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 c = o + fh22(i + o) * 0.8 + 0.1;
			float d = length(c - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = i + o;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec4(d1, d2, id);
}

// A glossy lacquer coat over a painted ground (emission to add).
vec3 s2_coat(vec3 n, vec3 view, float k) {
	vec3 r = reflect(-view, n);
	return fstudio(r, vec3(1.0)) * (0.03 + ffres(n, view, 3.0) * 0.5) * k;
}
