shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Steam rising from a roof vent: soft puffs drift up a vertical card, the
// plume widening, swaying and thinning as it climbs. UV.y = 1 at the vent.
uniform vec3 steam_color : source_color = vec3(0.62, 0.56, 0.95);
uniform float strength = 0.55;
uniform float speed = 0.4;
uniform float time_offset = 0.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float h = 1.0 - UV.y;                       // 0 at the vent, 1 at the top
	float t = TIME * speed + time_offset;
	float sway = (noise(vec2(h * 2.0 - t * 0.7, 7.0)) - 0.5) * 0.3 * h;
	float x = UV.x - 0.5 - sway;
	float width = mix(0.14, 0.48, h);
	float column = smoothstep(width, 0.0, abs(x));
	vec2 p = vec2(x * 5.0, h * 4.0 - t * 2.2);
	float puffs = noise(p) * 0.6 + noise(p * 2.3 + 3.1) * 0.4;
	float fade = smoothstep(0.0, 0.06, h) * pow(1.0 - h, 1.6);
	ALBEDO = steam_color * column * fade * (0.3 + 0.7 * smoothstep(0.3, 0.75, puffs)) * strength;
}
