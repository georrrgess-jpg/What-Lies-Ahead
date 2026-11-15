shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

// A Markdown Marker price tag (a QuadMesh, UV 0-1): a tag shape with a
// pointed left end and a punched hole, a cream border, a bright fill and a
// big "%" printed on it, readable at a distance. `ready` (0-1) makes the tag
// pulse white-hot (the zombie carries a full stack and the next hit pops it);
// `fade` (0-1) fades a tag that is about to peel off.
uniform vec3 fill_color : source_color = vec3(1.0, 0.31, 0.64);
uniform vec3 border_color : source_color = vec3(1.0, 0.96, 0.88);
uniform vec3 ink_color : source_color = vec3(0.17, 0.14, 0.25);
uniform float ready : hint_range(0.0, 1.0) = 0.0;
uniform float glow = 1.35;

float sd_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// Signed distance to the tag outline in a -1..1 (x) by -0.6..0.6 (y) frame.
float sd_tag(vec2 p) {
	float body = sd_box(p - vec2(0.12, 0.0), vec2(0.86, 0.56)) - 0.04;
	// The pointed end: cut the left corners with two slanted planes.
	float cut = (-(p.x + 0.98) + abs(p.y) * 0.75) * 0.8;
	return max(body, cut - 0.0);
}

float sd_percent(vec2 p) {
	float slash = abs(dot(p, normalize(vec2(0.9, -0.45)))) - 0.05;
	slash = max(slash, abs(p.y) - 0.38);
	float a = length(p - vec2(-0.16, 0.2)) - 0.11;
	float b = length(p - vec2(0.16, -0.2)) - 0.11;
	a = abs(a) - 0.035;
	b = abs(b) - 0.035;
	return min(slash, min(a, b));
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(2.0, -1.2);
	float d = sd_tag(p);
	float hole = length(p - vec2(-0.62, 0.0)) - 0.1;
	if (d > 0.0 || hole < 0.0) {
		discard;
	}
	float border = smoothstep(-0.14, -0.12, d) + smoothstep(0.06, 0.04, hole);
	float ink = smoothstep(0.012, -0.012, sd_percent(p - vec2(0.24, 0.0)));
	float pulse = ready * (0.5 + 0.5 * sin(TIME * 16.0));
	vec3 fill = mix(fill_color, vec3(1.0), pulse * 0.45);
	vec3 col = mix(fill, border_color, clamp(border, 0.0, 1.0));
	col = mix(col, ink_color, ink * (1.0 - clamp(border, 0.0, 1.0)));
	ALBEDO = col * (glow + pulse * 0.9);
}
