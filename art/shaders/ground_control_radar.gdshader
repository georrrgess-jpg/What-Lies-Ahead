shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

// Ground Control's round radar screen: a dark green scope with range rings,
// a lime sweep wedge turning round it and blips where zombies are (`blips`,
// on the disc -1..1, up = ahead of the player; `blip_count` of them). A
// stall turns it to static (`static_amount`); `charge` brightens the rings.
uniform vec3 lime : source_color = vec3(0.66, 0.9, 0.24);
uniform vec3 base : source_color = vec3(0.02, 0.12, 0.05);
uniform float sweep_speed = 3.0;
uniform float static_amount : hint_range(0.0, 1.0) = 0.0;
uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform int blip_count = 0;
uniform vec2 blips[6];
// The screen disc in the model: its radius and two in-plane axes (ahead, right).
uniform float screen_radius = 0.025;
uniform vec3 ahead_axis = vec3(0.0, 0.0, -1.0);
uniform vec3 right_axis = vec3(0.53, 0.848, 0.0);

varying vec3 local;

void vertex() {
	local = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = vec2(dot(local, right_axis), dot(local, ahead_axis)) / screen_radius;
	float r = length(p);
	float rings = 0.0;
	for (int i = 1; i <= 3; i++) {
		rings += 1.0 - smoothstep(0.0, 0.025, abs(r - float(i) / 3.2));
	}
	float cross_lines = (1.0 - smoothstep(0.0, 0.015, abs(p.x))) + (1.0 - smoothstep(0.0, 0.015, abs(p.y)));
	float sweep_angle = mod(TIME * sweep_speed, 6.2831853);
	float a = mod(atan(p.x, p.y) + 6.2831853, 6.2831853);
	float behind = mod(sweep_angle - a + 6.2831853, 6.2831853);
	float wedge = exp(-behind * 2.2) * step(r, 0.98);
	float blip_light = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= blip_count) {
			break;
		}
		vec2 b = blips[i];
		float ba = mod(atan(b.x, b.y) + 6.2831853, 6.2831853);
		float since = mod(sweep_angle - ba + 6.2831853, 6.2831853);
		float lit = 0.35 + 0.65 * exp(-since * 0.9);
		blip_light += (1.0 - smoothstep(0.05, 0.09, length(p - b))) * lit;
	}
	vec3 col = base + lime * (rings * (0.25 + charge * 0.5) + cross_lines * 0.12 + wedge * 0.7) + vec3(1.0, 0.5, 0.75) * blip_light;
	float noise = hash(floor(p * 24.0) + floor(TIME * 30.0));
	col = mix(col, vec3(noise * 0.8 + 0.1), static_amount);
	col *= step(r, 1.0);
	ALBEDO = col;
}
