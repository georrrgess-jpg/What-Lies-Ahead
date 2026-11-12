// Lens of a weapon optic: lightly tinted clear glass with a collimated reticle.
//
// The reticle is not painted on the glass. Each fragment works out the angle
// between its view ray and the point of aim (aim_basis, set every frame by
// WeaponView from the player's true aim) and draws the pattern in that angle
// space. Like a real red dot, the reticle therefore stays on the point of
// impact while the weapon and its sight sway around it, and it is only seen
// through the window.
//
// preview = 1 paints the reticle on the glass instead (menus, thumbnails),
// where there is no aim to follow.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://art/shaders/sight_reticle.gdshaderinc"

uniform vec4 glass_color : source_color = vec4(0.6, 0.92, 1.0, 0.06);
uniform vec4 reticle_color : source_color = vec4(1.0, 0.25, 0.3, 1.0);
uniform int pattern = 0;
// Tangent of the angle one reticle unit spans.
uniform float reticle_size = 0.021;
uniform float brightness = 1.5;
// Strength of the soft halo around the reticle.
uniform float glow = 1.0;
// Half-size of the window, with the longer side = 1.
uniform vec2 lens_aspect = vec2(1.0, 1.0);
// 1 = round window, 0 = rectangle with rounded corners.
uniform float lens_round = 0.0;
uniform float corner = 0.3;
// The point of aim in view space: columns right, up, back.
uniform mat3 aim_basis = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0));
// Reticle strength 0-1.
uniform float power = 1.0;
// 1 = dark, closed glass (a scope carried at the hip); 0 = clear.
uniform float occlude = 0.0;
// Darkening toward the rim (a tube's shadow).
uniform float edge_shadow = 0.0;
uniform float preview = 0.0;
// Reticle units across half the window in previews.
uniform float preview_scale = 2.6;

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y) * 2.0 - 1.0;
	vec2 q = uv * lens_aspect;
	float edge = length(uv) - 1.0;
	if (lens_round < 0.5) {
		vec2 d = abs(q) - (lens_aspect - corner);
		edge = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - corner;
	}
	float inside = clamp(0.5 - edge / max(fwidth(edge), 1e-5), 0.0, 1.0);

	vec3 local = -VIEW * aim_basis;
	vec2 p = local.xy / max(-local.z, 1e-4) / reticle_size;
	float facing = step(0.2, -local.z);
	if (preview > 0.5) {
		p = q * preview_scale;
		facing = 1.0;
	}
	float px = max(length(fwidth(p)) * 0.7071, 1e-5);
	float mark = sight_reticle(p, pattern, vec2(px, 0.0)) * facing * power;
	// A dark edge keeps the reticle readable on any background; a soft halo makes it glow.
	float outline = sight_reticle(p, pattern, vec2(px, px * 1.6)) * facing * power;
	float halo = sight_reticle(p, pattern, vec2(max(px * 5.0, 0.3), px)) * facing * power * glow;

	// Glass: a faint tint, two reflection streaks and a brighter grazing edge...
	float streak = smoothstep(0.1, 0.0, abs(uv.x * 0.55 + uv.y - 0.4)) * 0.6
		+ smoothstep(0.035, 0.0, abs(uv.x * 0.55 + uv.y - 0.12)) * 0.35;
	float graze = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	float sheen = clamp(glass_color.a * (1.0 + streak * 1.6) + graze * 0.35, 0.0, 1.0);
	// ...under the dark of a tube's rim or of a closed scope.
	float shadow = clamp(max(smoothstep(-0.4, 0.0, edge) * edge_shadow, occlude * 0.96), 0.0, 1.0);
	float alpha = sheen + shadow * (1.0 - sheen);
	vec3 dark = vec3(0.012, 0.02, 0.05) + streak * 0.1 * occlude;
	vec3 glass = (dark * shadow + (glass_color.rgb + streak * 0.25) * sheen * (1.0 - shadow)) / max(alpha, 1e-4);

	// Reticle: white-hot where it is solid, its colour at the edges and in the halo.
	vec3 lit = mix(reticle_color.rgb * brightness, vec3(1.0), smoothstep(0.75, 1.0, mark) * 0.45);
	vec3 color = mix(glass, reticle_color.rgb * brightness, halo * 0.45);
	color = mix(color, vec3(0.02, 0.01, 0.05), outline * 0.6);
	ALBEDO = mix(color, lit, mark);
	ALPHA = max(alpha, max(mark, max(outline * 0.6, halo * 0.4))) * inside;
}
