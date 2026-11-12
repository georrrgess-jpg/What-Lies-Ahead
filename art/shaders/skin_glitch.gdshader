shader_type spatial;
// Weapon finish "Glitch": corrupted video. Horizontal slices jump between
// colour channels, blocks flash cyan and magenta, scanlines roll through.
uniform vec3 shell_color : source_color = vec3(0.1, 0.08, 0.16);
uniform vec3 trim_color : source_color = vec3(0.22, 0.2, 0.3);
uniform bool is_trim = false;
uniform vec3 color_a : source_color = vec3(0.1, 1.0, 0.95);
uniform vec3 color_b : source_color = vec3(1.0, 0.15, 0.6);
uniform float rate = 10.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float frame = floor(TIME * rate);
	float slice = floor(lp.y * 46.0);
	float r = hash21(vec2(slice, frame));
	// Some slices shift sideways, so the block pattern tears.
	float shift = r > 0.8 ? (hash21(vec2(frame, slice + 3.0)) - 0.5) * 0.1 : 0.0;
	vec2 block = floor(vec2(lp.z + shift, lp.y) * vec2(22.0, 46.0));
	float b = hash21(block + frame * 0.37);
	vec3 base = is_trim ? trim_color : shell_color;
	vec3 col = base;
	vec3 glow = vec3(0.0);
	if (b > 0.9) {
		col = color_a;
		glow = color_a;
	} else if (b > 0.82) {
		col = color_b;
		glow = color_b;
	}
	// Faint channel bands and rolling scanlines everywhere.
	float bands = step(0.5, fract(lp.y * 46.0 + shift * 30.0));
	col += mix(color_a, color_b, bands) * 0.08;
	float scan = 0.85 + 0.15 * sin(lp.y * 700.0 - TIME * 40.0);
	float roll = smoothstep(0.03, 0.0, abs(fract(lp.y * 4.0 - TIME * 0.7) - 0.5) - 0.47);
	ALBEDO = col * scan;
	ROUGHNESS = 0.3;
	METALLIC = 0.2;
	EMISSION = glow * 1.6 + mix(color_a, color_b, 0.5) * roll * 0.6;
}
