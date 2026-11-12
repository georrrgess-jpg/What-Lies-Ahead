shader_type canvas_item;
// UI preview tile for a weapon finish (Career page, results, toasts). A
// rounded tile split diagonally into shell and trim colour with a lit bevel.
// style: 0 paint, 1 polished metal, 2 brushed gold, 3 diamond, 4 prismatic.
uniform vec4 shell_color : source_color = vec4(1.0);
uniform vec4 trim_color : source_color = vec4(0.3, 0.3, 0.35, 1.0);
uniform int style = 0;
uniform float hue_offset = 0.0;
uniform float hue_range = 1.0;
uniform bool locked = false;
uniform vec2 rect_size = vec2(64.0, 64.0);
uniform float corner = 12.0;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Nearest / second-nearest distance of a 2D Voronoi field, and the cell id.
vec2 voronoi(vec2 p, out vec2 id) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 d = vec2(8.0);
	id = i;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash2(i + g), hash2(i + g + 31.7));
			vec2 r = g + o - f;
			float dd = dot(r, r);
			if (dd < d.x) {
				d.y = d.x;
				d.x = dd;
				id = i + g;
			} else if (dd < d.y) {
				d.y = dd;
			}
		}
	}
	return sqrt(d);
}

void fragment() {
	vec2 px = UV * rect_size;
	float sd = rounded_box(px - rect_size * 0.5, rect_size * 0.5, corner);
	float alpha = clamp(0.5 - sd, 0.0, 1.0);
	// Bevel: light from the top-left on a soft rim.
	float rim = clamp(1.0 + sd / 7.0, 0.0, 1.0);
	vec2 to_edge = normalize(px - rect_size * 0.5 + 0.001);
	float lit = dot(-to_edge, normalize(vec2(1.0, 1.4))) * rim;

	bool trim = UV.x * 0.8 + UV.y > 1.25;
	vec3 base = trim ? trim_color.rgb : shell_color.rgb;
	vec3 col = base;
	float t = TIME;
	if (style == 1 || style == 2) {
		float band = smoothstep(0.25, 0.75, 1.0 - UV.y + 0.15 * sin(UV.x * 3.0));
		col = mix(base * 0.55, mix(base, vec3(1.0), 0.35), band);
		if (style == 2) {
			float grain = vnoise(vec2(UV.x * 6.0, UV.y * 140.0)) * 0.6 + vnoise(vec2(UV.x * 2.0, UV.y * 320.0)) * 0.4;
			col *= mix(0.78, 1.08, grain);
			float g = UV.x + UV.y * 0.5 - mix(-0.6, 2.2, fract(t * 0.25));
			col += vec3(1.0, 0.95, 0.75) * exp(-g * g * 60.0) * 0.9;
		}
	} else if (style == 3) {
		vec2 id;
		vec2 d = voronoi(UV * rect_size / 14.0, id);
		float shade = hash2(id);
		float edge = 1.0 - smoothstep(0.0, 0.08, d.y - d.x);
		col = base * (0.6 + 0.5 * shade);
		vec3 fire = 0.5 + 0.5 * cos(6.2831 * (shade + t * 0.1 + vec3(0.0, 0.33, 0.67)));
		col += fire * edge * 0.45;
		col += vec3(1.0) * pow(0.5 + 0.5 * sin(t * 3.0 + shade * 40.0), 18.0) * 0.9;
	} else if (style == 4) {
		float n = vnoise(UV * 3.0 + vec2(0.0, t * 0.3));
		float h = UV.x * 0.8 + UV.y * 0.5 + n * 0.5 - t * 0.2;
		float wave = hue_range >= 0.999 ? fract(h) : abs(fract(h * 0.5) * 2.0 - 1.0);
		vec3 rainbow = mix(hue(hue_offset + wave * hue_range), vec3(1.0), 0.12);
		col = trim ? mix(trim_color.rgb, rainbow, 0.55) : rainbow;
		float star = step(0.985, hash2(floor(px / 3.0))) * pow(0.5 + 0.5 * sin(t * 4.0 + hash2(floor(px / 3.0)) * 50.0), 6.0);
		col += vec3(star);
	}
	col *= 0.86 + 0.3 * lit;
	if (locked) {
		float grey = dot(col, vec3(0.3, 0.59, 0.11));
		col = mix(vec3(grey), vec3(0.16, 0.13, 0.3), 0.55);
	}
	COLOR = vec4(col, alpha);
}
