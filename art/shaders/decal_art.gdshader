// Printed holographic sticker (decal items with params.art and params.foil):
// the picture with a rainbow foil sheen that slides across it as the view
// angle changes and drifts slowly on its own.
shader_type spatial;
render_mode cull_back;

uniform sampler2D art : source_color, filter_linear_mipmap;
uniform float sheen = 0.55;

vec3 foil_hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	vec3 base = texture(art, UV).rgb;
	float facing = dot(NORMAL, VIEW);
	float band = UV.x * 1.3 + UV.y * 0.7 + facing * 2.5 + TIME * 0.15;
	vec3 rainbow = foil_hue(fract(band));
	// Bright parts of the picture catch the foil the most.
	float lum = dot(base, vec3(0.3, 0.55, 0.15));
	float k = sheen * smoothstep(0.25, 0.9, lum) * (0.6 + 0.4 * sin(band * 12.566));
	ALBEDO = mix(base, base * 0.5 + rainbow * 0.7, k);
	METALLIC = 0.35 * k;
	ROUGHNESS = 0.3;
	EMISSION = (base * 0.18 + rainbow * k * 0.35);
}
