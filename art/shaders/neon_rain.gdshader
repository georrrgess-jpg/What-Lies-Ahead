shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Rain streaks on open cylinders that follow the camera (see
// scripts/run/neon_skyline_environment.gd). UV.x runs around the cylinder,
// UV.y top to bottom. Each column holds a few falling streaks with their own
// speed and phase; they fade out at the top and bottom of the cylinder.
uniform vec3 rain_color : source_color = vec3(0.55, 0.7, 1.0);
uniform float columns = 160.0;
uniform float streaks = 3.0;
uniform float speed = 2.4;
uniform float streak_length = 0.16;
uniform float width = 0.06;
uniform float strength = 0.22;
uniform float slant = 0.04;

float hash(float x) {
	return fract(sin(x * 78.233) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	uv.x += uv.y * slant;
	float col_id = floor(uv.x * columns);
	float fx = fract(uv.x * columns);
	float h = hash(col_id);
	float h2 = hash(col_id + 17.0);
	float line = smoothstep(width, 0.0, abs(fx - 0.5 - (h - 0.5) * 0.6));
	float y = uv.y * streaks + TIME * speed * (0.75 + 0.5 * h2) + h * 7.0;
	float seg = fract(y);
	float drop = smoothstep(streak_length, 0.0, seg) * smoothstep(0.0, 0.02, seg);
	float fade = smoothstep(0.0, 0.15, UV.y) * smoothstep(1.0, 0.75, UV.y);
	float a = line * drop * fade * (0.5 + 0.5 * h2);
	ALBEDO = rain_color * a * strength;
}
