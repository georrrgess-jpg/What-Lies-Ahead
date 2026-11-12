shader_type spatial;
// Weapon finish "Comic Pop": cel-shaded colour bands, halftone dots in the
// shade, a hard white highlight and a dark ink rim, like a printed comic.
uniform vec3 shell_color : source_color = vec3(1.0, 0.84, 0.2);
uniform vec3 trim_color : source_color = vec3(0.95, 0.22, 0.32);
uniform bool is_trim = false;
uniform vec3 ink_color : source_color = vec3(0.07, 0.04, 0.12);
uniform float dot_size = 6.0;

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 base = is_trim ? trim_color : shell_color;
	ALBEDO = rim > 0.7 ? ink_color : base;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = ndl > 0.3 ? 1.0 : (ndl > -0.15 ? 0.62 : 0.4);
	// Halftone: screen-space dots that grow in the darker bands.
	vec2 cell = fract(FRAGCOORD.xy / dot_size) - 0.5;
	float radius = (1.0 - band) * 0.62;
	float halftone = step(length(cell), radius);
	float shade = band * (1.0 - halftone * 0.35);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * shade / 3.14159;
	vec3 h = normalize(VIEW + LIGHT);
	float spec = step(0.97, dot(NORMAL, h));
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec * 0.35;
}
