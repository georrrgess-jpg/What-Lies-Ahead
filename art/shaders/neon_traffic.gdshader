shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

// The city street far below: dark wet asphalt with lane lines and streaks of
// traffic. UV.x runs along the street. Lanes on one half flow one way with
// white-gold headlights, the other half the opposite way with red tail
// lights; a few cyan and magenta hover cars mix in.
uniform float length_metres = 200.0;
uniform float lanes = 6.0;
uniform float speed = 0.06;
uniform float density = 0.35;
uniform float glow = 2.6;
uniform vec3 asphalt : source_color = vec3(0.025, 0.02, 0.05);

float hash(float x) {
	return fract(sin(x * 51.7) * 43758.5453);
}

void fragment() {
	float lane_f = UV.y * lanes;
	float lane = floor(lane_f);
	float across = fract(lane_f);
	bool forward = lane < lanes * 0.5;
	float dir = forward ? 1.0 : -1.0;
	float h = hash(lane + 3.0);
	float x = UV.x * length_metres / 6.0;
	float t = TIME * speed * length_metres / 6.0 * (0.8 + 0.5 * h);
	float pos = x - dir * t + h * 13.0;
	float slot = floor(pos);
	float f = fract(pos);
	float car = step(1.0 - density, hash(slot + lane * 7.1));
	float body = smoothstep(0.0, 0.12, f) * smoothstep(0.75, 0.35, f);
	float in_lane = smoothstep(0.42, 0.18, abs(across - 0.5));
	float kind = hash(slot * 1.3 + lane);
	vec3 light = forward ? vec3(1.0, 0.86, 0.6) : vec3(1.0, 0.16, 0.22);
	if (kind > 0.86) {
		light = kind > 0.93 ? vec3(0.25, 0.95, 1.0) : vec3(1.0, 0.3, 0.85);
	}
	// Painted lane dashes.
	float dash = step(0.92, fract(lane_f)) * step(0.5, fract(UV.x * length_metres / 3.0)) * 0.15;
	vec3 col = asphalt + vec3(0.6, 0.55, 0.7) * dash + light * car * body * in_lane * glow;
	ALBEDO = col;
}
