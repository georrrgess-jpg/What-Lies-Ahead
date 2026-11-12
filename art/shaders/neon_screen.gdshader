shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

// Animated advert screen. The atlas holds one advert per row and its frames
// along the row; the screen cycles through `frames` of row `row`, with a
// quick glitch wipe between frames, LED scanlines, a slow brightness breath
// and an optional horizontal scroll (for tickers).
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_enable;
uniform int columns = 4;
uniform int rows = 8;
uniform int row = 0;
uniform int frames = 4;
uniform float frame_time = 2.6;
uniform float scroll = 0.0;
uniform float brightness = 2.2;
uniform float time_offset = 0.0;
uniform float scanline_density = 220.0;

float hash(float x) {
	return fract(sin(x * 91.3458) * 47453.5453);
}

void fragment() {
	float t = TIME + time_offset;
	float clock = t / frame_time;
	int frame = int(mod(floor(clock), float(max(frames, 1))));
	float into = fract(clock);
	vec2 uv = UV;
	uv.x = fract(uv.x + t * scroll);
	// Glitch wipe for the first few hundredths of each frame.
	float glitch = smoothstep(0.06, 0.0, into);
	float band = floor(uv.y * 18.0);
	uv.x += (hash(band + floor(t * 30.0)) - 0.5) * 0.12 * glitch;
	vec2 cell = vec2(1.0 / float(columns), 1.0 / float(rows));
	vec2 a_uv = (vec2(float(frame), float(row)) + clamp(uv, vec2(0.002), vec2(0.998))) * cell;
	vec3 col = texture(atlas, a_uv).rgb;
	// RGB split during the glitch.
	if (glitch > 0.01) {
		col.r = texture(atlas, a_uv + vec2(0.006 * glitch, 0.0)).r;
		col.b = texture(atlas, a_uv - vec2(0.006 * glitch, 0.0)).b;
	}
	float lines = 0.82 + 0.18 * sin(UV.y * scanline_density * 3.14159);
	float breath = 0.92 + 0.08 * sin(t * 1.7);
	vec2 v = UV * 2.0 - 1.0;
	float vignette = 1.0 - 0.25 * dot(v * v, vec2(0.5));
	ALBEDO = col * lines * breath * vignette * brightness * (1.0 + glitch * 0.6);
}
