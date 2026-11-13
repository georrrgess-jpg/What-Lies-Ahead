shader_type spatial;
// One surface for a whole zombie mesh (outfit, face or accessory): the flat
// colours and finishes that used to be separate materials are baked into the
// vertices by art/blender/build_zombie.py (skin):
//
//   COLOR.rgb  base colour (stored sRGB; the renderer hands it over linear)
//   COLOR.a    baked ambient occlusion
//   UV         (roughness, metallic)
//   UV2        (emission strength / 8, tint slot / 4)
//
// Tint slots let scripts/enemies/zombie.gd recolour one zombie without extra
// surfaces: 1 = skin, 2 = dark skin, 3 = shirt. A tint with alpha 0 keeps the
// authored colour.

uniform vec4 skin_tint : source_color = vec4(0.0);
uniform vec4 skin_dark_tint : source_color = vec4(0.0);
uniform vec4 shirt_tint : source_color = vec4(0.0);

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
	ALBEDO = v_albedo;
	ROUGHNESS = UV.x;
	METALLIC = UV.y;
	EMISSION = v_emission;
}
