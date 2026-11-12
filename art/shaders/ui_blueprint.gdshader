shader_type spatial;
render_mode unshaded;
// The blueprint monitor of the Arsenal booth: draws the selected weapon's
// thumbnail (`thumb`, transparent background) as cyan line art on a dark
// grid, with a few "annotation" bars under it. The screen mesh has no UVs,
// so they come from the vertex position (`screen_size` in metres).
uniform sampler2D thumb : source_color, filter_linear, repeat_disable;
uniform vec2 screen_size = vec2(0.52, 0.36);
uniform vec3 line_color : source_color = vec3(0.35, 0.95, 1.0);
uniform vec3 back_color : source_color = vec3(0.02, 0.11, 0.15);
// Width / height of the thumbnail.
uniform float thumb_aspect = 2.42;

varying vec2 uv;

void vertex() {
	uv = vec2(VERTEX.x / screen_size.x + 0.5, 0.5 - VERTEX.y / screen_size.y);
}

float coverage(vec2 at) {
	if (at.x < 0.0 || at.x > 1.0 || at.y < 0.0 || at.y > 1.0) {
		return 0.0;
	}
	return texture(thumb, at).a;
}

float shade(vec2 at) {
	if (at.x < 0.0 || at.x > 1.0 || at.y < 0.0 || at.y > 1.0) {
		return 0.0;
	}
	vec4 c = texture(thumb, at);
	return dot(c.rgb, vec3(0.3, 0.6, 0.1)) * c.a;
}

float bar(vec2 p, vec2 from, float length, float thickness) {
	return step(from.x, p.x) * step(p.x, from.x + length) * step(from.y, p.y) * step(p.y, from.y + thickness);
}

void fragment() {
	// The weapon fills the upper part of the screen.
	float screen_aspect = screen_size.x / screen_size.y;
	vec2 t = vec2((uv.x - 0.5) / 0.86 + 0.5, (uv.y - 0.4) / (0.86 * screen_aspect / thumb_aspect) + 0.5);
	vec2 d = vec2(0.006, 0.006 * thumb_aspect);
	float outline = abs(coverage(t + vec2(d.x, 0.0)) - coverage(t - vec2(d.x, 0.0))) + abs(coverage(t + vec2(0.0, d.y)) - coverage(t - vec2(0.0, d.y)));
	float detail = abs(shade(t + vec2(d.x, 0.0)) - shade(t - vec2(d.x, 0.0))) + abs(shade(t + vec2(0.0, d.y)) - shade(t - vec2(0.0, d.y)));
	float ink = clamp(outline * 1.6 + detail * 2.2, 0.0, 1.0) + coverage(t) * 0.12;
	vec2 cell = abs(fract(uv * vec2(10.0, 7.0)) - 0.5);
	float grid = smoothstep(0.47, 0.5, max(cell.x, cell.y)) * 0.12;
	float notes = bar(uv, vec2(0.1, 0.76), 0.34, 0.025) + bar(uv, vec2(0.1, 0.83), 0.22, 0.025) + bar(uv, vec2(0.1, 0.12), 0.12, 0.02);
	float scan = 0.92 + 0.08 * sin(uv.y * 240.0);
	ALBEDO = (back_color + line_color * (ink + grid + notes * 0.7)) * scan;
}
