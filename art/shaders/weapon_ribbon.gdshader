shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Camera-facing energy ribbons (beams, lightning, rail trails) built by
// scripts/weapons/weapon_fx.gd. COLOR carries the tint and fade; UV.x runs
// along the ribbon in metres, UV.y across it (0-1). A soft core plus
// scrolling energy bands make a beam read as flowing.
uniform float scroll_speed = 0.0;
uniform float band_scale = 0.0;
uniform float core_power = 2.0;

void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float core = pow(across, core_power);
	float hot = pow(across, 10.0);
	float bands = 1.0;
	if (band_scale > 0.0) {
		bands = 0.7 + 0.3 * sin(UV.x * band_scale - TIME * scroll_speed);
	}
	vec3 col = COLOR.rgb * core * bands + vec3(hot) * 0.9 * COLOR.a;
	ALBEDO = col * COLOR.a;
}
