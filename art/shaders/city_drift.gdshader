shader_type spatial;
render_mode cull_disabled, shadows_disabled;

// Ashfall City things that cross the floor on their own (one MultiMesh):
// paper blown down the streets by the wind, tumbling and hopping, and (with
// `scurry`) rats darting along the Metro's walls, stopping, darting on.
// Each instance runs along its local +X from its origin. INSTANCE_CUSTOM:
// x phase (0..1), y run length (m), z speed (m/s), w hop height (m).
// Each fades in at the start of its run and out at the end.
uniform bool scurry = false;

float hash(float n) {
	return fract(sin(n * 91.7) * 43758.5453);
}

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float len = max(c.y, 1.0);
	float cycle = len / max(c.z, 0.1);
	float t = fract(TIME / cycle + c.x);
	float run = floor(TIME / cycle + c.x);
	float x;
	float y = 0.0;
	float side = 0.0;
	vec3 v = VERTEX;
	if (scurry) {
		// Darts: the run is spent in four bursts with stops between.
		float seg = t * 4.0;
		float k = floor(seg);
		float f = smoothstep(0.0, 0.55, fract(seg));
		x = (k + f) / 4.0 * len;
		// The tail swishes while it runs.
		v.x += sin(TIME * 30.0 + c.x * 9.0) * 0.03 * smoothstep(0.0, -0.15, v.z) * (1.0 - step(0.55, fract(seg)));
	} else {
		x = t * len;
		// Gusts lift the sheet and drop it; it tumbles while airborne.
		float hop = abs(sin(t * len * 0.35 + c.x * 17.0));
		y = c.w * hop * hop * (0.5 + 0.5 * hash(run + c.x * 13.0));
		side = sin(t * 6.2832 * 2.0 + c.x * 5.0) * 0.6;
		float spin = TIME * 5.0 + c.x * 40.0;
		float tilt = y * 2.5 + 0.15;
		mat3 roll = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(spin * tilt), sin(spin * tilt)), vec3(0.0, -sin(spin * tilt), cos(spin * tilt)));
		mat3 yaw = mat3(vec3(cos(spin * 0.3), 0.0, -sin(spin * 0.3)), vec3(0.0, 1.0, 0.0), vec3(sin(spin * 0.3), 0.0, cos(spin * 0.3)));
		v = yaw * (roll * v);
		NORMAL = yaw * (roll * NORMAL);
	}
	float fade = smoothstep(0.0, 0.05, t) * smoothstep(1.0, 0.95, t);
	VERTEX = v * fade + vec3(x, y, side);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.85;
	BACKLIGHT = COLOR.rgb * 0.3;
}
