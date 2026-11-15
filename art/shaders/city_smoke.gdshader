shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// A far fire's smoke column on one card that turns to face the camera about
// its vertical axis (scenes/props/city_smoke_column.tscn). Billowing puffs rise,
// widen and lean with the wind; dark ash-brown above, lit ember-orange at the
// base. The card's base is at the node origin; scale the node to size it.
uniform vec3 smoke_color : source_color = vec3(0.17, 0.13, 0.14);
uniform vec3 rim_color : source_color = vec3(0.55, 0.32, 0.3);
uniform vec3 under_color : source_color = vec3(1.0, 0.4, 0.12);
uniform float opacity = 0.85;
uniform float speed = 0.04;
uniform float lean = 0.22;
uniform float under_glow = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise(p) * a;
		p = p * 2.07 + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return v;
}

varying float seed;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	seed = fract(sin(dot(MODEL_MATRIX[3].xyz, vec3(12.9898, 78.233, 37.719))) * 43758.5453) * 40.0;
}

void fragment() {
	float h = 1.0 - UV.y;
	float t = TIME * speed + seed;
	float x = (UV.x - 0.5 - h * h * lean) / mix(0.1, 0.48, pow(h, 0.65));
	float n = fbm(vec2(x * 1.3 + seed, h * 3.2 - t * 3.0));
	float body = 1.0 - smoothstep(0.5, 1.05, abs(x) + (n - 0.5) * 0.9);
	body *= smoothstep(0.0, 0.04, h) * (1.0 - smoothstep(0.7, 1.0, h + (n - 0.5) * 0.3));
	float puff = smoothstep(0.3, 0.75, n);
	vec3 col = mix(smoke_color, rim_color, smoothstep(0.55, 0.85, n) * 0.4);
	col = mix(col, under_color, (1.0 - smoothstep(0.0, 0.3, h)) * under_glow * (0.55 + 0.45 * puff));
	ALBEDO = col;
	ALPHA = clamp(body * mix(0.5, 1.0, puff) * opacity, 0.0, 1.0);
}
