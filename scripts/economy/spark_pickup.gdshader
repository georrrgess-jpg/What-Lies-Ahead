shader_type spatial;
// An Arcade Token in flight: a camera-facing gold coin that spins about its
// vertical axis (the face narrows to its edge and back), with a notched rim, a
// stamped star and a faint warm halo. Drawn through a MultiMesh (SparkField);
// INSTANCE_CUSTOM = (size in metres, spin in radians, fade 0-1, unused).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.847, 0.29, 1.0);
uniform vec4 rim_color : source_color = vec4(0.95, 0.62, 0.16, 1.0);
uniform vec4 edge_color : source_color = vec4(0.42, 0.2, 0.03, 1.0);

varying float v_spin;
varying float v_fade;

void vertex() {
	v_spin = INSTANCE_CUSTOM.y;
	v_fade = INSTANCE_CUSTOM.z;
	vec4 centre = VIEW_MATRIX * (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0));
	centre.xy += VERTEX.xy * INSTANCE_CUSTOM.x;
	POSITION = PROJECTION_MATRIX * centre;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float turn = cos(v_spin);
	// The coin's width as it spins; never thinner than its milled edge.
	float width = max(abs(turn), 0.16);
	vec2 f = vec2(p.x / width, p.y) / 0.78;
	float d = length(f);
	float coin = smoothstep(1.0, 0.92, d);
	float face = smoothstep(0.76, 0.7, d);
	float groove = smoothstep(0.84, 0.78, d) - face;
	// A five-point star stamped on the face: the outline's radius by angle.
	float a = atan(f.x, -f.y);
	float seg = 6.2831853 / 5.0;
	float k = abs(mod(a + seg * 0.5, seg) - seg * 0.5) / (seg * 0.5);
	float star_r = mix(0.52, 0.22, k);
	float star = smoothstep(star_r + 0.05, star_r - 0.02, d) * step(0.35, abs(turn));
	float notch = step(0.5, fract(a / 6.2831853 * 16.0)) * (1.0 - smoothstep(0.84, 0.92, d)) * (1.0 - face);
	vec3 col = mix(rim_color.rgb, edge_color.rgb, groove * 0.8 + notch * 0.35);
	col = mix(col, core_color.rgb * (0.85 - 0.25 * f.y), face);
	col = mix(col, vec3(1.0, 0.76, 0.22), star);
	// Edge-on, the coin is mostly milled brass; a glint sweeps as it turns.
	col = mix(edge_color.rgb * 1.6, col, smoothstep(0.16, 0.4, abs(turn)));
	col += vec3(1.0, 0.95, 0.8) * smoothstep(0.3, 0.0, length(f - vec2(-0.3, -0.35))) * 0.55 * abs(turn);
	float halo = smoothstep(1.0, 0.3, length(p)) * 0.3;
	ALBEDO = mix(core_color.rgb, col, coin);
	ALPHA = clamp(max(coin, halo), 0.0, 1.0) * v_fade;
}
