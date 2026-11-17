shader_type spatial;
render_mode cull_disabled, shadows_disabled;

// Ashfall City birds (one MultiMesh of small birds facing -Z, wings along
// X): crows wheeling over the smoke, and pigeons that sit on the street until
// someone comes near (scripts/props/city_birds.gd flies those).
// INSTANCE_CUSTOM: x phase (0..1), y circling radius (0: the instance
// transform is the bird), z circling speed (rad/s, the sign the direction),
// w wing beat (0 = perched: wings folded, pecking; 1 = full beat).
uniform float beat_speed = 16.0;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float ph = c.x * 6.2832;
	float wing = smoothstep(0.08, 0.3, abs(VERTEX.x));
	float flap = c.w;
	if (c.y > 0.0) {
		// Crows: a few beats, then a long glide.
		flap = 0.25 + 0.75 * smoothstep(0.2, 0.7, sin(TIME * 0.6 + ph * 3.0));
	}
	// Folded wings when perched, a beat that lifts the tips in flight.
	VERTEX.x *= mix(0.35, 1.0, min(flap * 4.0, 1.0)) * wing + (1.0 - wing);
	VERTEX.y += sin(TIME * beat_speed * (0.8 + c.x * 0.4) + ph * 7.0) * abs(VERTEX.x) * 0.9 * flap * wing;
	// Perched: a peck now and then (the head end dips).
	float peck = step(0.8, fract(TIME * 0.6 + c.x * 5.0)) * (1.0 - min(flap * 4.0, 1.0));
	VERTEX.y -= peck * smoothstep(0.0, -0.2, VERTEX.z) * 0.08;
	if (c.y > 0.0) {
		float a = TIME * c.z + ph;
		vec3 dir = vec3(-sin(a), 0.0, cos(a)) * sign(c.z);
		float yaw = atan(-dir.x, -dir.z);
		float roll = 0.35 * sign(c.z);
		mat3 r_roll = mat3(vec3(cos(roll), sin(roll), 0.0), vec3(-sin(roll), cos(roll), 0.0), vec3(0.0, 0.0, 1.0));
		mat3 r_yaw = mat3(vec3(cos(yaw), 0.0, -sin(yaw)), vec3(0.0, 1.0, 0.0), vec3(sin(yaw), 0.0, cos(yaw)));
		VERTEX = r_yaw * (r_roll * VERTEX);
		NORMAL = r_yaw * (r_roll * NORMAL);
		// The instance's scale is the bird's size: the path is in metres.
		VERTEX += vec3(cos(a) * c.y, sin(a * 2.3 + ph) * 1.5, sin(a) * c.y) / length(MODEL_MATRIX[0].xyz);
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.8;
}
