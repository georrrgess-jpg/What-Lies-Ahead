shader_type spatial;
render_mode cull_back, shadows_disabled;

// Fish, sharks and rays swimming behind glass, entirely on the GPU. Used on a
// MultiMesh: each instance transform places the centre of an orbit (with a
// uniform scale for the animal's size) and INSTANCE_CUSTOM carries
// (radius_x, radius_z, angular speed in rad/s (sign = direction), phase).
// The animal follows the ellipse, turns to face along it, bobs, optionally
// rises over obstacles at the ends of the orbit (`lift`, e.g. the walk-through
// tunnel), and its body flexes with a travelling wave toward the tail.
// The mesh faces +Z with its nose at +body_length/2.
uniform vec3 albedo : source_color = vec3(1.0, 0.5, 0.2);
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float roughness = 0.5;
uniform float body_length = 0.4;
uniform float wiggle = 0.06;
uniform float wiggle_freq = 7.0;
uniform float bob = 0.25;
// Extra height at the two ends of the long axis (cos(angle)^2 shaped).
uniform float lift = 0.0;
// Rays flap instead of wiggling: wing tips (|x| large) move up and down.
uniform float flap = 0.0;

void vertex() {
	vec4 c = INSTANCE_CUSTOM;
	float a = c.w + TIME * c.z;
	float dir = c.z < 0.0 ? -1.0 : 1.0;
	float ca = cos(a);
	float sa = sin(a);
	vec3 p = vec3(ca * c.x, sin(a * 2.0 + c.w * 3.0) * bob + lift * ca * ca, sa * c.y);
	vec3 tng = vec3(-sa * c.x, 0.0, ca * c.y) * dir;
	float yaw = atan(tng.x, tng.z + 1e-5);
	float k = clamp(0.5 - VERTEX.z / body_length, 0.0, 1.0);
	float phase = TIME * wiggle_freq + c.w * 5.0;
	VERTEX.x += sin(phase - VERTEX.z * 7.0) * wiggle * k * k;
	VERTEX.y += sin(phase * 0.5 + 1.0) * flap * VERTEX.x * VERTEX.x;
	mat3 r = mat3(vec3(cos(yaw), 0.0, -sin(yaw)), vec3(0.0, 1.0, 0.0), vec3(sin(yaw), 0.0, cos(yaw)));
	VERTEX = r * VERTEX;
	NORMAL = r * NORMAL;
	float sc = max(0.001, length(MODEL_MATRIX[0].xyz));
	VERTEX += p / sc;
}

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	SPECULAR = 0.5;
	EMISSION = emission * emission_energy;
	// A little rim light so silhouettes read against the blue.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION += albedo * rim * 0.35;
}
