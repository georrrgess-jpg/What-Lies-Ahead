shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

// A theatre marquee's border of chasing bulbs on a strip (a QuadMesh or a
// box face, UV.x along it): `bulbs` round bulbs on dark chrome, every
// `chase`-th one lit in turn, the rest glowing low. One pass, no textures.
uniform vec3 bulb_color : source_color = vec3(1.0, 0.82, 0.45);
uniform vec3 back_color : source_color = vec3(0.12, 0.08, 0.06);
uniform float bulbs = 24.0;
uniform float rows = 1.0;
uniform float chase = 3.0;
uniform float speed = 6.0;
uniform float strength = 2.4;

void fragment() {
	vec2 cell = vec2(UV.x * bulbs, UV.y * rows);
	vec2 f = fract(cell) - 0.5;
	float index = floor(cell.x) + floor(cell.y);
	float lit = step(mod(index + floor(TIME * speed), chase), 0.5);
	float bulb = smoothstep(0.36, 0.26, length(f));
	float glow = smoothstep(0.5, 0.0, length(f)) * 0.35;
	vec3 col = back_color + bulb_color * (bulb * mix(0.25, 1.0, lit) + glow * lit) * strength;
	ALBEDO = col;
}
