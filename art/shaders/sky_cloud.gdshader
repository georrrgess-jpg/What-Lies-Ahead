shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// A puffy cumulus on a card that turns to face the camera about its vertical
// axis (the cloud banks round the islands): a lumpy silhouette from stacked
// round puffs and noise, lit warm from the sun side, lilac underneath.
// `seed` varies the shape; `drift` makes it churn slowly.
uniform vec3 lit_color : source_color = vec3(1.0, 0.95, 0.9);
uniform vec3 warm_color : source_color = vec3(1.0, 0.78, 0.6);
uniform vec3 shade_color : source_color = vec3(0.7, 0.7, 0.88);
uniform float seed = 0.0;
uniform float opacity = 0.95;
uniform float drift = 0.02;
// Side of the card the sun is on (-1 left, 1 right), set per card.
uniform float sun_side = 1.0;

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
		p = p * 2.1 + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	// Face the camera about the card's own up axis, keeping its scale.
	vec3 up = MODEL_MATRIX[1].xyz;
	vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz)) * length(MODEL_MATRIX[0].xyz);
	vec3 fwd = normalize(cross(right, up));
	mat4 bill = mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * bill;
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float body = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		vec2 c = vec2(0.18 + 0.16 * fi + (hash12(vec2(fi, seed)) - 0.5) * 0.08, 0.3 + hash12(vec2(seed, fi)) * 0.18 - abs(fi - 2.0) * 0.06);
		float r = 0.16 + hash12(vec2(fi * 3.1, seed + 1.0)) * 0.1 + (2.0 - abs(fi - 2.0)) * 0.03;
		body = max(body, 1.0 - length((uv - c) / vec2(1.0, 1.1)) / r);
	}
	float n = fbm(uv * 6.0 + vec2(seed * 7.0, TIME * drift));
	body += (n - 0.5) * 0.5;
	body *= smoothstep(0.08, 0.2, uv.y);
	// Keep every puff inside the card: fade out toward its edges.
	body -= (1.0 - smoothstep(0.0, 0.18, uv.x) * smoothstep(1.0, 0.82, uv.x) * smoothstep(1.0, 0.78, uv.y)) * 0.8;
	float top = smoothstep(0.15, 0.7, uv.y);
	float side = clamp(0.5 + (uv.x - 0.5) * sun_side, 0.0, 1.0);
	vec3 col = mix(shade_color, lit_color, clamp(top * 0.8 + n * 0.35, 0.0, 1.0));
	col = mix(col, warm_color, side * top * 0.45);
	ALBEDO = col;
	ALPHA = smoothstep(0.0, 0.12, body) * opacity;
}
