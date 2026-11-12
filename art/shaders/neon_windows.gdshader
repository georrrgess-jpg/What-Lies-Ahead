shader_type spatial;
render_mode cull_back;

// Procedural lit windows for city towers and facades (no textures). Windows
// are laid out on every vertical face in world space, so boxes of any size
// tile cleanly. Each window rolls lit or dark and a colour (mostly warm,
// some cyan and magenta); a few flicker. Far away the grid fades to its
// average so it never shimmers.
uniform vec3 wall_color : source_color = vec3(0.07, 0.07, 0.14);
uniform vec3 roof_color : source_color = vec3(0.06, 0.06, 0.1);
uniform vec3 warm : source_color = vec3(1.0, 0.72, 0.4);
uniform vec3 cool : source_color = vec3(0.35, 0.85, 1.0);
uniform vec3 hot : source_color = vec3(1.0, 0.35, 0.8);
uniform vec2 cell = vec2(1.8, 3.2);
uniform vec2 window = vec2(0.62, 0.55);
uniform float lit_ratio : hint_range(0.0, 1.0) = 0.45;
uniform float glow = 1.6;
uniform float seed = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 n = world_normal;
	if (n.y > 0.7 || n.y < -0.7) {
		ALBEDO = roof_color;
		ROUGHNESS = 0.8;
	} else {
		// Horizontal coordinate along the face, vertical = height.
		float u = abs(n.x) > abs(n.z) ? world_pos.z * sign(n.x) : -world_pos.x * sign(n.z);
		vec2 g = vec2(u, world_pos.y) / cell;
		vec2 id = floor(g);
		vec2 f = fract(g);
		// Face id keeps opposite faces from mirroring each other.
		float face = floor(dot(n, vec3(1.0, 0.0, 10.0)) + 20.0);
		float h = hash12(id + vec2(seed * 17.0 + face * 31.0, seed * 5.0));
		float h2 = hash12(id * 1.7 + vec2(seed, face));
		// Floors light up in runs, like real offices.
		float row = hash12(vec2(id.y + seed * 3.0, face));
		float lit = step(1.0 - lit_ratio * (0.6 + 0.8 * row), h);
		vec3 tone = h2 < 0.72 ? warm : (h2 < 0.86 ? cool : hot);
		tone *= 0.55 + 0.45 * hash12(id + 9.0);
		float flick = h2 > 0.97 ? step(0.4, fract(sin(TIME * 3.0 + h * 40.0) * 3.0)) : 1.0;
		vec2 margin = (vec2(1.0) - window) * 0.5;
		vec2 inside = step(margin, f) * step(f, vec2(1.0) - margin);
		float win = inside.x * inside.y;
		// Blend to the average when the grid gets smaller than a pixel.
		vec2 fw = fwidth(g);
		float far = smoothstep(0.25, 0.6, max(fw.x, fw.y));
		vec3 lit_col = tone * lit * flick;
		vec3 avg = mix(warm, cool, 0.2) * lit_ratio * 0.45 * window.x * window.y;
		vec3 em = mix(lit_col * win, avg, far);
		vec3 dark_glass = vec3(0.03, 0.04, 0.09);
		ALBEDO = mix(wall_color, dark_glass, win * (1.0 - far));
		EMISSION = em * glow;
		ROUGHNESS = mix(0.85, 0.2, win);
		SPECULAR = 0.4;
	}
}
