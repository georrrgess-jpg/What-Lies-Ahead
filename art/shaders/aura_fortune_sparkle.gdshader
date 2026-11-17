shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Madame Fortuna's aura sparkles (scripts/cosmetics/operator_aura.gd): one
// MultiMesh of small quads; INSTANCE_CUSTOM.r is each sparkle's seed. The
// shader spirals every sparkle up round the operator, twinkles it as a
// four-point star and wraps its life, so nothing runs on the CPU. Alpha
// blended, so it shows on a transparent menu viewport.
uniform float radius = 0.62;
uniform float height = 2.1;
uniform float base = 0.05;
uniform float size = 0.05;
uniform float speed = 0.16;
uniform float strength = 1.0;
uniform vec3 red : source_color = vec3(1.0, 0.25, 0.38);
uniform vec3 gold : source_color = vec3(1.0, 0.82, 0.38);

varying float life;
varying float seed;

void vertex() {
	seed = INSTANCE_CUSTOM.r;
	life = fract(TIME * speed * (0.7 + 0.6 * fract(seed * 7.3)) + seed * 13.0);
	float turn = seed * 6.2832 + life * 4.0 + TIME * 0.3;
	float r = radius * (0.75 + 0.45 * fract(seed * 3.7)) * (1.0 - life * 0.25);
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 p = centre + vec3(cos(turn) * r, base + life * height, sin(turn) * r);
	vec4 view_pos = VIEW_MATRIX * vec4(p, 1.0);
	float s = size * (0.6 + 0.8 * fract(seed * 5.1)) * sin(life * 3.1416);
	view_pos.xy += VERTEX.xy * s;
	POSITION = PROJECTION_MATRIX * view_pos;
}

void fragment() {
	vec2 q = abs(UV * 2.0 - 1.0);
	float star = max(1.0 - (q.x * 6.0 + q.y), 0.0) + max(1.0 - (q.y * 6.0 + q.x), 0.0);
	star += exp(-dot(q, q) * 8.0) * 0.8;
	float twinkle = 0.6 + 0.4 * sin(TIME * 9.0 + seed * 40.0);
	float g = star * twinkle * strength * 1.6;
	ALBEDO = mix(mix(red, gold, fract(seed * 2.9)), vec3(1.0, 0.97, 0.9), clamp(g - 1.0, 0.0, 0.7));
	ALPHA = clamp(g, 0.0, 1.0);
}
