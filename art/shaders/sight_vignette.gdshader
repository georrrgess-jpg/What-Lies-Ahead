// Screen shading while aiming down sights (AimVignette): a soft darkening
// of the screen edges that draws the eye to the sight, and for a long scope
// the black surround of its eyepiece with a soft shadow inside the rim.
shader_type canvas_item;

// Edge darkening 0-1.
uniform float strength = 0.0;
// 0-1: how far the scope's surround has closed in.
uniform float scope = 0.0;
// The eyepiece on screen: centre (UV) and radius as a share of the screen height.
uniform vec2 centre = vec2(0.5, 0.5);
uniform float radius = 0.4;
// Screen width / height.
uniform float aspect = 1.7778;
uniform vec4 tint : source_color = vec4(0.03, 0.015, 0.07, 1.0);

void fragment() {
	vec2 d = (UV - 0.5) * vec2(aspect, 1.0);
	float alpha = smoothstep(0.42, 1.05, length(d)) * strength;
	float r = length((UV - centre) * vec2(aspect, 1.0)) / max(radius, 1e-4);
	float surround = smoothstep(1.0 - fwidth(r) * 1.5, 1.0, r);
	float shadow = smoothstep(0.72, 1.0, r) * 0.8;
	alpha = max(alpha, max(surround, shadow) * scope);
	COLOR = vec4(mix(tint.rgb, vec3(0.0), surround * scope), alpha);
}
