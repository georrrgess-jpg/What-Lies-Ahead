// The view through a weapon sight, drawn flat for menus (SightPreview): the
// window with its frame, a soft dusk backdrop behind the glass and the
// sight's reticle in the middle. Uses the same patterns as the lens in game.
shader_type canvas_item;

#include "res://art/shaders/sight_reticle.gdshaderinc"

uniform vec4 reticle_color : source_color = vec4(1.0, 0.2, 0.26, 1.0);
uniform vec4 frame_color : source_color = vec4(0.2, 0.16, 0.33, 1.0);
uniform vec4 accent_color : source_color = vec4(0.07, 0.71, 0.64, 1.0);
uniform int pattern = 0;
// 1 = round window, 0 = rectangle with rounded corners.
uniform float lens_round = 0.0;
// Reticle units from the centre to the edge of the window's short side.
uniform float extent = 2.6;
// Dark rim inside the window (tubes and scopes).
uniform float edge_shadow = 0.0;
// Control size divided by its shorter side.
uniform vec2 aspect = vec2(1.0, 1.0);

void fragment() {
	vec2 q = (UV * 2.0 - 1.0) * aspect;
	q.y = -q.y;
	// The window with its frame: signed distance to the outer edge, in units of the short side.
	vec2 half_size = mix(min(aspect, vec2(1.45, 1.0)), vec2(1.0), lens_round) * 0.94;
	float corner = mix(0.3, 0.94, lens_round);
	vec2 d = abs(q) - (half_size - corner);
	float edge = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - corner;
	float px = max(fwidth(edge), 1e-5);
	float shape = clamp(0.5 - edge / px, 0.0, 1.0);
	float border = 0.13;
	float glass = clamp(0.5 - (edge + border) / px, 0.0, 1.0);

	// Backdrop: dusk sky over a dark deck, with two out-of-focus lights.
	vec3 sky = mix(vec3(1.0, 0.56, 0.42), vec3(0.36, 0.2, 0.62), smoothstep(-0.2, 0.9, q.y));
	vec3 scene = mix(vec3(0.24, 0.1, 0.3), sky, smoothstep(-0.34, -0.26, q.y));
	scene += vec3(1.0, 0.8, 0.4) * smoothstep(0.2, 0.0, length(q - vec2(-0.5, 0.3))) * 0.35;
	scene += vec3(0.3, 0.9, 1.0) * smoothstep(0.16, 0.0, length(q - vec2(0.55, 0.05))) * 0.3;
	float streak = smoothstep(0.09, 0.0, abs(q.x * 0.55 + q.y - 0.45)) * 0.16;
	scene = mix(scene + streak, vec3(0.015, 0.03, 0.07), smoothstep(-0.5, 0.0, edge + border) * edge_shadow);

	vec2 p = q * extent / (1.0 - border);
	float rpx = max(length(fwidth(p)) * 0.7071, 1e-5);
	float mark = sight_reticle(p, pattern, vec2(rpx, 0.0));
	float outline = sight_reticle(p, pattern, vec2(rpx, rpx * 1.6));
	float halo = sight_reticle(p, pattern, vec2(max(rpx * 5.0, 0.3), rpx));
	vec3 lit = mix(reticle_color.rgb * 1.3, vec3(1.0), smoothstep(0.75, 1.0, mark) * 0.45);
	scene = mix(scene, reticle_color.rgb, halo * 0.45);
	scene = mix(scene, vec3(0.02, 0.01, 0.05), outline * 0.6);
	scene = mix(scene, lit, mark);

	// Frame: housing colour with an accent line along its middle.
	float mid = smoothstep(0.02, 0.0, abs(edge + border * 0.5) - 0.012);
	vec3 housing = mix(frame_color.rgb * (0.85 + 0.3 * smoothstep(-border, 0.0, edge)), accent_color.rgb, mid * 0.9);
	COLOR = vec4(mix(housing, scene, glass), shape);
}
