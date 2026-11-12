shader_type canvas_item;
// Player banner art for the progression UI (level and challenge rewards).
// CosmeticItem contract for slot "banner": colors = [base, pattern, accent],
// params.pattern = stripes | swirl | bulbs | waves | checker | sunburst | stars | chevrons.
uniform vec4 base_color : source_color = vec4(0.2, 0.1, 0.4, 1.0);
uniform vec4 pattern_color : source_color = vec4(1.0, 0.25, 0.64, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.95, 0.86, 1.0);
uniform int pattern = 0;
uniform vec2 rect_size = vec2(320.0, 96.0);
uniform float corner = 14.0;
uniform bool locked = false;
// Multiplies the pattern contrast (lower when text sits on top).
uniform float strength = 1.0;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float aa_step(float edge, float x) {
	float w = fwidth(x) * 0.75;
	return smoothstep(edge - w, edge + w, x);
}

void fragment() {
	vec2 px = UV * rect_size;
	float t = TIME;
	vec3 base = base_color.rgb;
	vec3 pat = pattern_color.rgb;
	vec3 acc = accent_color.rgb;
	vec3 col = base;
	if (pattern == 0) {
		float s = fract((px.x + px.y) / 34.0 - t * 0.08);
		col = mix(base, pat, aa_step(0.5, s) * 0.85);
		col = mix(col, acc, (1.0 - aa_step(2.5, abs(px.y - rect_size.y + 7.0))) * 0.9);
	} else if (pattern == 1) {
		vec2 p = px - vec2(rect_size.x * 0.18, rect_size.y * 0.5);
		float a = atan(p.y, p.x);
		float r = length(p) + 1.0;
		float s = sin(a * 4.0 + log(r) * 5.0 - t * 0.8);
		col = mix(base, pat, aa_step(0.0, s) * 0.8);
		col = mix(col, acc, (1.0 - smoothstep(10.0, 26.0, r)) * 0.8);
	} else if (pattern == 2) {
		col = mix(base * 0.7, base * 1.15, UV.y);
		float spacing = 26.0;
		for (int row = 0; row < 2; row++) {
			float y = row == 0 ? 11.0 : rect_size.y - 11.0;
			float i = floor(px.x / spacing);
			vec2 cpos = vec2((i + 0.5) * spacing, y);
			float d = length(px - cpos);
			float on = 0.55 + 0.45 * step(0.5, fract((i + float(row)) * 0.5 + floor(t * 2.0) * 0.5));
			col += pat * (1.0 - smoothstep(4.0, 5.5, d)) * on;
			col += pat * exp(-d * d / 60.0) * 0.5 * on;
		}
		float glow = exp(-pow((UV.y - 0.5) * 3.0, 2.0));
		col = mix(col, acc, glow * 0.12);
	} else if (pattern == 3) {
		float w1 = rect_size.y * 0.55 + sin(px.x / 38.0 + t * 0.9) * 7.0;
		float w2 = rect_size.y * 0.78 + sin(px.x / 26.0 - t * 1.2 + 1.7) * 5.0;
		col = mix(base * 1.2, base, UV.y);
		col = mix(col, pat, aa_step(w1, px.y) * 0.75);
		col = mix(col, acc, aa_step(w2, px.y) * 0.6);
	} else if (pattern == 4) {
		vec2 cell = floor((px + vec2(t * 6.0, 0.0)) / 22.0);
		float c = mod(cell.x + cell.y, 2.0);
		col = mix(base, pat, c * 0.7);
		col = mix(col, acc, (1.0 - aa_step(2.0, abs(px.y - 5.0))) * 0.9);
		col = mix(col, acc, (1.0 - aa_step(2.0, abs(px.y - rect_size.y + 5.0))) * 0.9);
	} else if (pattern == 5) {
		vec2 p = px - vec2(rect_size.x * 0.5, rect_size.y * 1.35);
		float a = atan(p.y, p.x) + t * 0.06;
		float rays = sin(a * 26.0);
		col = mix(base, pat, aa_step(0.0, rays) * 0.55);
		float sun = length(p) / rect_size.y;
		col = mix(col, acc, (1.0 - smoothstep(0.55, 0.95, sun)) * 0.75);
	} else if (pattern == 6) {
		col = mix(base * 1.35, base, UV.y);
		vec2 cell = floor(px / 18.0);
		float h = hash2(cell);
		vec2 c = (cell + 0.3 + 0.4 * vec2(hash2(cell + 3.1), hash2(cell + 7.7))) * 18.0;
		float d = length(px - c);
		float tw = 0.5 + 0.5 * sin(t * 2.5 + h * 30.0);
		col += mix(acc, pat, step(0.5, h)) * (1.0 - smoothstep(0.6, 2.2, d)) * step(0.55, h) * (0.5 + 0.5 * tw);
		col += pat * 0.18 * (1.0 - smoothstep(0.0, 1.0, UV.y));
	} else if (pattern == 7) {
		float x = px.x - abs(px.y - rect_size.y * 0.5) * 0.9 - t * 18.0;
		float s = fract(x / 30.0);
		col = mix(base, pat, aa_step(0.55, s) * 0.8);
		col = mix(col, acc, (1.0 - aa_step(0.06, abs(s - 0.5))) * 0.35);
	}
	col = mix(base, col, strength);
	// Soft top light and edge shade.
	col *= 0.85 + 0.3 * (1.0 - UV.y);
	float sd = rounded_box(px - rect_size * 0.5, rect_size * 0.5, corner);
	float rim = 1.0 - smoothstep(-4.0, 0.0, sd);
	col = mix(col * 0.75, col, rim);
	if (locked) {
		float grey = dot(col, vec3(0.3, 0.59, 0.11));
		col = mix(vec3(grey), vec3(0.16, 0.13, 0.3), 0.6);
	}
	COLOR = vec4(col, clamp(0.5 - sd, 0.0, 1.0));
}
