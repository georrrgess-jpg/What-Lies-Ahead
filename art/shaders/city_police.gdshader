shader_type spatial;

// Police light bar half: a double strobe flash; the red and blue halves run
// half a cycle apart (phase), so the bar alternates red-red, blue-blue.
uniform vec3 color : source_color = vec3(1.0, 0.18, 0.25);
uniform float phase = 0.0;
uniform float rate = 1.4;
uniform float strength = 6.0;

void fragment() {
	float t = fract(TIME * rate + phase);
	float on = step(t, 0.09) + step(0.16, t) * step(t, 0.25);
	ALBEDO = color * 0.3;
	ROUGHNESS = 0.25;
	EMISSION = color * (0.25 + on * strength);
}
