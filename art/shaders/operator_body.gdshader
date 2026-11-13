shader_type spatial;
// Operator bodies (scripts/cosmetics/operators.gd). The flat colours and a
// baked ambient occlusion live in the vertex colours; UV.x is roughness and
// UV.y metallic (art/blender/operator_kit.py). A soft rim gives the moulded
// vinyl-toy sheen, and metals get a fake sky reflection so they stay bright
// in menus that have no environment to reflect.
uniform float sheen : hint_range(0.0, 1.0) = 0.45;
uniform float metal_glow : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = UV.x;
	METALLIC = UV.y * 0.55;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	RIM = sheen * (1.0 - UV.y);
	RIM_TINT = 0.6;
	float sky = smoothstep(-0.2, 0.9, NORMAL.y) * (0.35 + 0.65 * pow(1.0 - facing, 2.0));
	EMISSION = COLOR.rgb * UV.y * metal_glow * sky;
}
