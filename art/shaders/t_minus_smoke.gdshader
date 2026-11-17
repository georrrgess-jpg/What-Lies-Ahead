shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// T-Minus Six rocket smoke (scripts/weapons/t_minus_rocket.gd): a soft,
// puffy ribbon laid along the rocket's corkscrew. COLOR carries the tint,
// the twist shading and the fade; UV.x is the metres the rocket had flown
// when that point was laid (so the puffs stay where they were puffed);
// UV.y runs across the ribbon (0-1).
uniform float puff_scale = 4.5;

void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float puff = 0.5 + 0.5 * sin(UV.x * puff_scale + 1.7 * sin(UV.x * 1.9));
	float edge = smoothstep(0.0, mix(0.5, 0.95, puff), across);
	ALBEDO = COLOR.rgb * mix(0.84, 1.0, across);
	ALPHA = COLOR.a * edge * mix(0.72, 1.0, puff);
}
