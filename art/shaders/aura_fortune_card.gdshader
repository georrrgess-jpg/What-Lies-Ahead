shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
// A fortune card circling Madame Fortuna (scripts/cosmetics/operator_aura.gd):
// a gold-edged midnight face with a glowing symbol (0 star, 1 moon, 2 sun,
// 3 eye, 4 heart), a crimson back with a gold lattice, and a glint that runs
// across it. Cut out of the quad with a rounded rectangle.
uniform int symbol = 0;
uniform float strength = 1.0;
uniform vec3 face : source_color = vec3(0.12, 0.08, 0.3);
uniform vec3 back : source_color = vec3(0.78, 0.1, 0.27);
uniform vec3 gold : source_color = vec3(1.0, 0.8, 0.32);
uniform vec3 glow : source_color = vec3(0.35, 0.95, 1.0);

float box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float star5(vec2 p, float r) {
	float a = atan(p.x, p.y);
	float k = 6.2832 / 5.0;
	float m = mod(a + k * 0.5, k) - k * 0.5;
	float rr = mix(r * 0.45, r, pow(abs(cos(m * 2.5)), 6.0));
	return length(p) - rr;
}

// The classic heart distance (point up the y axis, about one unit tall).
float heart(vec2 p) {
	p.x = abs(p.x);
	if (p.y + p.x > 1.0) {
		return length(p - vec2(0.25, 0.75)) - 0.35355;
	}
	vec2 a = p - vec2(0.0, 1.0);
	vec2 b = p - 0.5 * max(p.x + p.y, 0.0);
	return sqrt(min(dot(a, a), dot(b, b))) * sign(p.x - p.y);
}

float symbol_sdf(vec2 p) {
	if (symbol == 0) return star5(p, 0.3);
	if (symbol == 1) return max(length(p) - 0.28, -(length(p - vec2(0.12, 0.08)) - 0.24));
	if (symbol == 2) {
		float rays = length(p) - (0.22 + 0.07 * step(0.0, sin(atan(p.y, p.x) * 8.0)));
		return min(length(p) - 0.15, max(rays, -(length(p) - 0.19)));
	}
	if (symbol == 3) {
		float almond = max(length(p - vec2(0.0, -0.3)) - 0.42, length(p - vec2(0.0, 0.3)) - 0.42);
		return min(max(almond, -(length(p) - 0.14)), length(p) - 0.08);
	}
	return heart(p * 2.6 + vec2(0.0, 0.62)) / 2.6;
}

void fragment() {
	vec2 p = vec2(UV.x - 0.5, 0.5 - UV.y) * vec2(1.0, 1.6) * 2.0;
	float d = box(p, vec2(0.92, 1.52), 0.18);
	if (d > 0.0) {
		discard;
	}
	float edge = smoothstep(-0.1, -0.06, d);
	float inner = smoothstep(-0.16, -0.14, d) * (1.0 - smoothstep(-0.13, -0.11, d));
	vec3 col;
	if (FRONT_FACING) {
		float s = symbol_sdf(p * vec2(1.0, 0.85));
		float halo = exp(-max(s, 0.0) * 9.0) * 0.6;
		col = face + glow * halo * 0.5;
		col = mix(col, mix(glow, vec3(1.0), 0.35), smoothstep(0.02, -0.01, s));
		float dots = step(0.94, fract(sin(dot(floor(p * 9.0), vec2(12.9898, 78.233))) * 43758.5453)) * (0.5 + 0.5 * sin(TIME * 3.0 + p.x * 9.0));
		col += gold * dots * 0.4;
	} else {
		vec2 g = abs(fract(vec2(p.x + p.y, p.x - p.y) * 2.2) - 0.5);
		col = mix(back, gold, smoothstep(0.06, 0.0, min(g.x, g.y)) * 0.8);
	}
	col = mix(col, gold, max(edge, inner));
	float glint = smoothstep(0.12, 0.0, abs(fract(p.x * 0.25 + p.y * 0.12 - TIME * 0.35) - 0.5));
	ALBEDO = (col + vec3(1.0, 0.95, 0.85) * glint * 0.35) * strength;
}
