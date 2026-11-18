shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back;

// The Bedsheet Ghost while it fades (scripts/enemies/behaviours/fright_ghost_fade.gd):
// the zombie body material (art/shaders/zombie_body.gdshader: colours, AO,
// finish and tints baked in the vertices) made see-through to `alpha`, with a
// cold rim glow. Emissive parts (the eyes) stay solid, so a faded ghost still
// reads by its glowing eyes.

uniform vec4 skin_tint : source_color = vec4(0.0);
uniform vec4 skin_dark_tint : source_color = vec4(0.0);
uniform vec4 shirt_tint : source_color = vec4(0.0);
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform vec3 rim_color : source_color = vec3(0.7, 0.9, 1.0);

varying vec3 v_albedo;
varying vec3 v_emission;

void vertex() {
	vec3 base = COLOR.rgb;
	float slot = floor(UV2.y * 4.0 + 0.5);
	if (slot == 1.0) {
		base = mix(base, skin_tint.rgb, skin_tint.a);
	} else if (slot == 2.0) {
		base = mix(base, skin_dark_tint.rgb, skin_dark_tint.a);
	} else if (slot == 3.0) {
		base = mix(base, shirt_tint.rgb, shirt_tint.a);
	}
	v_albedo = base * COLOR.a;
	v_emission = base * UV2.x * 8.0;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float fade = 1.0 - alpha;
	ALBEDO = v_albedo;
	ROUGHNESS = UV.x;
	METALLIC = UV.y;
	EMISSION = v_emission + rim_color * rim * fade * 0.9;
	ALPHA = max(clamp(alpha + rim * fade * 0.5, 0.0, 1.0), clamp(length(v_emission), 0.0, 1.0));
}
