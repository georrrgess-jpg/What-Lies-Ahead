shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
// Soap bubble for the "Bubble Pop" kill effect: an almost clear centre with
// a bright iridescent rim and a small window highlight. Tinted by the
// particle's instance colour.

void fragment() {
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 film = 0.5 + 0.5 * cos(6.28318 * (fres * 1.3 + TIME * 0.2 + vec3(0.0, 0.33, 0.67)));
	float rim = pow(fres, 2.5);
	float spot = smoothstep(0.86, 0.95, dot(NORMAL, normalize(vec3(-0.4, 0.5, 0.75))));
	ALBEDO = (COLOR.rgb * 0.5 + film * 0.6) * (0.05 + rim * 1.4) + vec3(spot) * 0.9;
}
